--!strict
--[[
	AbilityController (cliente)
	  - Slot1..4 / Awaken (teclas em Controls.luau: 1-4 / G; gamepad LB/LT/RT/RB / D-pad cima) -> RequestAbility / RequestAwaken
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
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Controls = require(Modules:WaitForChild("Controls"))
local Log = require(Modules:WaitForChild("Log"))
local FX = require(Modules:WaitForChild("FX"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local MovementController = require(script.Parent:WaitForChild("MovementController"))
local CutsceneController = require(script.Parent:WaitForChild("CutsceneController"))

local AbilityController = {}

local localPlayer = Players.LocalPlayer

local TRAIL_DEFAULT = Color3.fromRGB(255, 255, 255)
local function trailColor(characterId: string): Color3
	local def = CharacterDefs.Get(characterId)
	return if def and def.Color then def.Color else TRAIL_DEFAULT
end


local requestAbility: RemoteEvent
local requestAwaken: RemoteEvent
local grabConn: RBXScriptConnection? = nil -- eu estou sendo carregado por um agarrão

local function stopGrabbed()
	if grabConn then
		grabConn:Disconnect()
		grabConn = nil
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and localPlayer:GetAttribute("Ragdolled") ~= true then
		humanoid.PlatformStand = false -- (caído, o RagdollService é quem manda)
	end
end

--- Preso num agarrão: meu boneco (eu sou dono da física) fica colado à frente do atacante por `seconds`.
--- `lift` = studs acima (chokeslam); `spin` = voltas/s ao redor do atacante (mesma fórmula do servidor:
--- AbilityService.spinAngle, que calcula a tangente na hora de soltar).
local function startGrabbed(attacker: Model, seconds: number, offset: number, lift: number?, spin: number?)
	stopGrabbed()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local aRoot = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not humanoid or not aRoot then
		return
	end
	humanoid.PlatformStand = true
	local startedAt = os.clock()
	local endsAt = startedAt + seconds
	grabConn = RunService.RenderStepped:Connect(function()
		if os.clock() >= endsAt or not aRoot.Parent or not root.Parent then
			stopGrabbed()
			return
		end
		-- de frente para o atacante, colado à frente dele (erguido se lift; orbitando se spin)
		local angle = if spin then (os.clock() - startedAt) * spin * math.pi * 2 else 0
		local target = aRoot.CFrame * CFrame.Angles(0, angle, 0) * CFrame.new(0, lift or 0, -offset)
		local lookAt = Vector3.new(aRoot.Position.X, target.Position.Y, aRoot.Position.Z)
		root.CFrame = CFrame.lookAt(target.Position, lookAt)
		root.AssemblyLinearVelocity = Vector3.zero
	end)
end
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
	if abilityId == "Awakening" then
		-- Modo: aura que segue o personagem (VFX.<Char>.Awakening ou Shared.Awakening) + contorno dourado
		if phase == "start" then
			-- Cutscene de transformação (câmera + poses + VFX + sons); a aura/contorno do modo ficam depois
			CutsceneController.PlayAwakening(character, characterId, data)
			FX.PlayAnimation(character, characterId, "Awakening") -- se a equipe publicar uma, toca por cima
		else
			FX.SetOutline(character, nil)
			FX.PlaySoundAt(character, "Shared", "Awakening_End")
		end
		return
	end
	if phase == "start" then
		FX.PlayAnimation(character, characterId, abilityId)
		FX.SpawnVFX(character, characterId, abilityId, false, at)
		FX.PlaySoundAt(character, characterId, abilityId)
		-- ultimate (a habilidade com EnergyCost = Max): estouro da aura por cima do som próprio
		local def = CharacterDefs.Get(characterId)
		if def then
			for _, ab in def.Abilities do
				if ab.Id == abilityId and ab.EnergyCost >= CharacterDefs.Energy.Max then
					FX.PlaySoundAt(character, "Shared", "Awakening_Burst")
					break
				end
			end
		end
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
	elseif phase == "grab" then
		-- agarrou: a vítima segue o atacante (no cliente dela); todos veem a animação de carregar
		FX.PlayAnimation(character, characterId, abilityId .. "_Carry")
		local victim = if typeof(data) == "table" then data.Victim else nil
		if typeof(victim) == "Instance" and victim == localPlayer.Character then
			startGrabbed(character, tonumber(data.Carry) or 0.8, tonumber(data.Offset) or 3, tonumber(data.Lift), tonumber(data.Spin))
			FX.Shake(0.4, 0.2)
		end
	elseif phase == "release" then
		local victim = if typeof(data) == "table" then data.Victim else nil
		if typeof(victim) == "Instance" and victim == localPlayer.Character then
			stopGrabbed()
		end
	elseif phase == "hit" then
		local victim = if typeof(data) == "table" then data.Victim else nil
		if typeof(victim) == "Instance" and victim == localPlayer.Character then
			stopGrabbed()
			FX.Shake(0.6, 0.3)
		end
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
	local action = Controls.ActionOf(input)
	local slot = if action then tonumber(action:match("^Slot(%d)$")) else nil
	if slot then
		AbilityController.Use(slot)
	elseif action == "Awaken" then
		AbilityController.Awaken()
	end
end

--- Pede o Awakening (G / botão de toque). O servidor confere a carga.
function AbilityController.Awaken()
	requestAwaken:FireServer()
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
	requestAwaken = Remotes.GetEvent(Remotes.Events.RequestAwaken)
end

function AbilityController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyAbility).OnClientEvent:Connect(onNotifyAbility)
	Remotes.GetEvent(Remotes.Events.NotifyAbilityCooldown).OnClientEvent:Connect(onNotifyAbilityCooldown)
	Remotes.GetEvent(Remotes.Events.NotifyAbilityDenied).OnClientEvent:Connect(onNotifyAbilityDenied)
	UserInputService.InputBegan:Connect(onInputBegan)

	local function onCharacter(character: Model)
		table.clear(cooldowns)
		stopGrabbed()
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

	Log.debug("[AbilityController] pronto. 1/2/3/4 = habilidades (direção pelo WASD), G = ultimate")
end

return AbilityController
