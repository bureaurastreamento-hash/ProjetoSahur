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

local function migrate(raw: any): DataConfig.Profile
	local profile = DataConfig.DefaultProfile()
	if typeof(raw) ~= "table" then
		return profile
	end
	-- Copia campos conhecidos com validação de tipo; o resto fica no default.
	if typeof(raw.coins) == "number" and raw.coins >= 0 then
		profile.coins = math.floor(raw.coins)
	end
	if typeof(raw.unlockedCharacters) == "table" then
		for _, id in raw.unlockedCharacters do
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
	-- if raw.schemaVersion == 1 then ... migrações futuras aqui
	profile.schemaVersion = DataConfig.SchemaVersion
	return profile
end

-- ---------------------------------------------------------------------------
-- Load / Save
-- ---------------------------------------------------------------------------

local function pushToClient(player: Player, session: Session)
	player:SetAttribute("Coins", session.profile.coins)
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
		session.sessionOnly = false
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
	local final = math.floor(amount * (if typeof(mult) == "number" and mult > 0 then mult else 1) + 0.5)
	DataService.AddCoins(player, final)
	return final
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

--- [Admin] Concede personagem sem cobrar. Retorna false se já tinha/inexistente.
function DataService.GrantCharacter(player: Player, characterId: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile or not CharacterDefs.Get(characterId) or table.find(profile.unlockedCharacters, characterId) then
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
	if profile ~= nil and table.find(profile.unlockedCharacters, characterId) ~= nil then
		return true -- concedido (admin GrantAll / passe "Todos os personagens")
	end
	local access = CharacterDefs.AccessOf(def)
	if access == "early" then
		return player:GetAttribute("IsDeveloper") == true
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
