--!strict
--[[
	AbilityController (cliente)
	  - Q / E / R (ou Gamepad X / Y / B) -> RequestAbility(1 / 2 / 3)
	Não decide nada: cooldown mostrado é o que o servidor informou.
	Movimento de Dash é aplicado aqui (cliente é dono da física do próprio
	personagem); o DANO do dash é decidido pelo servidor.

	Feedback por nome em ReplicatedStorage.Assets:
	  Animations.<CharacterId>.<AbilityId>
	  VFX.<CharacterId>.<AbilityId> (start) e <AbilityId>_Hit (impacto)
	  Sounds.<CharacterId>.<AbilityId> (start) e <AbilityId>_Hit (impacto)

	API para a HUD:
	  AbilityController.GetCooldowns() -> { [slot]: { abilityId, readyAt } } (readyAt em GetServerTimeNow)
	  AbilityController.CooldownChanged (BindableEvent) -> (slot, abilityId, readyAt)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local FX = require(Modules:WaitForChild("FX"))

local AbilityController = {}

local localPlayer = Players.LocalPlayer

local SLOT_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.Q] = 1,
	[Enum.KeyCode.E] = 2,
	[Enum.KeyCode.R] = 3,
	[Enum.KeyCode.ButtonX] = 1,
	[Enum.KeyCode.ButtonY] = 2,
	[Enum.KeyCode.ButtonB] = 3,
}

local requestAbility: RemoteEvent
local cooldowns: { [number]: { abilityId: string, readyAt: number } } = {}

AbilityController.CooldownChanged = Instance.new("BindableEvent")

-- ---------------------------------------------------------------------------
-- Dash local: só para o próprio personagem
-- ---------------------------------------------------------------------------

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
-- Handlers do servidor
-- ---------------------------------------------------------------------------

local function onNotifyAbility(character: Model?, characterId: string, abilityId: string, phase: string, data: any)
	if not character then
		return
	end
	if phase == "start" then
		FX.PlayAnimation(character, characterId, abilityId)
		FX.SpawnVFX(character, characterId, abilityId)
		FX.PlaySoundAt(character, characterId, abilityId)
		if character == localPlayer.Character and typeof(data) == "table" and data.Speed and data.Duration then
			applyDash(character, data.Speed, data.Duration)
		end
	elseif phase == "hit" then
		FX.SpawnVFX(character, characterId, abilityId .. "_Hit", true)
		FX.PlaySoundAt(character, characterId, abilityId .. "_Hit")
	end
end

local function onNotifyAbilityCooldown(slot: number, abilityId: string, readyAt: number)
	cooldowns[slot] = { abilityId = abilityId, readyAt = readyAt }
	AbilityController.CooldownChanged:Fire(slot, abilityId, readyAt)
end

local function onNotifyAbilityDenied(slot: number, reason: string)
	Log.debug(("[AbilityController] slot %d negado pelo servidor: %s"):format(slot, reason))
end

-- ---------------------------------------------------------------------------
-- Input / API
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
	end)
	localPlayer:GetAttributeChangedSignal("CharacterId"):Connect(function()
		table.clear(cooldowns)
	end)

	Log.debug("[AbilityController] pronto. Q/E/R = habilidades")
end

return AbilityController
