--!strict
--[[
	RemoteEvents
	Módulo ÚNICO de definição de RemoteEvents / RemoteFunctions do jogo.

	Padrão de nomes:
	  Request* -> cliente PEDE algo ao servidor (RemoteEvent, FireServer).
	              O servidor sempre valida; nunca confia no cliente.
	  Notify*  -> servidor AVISA o(s) cliente(s) (RemoteEvent, FireClient/FireAllClients).
	  Fetch*   -> cliente CONSULTA algo ao servidor (RemoteFunction, InvokeServer).
	              Nunca use InvokeClient no servidor.

	Uso:
	  local Remotes = require(ReplicatedStorage.Shared.Modules.RemoteEvents)
	  -- servidor (uma vez, no boot):
	  Remotes.Init()
	  -- qualquer lado:
	  local attack = Remotes.GetEvent(Remotes.Events.RequestAttack)
	  local ping   = Remotes.GetFunction(Remotes.Functions.FetchServerTime)

	Nunca use strings soltas ("RequestAttack") fora deste módulo.
	Para adicionar um remote: acrescente a entrada na tabela abaixo e pronto.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(script.Parent:WaitForChild("Log"))
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local EVENTS_FOLDER = "Events"
local FUNCTIONS_FOLDER = "Functions"

local RemoteEvents = {}

-- ---------------------------------------------------------------------------
-- DEFINIÇÕES (fonte única da verdade)
-- ---------------------------------------------------------------------------

-- RemoteEvents
RemoteEvents.Events = ({
	-- Request: cliente -> servidor
	RequestAttack = "RequestAttack", -- (attackId: string)
	RequestBlock = "RequestBlock", -- (active: boolean)
	RequestRespawn = "RequestRespawn", -- ()
	RequestSprint = "RequestSprint", -- (active: boolean)
	RequestDash = "RequestDash", -- (direction: Vector3?, cameraLook: Vector3?) — dash universal (Q); ragdollado = ragdoll cancel
	RequestAbility = "RequestAbility", -- (slot: number, direction: Vector3?)
	RequestAwaken = "RequestAwaken", -- () — G: ativa o Awakening se a carga da ult estiver cheia
	RequestSelectCharacter = "RequestSelectCharacter", -- (characterId: string)
	RequestQueue = "RequestQueue", -- (inQueue: boolean)
	RequestUnlockCharacter = "RequestUnlockCharacter", -- (characterId: string)
	RequestAdminCommand = "RequestAdminCommand", -- (command: string, args: table) — só após FetchAdminLogin ok
	RequestProfile = "RequestProfile", -- () — cliente pronto pede o perfil de novo (o 1º NotifyProfile pode sair antes do boot do cliente)
	RequestShop = "RequestShop", -- (kind: "product"|"pass", key: string) — abre o prompt de compra da Roblox
	RequestCosmetic = "RequestCosmetic", -- (action: "roll"|"equip"|"unequip"|"pick_robux", id: string?)
	RequestEmote = "RequestEmote", -- (emoteId: string) — roda de emotes (B)
	RequestSetting = "RequestSetting", -- (key: string, value: number|boolean) — Controls.Settings; salva em profile.settings
	RequestWar = "RequestWar", -- (action: "queue"|"leave"|"refresh") — guerra de clã (líder/oficial põe o clã na fila)
	RequestClan = "RequestClan", -- (action: "create"|"invite"|"accept"|"decline"|"leave"|"kick"|"promote"|"demote"|"deposit"|"disband"|"refresh", a: any?, b: any?) — create(name, tag), invite/kick/promote/demote(userId), deposit(amount)
	RequestDuel = "RequestDuel", -- (action: "challenge"|"accept"|"decline"|"cancel"|"leave"|"create_room"|"join_room"|"switch_team"|"leave_room"|"list_rooms", userId: number?)
	RequestReport = "RequestReport", -- (targetName: string, reasonId: string, text: string?) — ReportConfig.Reasons

	-- Notify: servidor -> cliente
	NotifyAttack = "NotifyAttack", -- all: (attacker: Model, attackId: "M1"|"Downslam"|"Uppercut", comboIndex: number)
	NotifyDamage = "NotifyDamage", -- all: (attacker: Model?, victim: Model, amount: number, kind: "hit"|"blocked"|"parry"|"guardbreak"|"finisher"|"crit"|"blackflash"|"wallsplat")
	NotifyHealth = "NotifyHealth", -- vítima: (current: number, max: number)
	NotifyKill = "NotifyKill", -- all: (killer: Player?, victim: Player)
	NotifyWarning = "NotifyWarning", -- dono: (kind: "antiexploit", level: number, message: string) — aviso grande na tela
	NotifyStreak = "NotifyStreak", -- all: (event: "milestone"|"shutdown", player: Player, streak: number, data: { coins: number?, victim: string?, ended: number? })
	NotifyCooldown = "NotifyCooldown", -- dono: (reason: "parried"|"guardbreak"|"hit"|"stunned"|"crit_ready", seconds: number)
	NotifyBlock = "NotifyBlock", -- all: (character: Model, active: boolean)
	NotifyKnockback = "NotifyKnockback", -- vítima: (direction: Vector3, speed: number, duration: number, up: number?)
	NotifyDash = "NotifyDash", -- all: (character: Model, data: { Direction: Vector3, Facing: Vector3, Speed: number, Duration: number, Kind: "forward"|"side", Cancel: boolean? })
	NotifyDashCooldown = "NotifyDashCooldown", -- dono: (kind: "forward"|"side"|"cancel", readyAtServerTime: number, total: number)
	NotifyRagdoll = "NotifyRagdoll", -- all: (character: Model, active: boolean, seconds: number?)
	NotifyMatchState = "NotifyMatchState", -- all: (state: "Waiting"|"Selecting"|"InProgress"|"Ending", data: table)
	NotifyAbility = "NotifyAbility", -- all: (character: Model, characterId: string, abilityId: string, phase: string, data: table?)
	NotifyAbilityCooldown = "NotifyAbilityCooldown", -- dono: (slot: number, abilityId: string, readyAtServerTime: number)
	NotifyAbilityDenied = "NotifyAbilityDenied", -- dono: (slot: number, reason: string)
	NotifyProfile = "NotifyProfile", -- dono: (profile: DataConfig.Profile, sessionOnly: boolean)
	NotifyUnlockDenied = "NotifyUnlockDenied", -- dono: (characterId: string, reason: string)
	NotifyLeaderboard = "NotifyLeaderboard", -- all: ({ kills = rows, rating = rows }, rows: { {name: string, value: number} })
	NotifyAdminResult = "NotifyAdminResult", -- dev: (ok: boolean, message: string, data: table?)
	NotifyTrailer = "NotifyTrailer", -- all: (event: "begin"|"shot"|"title"|"fade"|"end", data: table) — TrailerService
	NotifyAnnouncement = "NotifyAnnouncement", -- all/um: (text: string, scope: "global"|"server"|"you", from: string)
	NotifyBoss = "NotifyBoss", -- all: (event: "summoned"|"warning"|"state"|"phase"|"enrage"|"attack"|"defeated"|"despawned"|"denied", data: table)
	NotifyProgression = "NotifyProgression", -- dono: (event: "xp"|"levelup"|"mastery_up", data: table)
	NotifyAchievement = "NotifyAchievement", -- dono: (event: "done"|"list"|"granted", data: table) — AchievementService
	NotifyCosmetics = "NotifyCosmetics", -- dono: (event: "rolled"|"equipped"|"pick_pending"|"denied", data: table)
	NotifyEmote = "NotifyEmote", -- all: (character: Model, emoteId: string, active: boolean)
	NotifyShop = "NotifyShop", -- dono: (event: "purchased"|"denied"|"owned", data: table)
	NotifyWar = "NotifyWar", -- envolvidos: (event: "queue"|"start"|"state"|"end"|"denied"|"info", data: table); "queue" vai para os membros do clã
	NotifyClan = "NotifyClan", -- dono: (event: "state"|"invite"|"denied"|"info", data: table) — state = { clan: ClanConfig.Clan? , role: string? }
	NotifyDuel = "NotifyDuel", -- envolvidos: (event: "invite"|"invite_sent"|"invite_closed"|"start"|"round_end"|"end"|"rating"|"denied"|"state"|"room_joined"|"room_left", data: table; melhor de 3: start/state/round_end trazem round, wins, roundsToWin); todos: "rooms" (lista de salas 2v2)
	NotifyReport = "NotifyReport", -- dono: (ok: boolean, message: string) — resultado do RequestReport
}) :: { [string]: string }

-- RemoteFunctions (cliente -> servidor apenas)
RemoteEvents.Functions = ({
	FetchServerTime = "FetchServerTime", -- () -> number
	FetchAdminLogin = "FetchAdminLogin", -- () -> boolean (abre sessão dev; só para Players em AdminConfig)
	FetchAchievements = "FetchAchievements", -- () -> { season: {...}?, list: { { id, name, desc, progress, goal, done, season, reward } } }
}) :: { [string]: string }

-- ---------------------------------------------------------------------------
-- IMPLEMENTAÇÃO
-- ---------------------------------------------------------------------------

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

--- Servidor: cria todas as instâncias declaradas acima. Idempotente.
function RemoteEvents.Init()
	assert(RunService:IsServer(), "RemoteEvents.Init() só deve ser chamado no servidor")

	local root = getOrCreateFolder(ReplicatedStorage, FOLDER_NAME)
	local eventsFolder = getOrCreateFolder(root, EVENTS_FOLDER)
	local functionsFolder = getOrCreateFolder(root, FUNCTIONS_FOLDER)

	local createdEvents, createdFunctions = 0, 0

	for _, name in RemoteEvents.Events do
		if not eventsFolder:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = eventsFolder
			createdEvents += 1
		end
	end

	for _, name in RemoteEvents.Functions do
		if not functionsFolder:FindFirstChild(name) then
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = functionsFolder
			createdFunctions += 1
		end
	end

	Log.debug(("[RemoteEvents] Init: %d RemoteEvents, %d RemoteFunctions criados"):format(createdEvents, createdFunctions))
end

local function getRemote(subfolder: string, name: string, className: string): Instance
	local root = ReplicatedStorage:WaitForChild(FOLDER_NAME, 10)
	assert(root, "[RemoteEvents] pasta Remotes não encontrada. Init() rodou no servidor?")
	local folder = root:WaitForChild(subfolder, 10)
	assert(folder, ("[RemoteEvents] subpasta %s não encontrada"):format(subfolder))
	local remote = folder:WaitForChild(name, 10)
	assert(remote and remote:IsA(className), ("[RemoteEvents] %s '%s' não encontrado. Está declarado no módulo?"):format(className, name))
	return remote
end

--- Retorna um RemoteEvent pelo nome. Use sempre RemoteEvents.Events.X como argumento.
function RemoteEvents.GetEvent(name: string): RemoteEvent
	return getRemote(EVENTS_FOLDER, name, "RemoteEvent") :: RemoteEvent
end

--- Retorna uma RemoteFunction pelo nome. Use sempre RemoteEvents.Functions.X como argumento.
function RemoteEvents.GetFunction(name: string): RemoteFunction
	return getRemote(FUNCTIONS_FOLDER, name, "RemoteFunction") :: RemoteFunction
end

return RemoteEvents
