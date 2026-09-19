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
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Controls = require(Modules:WaitForChild("Controls"))
local Log = require(Modules:WaitForChild("Log"))
local FX = require(Modules:WaitForChild("FX"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local MovementController = require(script.Parent:WaitForChild("MovementController"))
local CutsceneController = require(script.Parent:WaitForChild("CutsceneController"))
local AwakeningDefs = require(Modules:WaitForChild("AwakeningDefs"))
local VFXLibrary = require(Modules:WaitForChild("VFXLibrary"))
local RigAnimController = require(script.Parent:WaitForChild("RigAnimController"))

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

local grabbedTrackRef: { track: AnimationTrack? } = { track = nil }
local function stopGrabbed()
	if grabConn then
		grabConn:Disconnect()
		grabConn = nil
	end
	if grabbedTrackRef.track then
		grabbedTrackRef.track:Stop(0.15)
		grabbedTrackRef.track = nil
	end
	local character = localPlayer.Character
	if character then
		FX.StopAnimation(character, "Shared", "Grabbed") -- versão procedural (loop)
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and localPlayer:GetAttribute("Ragdolled") ~= true then
		humanoid.PlatformStand = false -- (caído, o RagdollService é quem manda)
	end
end

--- Preso num agarrão: o servidor já me soldou no atacante (Weld HRP→HRP, física no cliente dele); aqui só
--- a animação de "agarrado" (Shared/Grabbed, loop) e o PlatformStand local para o Humanoid não tentar andar.
local function startGrabbed(attacker: Model, seconds: number)
	stopGrabbed()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	humanoid.PlatformStand = true
	grabbedTrackRef.track = FX.PlayAnimation(character, "Shared", "Grabbed", true, Enum.AnimationPriority.Action)
	grabConn = RunService.Heartbeat:Connect(function()
		if not attacker.Parent then
			stopGrabbed()
		end
	end)
	task.delay(seconds + 0.5, stopGrabbed)
end
local cooldowns: { [number]: { abilityId: string, readyAt: number } } = {}

AbilityController.CooldownChanged = Instance.new("BindableEvent")

-- ---------------------------------------------------------------------------
-- Handlers do servidor
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- DOMÍNIO DO TEMPO (Swift): cúpula visual no ponto do cast (Ball ForceField + anel no chão + ponteiro
-- girando devagar), som em loop; quebra (estilhaça) quando o Swift sai; some no fim.
-- ---------------------------------------------------------------------------
local domes: { [Model]: { parts: { BasePart }, stopLoop: (() -> ())?, conn: RBXScriptConnection? } } = {}
local DOME_COLOR = Color3.fromRGB(110, 230, 255)

local function destroyDome(character: Model, shatter: boolean)
	local d = domes[character]
	if not d then
		return
	end
	domes[character] = nil
	if d.conn then
		d.conn:Disconnect()
	end
	if d.stopLoop then
		d.stopLoop()
	end
	for _, p in d.parts do
		if shatter then
			TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1, Size = p.Size * 1.08 }):Play()
		else
			TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Transparency = 1 }):Play()
		end
		task.delay(0.7, function()
			p:Destroy()
		end)
	end
end

local function createDome(character: Model, center: Vector3, radius: number, duration: number, growSeconds: number?)
	destroyDome(character, false)
	local parts: { BasePart } = {}
	local function mk(name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, material: Enum.Material, transparency: number): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.CFrame = cf
		p.Color = DOME_COLOR
		p.Material = material
		p.Transparency = transparency
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = Workspace
		table.insert(parts, p)
		return p
	end
	local dome = mk("TimeDome", Enum.PartType.Ball, Vector3.new(1, 1, 1), CFrame.new(center), Enum.Material.ForceField, 0.5)
	-- cresce durante a "carga" da animação (Cinematic.Charge) e estoura no tamanho final
	local grow = growSeconds or 0.35
	TweenService:Create(dome, TweenInfo.new(grow, if growSeconds then Enum.EasingStyle.Quart else Enum.EasingStyle.Back, if growSeconds then Enum.EasingDirection.In else Enum.EasingDirection.Out), { Size = Vector3.new(radius * 2, radius * 2, radius * 2) }):Play()
	local ring = mk("TimeDomeRing", Enum.PartType.Cylinder, Vector3.new(0.2, radius * 2, radius * 2), CFrame.new(center - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon, 0.88)
	local hand = mk("TimeDomeHand", Enum.PartType.Block, Vector3.new(0.35, 0.2, radius * 0.9), CFrame.new(center - Vector3.new(0, 2.4, 0)), Enum.Material.Neon, 0.3)
	local light = Instance.new("PointLight")
	light.Color = DOME_COLOR
	light.Range = radius * 1.5
	light.Brightness = 1.2
	light.Parent = dome
	local t0 = os.clock()
	local conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		-- ponteiro do relógio girando DEVAGAR (o tempo quase parado) + anel pulsando
		hand.CFrame = CFrame.new(center - Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, -t * 0.35, 0) * CFrame.new(0, 0, -radius * 0.45)
		ring.Transparency = 0.86 + math.sin(t * 3) * 0.06
		dome.Transparency = 0.5 + math.sin(t * 1.5) * 0.05
	end)
	local stopLoop = FX.PlaySoundAtStoppable(character, "Swift", "TimeDome_Loop")
	domes[character] = { parts = parts, stopLoop = stopLoop, conn = conn }
	task.delay(duration + 0.5, function()
		if domes[character] and domes[character].parts == parts then
			destroyDome(character, false)
		end
	end)
end

-- Quem está lento (Player.TimeSlow < 1): animações na mesma velocidade; a própria tela fica azulada.
local slowCC: ColorCorrectionEffect? = nil
local function setLocalSlowScreen(slow: number?)
	if slow and slow < 1 then
		if not slowCC then
			local cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "TimeSlowColor"
			cc.Saturation = -0.4
			cc.TintColor = Color3.fromRGB(170, 215, 255)
			cc.Contrast = 0.1
			cc.Parent = Lighting
			slowCC = cc
		end
	elseif slowCC then
		slowCC:Destroy()
		slowCC = nil
	end
end
local slowedTracks: { [Model]: boolean? } = {}
local function applyAnimSlow()
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if not c or not animator then
			continue
		end
		local slow = p:GetAttribute("TimeSlow")
		local speed = if typeof(slow) == "number" then slow else 1
		if speed ~= 1 or slowedTracks[c] then
			for _, track in animator:GetPlayingAnimationTracks() do
				if math.abs(track.Speed - speed) > 0.01 and track.Speed ~= 0 then
					track:AdjustSpeed(speed)
				end
			end
			slowedTracks[c] = if speed ~= 1 then true else nil
		end
	end
end

local function onNotifyAbility(character: Model?, characterId: string, abilityId: string, phase: string, data: any)
	if not character then
		return
	end
	local at: Vector3? = if typeof(data) == "table" and typeof(data.Position) == "Vector3" then data.Position else nil
	if abilityId == "TimeDome" then
		local radius = if typeof(data) == "table" then tonumber(data.Radius) or 22 else 22
		if phase == "start" then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local center = at or (if root then root.Position else Vector3.zero)
			local def = CharacterDefs.Get(characterId)
			local ability = def and CharacterDefs.FindAbility(def, abilityId)
			local cine = ability and (ability.Effect :: any).Cinematic
			local charge = if cine then tonumber(cine.Charge) or 1 else 0.35
			createDome(character, center, radius, if typeof(data) == "table" then tonumber(data.Duration) or 8 else 8, if cine then charge else nil)
			FX.PlayAnimation(character, characterId, abilityId)
			FX.PlaySoundAt(character, characterId, abilityId)
			if cine and ability then
				local awDef = AwakeningDefs.Get(characterId)
				CutsceneController.PlayUltimate(character, {
					Charge = charge,
					Total = tonumber(cine.Total) or charge + 1.6,
					Name = ability.DisplayName:upper(),
					Subtitle = awDef.Subtitle,
					Color = awDef.Color or (def and def.Color) or Color3.fromRGB(90, 200, 255),
					Theme = awDef.Theme,
					OnBurst = function()
						FX.SpawnVFX(character, characterId, abilityId, true, center)
					end,
				})
			else
				FX.SpawnVFX(character, characterId, abilityId, true, center)
				if character == localPlayer.Character then
					FX.Shake(0.8, 0.5)
				end
			end
		elseif phase == "break" then
			destroyDome(character, true)
			FX.SpawnVFX(character, characterId, "TimeDome_Break", true, at)
			FX.PlaySoundAt(character, characterId, "TimeDome_Break")
			FX.Shake(0.6, 0.4)
		elseif phase == "end" then
			destroyDome(character, false)
		end
		return
	end
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
		if character:GetAttribute("BossRig") ~= nil then
			RigAnimController.Pose(character, abilityId) -- rig por peças: pose própria da habilidade
		end
		FX.PlayAnimation(character, characterId, abilityId)
		FX.SpawnVFX(character, characterId, abilityId, false, at)
		FX.PlaySoundAt(character, characterId, abilityId)
		-- (o estouro genérico Awakening_Burst por cima das ults saiu — dono: cada ult tem o próprio som)
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
		local carry = if typeof(data) == "table" then tonumber(data.Carry) or 0.8 else 0.8
		-- captura: estalo na vítima + congela os dois por um instante (peso) + poeira arrastada enquanto carrega
		if typeof(victim) == "Instance" and victim:IsA("Model") then
			FX.SpawnVFX(victim, "Shared", "GrabCatch", true)
			FX.Hitstop(victim, 0.08)
			FX.PlaySoundAt(victim, "Shared", "Punch_Hit")
		end
		FX.Hitstop(character, 0.08)
		local carryFx = VFXLibrary.Get("Shared", "GrabCarry")
		if carryFx then
			-- emissão contínua pelo tempo real do Carry (a definição tem 0,8 s de referência)
			local fx = table.clone(carryFx)
			fx.lifetime = carry + 0.3
			fx.layers = {}
			for _, layer in carryFx.layers do
				local l = table.clone(layer)
				if l.duration then
					l.duration = carry
				end
				table.insert(fx.layers, l)
			end
			FX.PlayComposed(character, fx)
		end
		if typeof(victim) == "Instance" and victim == localPlayer.Character then
			startGrabbed(character, carry)
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
		-- final do agarrão por tipo (CharacterDefs Effect.Finish): vento do arremesso / rachadura / redemoinho
		local def = CharacterDefs.Get(characterId)
		local ability = def and CharacterDefs.FindAbility(def, abilityId)
		local effect = ability and (ability.Effect :: any)
		if effect and effect.Type == "Grab" and typeof(victim) == "Instance" and victim:IsA("Model") then
			local finish = if typeof(effect.Finish) == "string" then effect.Finish else "Slam"
			if finish == "Throw" then
				FX.SpawnVFX(character, "Shared", "GrabThrow", true)
				FX.Trail(victim, trailColor(characterId), 0.5, 3)
			elseif finish == "Chokeslam" then
				FX.SpawnVFX(victim, "Shared", "GrabSlam", true, at)
			elseif finish == "Spin" then
				FX.SpawnVFX(character, "Shared", "GrabSpin", true)
				FX.Trail(victim, trailColor(characterId), 0.4, 2)
			end
			FX.Hitstop(victim, 0.1)
		end
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
	-- Domínio do Tempo: animações lentas de quem está preso + tela azulada do próprio jogador
	RunService.Heartbeat:Connect(applyAnimSlow)
	localPlayer:GetAttributeChangedSignal("TimeSlow"):Connect(function()
		local v = localPlayer:GetAttribute("TimeSlow")
		setLocalSlowScreen(if typeof(v) == "number" then v else nil)
	end)
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
