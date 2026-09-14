--!strict
--[[
	AbilityController (cliente)
	  - Q / E / R  -> RequestAbility(1 / 2 / 3)
	  (seleção de personagem fica no LobbyController)
	Não decide nada: o cooldown mostrado é apenas o que o servidor informou.
	Movimento de Dash é aplicado aqui porque o cliente é dono da física do
	próprio personagem; o DANO do dash continua sendo decidido pelo servidor.

	Feedback: animação Assets.Animations.<CharacterId>.<AbilityId>,
	VFX clonado de Assets.VFX.<CharacterId>.<AbilityId>, e um painel de
	debug com cooldowns/energia (TODO: substituir pela HUD real).

	API para a HUD futura:
	  AbilityController.GetCooldowns() -> { [slot]: { abilityId, readyAt } } (readyAt em GetServerTimeNow)
	  AbilityController.CooldownChanged (BindableEvent) disparado a cada NotifyAbilityCooldown
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local Assets = require(Modules:WaitForChild("Assets"))

local AbilityController = {}

local localPlayer = Players.LocalPlayer

local SLOT_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.Q] = 1,
	[Enum.KeyCode.E] = 2,
	[Enum.KeyCode.R] = 3,
}
local VFX_LIFETIME = 2

local requestAbility: RemoteEvent

local cooldowns: { [number]: { abilityId: string, readyAt: number } } = {}
local animCache: { [string]: AnimationTrack } = {}

AbilityController.CooldownChanged = Instance.new("BindableEvent")

-- ---------------------------------------------------------------------------
-- Feedback
-- ---------------------------------------------------------------------------

local function playAnim(character: Model, characterId: string, abilityId: string)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local key = tostring(character) .. "/" .. characterId .. "/" .. abilityId
	local track = animCache[key]
	if not track then
		local anim = Assets.GetAnimation(characterId, abilityId)
		if not anim then
			return
		end
		track = animator:LoadAnimation(anim)
		animCache[key] = track
	end
	track:Play()
end

local function spawnVFX(character: Model, characterId: string, abilityId: string)
	local template = Assets.GetVFX(characterId, abilityId)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not template or not root then
		return
	end
	local clone = template:Clone()
	if clone:IsA("Attachment") then
		clone.Parent = root
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.CFrame = root.CFrame
		clone.Parent = Workspace
	elseif clone:IsA("Model") then
		clone:PivotTo(root.CFrame)
		clone.Parent = Workspace
	else
		clone.Parent = root
	end
	for _, emitter in clone:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			local count = emitter:GetAttribute("EmitCount")
			emitter:Emit(if typeof(count) == "number" then count else 20)
		end
	end
	if clone:IsA("ParticleEmitter") then
		clone:Emit(20)
	end
	task.delay(VFX_LIFETIME, function()
		clone:Destroy()
	end)
end

-- Dash local: só para o próprio personagem
local function applyDash(character: Model, speed: number, duration: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = math.huge
	lv.VectorVelocity = root.CFrame.LookVector * speed
	lv.Parent = root
	task.delay(duration, function()
		lv:Destroy()
		attachment:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- Painel de debug (TODO: substituir pela HUD real no sub-prompt de HUD)
-- ---------------------------------------------------------------------------

local debugLabel: TextLabel

local function buildDebugPanel()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AbilityDebug"
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(320, 110)
	label.Position = UDim2.new(0, 10, 1, -120)
	label.BackgroundTransparency = 0.4
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Font = Enum.Font.Code
	label.TextSize = 14
	label.Parent = gui
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	debugLabel = label
end

local function refreshDebugPanel()
	if not debugLabel then
		return
	end
	local characterId = localPlayer:GetAttribute("CharacterId")
	local energy = localPlayer:GetAttribute("Energy")
	local def = if typeof(characterId) == "string" then CharacterDefs.Get(characterId) else nil
	local lines = {
		("Personagem: %s   Energia: %s/%d"):format(tostring(characterId), tostring(energy), CharacterDefs.Energy.Max),
	}
	if def then
		local keys = { "Q", "E", "R" }
		local now = Workspace:GetServerTimeNow()
		for slot, ability in def.Abilities do
			local cd = cooldowns[slot]
			local remaining = if cd then math.max(0, cd.readyAt - now) else 0
			local status = if remaining > 0 then ("%.1fs"):format(remaining) else "PRONTO"
			table.insert(lines, ("[%s] %-14s %s  (%d energia)"):format(keys[slot] or "?", ability.DisplayName, status, ability.EnergyCost))
		end
	end
	debugLabel.Text = table.concat(lines, "\n")
end

-- ---------------------------------------------------------------------------
-- Handlers do servidor
-- ---------------------------------------------------------------------------

local function onNotifyAbility(character: Model?, characterId: string, abilityId: string, phase: string, data: any)
	if not character then
		return
	end
	if phase == "start" then
		playAnim(character, characterId, abilityId)
		spawnVFX(character, characterId, abilityId)
		if character == localPlayer.Character and typeof(data) == "table" and data.Speed and data.Duration then
			applyDash(character, data.Speed, data.Duration)
		end
	elseif phase == "hit" then
		-- ponto de extensão: VFX de impacto (Assets.VFX.<CharacterId>.<AbilityId>_Hit)
		if Assets.HasVFX(characterId, abilityId .. "_Hit") then
			spawnVFX(character, characterId, abilityId .. "_Hit")
		end
	end
end

local function onNotifyAbilityCooldown(slot: number, abilityId: string, readyAt: number)
	cooldowns[slot] = { abilityId = abilityId, readyAt = readyAt }
	AbilityController.CooldownChanged:Fire(slot, abilityId, readyAt)
end

local function onNotifyAbilityDenied(slot: number, reason: string)
	-- TODO(launch): reduzir log; HUD deve piscar o slot
	print(("[AbilityController] slot %d negado pelo servidor: %s"):format(slot, reason))
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local slot = SLOT_KEYS[input.KeyCode]
	if slot then
		requestAbility:FireServer(slot)
	end
end

-- ---------------------------------------------------------------------------
-- API pública
-- ---------------------------------------------------------------------------

function AbilityController.GetCooldowns()
	return cooldowns
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function AbilityController.Init()
	requestAbility = Remotes.GetEvent(Remotes.Events.RequestAbility)
end

function AbilityController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyAbility).OnClientEvent:Connect(onNotifyAbility)
	Remotes.GetEvent(Remotes.Events.NotifyAbilityCooldown).OnClientEvent:Connect(onNotifyAbilityCooldown)
	Remotes.GetEvent(Remotes.Events.NotifyAbilityDenied).OnClientEvent:Connect(onNotifyAbilityDenied)
	UserInputService.InputBegan:Connect(onInputBegan)

	localPlayer.CharacterAdded:Connect(function()
		table.clear(cooldowns)
		table.clear(animCache)
	end)
	localPlayer:GetAttributeChangedSignal("CharacterId"):Connect(function()
		table.clear(cooldowns)
	end)

	buildDebugPanel()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			refreshDebugPanel()
		end
	end)

	-- TODO(launch): reduzir log
	print("[AbilityController] pronto. Q/E/R = habilidades")
end

return AbilityController
