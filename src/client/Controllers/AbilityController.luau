--!strict
--[[
	AbilityController (cliente)
	  - Q / E / R / T (ou Gamepad X / Y / B / R2) -> RequestAbility(1 / 2 / 3 / 4, direção)
	Não decide nada: cooldown mostrado é o que o servidor informou.
	Direção: a do WASD/analógico no momento (ou a frente do personagem se parado). Serve para
	dash e teleporte. Afinação em CharacterDefs.DashTuning (escala frente/lado, correção pelo WASD,
	duração conta mesmo travado numa parede).
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
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local FX = require(Modules:WaitForChild("FX"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))

local AbilityController = {}

local localPlayer = Players.LocalPlayer

local SLOT_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.Q] = 1,
	[Enum.KeyCode.E] = 2,
	[Enum.KeyCode.R] = 3,
	[Enum.KeyCode.T] = 4,
	[Enum.KeyCode.ButtonX] = 1,
	[Enum.KeyCode.ButtonY] = 2,
	[Enum.KeyCode.ButtonB] = 3,
	[Enum.KeyCode.ButtonR2] = 4,
}

local TRAIL_DEFAULT = Color3.fromRGB(255, 255, 255)
local TRAIL_COLORS: { [string]: Color3 } = {
	Brawler = Color3.fromRGB(255, 150, 60),
	Swift = Color3.fromRGB(110, 230, 255),
	Mystic = Color3.fromRGB(170, 110, 255),
	Guardian = Color3.fromRGB(255, 205, 80),
}

local requestAbility: RemoteEvent
local cooldowns: { [number]: { abilityId: string, readyAt: number } } = {}

AbilityController.CooldownChanged = Instance.new("BindableEvent")
local dashConn: RBXScriptConnection? = nil
local DASH_STOP_DISTANCE = 3.5 -- studs de folga antes do obstáculo
local DASH_RAY_OFFSETS = { Vector3.new(0, 1.5, 0), Vector3.new(0, 0, 0), Vector3.new(0, -2, 0) } -- cabeça, tronco, pés

--- Direção horizontal desejada: WASD/analógico, senão a frente do personagem.
local function moveDirection(character: Model): Vector3
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local move = if humanoid then humanoid.MoveDirection else Vector3.zero
	local flat = Vector3.new(move.X, 0, move.Z)
	if flat.Magnitude > 0.1 then
		return flat.Unit
	end
	if root then
		local look = root.CFrame.LookVector
		flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			return flat.Unit
		end
	end
	return Vector3.new(0, 0, -1)
end

--- Dash dirigível: LinearVelocity cujo vetor segue o WASD enquanto durar (mantém a última direção
--- se soltar as teclas). Sem componente vertical: o Humanoid continua cuidando da gravidade/pulo.
local function steerableDash(character: Model, speed: number, duration: number, initial: Vector3)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local tuning = CharacterDefs.DashTuning
	-- Lateral vs frente/trás: escala da duração (distância) conforme a direção inicial
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local sideways = flatLook.Magnitude > 0.01 and math.abs(initial:Dot(flatLook.Unit)) < 0.5
	duration *= if sideways then tuning.SideScale else tuning.ForwardScale

	if dashConn then
		dashConn:Disconnect()
		dashConn = nil
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.MaxForce = math.huge
	lv.PlaneVelocity = Vector2.new(initial.X, initial.Z) * speed
	lv.Parent = root
	local direction = initial
	local endsAt = os.clock() + duration
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	rayParams.RespectCanCollide = true
	local function finish()
		if dashConn then
			dashConn:Disconnect()
			dashConn = nil
		end
		lv:Destroy()
		attachment:Destroy()
		if root.Parent then
			-- sem momento residual (era isso que o AntiExploit via como "moveu demais" e o
			-- que devolvia o boneco para o lado contrário na parede)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local walk = if humanoid then humanoid.WalkSpeed else 16
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(direction.X * walk, math.min(v.Y, 0), direction.Z * walk)
		end
	end
	dashConn = RunService.Heartbeat:Connect(function(dt)
		if os.clock() >= endsAt or lv.Parent == nil or root.Parent == nil then
			finish()
			return
		end
		-- Correção limitada pelo WASD (SteerRate rad/s): dá para curvar e, se bateu numa parede,
		-- virar e seguir para outro lado — a duração continua contando de qualquer jeito.
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local move = if humanoid then humanoid.MoveDirection else Vector3.zero
		local flat = Vector3.new(move.X, 0, move.Z)
		if flat.Magnitude > 0.1 then
			local want = flat.Unit
			local angle = math.atan2(direction:Cross(want).Y, direction:Dot(want))
			local step = math.clamp(angle, -tuning.SteerRate * dt, tuning.SteerRate * dt)
			direction = (CFrame.Angles(0, step, 0) * direction).Unit
		end
		-- Parede/personagem à frente: zera o empurrão só neste frame (nada de forçar contra o
		-- obstáculo, que travava e derrubava). O tempo do dash não para: sem "dash grátis".
		local ahead = speed * dt + DASH_STOP_DISTANCE
		local blocked = false
		for _, offset in DASH_RAY_OFFSETS do
			if Workspace:Raycast(root.Position + offset, direction * ahead, rayParams) then
				blocked = true
				break
			end
		end
		if blocked then
			lv.PlaneVelocity = Vector2.zero
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, math.min(v.Y, 0), 0)
		else
			lv.PlaneVelocity = Vector2.new(direction.X, direction.Z) * speed
		end
	end)
end

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
				local dir = if typeof(data.Direction) == "Vector3" then data.Direction else moveDirection(character)
				steerableDash(character, data.Speed, data.Duration, dir)
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
	local character = localPlayer.Character
	local direction = if character then moveDirection(character) else nil
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

	Log.debug("[AbilityController] pronto. Q/E/R/T = habilidades (direção pelo WASD)")
end

return AbilityController
