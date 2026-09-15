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

local TRAIL_DEFAULT = Color3.fromRGB(255, 255, 255)
local TRAIL_COLORS: { [string]: Color3 } = {
	Brawler = Color3.fromRGB(255, 150, 60),
	Swift = Color3.fromRGB(110, 230, 255),
	Mystic = Color3.fromRGB(170, 110, 255),
}

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
			FX.Trail(character, TRAIL_COLORS[characterId] or TRAIL_DEFAULT, data.Duration + 0.1)
			if character == localPlayer.Character then
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					FX.Push(character, root.CFrame.LookVector * data.Speed, data.Duration)
				end
			end
		elseif typeof(data) == "table" and data.Teleported then
			FX.Trail(character, TRAIL_COLORS[characterId] or TRAIL_DEFAULT, 0.15, 3)
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
	requestAbility:FireServer(slot)
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
