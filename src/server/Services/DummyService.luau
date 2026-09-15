--!strict
--[[
	DummyService (servidor)
	Bonecos de treino no mapa livre. Rig R6 criado em runtime
	(Players:CreateHumanoidModelFromDescription), tag "Combatant" para a Hitbox
	aceitar, vida via HealthService (dano normal, sem crédito de kill/moedas: não é Player).
	Posições: Parts "DummyPad*" em Workspace.Sahur (ArenaExtras); sem pads = nada.
	Respawn RESPAWN_SECONDS depois de morrer.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))

local DummyService = {}

DummyService.Enabled = true
local RESPAWN_SECONDS = 4
local PAD_PREFIX = "DummyPad"
local FOLDER_NAME = "Dummies"
local HEALTH = CombatConfig.MaxHealth

local folder: Folder

local function findPads(): { BasePart }
	local pads: { BasePart } = {}
	local arena = Workspace:FindFirstChild("Sahur") -- Arena (importado) + ArenaExtras (spawns/pads/placar)
	if not arena then
		return pads
	end
	for _, d in arena:GetDescendants() do
		if d:IsA("BasePart") and d.Name:sub(1, #PAD_PREFIX) == PAD_PREFIX then
			table.insert(pads, d)
		end
	end
	table.sort(pads, function(a, b)
		return a.Name < b.Name
	end)
	return pads
end

local function buildRig(index: number): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("[DummyService] não consegui criar o rig: " .. tostring(model))
		return nil
	end
	model.Name = "Boneco " .. index
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if not humanoid:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = humanoid -- animação de "Hit" do cliente precisa dele
		end
		humanoid.DisplayName = "Boneco de treino"
		humanoid.MaxHealth = HEALTH
		humanoid.Health = HEALTH
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
		humanoid.NameDisplayDistance = 60
		humanoid.BreakJointsOnDeath = false
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true -- estático de verdade: nada de física afundando/deitando o boneco
			d.CanCollide = d.Name ~= "HumanoidRootPart"
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy() -- Animate/Health padrão não interessam
		end
	end
	local torso = model:FindFirstChild("Torso") :: BasePart?
	if torso then
		torso.Color = Color3.fromRGB(150, 60, 60)
	end
	CollectionService:AddTag(model, "Combatant")
	return model
end

local function spawnAt(pad: BasePart, index: number)
	local model = buildRig(index)
	if not model then
		return
	end
	-- apoia os pés no chão real abaixo do pad (o mapa da equipe pode não estar em y=0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, pad }
	local hit = Workspace:Raycast(pad.Position + Vector3.new(0, 5, 0), Vector3.new(0, -30, 0), params)
	local floorY = if hit then hit.Position.Y else pad.Position.Y + pad.Size.Y / 2
	local rootY = floorY + 3 + 0.05 -- R6: pernas 2 + metade do HRP 1
	local cf = CFrame.new(pad.Position.X, math.max(rootY, pad.Position.Y + pad.Size.Y / 2 + 3), pad.Position.Z) * CFrame.Angles(0, math.rad(180), 0)
	model:PivotTo(cf)
	model.Parent = folder
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- regen própria fora de combate (a do HealthService só cobre Players)
		local lastHit = os.clock()
		humanoid.HealthChanged:Connect(function(health: number)
			if health < HEALTH then
				lastHit = os.clock()
			end
		end)
		task.spawn(function()
			while model.Parent and humanoid.Health > 0 do
				task.wait(1)
				if os.clock() - lastHit >= CombatConfig.Regen.Delay and humanoid.Health < HEALTH then
					humanoid.Health = math.min(HEALTH, humanoid.Health + CombatConfig.Regen.PerSecond * 3)
				end
			end
		end)
		humanoid.Died:Once(function()
			task.delay(RESPAWN_SECONDS, function()
				model:Destroy()
				if DummyService.Enabled and pad.Parent then
					spawnAt(pad, index)
				end
			end)
		end)
	end
end

local function ensureFolder(): Folder
	if not folder then
		local f = Workspace:FindFirstChild(FOLDER_NAME) :: Folder? or Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = Workspace
		folder = f
	end
	return folder
end

--- [Admin] Remove todos e recria (se Enabled).
function DummyService.Respawn(): number
	ensureFolder():ClearAllChildren()
	if not DummyService.Enabled then
		return 0
	end
	local pads = findPads()
	for i, pad in pads do
		spawnAt(pad, i)
	end
	return #pads
end

--- [Admin] Liga/desliga.
function DummyService.SetEnabled(enabled: boolean): number
	DummyService.Enabled = enabled
	return DummyService.Respawn()
end

function DummyService.Start()
	if not DummyService.Enabled then
		return
	end
	ensureFolder()
	local pads = findPads()
	for i, pad in pads do
		spawnAt(pad, i)
	end
	Log.debug(("[DummyService] %d boneco(s) de treino"):format(#pads))
end

return DummyService
