--!strict
--[[
	AdminService (servidor)
	Menu de desenvolvedor: lista de nicks/UserIds permitidos (AdminConfig) + comandos
	para mexer no jogo em runtime.

	Fluxo:
	  1. No PlayerAdded, quem passa em AdminConfig recebe o atributo IsDeveloper=true
	     (o cliente só usa isso para mostrar o botão; a autoridade é daqui).
	  2. FetchAdminLogin() -> true/false (abre a sessão; sem senha).
	  3. RequestAdminCommand(command, args) só funciona com sessão aberta.
	  4. NotifyAdminResult(ok, message) devolve o resultado para o painel.

	Comandos por alvo (args.target = nome/UserId; ausente = o próprio dev; "*" = todos):
	  SetCoins/AddCoins/AddXP/SetEnergy/SetHealth/SetSpeed/SetDamageMult {amount}, CompleteAchievements,
	  GrantItem {id} (entrega cosmético/emote/personagem, inclusive limitado de passe antigo),
	  InfiniteEnergy/NoCooldown/God {enabled?} (toggle), ResetCooldowns, ClearFlags,
	  GrantCharacter/RevokeCharacter/SetCharacter {characterId}, GrantAll, RevokeAll,
	  Heal, Kill, Respawn, Teleport (dev -> alvo), Bring (alvo -> dev), Kick {reason}, ResetData,
	  Fly (toggle: atributo DevFly; o cliente voa, AntiExploit ignora), Awaken (carga cheia + ultimate
	  na hora), SetStreak {amount}, GrantCosmetics/ResetCosmetics, Ragdoll {amount}, ClearAntiExploit
	Globais: GetState {target} (devolve data), ListPlayers, RespawnDummies, ToggleDummies,
	  RefreshLeaderboard, SetTime {amount}, ServerInfo, SummonBoss, DespawnBoss
	Flags viram atributos no Player: Invulnerable, DevInfiniteEnergy, DevNoCooldown,
	  DevDamageMult, DevSpeed, DevFly (lidos por HealthService/AbilityService/CombatService/AntiExploit).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local AdminConfig = require(script.Parent.Parent:WaitForChild("AdminConfig"))
local AchievementsConfig = require(Modules:WaitForChild("AchievementsConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))
local DummyService = require(script.Parent:WaitForChild("DummyService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))
local BossService = require(script.Parent:WaitForChild("BossService"))
local EnvironmentService = require(script.Parent:WaitForChild("EnvironmentService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local BossConfig = require(Modules:WaitForChild("BossConfig"))
local ReportService = require(script.Parent:WaitForChild("ReportService"))
local ArenaService = require(script.Parent:WaitForChild("ArenaService"))
local ReportConfig = require(Modules:WaitForChild("ReportConfig"))
local TeleportService = game:GetService("TeleportService")
-- RitualService/BossFormService dependem do AbilityService, que depende deste módulo: carregados no Start
local RitualService: any = nil
local BossFormService: any = nil
local CosmeticsConfig = require(Modules:WaitForChild("CosmeticsConfig"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local MatchConfig = require(Modules:WaitForChild("MatchConfig"))
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local AdminService = {}

-- Ganchos preenchidos por AbilityService no Start (evita require circular)
AdminService.ForceCharacter = function(_player: Player, _characterId: string) end
AdminService.SetEnergy = function(_player: Player, _amount: number) end
AdminService.ResetCooldowns = function(_player: Player) end
AdminService.Awaken = function(_player: Player) end -- AbilityService
AdminService.ResetDash = function(_player: Player) end -- MovementService

local sessions: { [Player]: boolean } = {}
local loginLimiter = RateLimiter.new(5, 60)
local developerNames: { [string]: boolean } = {}
for _, name in AdminConfig.Developers do
	developerNames[name:lower()] = true
end
local commandLimiter = RateLimiter.new(10, 1)
local notifyResult: RemoteEvent

-- ---------------------------------------------------------------------------
-- Permissão
-- ---------------------------------------------------------------------------

local function isDeveloper(player: Player): boolean
	if developerNames[player.Name:lower()] or AdminConfig.DeveloperIds[player.UserId] then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId then
		return true
	end
	if AdminConfig.AllowAnyoneInStudio and RunService:IsStudio() then
		return true
	end
	return false
end

function AdminService.IsLoggedIn(player: Player): boolean
	return sessions[player] == true
end

-- ---------------------------------------------------------------------------
-- Comandos
-- ---------------------------------------------------------------------------

local ALL = "*"

--- Alvos: nil/"" = o próprio dev; "*" = todos; nome/UserId = um jogador.
local function findTargets(admin: Player, raw: any): { Player }
	if raw == nil or raw == "" then
		return { admin }
	end
	if raw == ALL then
		return Players:GetPlayers()
	end
	if typeof(raw) == "number" then
		local p = Players:GetPlayerByUserId(raw)
		return if p then { p } else {}
	end
	if typeof(raw) == "string" then
		local lowered = raw:lower()
		for _, p in Players:GetPlayers() do
			if p.Name:lower() == lowered or p.DisplayName:lower() == lowered then
				return { p }
			end
		end
		for _, p in Players:GetPlayers() do
			if p.Name:lower():sub(1, #lowered) == lowered then
				return { p }
			end
		end
	end
	return {}
end

local function number(value: any): number?
	if typeof(value) == "number" then
		return value
	end
	if typeof(value) == "string" then
		return tonumber(value)
	end
	return nil
end

local function toggleAttribute(target: Player, attr: string, value: any): boolean
	local enabled = if typeof(value) == "boolean" then value else target:GetAttribute(attr) ~= true
	target:SetAttribute(attr, if enabled then true else nil)
	return enabled
end

local function applySpeed(target: Player)
	local speed = target:GetAttribute("DevSpeed")
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and typeof(speed) == "number" then
		humanoid.WalkSpeed = speed
	end
end

--- Estado do alvo para o painel.
local function stateOf(target: Player): { [string]: any }
	local profile = DataService.GetProfile(target)
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	return {
		name = target.Name,
		userId = target.UserId,
		coins = if profile then profile.coins else 0,
		kills = if profile then profile.stats.kills else 0,
		characterId = target:GetAttribute("CharacterId"),
		unlocked = if profile then profile.unlockedCharacters else {},
		energy = target:GetAttribute("Energy"),
		health = if humanoid then humanoid.Health else 0,
		maxHealth = if humanoid then humanoid.MaxHealth else 0,
		speed = if humanoid then humanoid.WalkSpeed else 0,
		god = target:GetAttribute("Invulnerable") == true,
		infiniteEnergy = target:GetAttribute("DevInfiniteEnergy") == true,
		noCooldown = target:GetAttribute("DevNoCooldown") == true,
		fly = target:GetAttribute("DevFly") == true,
		streak = target:GetAttribute("KillStreak") or 0,
		damageMult = target:GetAttribute("DevDamageMult") or 1,
		sessionOnly = DataService.IsSessionOnly(target),
	}
end

-- Handlers por alvo: (admin, target, args) -> (ok, mensagem)
type Handler = (admin: Player, target: Player, args: { [string]: any }) -> (boolean, string)
local perTarget: { [string]: Handler } = {}
-- Handlers globais (sem alvo): (admin, args) -> (ok, mensagem, data?)
type GlobalHandler = (admin: Player, args: { [string]: any }) -> (boolean, string, any?)
local global: { [string]: GlobalHandler } = {}

-- Moedas / energia / vida / velocidade / dano ---------------------------------

perTarget.SetCoins = function(_, target, args)
	local amount = number(args.amount)
	if not amount then
		return false, "quantidade inválida"
	end
	DataService.SetCoins(target, amount)
	return true, ("%s: %d moedas"):format(target.Name, math.max(0, math.floor(amount)))
end

perTarget.AddXP = function(_, target, args)
	local amount = number(args.amount)
	if not amount or amount <= 0 then
		return false, "quantidade inválida"
	end
	ProgressionService.AddXP(target, amount, "admin")
	local profile = DataService.GetProfile(target)
	return true, ("%s: +%d XP (nível %d)"):format(target.Name, amount, if profile then profile.level else 0)
end

--- Conclui TODAS as conquistas ativas (permanentes + passe) empurrando os contadores até a meta.
perTarget.CompleteAchievements = function(_, target)
	local n = 0
	for _, ach in AchievementsConfig.Active() do
		AchievementService.SetCounter(target, ach.Kind, ach.Goal)
		n += 1
	end
	AchievementService.Refresh(target)
	return true, ("%s: %d conquista(s) empurradas para a meta"):format(target.Name, n)
end

--- Entrega um cosmético/emote/personagem por id (inclusive LIMITADO de passe antigo).
perTarget.GrantItem = function(_, target, args)
	local id = args.id
	if typeof(id) ~= "string" or id == "" then
		return false, "id vazio"
	end
	local ok, msg = AchievementService.GrantReward(target, id)
	return ok, ("%s: %s (%s)"):format(target.Name, id, msg)
end

perTarget.AddCoins = function(_, target, args)
	local amount = number(args.amount)
	if not amount then
		return false, "quantidade inválida"
	end
	DataService.AddCoins(target, amount)
	local profile = DataService.GetProfile(target)
	return true, ("%s: %+d moedas (total %d)"):format(target.Name, amount, if profile then profile.coins else 0)
end

perTarget.SetEnergy = function(_, target, args)
	local amount = number(args.amount)
	if not amount then
		return false, "quantidade inválida"
	end
	AdminService.SetEnergy(target, amount)
	return true, ("%s: energia %d (máx %d; use Energia infinita para não gastar)"):format(target.Name, math.clamp(amount, 0, CharacterDefs.Energy.Max), CharacterDefs.Energy.Max)
end

perTarget.InfiniteEnergy = function(_, target, args)
	local on = toggleAttribute(target, "DevInfiniteEnergy", args.enabled)
	return true, ("%s: energia infinita %s"):format(target.Name, if on then "ON" else "OFF")
end

perTarget.NoCooldown = function(_, target, args)
	local on = toggleAttribute(target, "DevNoCooldown", args.enabled)
	if on then
		AdminService.ResetCooldowns(target)
	end
	return true, ("%s: sem cooldown %s"):format(target.Name, if on then "ON" else "OFF")
end

perTarget.ResetCooldowns = function(_, target)
	AdminService.ResetCooldowns(target)
	AdminService.ResetDash(target)
	return true, ("%s: cooldowns zerados (habilidades e dash)"):format(target.Name)
end

perTarget.Fly = function(_, target, args)
	local on = toggleAttribute(target, "DevFly", args.enabled)
	AntiExploitService.Grace(target, 1)
	return true, ("%s: voo %s (Espaço sobe, Ctrl desce)"):format(target.Name, if on then "ON" else "OFF")
end

perTarget.Awaken = function(_, target)
	AdminService.SetEnergy(target, CharacterDefs.Energy.Max)
	AdminService.Awaken(target)
	return true, ("%s: ULTIMATE + despertar"):format(target.Name)
end

perTarget.SetStreak = function(_, target, args)
	local amount = number(args.amount)
	if not amount or amount < 0 then
		return false, "quantidade inválida"
	end
	target:SetAttribute("KillStreak", math.floor(amount))
	return true, ("%s: kill streak = %d"):format(target.Name, math.floor(amount))
end

perTarget.GrantCosmetics = function(_, target)
	local profile = DataService.GetProfile(target)
	if not profile then
		return false, "perfil não carregado"
	end
	local n = 0
	for _, item in CosmeticsConfig.Items do
		if not table.find(profile.cosmetics.owned, item.Id) then
			table.insert(profile.cosmetics.owned, item.Id)
			n += 1
		end
	end
	for _, emote in CosmeticsConfig.Emotes do
		if not table.find(profile.emotes, emote.Id) then
			table.insert(profile.emotes, emote.Id)
			n += 1
		end
	end
	DataService.MarkDirty(target)
	return true, ("%s: +%d cosméticos/emotes"):format(target.Name, n)
end

perTarget.ResetCosmetics = function(_, target)
	local profile = DataService.GetProfile(target)
	if not profile then
		return false, "perfil não carregado"
	end
	profile.cosmetics = { owned = {}, equipped = {} }
	profile.emotes = {}
	DataService.MarkDirty(target)
	for _, attr in { "CosmeticCape", "CosmeticAura" } do
		target:SetAttribute(attr, "")
	end
	return true, ("%s: cosméticos zerados"):format(target.Name)
end

perTarget.Ragdoll = function(_, target, args)
	local seconds = number(args.amount) or 2
	RagdollService.Ragdoll(target, seconds)
	return true, ("%s: ragdoll %.1fs"):format(target.Name, seconds)
end

perTarget.ClearAntiExploit = function(_, target)
	AntiExploitService.ClearFlags(target)
	return true, ("%s: flags do anti-exploit zeradas"):format(target.Name)
end

perTarget.God = function(_, target, args)
	local on = toggleAttribute(target, "Invulnerable", args.enabled)
	return true, ("%s: modo deus %s"):format(target.Name, if on then "ON" else "OFF")
end

perTarget.SetHealth = function(_, target, args)
	local amount = number(args.amount)
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not amount or not humanoid or not character then
		return false, "valor inválido ou sem personagem"
	end
	if amount > humanoid.MaxHealth then
		humanoid.MaxHealth = amount
	end
	if amount <= 0 then
		HealthService.Kill(character)
	elseif amount > humanoid.Health then
		HealthService.Heal(character, amount - humanoid.Health)
	else
		humanoid.Health = amount
	end
	return true, ("%s: vida %d/%d"):format(target.Name, amount, humanoid.MaxHealth)
end

perTarget.SetSpeed = function(_, target, args)
	local amount = number(args.amount)
	if not amount or amount < 0 or amount > 500 then
		return false, "velocidade inválida (0–500)"
	end
	if amount == CombatConfig.WalkSpeed then
		target:SetAttribute("DevSpeed", nil)
	else
		target:SetAttribute("DevSpeed", amount)
	end
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = amount
	end
	AntiExploitService.Grace(target, 2)
	return true, ("%s: WalkSpeed %d"):format(target.Name, amount)
end

perTarget.SetDamageMult = function(_, target, args)
	local amount = number(args.amount)
	if not amount or amount < 0 or amount > 1000 then
		return false, "multiplicador inválido (0–1000)"
	end
	target:SetAttribute("DevDamageMult", if amount == 1 then nil else amount)
	return true, ("%s: dano x%s"):format(target.Name, tostring(amount))
end

-- Personagens ------------------------------------------------------------------

perTarget.GrantCharacter = function(_, target, args)
	local id = args.characterId
	if typeof(id) ~= "string" or not CharacterDefs.Get(id) then
		return false, "personagem desconhecido"
	end
	if not DataService.GrantCharacter(target, id) then
		return false, ("%s já tem %s"):format(target.Name, id)
	end
	return true, ("%s recebeu %s"):format(target.Name, id)
end

perTarget.RevokeCharacter = function(_, target, args)
	local id = args.characterId
	if typeof(id) ~= "string" or not CharacterDefs.Get(id) then
		return false, "personagem desconhecido"
	end
	if not DataService.RevokeCharacter(target, id) then
		return false, ("%s não tem %s (ou é gratuito)"):format(target.Name, id)
	end
	if target:GetAttribute("CharacterId") == id then
		AdminService.ForceCharacter(target, CharacterDefs.DefaultCharacter)
	end
	return true, ("%s perdeu %s"):format(target.Name, id)
end

perTarget.SetCharacter = function(_, target, args)
	local id = args.characterId
	if typeof(id) ~= "string" or not CharacterDefs.Get(id) then
		return false, "personagem desconhecido"
	end
	if not DataService.HasCharacter(target, id) then
		DataService.GrantCharacter(target, id)
	end
	AdminService.ForceCharacter(target, id)
	return true, ("%s agora é %s"):format(target.Name, id)
end

perTarget.GrantAll = function(_, target)
	local n = 0
	for _, id in CharacterDefs.Order do
		if DataService.GrantCharacter(target, id) then
			n += 1
		end
	end
	return true, ("%s: +%d personagens"):format(target.Name, n)
end

perTarget.RevokeAll = function(_, target)
	local n = 0
	for _, id in CharacterDefs.Order do
		if DataService.RevokeCharacter(target, id) then
			n += 1
		end
	end
	AdminService.ForceCharacter(target, CharacterDefs.DefaultCharacter)
	return true, ("%s: -%d personagens"):format(target.Name, n)
end

-- Ações --------------------------------------------------------------------------

perTarget.Heal = function(_, target)
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return false, "sem personagem"
	end
	HealthService.Heal(character, humanoid.MaxHealth)
	return true, ("%s curado"):format(target.Name)
end

perTarget.Kill = function(_, target)
	local character = target.Character
	if not character then
		return false, "sem personagem"
	end
	HealthService.Kill(character)
	return true, ("%s eliminado"):format(target.Name)
end

perTarget.Respawn = function(_, target)
	AntiExploitService.Grace(target, 3)
	CharacterService.Load(target)
	return true, ("%s respawnado"):format(target.Name)
end

local function moveTo(who: Player, destination: Player): (boolean, string)
	local from = who.Character and who.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local to = destination.Character and destination.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not from or not to then
		return false, "personagem indisponível"
	end
	AntiExploitService.Grace(who, 2)
	from.CFrame = to.CFrame * CFrame.new(0, 0, 4)
	return true, ("%s -> %s"):format(who.Name, destination.Name)
end

perTarget.Teleport = function(admin, target)
	return moveTo(admin, target)
end

perTarget.Bring = function(admin, target)
	if target == admin then
		return false, "você mesmo"
	end
	return moveTo(target, admin)
end

--- Toggle: liga a câmera do dev no alvo (atributo lido pelo DevController); de novo no mesmo alvo desliga.
perTarget.Spectate = function(admin, target)
	if target == admin then
		admin:SetAttribute("SpectateTargetUserId", nil)
		return true, "câmera livre"
	end
	if admin:GetAttribute("SpectateTargetUserId") == target.UserId then
		admin:SetAttribute("SpectateTargetUserId", nil)
		return true, "parou de assistir " .. target.Name
	end
	admin:SetAttribute("SpectateTargetUserId", target.UserId)
	return true, ("assistindo %s (de novo no mesmo alvo pra parar)"):format(target.Name)
end

perTarget.Kick = function(admin, target, args)
	if target == admin then
		return false, "não dá pra se kickar"
	end
	local reason = if typeof(args.reason) == "string" and args.reason ~= "" then args.reason else "Removido por um desenvolvedor"
	target:Kick(reason)
	return true, ("%s kickado"):format(target.Name)
end

perTarget.ResetData = function(_, target)
	DataService.ResetProfile(target)
	AdminService.ForceCharacter(target, CharacterDefs.DefaultCharacter)
	return true, ("dados de %s zerados (salva no próximo autosave)"):format(target.Name)
end

perTarget.ClearFlags = function(_, target)
	for _, attr in { "Invulnerable", "DevInfiniteEnergy", "DevNoCooldown", "DevDamageMult", "DevSpeed", "DevFly" } do
		target:SetAttribute(attr, nil)
	end
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = CombatConfig.WalkSpeed
	end
	return true, ("%s: flags de dev limpas"):format(target.Name)
end

-- Globais / mundo -------------------------------------------------------------

global.GetState = function(admin, args)
	local targets = findTargets(admin, args.target)
	local target = targets[1]
	if not target then
		return false, "alvo não encontrado"
	end
	return true, "", stateOf(target)
end

global.ListPlayers = function()
	local names = {}
	for _, p in Players:GetPlayers() do
		table.insert(names, ("%s (%d)"):format(p.Name, p.UserId))
	end
	return true, "online: " .. table.concat(names, ", ")
end

global.RespawnDummies = function()
	local n = DummyService.Respawn()
	return true, ("%d boneco(s) recriados"):format(n)
end

global.BringDummy = function(admin)
	local root = admin.Character and admin.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "sem personagem"
	end
	local m = DummyService.BringTo(root.CFrame * CFrame.new(0, 0, -6))
	return m ~= nil, if m then ("%s trazido (fica aqui até 'Recriar bonecos')"):format(m.Name) else "nenhum boneco vivo"
end

global.ToggleDummies = function()
	local n = DummyService.SetEnabled(not DummyService.Enabled)
	return true, ("bonecos %s (%d)"):format(if DummyService.Enabled then "ON" else "OFF", n)
end

global.SummonBoss = function(admin)
	local ok, msg = BossService.Summon(admin)
	return ok, if ok then "boss invocado" else ("não invocou: %s"):format(tostring(msg))
end

global.InspectBoss = function()
	return true, BossService.Inspect()
end

global.DespawnBoss = function()
	local ok = BossService.Despawn()
	return true, if ok then "boss removido" else "não havia boss"
end

global.RefreshLeaderboard = function()
	LeaderboardService.Refresh()
	return true, "placar publicado e atualizado"
end

-- Tempo: o dev manda. SetTime/SetDay/SetNight CONGELAM a hora (o ciclo automático para); TimeAuto solta.
global.SetTime = function(_, args)
	local hour = number(args.amount)
	if not hour then
		return false, "hora inválida (0–24)"
	end
	EnvironmentService.SetClockOverride(hour % 24)
	return true, ("hora congelada em %.1f (%s)"):format(Lighting.ClockTime, if EnvironmentService.IsNight() then "noite" else "dia")
end

global.SetDay = function()
	EnvironmentService.SetClockOverride(13)
	return true, "DIA (hora congelada em 13:00)"
end

global.SetNight = function()
	EnvironmentService.SetClockOverride(22)
	return true, "NOITE (hora congelada em 22:00) — altar aceita invocação se o ritual estiver completo"
end

global.TimeAuto = function()
	EnvironmentService.SetClockOverride(nil)
	local dn = EnvironmentService.DayNight
	return true, ("ciclo automático (dia %d min / noite %d min)"):format(dn.DayMinutes, dn.NightMinutes)
end

global.GiveArrow = function(admin)
	if not RitualService then
		return false, "RitualService não carregou"
	end
	RitualService.GiveArrow(admin)
	return true, "você está com a flecha; à noite, E no altar vira o " .. BossConfig.Name
end

global.BecomeBoss = function(admin)
	if not BossFormService then
		return false, "BossFormService não carregou"
	end
	if RitualService then
		RitualService.GiveArrow(nil) -- solta a flecha no mapa para os outros
	end
	local ok, why = BossFormService.Transform(admin)
	return ok, if ok then ("virando %s em %.1f s"):format(BossConfig.Name, BossConfig.Form.TransformSeconds) else tostring(why)
end

global.EndBossForm = function()
	if not BossFormService or not BossFormService.IsActive() then
		return false, "ninguém está na forma de boss"
	end
	BossFormService.End("admin")
	return true, "forma de boss encerrada"
end

-- ---------------------------------------------------------------------------
-- Administração (item 7 dos planos): mensagens, ban, kick
-- ---------------------------------------------------------------------------
local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")
local ANNOUNCE_TOPIC = "SahurAnnounce"
local BAN_STORE = "Bans_v1"

--- Módulos que dependem (indiretamente) deste: carregados só na hora (evita ciclo de require).
local lazyCache: { [string]: any } = {}
local function lazyRequire(name: string): any
	if lazyCache[name] == nil then
		local ok, mod = pcall(function()
			return (require :: any)(script.Parent:WaitForChild(name))
		end)
		lazyCache[name] = if ok then mod else false
	end
	return lazyCache[name] or nil
end

local function textArg(args: { [string]: any }): string?
	local t = args.text
	if typeof(t) ~= "string" then
		return nil
	end
	t = t:gsub("^%s+", ""):gsub("%s+$", "")
	if #t == 0 then
		return nil
	end
	return t:sub(1, 200)
end

local function announceHere(text: string, scope: string, from: string)
	Remotes.GetEvent(Remotes.Events.NotifyAnnouncement):FireAllClients(text, scope, from)
end

global.AnnounceServer = function(admin, args)
	local text = textArg(args)
	if not text then
		return false, "escreva a mensagem na caixa"
	end
	announceHere(text, "server", admin.Name)
	return true, "mensagem enviada a este servidor"
end

global.AnnounceGlobal = function(admin, args)
	local text = textArg(args)
	if not text then
		return false, "escreva a mensagem na caixa"
	end
	local ok, err = pcall(function()
		MessagingService:PublishAsync(ANNOUNCE_TOPIC, { text = text, from = admin.Name })
	end)
	if not ok then
		announceHere(text, "server", admin.Name)
		return true, "MessagingService falhou (" .. tostring(err) .. "); enviada só a este servidor"
	end
	return true, "mensagem GLOBAL publicada (todos os servidores)"
end

perTarget.Announce = function(admin, target, args)
	local text = textArg(args)
	if not text then
		return false, "escreva a mensagem na caixa"
	end
	Remotes.GetEvent(Remotes.Events.NotifyAnnouncement):FireClient(target, text, "you", admin.Name)
	return true, ("mensagem enviada a %s"):format(target.Name)
end

local function banStore(): DataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(BAN_STORE)
	end)
	return if ok then store else nil
end

--- Ban (DataStore) + kick. `args.text` = motivo (opcional), `args.amount` = dias (0/nil = permanente).
perTarget.Ban = function(admin, target, args)
	if target == admin then
		return false, "não dá pra se banir"
	end
	if isDeveloper(target) then
		return false, "não dá pra banir outro dev"
	end
	local reason = textArg(args) or "Banido por um desenvolvedor"
	local days = number(args.amount)
	local until_ = if days and days > 0 then os.time() + days * 86400 else 0
	local store = banStore()
	if not store then
		return false, "DataStore indisponível (Studio: ligue 'Enable Studio Access to API Services')"
	end
	local ok, err = pcall(function()
		store:SetAsync(tostring(target.UserId), { reason = reason, until_ = until_, by = admin.Name, name = target.Name, at = os.time() })
	end)
	if not ok then
		return false, "não gravou o ban: " .. tostring(err)
	end
	target:Kick(("Você foi banido: %s%s"):format(reason, if until_ > 0 then (" (até %s)"):format(os.date("%d/%m/%Y", until_)) else ""))
	return true, ("%s banido (%s)"):format(target.Name, if until_ > 0 then tostring(days) .. " dia(s)" else "permanente")
end

--- Desbanir pelo nome (args.text = nome do jogador).
global.Unban = function(_, args)
	local name = textArg(args)
	if not name then
		return false, "escreva o NOME do jogador na caixa"
	end
	local okId, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(name)
	end)
	if not okId then
		return false, "jogador não encontrado: " .. name
	end
	local store = banStore()
	if not store then
		return false, "DataStore indisponível"
	end
	local ok, err = pcall(function()
		store:RemoveAsync(tostring(userId))
	end)
	return ok, if ok then name .. " desbanido" else "erro: " .. tostring(err)
end

--- Na entrada: banido = kick (falha do DataStore deixa entrar, mas avisa no Output).
local function checkBan(player: Player)
	local store = banStore()
	if not store then
		return
	end
	local ok, entry = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if not ok then
		warn(("[AdminService] não consegui ler o ban de %s: %s"):format(player.Name, tostring(entry)))
		return
	end
	if typeof(entry) == "table" then
		local until_ = tonumber(entry.until_) or 0
		if until_ == 0 or os.time() < until_ then
			player:Kick(("Você está banido: %s%s"):format(tostring(entry.reason), if until_ > 0 then (" (até %s)"):format(os.date("%d/%m/%Y", until_)) else ""))
		end
	end
end

global.Trailer = function()
	local TrailerService = lazyRequire("TrailerService")
	if not TrailerService then
		return false, "TrailerService não carregou"
	end
	local ok, msg = TrailerService.Run()
	return ok, msg
end

global.TrailerStop = function()
	local TrailerService = lazyRequire("TrailerService")
	if TrailerService then
		TrailerService.Stop()
	end
	return true, "trailer interrompido"
end

global.RespawnArrow = function()
	if not RitualService then
		return false, "RitualService não carregou"
	end
	RitualService.GiveArrow(nil)
	return true, "flecha sorteada num ponto do mapa"
end

global.TestSounds = function()
	local list = require(Modules:WaitForChild("PackSounds")) :: { any }
	return true, ("testando %d sons no cliente (veja o Output: [SoundProbe])"):format(#list), { testSounds = true }
end

--- Evento no Canion (EventService): leva/traz todo mundo.
global.StartEvent = function()
	local EventService = lazyRequire("EventService")
	if not EventService then
		return false, "EventService não carregou"
	end
	return EventService.Begin()
end

global.EndEvent = function()
	local EventService = lazyRequire("EventService")
	if not EventService then
		return false, "EventService não carregou"
	end
	return EventService.Finish()
end

--- Teleporta o dev para um ponto de spawn do mapa da arena (Workspace.CurrentMap.Spawns).
global.TeleportArena = function(admin)
	local root = admin.Character and admin.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "sem personagem"
	end
	-- mapa livre: SpawnLocations do Workspace (CharacterService); em rounds, os spawns do mapa carregado
	local spawns = ArenaService.GetSpawnCFrames()
	local cf = if #spawns > 0 then spawns[math.random(1, #spawns)] + Vector3.new(0, 3, 0) else CharacterService.PickSpawn(admin) * CFrame.new(0, 3.05, 0)
	AntiExploitService.Grace(admin, 2)
	root.CFrame = cf
	return true, "teleportado para a arena"
end

--- Entra no servidor de um jogador (args.text = nick; funciona mesmo se ele estiver em OUTRO servidor).
global.JoinPlayerServer = function(admin, args)
	local name = textArg(args)
	if not name then
		return false, "escreva o NOME do jogador na caixa"
	end
	local okId, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(name)
	end)
	if not okId then
		return false, "jogador não encontrado: " .. name
	end
	local okInfo, inServer, placeId, jobId = pcall(function()
		return TeleportService:GetPlayerPlaceInstanceAsync(userId)
	end)
	if not okInfo or not inServer then
		return false, name .. " não está em nenhum servidor agora"
	end
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(placeId, jobId, admin)
	end)
	return ok, if ok then ("entrando no servidor de %s..."):format(name) else "erro: " .. tostring(err)
end

--- Denúncias contra um jogador. args.target = nick (online ou não), lido do seletor de alvo do menu.
local function formatReports(list: { ReportService.ReportEntry }): string
	if #list == 0 then
		return "sem denúncias"
	end
	local reasonLabel: { [string]: string } = {}
	for _, r in ReportConfig.Reasons do
		reasonLabel[r.Id] = r.Label
	end
	local lines = {}
	for i, entry in list do
		if i > 10 then
			table.insert(lines, ("... e mais %d"):format(#list - 10))
			break
		end
		table.insert(lines, ("%s — %s (por %s, %s)%s"):format(
			os.date("%d/%m %H:%M", entry.at),
			reasonLabel[entry.reason] or entry.reason,
			entry.reporter,
			entry.jobId == game.JobId and "este servidor" or "outro servidor",
			if entry.text ~= "" then ": " .. entry.text else ""
		))
	end
	return ("%d denúncia(s):\n%s"):format(#list, table.concat(lines, "\n"))
end

global.GetReports = function(admin, args)
	local targets = findTargets(admin, args.target)
	local target = targets[1]
	if not target then
		return false, "selecione um jogador (não TODOS)"
	end
	local list, err = ReportService.GetReports(target.UserId)
	if err and #list == 0 then
		return false, "erro lendo denúncias: " .. err
	end
	return true, ("%s: %s"):format(target.Name, formatReports(list))
end

--- Denúncias de alguém que não está online agora (args.text = nick).
global.GetReportsByName = function(_, args)
	local name = textArg(args)
	if not name then
		return false, "escreva o NOME do jogador na caixa"
	end
	local okId, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(name)
	end)
	if not okId then
		return false, "jogador não encontrado: " .. name
	end
	local list, err = ReportService.GetReports(userId)
	if err and #list == 0 then
		return false, "erro lendo denúncias: " .. err
	end
	return true, ("%s: %s"):format(name, formatReports(list))
end

global.ServerInfo = function()
	local stats = AntiExploitService.GetStats()
	local flagged = {}
	for k, v in stats do
		table.insert(flagged, ("%s=%d"):format(k, v))
	end
	return true, ("jogadores %d · uptime %ds · memória %.0f MB · FreeRoam %s · anti-exploit {%s}"):format(
		#Players:GetPlayers(),
		math.floor(Workspace.DistributedGameTime),
		Stats:GetTotalMemoryUsageMb(),
		tostring(MatchConfig.FreeRoam),
		table.concat(flagged, " ")
	)
end

-- ---------------------------------------------------------------------------
-- Remotes
-- ---------------------------------------------------------------------------

local function onLogin(player: Player): boolean
	if not isDeveloper(player) then
		warn(("[AdminService] %s tentou abrir o menu dev sem permissão"):format(player.Name))
		return false
	end
	if sessions[player] then
		return true
	end
	if not loginLimiter:Allow(player) then
		return false
	end
	sessions[player] = true
	Log.debug(("[AdminService] %s entrou no menu de desenvolvedor"):format(player.Name))
	return true
end

local function onCommand(player: Player, command: any, args: any)
	if not sessions[player] or not isDeveloper(player) then
		return
	end
	if not commandLimiter:Allow(player) or typeof(command) ~= "string" then
		return
	end
	local safeArgs: { [string]: any } = if typeof(args) == "table" then args else {}

	local globalHandler = global[command]
	if globalHandler then
		local ok, result, message, data = pcall(globalHandler, player, safeArgs)
		if not ok then
			warn(("[AdminService] erro em %s: %s"):format(command, tostring(result)))
			notifyResult:FireClient(player, false, "erro: " .. tostring(result))
			return
		end
		if command ~= "GetState" then
			warn(("[AdminService] %s -> %s: %s"):format(player.Name, command, tostring(message)))
		end
		notifyResult:FireClient(player, result == true, tostring(message), data)
		return
	end

	local handler = perTarget[command]
	if not handler then
		notifyResult:FireClient(player, false, "comando desconhecido: " .. command)
		return
	end
	local targets = findTargets(player, safeArgs.target)
	if #targets == 0 then
		notifyResult:FireClient(player, false, "jogador não encontrado: " .. tostring(safeArgs.target))
		return
	end
	local okCount, messages = 0, {}
	for _, target in targets do
		local ok, result, message = pcall(handler, player, target, safeArgs)
		if not ok then
			warn(("[AdminService] erro em %s(%s): %s"):format(command, target.Name, tostring(result)))
			table.insert(messages, "erro: " .. tostring(result))
		else
			if result == true then
				okCount += 1
			end
			table.insert(messages, tostring(message))
		end
	end
	local summary = table.concat(messages, " | ")
	warn(("[AdminService] %s -> %s(%s): %s"):format(player.Name, command, tostring(safeArgs.target or "eu"), summary))
	notifyResult:FireClient(player, okCount > 0, summary, stateOf(targets[1]))
end

function AdminService.Init()
	notifyResult = Remotes.GetEvent(Remotes.Events.NotifyAdminResult)
end

function AdminService.Start()
	local okR, r = pcall(require, script.Parent:WaitForChild("RitualService"))
	if okR then
		RitualService = r
	end
	local okF, f = pcall(require, script.Parent:WaitForChild("BossFormService"))
	if okF then
		BossFormService = f
	end
	-- anúncios globais (outros servidores) e ban na entrada
	pcall(function()
		MessagingService:SubscribeAsync(ANNOUNCE_TOPIC, function(message)
			local data = message.Data
			if typeof(data) == "table" and typeof(data.text) == "string" then
				announceHere(data.text, "global", tostring(data.from))
			end
		end)
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(checkBan, player)
	end)
	Remotes.GetFunction(Remotes.Functions.FetchAdminLogin).OnServerInvoke = onLogin
	Remotes.GetEvent(Remotes.Events.RequestAdminCommand).OnServerEvent:Connect(onCommand)

	local function onPlayer(player: Player)
		if isDeveloper(player) then
			player:SetAttribute("IsDeveloper", true)
		end
		player.CharacterAdded:Connect(function()
			task.defer(applySpeed, player) -- depois do HealthService setar o WalkSpeed padrão
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return AdminService
