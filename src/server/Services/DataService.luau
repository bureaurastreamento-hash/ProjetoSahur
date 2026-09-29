--!strict
--[[
	DataService (servidor)
	Persistência do jogador em DataStore: moedas, personagens desbloqueados, estatísticas.

	Garantias:
	  - A entrada do jogador NUNCA trava: se o load falhar após os retries, ele joga
	    com um perfil padrão marcado sessionOnly = true, e esse perfil NÃO é salvo
	    (para não sobrescrever dados bons com dados vazios).
	  - Saves usam UpdateAsync com retry; autosave periódico, save ao sair e BindToClose.
	  - Toda escrita passa por esta API; ninguém mais toca no DataStore.

	Replicação: NotifyProfile(profile, sessionOnly) para o dono; atributo Coins no Player.
	Teste de falha: DataConfig.SimulateFailure = true, ou desligar
	"Enable Studio Access to API Services" em Game Settings > Security.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local DataConfig = require(Modules:WaitForChild("DataConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local StandConfig = require(Modules:WaitForChild("StandConfig"))
local Controls = require(Modules:WaitForChild("Controls"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))

local unlockLimiter = RateLimiter.new(2, 1)

local DataService = {}

type Session = {
	profile: DataConfig.Profile,
	sessionOnly: boolean, -- true = load falhou; não salvar
	dirty: boolean,
	loaded: boolean,
	saving: boolean,
}

local sessions: { [Player]: Session } = {}
local store: DataStore? = nil
local notifyProfile: RemoteEvent

--- Disparado quando o perfil de um jogador termina de carregar: (player, profile, sessionOnly)
DataService.ProfileLoaded = Instance.new("BindableEvent")

-- ---------------------------------------------------------------------------
-- DataStore com retry
-- ---------------------------------------------------------------------------

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function withRetry(label: string, attempts: number, fn: () -> any): (boolean, any)
	local delaySeconds = DataConfig.RetryBaseDelay
	local lastErr: any = nil
	for attempt = 1, attempts do
		if DataConfig.SimulateFailure then
			lastErr = "SimulateFailure ativo"
		else
			local ok, result = pcall(fn)
			if ok then
				return true, result
			end
			lastErr = result
		end
		warn(("[DataService] %s falhou (tentativa %d/%d): %s"):format(label, attempt, attempts, tostring(lastErr)))
		if attempt < attempts then
			task.wait(delaySeconds)
			delaySeconds *= 2
		end
	end
	return false, lastErr
end

--- Ids de personagem que MUDARAM de nome (2026-09-21: Brawler/Mystic/Guardian saíram; Jotaro/Kira/Dio
--- herdaram os kits). Aplicado em todo carregamento (idempotente), sem trocar o schema.
local RENAMED_CHARACTERS: { [string]: string } = { Brawler = "Jotaro", Mystic = "Kira", Guardian = "Dio" }
local function renameCharacter(id: any): any
	return if typeof(id) == "string" then (RENAMED_CHARACTERS[id] or id) else id
end

local function copyTrueFlags(incoming: any, target: { [string]: boolean })
	if typeof(incoming) ~= "table" then return end
	for id, value in incoming do
		if typeof(id) == "string" and value == true then target[id] = true end
	end
end

local function migrate(raw: any): DataConfig.Profile
	local profile = DataConfig.DefaultProfile()
	if typeof(raw) ~= "table" then
		return profile
	end
	-- Copia campos conhecidos com validação de tipo; o resto fica no default.
	if typeof(raw.coins) == "number" and raw.coins >= 0 then
		profile.coins = math.floor(raw.coins)
	end
	if typeof(raw.eventPoints) == "number" and raw.eventPoints >= 0 then
		profile.eventPoints = math.floor(raw.eventPoints) -- schema 3
	end
	if typeof(raw.unlockedCharacters) == "table" then
		for _, rawId in raw.unlockedCharacters do
			local id = renameCharacter(rawId)
			if typeof(id) == "string" and CharacterDefs.Get(id) and not table.find(profile.unlockedCharacters, id) then
				table.insert(profile.unlockedCharacters, id)
			end
		end
	end
	if typeof(raw.stats) == "table" then
		for k, v in profile.stats :: any do
			local incoming = (raw.stats :: any)[k]
			if typeof(incoming) == "number" and incoming >= 0 then
				(profile.stats :: any)[k] = math.floor(incoming)
			end
		end
	end
	-- progressão (campos novos; perfis antigos ficam no default)
	if typeof(raw.xp) == "number" and raw.xp >= 0 then
		profile.xp = math.floor(raw.xp)
	end
	if typeof(raw.level) == "number" and raw.level >= 1 then
		profile.level = math.floor(raw.level)
	end
	if typeof(raw.daily) == "table" then
		local d = raw.daily :: any
		if typeof(d.lastDay) == "number" and typeof(d.streak) == "number" then
			profile.daily = { lastDay = math.floor(d.lastDay), streak = math.max(0, math.floor(d.streak)) }
		end
	end
	if typeof(raw.missions) == "table" and typeof((raw.missions :: any).day) == "number" and typeof((raw.missions :: any).list) == "table" then
		local list: { DataConfig.Mission } = {}
		for _, m in (raw.missions :: any).list do
			if typeof(m) == "table" and typeof(m.id) == "string" and typeof(m.progress) == "number" then
				table.insert(list, { id = m.id, progress = math.floor(m.progress), done = m.done == true })
			end
		end
		profile.missions = { day = math.floor((raw.missions :: any).day), list = list }
	end
	-- cosméticos/emotes (campos novos)
	if typeof(raw.cosmetics) == "table" then
		local c = raw.cosmetics :: any
		if typeof(c.owned) == "table" then
			for _, id in c.owned do
				if typeof(id) == "string" then
					table.insert(profile.cosmetics.owned, id)
				end
			end
		end
		if typeof(c.equipped) == "table" then
			for category, id in c.equipped do
				if typeof(category) == "string" and typeof(id) == "string" then
					profile.cosmetics.equipped[category] = id
				end
			end
		end
	end
	if typeof(raw.emotes) == "table" then
		for _, id in raw.emotes do
			if typeof(id) == "string" then
				table.insert(profile.emotes, id)
			end
		end
	end
	if typeof(raw.mastery) == "table" then
		for rawId, xp in raw.mastery do
			local id = renameCharacter(rawId)
			if typeof(id) == "string" and typeof(xp) == "number" and xp >= 0 then
				profile.mastery[id] = (profile.mastery[id] or 0) + math.floor(xp)
			end
		end
	end
	if typeof(raw.rating) == "number" and raw.rating >= 0 then
		profile.rating = math.floor(raw.rating)
	end
	if typeof(raw.clanTag) == "string" and raw.clanTag ~= "" then
		profile.clanTag = raw.clanTag
	end
	if typeof(raw.settings) == "table" then
		for k, v in raw.settings do
			if Controls.ValidateSetting(k, v) ~= nil then
				profile.settings[k] = v
			end
		end
	end
	-- conquistas (schema 2). Perfil antigo (só missões): os contadores começam do que já dá para
	-- saber pelas estatísticas, para ninguém perder o que já jogou.
	if typeof(raw.achievements) == "table" then
		local a = raw.achievements :: any
		if typeof(a.counters) == "table" then
			for kind, value in a.counters do
				if typeof(kind) == "string" and typeof(value) == "number" and value >= 0 then
					profile.achievements.counters[kind] = math.floor(value)
				end
			end
		end
		if typeof(a.done) == "table" then
			for id, done in a.done do
				if typeof(id) == "string" and done == true then
					profile.achievements.done[id] = true
				end
			end
		end
		if typeof(a.season) == "table" and typeof((a.season :: any).id) == "string" then
			local counters: { [string]: number } = {}
			if typeof((a.season :: any).counters) == "table" then
				for kind, value in (a.season :: any).counters do
					if typeof(kind) == "string" and typeof(value) == "number" and value >= 0 then
						counters[kind] = math.floor(value)
					end
				end
			end
			profile.achievements.season = { id = (a.season :: any).id, counters = counters }
		end
	elseif typeof(raw.schemaVersion) == "number" and raw.schemaVersion < 2 then
		profile.achievements.counters.kills = profile.stats.kills
		profile.achievements.counters.level = profile.level
	end
	-- quests (história em capítulos, 2026-09-22; sem trocar o schema: perfil sem o campo começa do 1)
	if typeof(raw.quests) == "table" then
		local q = raw.quests :: any
		if typeof(q.chapter) == "number" and q.chapter >= 1 then
			profile.quests.chapter = math.floor(q.chapter)
		end
		profile.quests.active = q.active == true
		if typeof(q.counters) == "table" then
			for kind, value in q.counters do
				if typeof(kind) == "string" and typeof(value) == "number" and value >= 0 then
					profile.quests.counters[kind] = math.floor(value)
				end
			end
		end
		if typeof(q.done) == "table" then
			for id, done in q.done do
				if typeof(id) == "string" and done == true then
					profile.quests.done[id] = true
				end
			end
		end
	end
	-- Fundação F/X (2026-09-28). Mantida no mesmo DataStore v4 para não abandonar os saves existentes.
	if typeof(raw.world) == "table" then
		local w = raw.world :: any
		if typeof(w.region) == "string" then profile.world.region = w.region end
		if typeof(w.checkpoint) == "string" then profile.world.checkpoint = w.checkpoint end
		if typeof(w.discovered) == "table" then
			for id, discovered in w.discovered do
				if typeof(id) == "string" and discovered == true then profile.world.discovered[id] = true end
			end
		end
	end
	if typeof(raw.story) == "table" then
		local s = raw.story :: any
		profile.story.rev = if typeof(s.rev) == "number" then s.rev else 1 -- sem rev = atos antigos (StoryService.migrate)
		if typeof(s.chapter) == "string" then profile.story.chapter = s.chapter end
		if typeof(s.act) == "number" and s.act >= 1 then profile.story.act = math.floor(s.act) end
		if typeof(s.counters) == "table" then
			for id, value in s.counters do
				if typeof(id) == "string" and typeof(value) == "number" and value >= 0 then profile.story.counters[id] = math.floor(value) end
			end
		end
		copyTrueFlags(s.flags, profile.story.flags)
		copyTrueFlags(s.traces, profile.story.traces)
		copyTrueFlags(s.completed, profile.story.completed)
	end
	-- log de atualização (schema 4): versão já vista; perfil antigo = "" (vê a publicada na próxima entrada)
	if typeof(raw.lastUpdateSeen) == "string" then
		profile.lastUpdateSeen = raw.lastUpdateSeen:sub(1, 16)
	end
	-- Stands/raças/inventário (schema 5)
	if typeof(raw.power) == "string" and StandConfig.IsStand(raw.power) then
		profile.power = raw.power
	end
	if typeof(raw.race) == "string" and StandConfig.GetRace(raw.race) then
		profile.race = raw.race
	end
	if typeof(raw.inventory) == "table" then
		for id, n in raw.inventory do
			if typeof(id) == "string" and typeof(n) == "number" and n >= 1 and StandConfig.ItemInfo(id) then
				profile.inventory[id] = math.floor(n)
			end
		end
	end
	profile.born = raw.born == true
	profile.schemaVersion = DataConfig.SchemaVersion
	return profile
end

-- ---------------------------------------------------------------------------
-- Load / Save
-- ---------------------------------------------------------------------------

local function pushToClient(player: Player, session: Session)
	player:SetAttribute("Coins", session.profile.coins)
	player:SetAttribute("EventPoints", session.profile.eventPoints)
	notifyProfile:FireClient(player, session.profile, session.sessionOnly)
end

local function load(player: Player)
	local session: Session = {
		profile = DataConfig.DefaultProfile(),
		sessionOnly = true,
		dirty = false,
		loaded = false,
		saving = false,
	}
	sessions[player] = session

	local ok, raw = withRetry("GetAsync " .. player.Name, DataConfig.LoadRetries, function()
		assert(store, "DataStore indisponível")
		return store:GetAsync(keyFor(player))
	end)

	if player.Parent ~= Players then
		sessions[player] = nil
		return
	end

	if ok then
		session.profile = migrate(raw)
		-- SERVIDOR PRIVADO (dono, 2026-09-22): NADA salva — nem pontos, nem itens, nem quests. O perfil carrega
		-- (o jogador usa o que já tem) e fica só na sessão; DataService.IsSessionOnly = true bloqueia compras.
		session.sessionOnly = game.PrivateServerId ~= ""
		if session.sessionOnly then
			Log.debug(("[DataService] %s em servidor PRIVADO: perfil carregado, nada será salvo"):format(player.Name))
		end
		Log.debug(("[DataService] %s carregado: %d moedas, %d personagens, %d vitórias"):format(
			player.Name, session.profile.coins, #session.profile.unlockedCharacters, session.profile.stats.wins))
	else
		session.sessionOnly = true
		warn(("[DataService] %s jogando com perfil TEMPORÁRIO (não será salvo): %s"):format(player.Name, tostring(raw)))
	end
	session.loaded = true
	pushToClient(player, session)
	DataService.ProfileLoaded:Fire(player, session.profile, session.sessionOnly)
end

local function save(player: Player, reason: string): boolean
	local session = sessions[player]
	if not session or not session.loaded or session.sessionOnly or session.saving then
		return false
	end
	if not session.dirty and reason ~= "leave" and reason ~= "close" then
		return true
	end
	session.saving = true
	local snapshot = session.profile
	local ok, err = withRetry(("UpdateAsync %s (%s)"):format(player.Name, reason), DataConfig.SaveRetries, function()
		assert(store, "DataStore indisponível")
		return store:UpdateAsync(keyFor(player), function(_old)
			return snapshot
		end)
	end)
	session.saving = false
	if ok then
		session.dirty = false
		Log.debug(("[DataService] %s salvo (%s)"):format(player.Name, reason))
	else
		warn(("[DataService] %s NÃO salvo (%s): %s"):format(player.Name, reason, tostring(err)))
	end
	return ok
end

-- ---------------------------------------------------------------------------
-- API pública
-- ---------------------------------------------------------------------------

function DataService.GetProfile(player: Player): DataConfig.Profile?
	local session = sessions[player]
	return if session and session.loaded then session.profile else nil
end

function DataService.IsSessionOnly(player: Player): boolean
	local session = sessions[player]
	return session == nil or session.sessionOnly
end

local function touch(player: Player)
	local session = sessions[player]
	if session then
		session.dirty = true
		pushToClient(player, session)
	end
end

--- Marca o perfil como alterado (salva no próximo autosave) e reenvia ao cliente.
--- Para services que mexem direto em campos do perfil (ProgressionService).
function DataService.MarkDirty(player: Player)
	touch(player)
end

function DataService.AddCoins(player: Player, amount: number)
	local profile = DataService.GetProfile(player)
	if not profile or amount == 0 then
		return
	end
	profile.coins = math.max(0, math.floor(profile.coins + amount))
	touch(player)
end

--- Recompensa de jogo (kill, duelo, boss, missão, nível): aplica o multiplicador do passe
--- "Moedas x2" (Player attr CoinMultiplier, ShopService). Retorna o valor realmente dado.
function DataService.RewardCoins(player: Player, amount: number): number
	local mult = player:GetAttribute("CoinMultiplier")
	local clanBonus = player:GetAttribute("ClanCoinBonus") -- patente do clã (ClanService)
	local final = math.floor(amount * (if typeof(mult) == "number" and mult > 0 then mult else 1)
		* (1 + (if typeof(clanBonus) == "number" then clanBonus else 0)) + 0.5)
	DataService.AddCoins(player, final)
	return final
end

--- Pontos de EVENTO (mini eventos; o vendedor cobra em EventPrice). Sem multiplicador de passe.
function DataService.AddEventPoints(player: Player, amount: number)
	local profile = DataService.GetProfile(player)
	if not profile or amount == 0 then
		return
	end
	profile.eventPoints = math.max(0, math.floor(profile.eventPoints + amount))
	touch(player)
end

--- Salva agora (compras). Se estiver salvando, espera terminar. false = não salvou.
function DataService.SaveNow(player: Player, reason: string): boolean
	local session = sessions[player]
	if not session or not session.loaded or session.sessionOnly then
		return false
	end
	local waited = 0
	while session.saving and waited < 10 do
		waited += task.wait(0.2)
	end
	session.dirty = true
	return save(player, reason)
end

--- [Admin] Define moedas direto.
function DataService.SetCoins(player: Player, amount: number)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	profile.coins = math.max(0, math.floor(amount))
	touch(player)
end

--- Concede personagem sem cobrar. Retorna false se já tinha/inexistente.
--- Stand (StandConfig) vira um DISCO no inventário (conquista, loot, admin): quem decide usar é o jogador.
function DataService.GrantCharacter(player: Player, characterId: string): boolean
	local profile = DataService.GetProfile(player)
	local def = CharacterDefs.Get(characterId)
	if profile and def and CharacterDefs.AccessOf(def) == "stand" then
		return DataService.AddItem(player, "stand:" .. characterId, 1)
	end
	if not profile or not def or table.find(profile.unlockedCharacters, characterId) then
		return false
	end
	table.insert(profile.unlockedCharacters, characterId)
	touch(player)
	return true
end

--- [Admin] Remove personagem (não remove os gratuitos).
function DataService.RevokeCharacter(player: Player, characterId: string): boolean
	local profile = DataService.GetProfile(player)
	local def = CharacterDefs.Get(characterId)
	if not profile or not def or def.UnlockCost <= 0 then
		return false
	end
	local index = table.find(profile.unlockedCharacters, characterId)
	if not index then
		return false
	end
	table.remove(profile.unlockedCharacters, index)
	touch(player)
	return true
end

--- Inventário (StandService): itens de StandConfig.ItemInfo ("flecha", "stand:<id>", "raca:<id>").
function DataService.AddItem(player: Player, itemId: string, amount: number): boolean
	local profile = DataService.GetProfile(player)
	if not profile or not StandConfig.ItemInfo(itemId) or amount <= 0 then
		return false
	end
	profile.inventory[itemId] = (profile.inventory[itemId] or 0) + math.floor(amount)
	touch(player)
	return true
end

--- Tira `amount` do item; false (e nada muda) se não tinha o suficiente.
function DataService.TakeItem(player: Player, itemId: string, amount: number): boolean
	local profile = DataService.GetProfile(player)
	local have = if profile then profile.inventory[itemId] or 0 else 0
	if not profile or amount <= 0 or have < amount then
		return false
	end
	profile.inventory[itemId] = if have - amount > 0 then have - amount else nil
	touch(player)
	return true
end

--- [Admin] Volta o perfil ao padrão (salva no próximo autosave/saída).
function DataService.ResetProfile(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	session.profile = DataConfig.DefaultProfile()
	touch(player)
end

function DataService.HasCharacter(player: Player, characterId: string): boolean
	local def = CharacterDefs.Get(characterId)
	if not def then
		return false
	end
	local profile = DataService.GetProfile(player)
	local kind = CharacterDefs.AccessOf(def)
	if kind == "human" then
		return true
	elseif kind == "stand" then
		-- só o Stand ATIVO (StandService); dev e mod "todos os personagens" usam qualquer um
		return player:GetAttribute("IsDeveloper") == true or player:GetAttribute("AllCharacters") == true
			or (profile ~= nil and profile.power == characterId)
	end
	if profile ~= nil and table.find(profile.unlockedCharacters, characterId) ~= nil then
		return true -- concedido (admin GrantAll / passe "Todos os personagens")
	end
	local access = CharacterDefs.AccessOf(def)
	if access == "form" then
		return false -- forma de boss (ritual): nunca pela seleção
	elseif access == "early" or access == "admin" or access == "drop" then
		return player:GetAttribute("IsDeveloper") == true -- "drop": só quem ganhou do boss (já voltou true acima)
	elseif access == "vip" then
		return player:GetAttribute("Pass_vip") == true or player:GetAttribute("Pass_all_characters") == true
			or player:GetAttribute("IsDeveloper") == true
	end
	return def.UnlockCost <= 0
end

--- Tenta comprar. Retorna (ok, motivo).
function DataService.UnlockCharacter(player: Player, characterId: string): (boolean, string)
	local def = CharacterDefs.Get(characterId)
	if not def then
		return false, "unknown"
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "not_loaded"
	end
	if DataService.HasCharacter(player, characterId) then
		return false, "already_owned"
	end
	local access = CharacterDefs.AccessOf(def)
	if access ~= "coins" then
		return false, access -- "vip": compra na loja; "early": ainda não liberado
	end
	if profile.coins < def.UnlockCost then
		return false, "coins"
	end
	profile.coins -= def.UnlockCost
	table.insert(profile.unlockedCharacters, characterId)
	touch(player)
	Log.debug(("[DataService] %s desbloqueou %s"):format(player.Name, characterId))
	return true, "ok"
end

--- Mapa livre: recompensa imediata por kill / registro de morte.
function DataService.RecordKill(killer: Player)
	local profile = DataService.GetProfile(killer)
	if not profile then
		return
	end
	profile.stats.kills += 1
	touch(killer)
	DataService.RewardCoins(killer, DataConfig.Rewards.Kill)
end

function DataService.RecordDeath(victim: Player)
	local profile = DataService.GetProfile(victim)
	if not profile then
		return
	end
	profile.stats.deaths += 1
	touch(victim)
end

--- Registra o resultado de um round para um participante.
function DataService.RecordMatchResult(player: Player, won: boolean, kills: number, died: boolean)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local stats = profile.stats
	stats.matches += 1
	stats.kills += kills
	if died then
		stats.deaths += 1
	end
	local reward = kills * DataConfig.Rewards.Kill
	if won then
		stats.wins += 1
		reward += DataConfig.Rewards.Win
	else
		stats.losses += 1
		reward += DataConfig.Rewards.Loss
	end
	touch(player)
	DataService.RewardCoins(player, reward)
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function DataService.Init()
	notifyProfile = Remotes.GetEvent(Remotes.Events.NotifyProfile)
	Remotes.GetEvent(Remotes.Events.RequestProfile).OnServerEvent:Connect(function(player)
		local session = sessions[player]
		if session and session.loaded then
			pushToClient(player, session)
		end
	end)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DataConfig.StoreName .. "_v" .. DataConfig.SchemaVersion)
	end)
	if ok then
		store = result
	else
		warn("[DataService] GetDataStore falhou; todos os jogadores ficarão com perfil temporário: " .. tostring(result))
	end
end

function DataService.Start()
	Remotes.GetEvent(Remotes.Events.RequestUnlockCharacter).OnServerEvent:Connect(function(player, characterId)
		if not unlockLimiter:Allow(player) then
			return
		end
		if typeof(characterId) ~= "string" then
			return
		end
		local ok, reason = DataService.UnlockCharacter(player, characterId)
		if not ok then
			Remotes.GetEvent(Remotes.Events.NotifyUnlockDenied):FireClient(player, characterId, reason)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player, "leave")
		sessions[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(DataConfig.AutosaveInterval)
			for player in sessions do
				task.spawn(save, player, "autosave")
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				save(player, "close")
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
