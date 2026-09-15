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

	Comandos (args.target = nome ou UserId do alvo; ausente = o próprio dev):
	  SetCoins {amount}, AddCoins {amount}, GrantCharacter {characterId},
	  RevokeCharacter {characterId}, SetCharacter {characterId}, Heal, Kill,
	  God {enabled}, Teleport (dev -> alvo), Bring (alvo -> dev), Kick {reason},
	  ResetData, SetEnergy {amount}, ListPlayers
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
local DataService = require(script.Parent:WaitForChild("DataService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))

local AdminService = {}

-- Ganchos preenchidos por AbilityService no Start (evita require circular)
AdminService.ForceCharacter = function(_player: Player, _characterId: string) end
AdminService.SetEnergy = function(_player: Player, _amount: number) end

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

local function findTarget(admin: Player, raw: any): Player?
	if raw == nil or raw == "" then
		return admin
	end
	if typeof(raw) == "number" then
		return Players:GetPlayerByUserId(raw)
	end
	if typeof(raw) == "string" then
		local lowered = raw:lower()
		for _, p in Players:GetPlayers() do
			if p.Name:lower() == lowered or p.DisplayName:lower() == lowered then
				return p
			end
		end
		for _, p in Players:GetPlayers() do
			if p.Name:lower():sub(1, #lowered) == lowered then
				return p
			end
		end
	end
	return nil
end

local function number(value: any, default: number?): number?
	if typeof(value) == "number" then
		return value
	end
	if typeof(value) == "string" then
		return tonumber(value)
	end
	return default
end

type Handler = (admin: Player, target: Player, args: { [string]: any }) -> (boolean, string)
local commands: { [string]: Handler } = {}

commands.SetCoins = function(_, target, args)
	local amount = number(args.amount)
	if not amount then
		return false, "amount inválido"
	end
	DataService.SetCoins(target, amount)
	return true, ("%s agora tem %d moedas"):format(target.Name, math.max(0, math.floor(amount)))
end

commands.AddCoins = function(_, target, args)
	local amount = number(args.amount)
	if not amount then
		return false, "amount inválido"
	end
	DataService.AddCoins(target, amount)
	local profile = DataService.GetProfile(target)
	return true, ("%s: %+d moedas (total %d)"):format(target.Name, amount, if profile then profile.coins else 0)
end

commands.GrantCharacter = function(_, target, args)
	local id = args.characterId
	if typeof(id) ~= "string" or not CharacterDefs.Get(id) then
		return false, "personagem desconhecido"
	end
	if not DataService.GrantCharacter(target, id) then
		return false, ("%s já tem %s"):format(target.Name, id)
	end
	return true, ("%s recebeu %s"):format(target.Name, id)
end

commands.RevokeCharacter = function(_, target, args)
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

commands.SetCharacter = function(_, target, args)
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

commands.Heal = function(_, target)
	local character = target.Character
	if not character then
		return false, "sem personagem"
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false, "sem humanoid"
	end
	HealthService.Heal(character, humanoid.MaxHealth)
	return true, ("%s curado"):format(target.Name)
end

commands.Kill = function(_, target)
	local character = target.Character
	if not character then
		return false, "sem personagem"
	end
	HealthService.Kill(character)
	return true, ("%s eliminado"):format(target.Name)
end

commands.God = function(_, target, args)
	local enabled = args.enabled
	if typeof(enabled) ~= "boolean" then
		enabled = target:GetAttribute("Invulnerable") ~= true
	end
	target:SetAttribute("Invulnerable", if enabled then true else nil)
	return true, ("%s: modo deus %s"):format(target.Name, if enabled then "ON" else "OFF")
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

commands.Teleport = function(admin, target)
	return moveTo(admin, target)
end

commands.Bring = function(admin, target)
	return moveTo(target, admin)
end

commands.Kick = function(admin, target, args)
	if target == admin then
		return false, "não dá pra se kickar"
	end
	local reason = if typeof(args.reason) == "string" then args.reason else "Removido por um desenvolvedor"
	target:Kick(reason)
	return true, ("%s kickado"):format(target.Name)
end

commands.ResetData = function(_, target)
	DataService.ResetProfile(target)
	AdminService.ForceCharacter(target, CharacterDefs.DefaultCharacter)
	return true, ("dados de %s zerados (salva no próximo autosave)"):format(target.Name)
end

commands.SetEnergy = function(_, target, args)
	local amount = number(args.amount)
	if not amount then
		return false, "amount inválido"
	end
	AdminService.SetEnergy(target, amount)
	return true, ("%s: energia %d"):format(target.Name, amount)
end

commands.ListPlayers = function()
	local names = {}
	for _, p in Players:GetPlayers() do
		table.insert(names, ("%s (%d)"):format(p.Name, p.UserId))
	end
	return true, table.concat(names, ", ")
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
	if not commandLimiter:Allow(player) then
		return
	end
	if typeof(command) ~= "string" then
		return
	end
	local handler = commands[command]
	if not handler then
		notifyResult:FireClient(player, false, "comando desconhecido: " .. command)
		return
	end
	local safeArgs: { [string]: any } = if typeof(args) == "table" then args else {}
	local target = findTarget(player, safeArgs.target)
	if not target then
		notifyResult:FireClient(player, false, "jogador não encontrado: " .. tostring(safeArgs.target))
		return
	end
	local ok, result, message = pcall(handler, player, target, safeArgs)
	if not ok then
		warn(("[AdminService] erro em %s: %s"):format(command, tostring(result)))
		notifyResult:FireClient(player, false, "erro: " .. tostring(result))
		return
	end
	warn(("[AdminService] %s -> %s(%s): %s"):format(player.Name, command, target.Name, tostring(message)))
	notifyResult:FireClient(player, result == true, tostring(message))
end

function AdminService.Init()
	notifyResult = Remotes.GetEvent(Remotes.Events.NotifyAdminResult)
end

function AdminService.Start()
	Remotes.GetFunction(Remotes.Functions.FetchAdminLogin).OnServerInvoke = onLogin
	Remotes.GetEvent(Remotes.Events.RequestAdminCommand).OnServerEvent:Connect(onCommand)

	local function onPlayer(player: Player)
		if isDeveloper(player) then
			player:SetAttribute("IsDeveloper", true)
		end
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
