--!strict
--[[
	AbilityController (cliente)
	  - E / R / T (ou Gamepad Y / B / R2) -> RequestAbility(1 / 2 / 3, direção)
	  (Q é o dash universal: MovementController.)
	Não decide nada: cooldown mostrado é o que o servidor informou.
	Direção: a do WASD/analógico no momento (ou a frente do personagem se parado). Serve para
	investidas (Effect Dash) e teleporte. O movimento da investida usa
	MovementController.SteerableDash (cliente é dono da física); o DANO é decidido pelo servidor.

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
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local MovementController = require(script.Parent:WaitForChild("MovementController"))

local AbilityController = {}

local localPlayer = Players.LocalPlayer

local SLOT_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.E] = 1,
	[Enum.KeyCode.R] = 2,
	[Enum.KeyCode.T] = 3,
	[Enum.KeyCode.ButtonY] = 1,
	[Enum.KeyCode.ButtonB] = 2,
	[Enum.KeyCode.ButtonR2] = 3,
}

local TRAIL_DEFAULT = Color3.fromRGB(255, 255, 255)
local function trailColor(characterId: string): Color3
	local def = CharacterDefs.Get(characterId)
	return if def and def.Color then def.Color else TRAIL_DEFAULT
end

local requestAbility: RemoteEvent
local cooldowns: { [number]: { abilityId: string, readyAt: number } } = {}

AbilityController.CooldownChanged = Instance.new("BindableEvent")

-- ---------------------------------------------------------------------------
-- Handlers do servidor
-- ---------------------------------------------------------------------------

local function onNotifyAbility(character: Model?, characterId: string, abilityId: string, phase: string, data: any)
	if not character then
		return
	end
	local at: Vector3? = if typeof(data) == "table" and typeof(data.Position) == "Vector3" then data.Position else nil
	if phase == "start" then
		FX.PlayAnimation(character, characterId, abilityId)
		FX.SpawnVFX(character, characterId, abilityId, false, at)
		FX.PlaySoundAt(character, characterId, abilityId)
		if typeof(data) == "table" and typeof(data.Healed) == "number" and data.Healed > 0 then
			FX.DamageNumber(character, "+" .. math.floor(data.Healed), Color3.fromRGB(120, 255, 140))
		end
		if typeof(data) == "table" and data.Speed and data.Duration then
			-- Dash: rastro em todo mundo, movimento só no dono da física
			FX.Trail(character, trailColor(characterId), data.Duration + 0.1)
			if character == localPlayer.Character then
				local dir = if typeof(data.Direction) == "Vector3" then data.Direction else MovementController.MoveDirection(character)
				MovementController.SteerableDash(character, data.Speed, data.Duration, dir)
			end
		elseif typeof(data) == "table" and data.Teleported then
			FX.Trail(character, trailColor(characterId), 0.15, 3)
		end
	elseif phase == "hit" then
		FX.SpawnVFX(character, characterId, abilityId .. "_Hit", true, at)
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
		AbilityController.Use(slot)
	end
end

--- Pede a habilidade do slot ao servidor (teclado, gamepad ou botão de toque).
function AbilityController.Use(slot: number)
	local character = localPlayer.Character
	local direction = if character then MovementController.MoveDirection(character) else nil
	requestAbility:FireServer(slot, direction)
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

	local function onCharacter(character: Model)
		table.clear(cooldowns)
		-- Battlegrounds: o boneco nunca cai/ragdolla por empurrão (dash em parede, knockback)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		end
	end
	localPlayer.CharacterAdded:Connect(onCharacter)
	if localPlayer.Character then
		task.spawn(onCharacter, localPlayer.Character)
	end
	localPlayer:GetAttributeChangedSignal("CharacterId"):Connect(function()
		table.clear(cooldowns)
	end)

	Log.debug("[AbilityController] pronto. E/R/T = habilidades (direção pelo WASD)")
end

return AbilityController
