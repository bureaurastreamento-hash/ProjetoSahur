--!strict
--[[
	CharacterService
	Garante rig R6 para TODO jogador, sem depender do Game Settings > Avatar (que no place
	oficial continuou entregando R15 mesmo configurado como R6, e as animações da equipe
	são R6). Desliga o CharacterAutoLoads e monta o personagem na mão:
	  Players:CreateHumanoidModelFromDescription(descrição do avatar do jogador, R6)
	Mantém roupas/acessórios/cores do avatar do jogador (pacotes de corpo R15 são ignorados).

	Quem precisava de player:LoadCharacter() agora chama CharacterService.Load(player).
	Respawn automático após CombatConfig.RespawnTime (antes era o engine que fazia).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local Log = require(Modules:WaitForChild("Log"))

local CharacterService = {}

--- Nome mostrado sobre a cabeça: "[CLÃ] [Título] Nick" (atributos ClanTag do ClanService e NameTag do
--- ProgressionService/ShopService).
function CharacterService.DisplayNameFor(player: Player): string
	local name = player.DisplayName
	local title = player:GetAttribute("NameTag")
	if typeof(title) == "string" and title ~= "" then
		name = ("[%s] %s"):format(title, name)
	end
	local clan = player:GetAttribute("ClanTag")
	if typeof(clan) == "string" and clan ~= "" then
		name = ("[%s] %s"):format(clan, name)
	end
	return name
end

--- Reaplica o DisplayName no personagem atual (quando ClanTag/NameTag mudam sem respawn).
function CharacterService.RefreshDisplayName(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = CharacterService.DisplayNameFor(player)
	end
end

local descriptionCache: { [Player]: HumanoidDescription } = {}
local loading: { [Player]: boolean } = {}

local function getDescription(player: Player): HumanoidDescription
	local cached = descriptionCache[player]
	if cached then
		return cached
	end
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)
	if not ok or typeof(desc) ~= "Instance" then
		Log.debug(("[CharacterService] sem descrição do avatar de %s (%s); usando padrão"):format(player.Name, tostring(desc)))
		desc = Instance.new("HumanoidDescription")
	end
	descriptionCache[player] = desc :: HumanoidDescription
	return desc :: HumanoidDescription
end

--- Mesma regra do LoadCharacter: RespawnLocation, senão um SpawnLocation habilitado e neutro
--- (fora das arenas de duelo), senão a origem.
local function pickSpawn(player: Player): CFrame
	local respawn = player.RespawnLocation
	if respawn and respawn.Parent and respawn.Enabled then
		return respawn.CFrame + Vector3.new(0, respawn.Size.Y / 2, 0)
	end
	local duels = Workspace:FindFirstChild("Duels")
	local candidates: { SpawnLocation } = {}
	for _, d in Workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and d.Enabled and (d.Neutral or player.TeamColor == d.TeamColor) then
			if not (duels and d:IsDescendantOf(duels)) then
				table.insert(candidates, d)
			end
		end
	end
	if #candidates == 0 then
		return CFrame.new(0, 10, 0)
	end
	local spawn = candidates[math.random(#candidates)]
	return CFrame.new(spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0))
		* CFrame.Angles(0, math.rad(spawn.Orientation.Y), 0)
end

local function buildCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(getDescription(player), Enum.HumanoidRigType.R6)
	end)
	if not ok or typeof(model) ~= "Instance" then
		warn(("[CharacterService] não consegui montar o rig R6 de %s: %s"):format(player.Name, tostring(model)))
		return nil, nil, nil
	end
	local m = model :: Model
	local humanoid = m:FindFirstChildOfClass("Humanoid")
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		m:Destroy()
		warn(("[CharacterService] rig de %s veio sem Humanoid/HumanoidRootPart"):format(player.Name))
		return nil, nil, nil
	end
	m.Name = player.Name
	m.PrimaryPart = root
	humanoid.DisplayName = CharacterService.DisplayNameFor(player)
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	-- "Health" padrão regenera sozinho; o nosso (StarterCharacterScripts) substitui. Animate fica (pulo/queda).
	local defaultHealth = m:FindFirstChild("Health")
	if defaultHealth and defaultHealth:IsA("Script") then
		defaultHealth:Destroy()
	end
	return m, humanoid, root
end

--- Põe `model` (com Humanoid + HumanoidRootPart) como personagem do jogador em `cf`, com os scripts de
--- StarterCharacterScripts e respawn automático. Usado pelo Load (R6) e pela forma de boss (BossFormService).
function CharacterService.LoadModel(player: Player, model: Model, cf: CFrame): boolean
	if player.Parent ~= Players then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return false
	end
	model.Name = player.Name
	model.PrimaryPart = root
	humanoid.DisplayName = CharacterService.DisplayNameFor(player)
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	local starterScripts = StarterPlayer:FindFirstChild("StarterCharacterScripts")
	if starterScripts then
		for _, sc in starterScripts:GetChildren() do
			if not model:FindFirstChild(sc.Name) then
				sc:Clone().Parent = model
			end
		end
	end
	local old = player.Character
	model:PivotTo(cf)
	if old and old ~= model then
		old:Destroy()
	end
	player.Character = model -- dispara CharacterAdded
	model.Parent = Workspace
	pcall(function()
		root:SetNetworkOwner(player)
	end)
	-- Respawn automático (o engine só faz isso com CharacterAutoLoads = true)
	humanoid.Died:Once(function()
		task.delay(Players.RespawnTime, function()
			if player.Parent == Players and player.Character == model then
				CharacterService.Load(player)
			end
		end)
	end)
	return true
end

--- Substitui player:LoadCharacter(): remove o personagem atual e monta um R6 novo no spawn.
function CharacterService.Load(player: Player)
	if player.Parent ~= Players or loading[player] then
		return
	end
	loading[player] = true
	local ok, err = pcall(function()
		local model = buildCharacter(player)
		if not model then
			return nil
		end
		-- R6: pernas 2 + metade do HRP 1
		if not CharacterService.LoadModel(player, model, pickSpawn(player) * CFrame.new(0, 3.05, 0)) then
			model:Destroy()
		end
		return nil
	end)
	loading[player] = nil
	if not ok then
		warn(("[CharacterService] falha ao carregar %s: %s"):format(player.Name, tostring(err)))
	end
end

function CharacterService.Init()
	Players.CharacterAutoLoads = false
	Players.RespawnTime = CombatConfig.RespawnTime

	local function onPlayer(player: Player)
		-- deixa os outros services conectarem CharacterAdded antes do primeiro spawn
		task.defer(function()
			task.wait()
			CharacterService.Load(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		descriptionCache[player] = nil
		loading[player] = nil
	end)
	Log.info("[CharacterService] rig R6 forçado no servidor (CharacterAutoLoads desligado)")
end

return CharacterService
