--!strict
--[[
	CombatController (cliente)
	Só captura input e mostra feedback. NUNCA decide dano.
	  - Botão esquerdo do mouse: RequestAttack("M1"); segurar = combo de 4 automático
	    · SÓ NO 4º GOLPE do combo (no lugar do finisher com empurrão): no ar SUBINDO = "Uppercut"
	    (levanta o alvo e você) · no ar CAINDO = "Downslam" (ignora block, esmaga). O servidor confere
	    combo e subindo/caindo; aqui só se escolhe o pedido.
	  - Segurar F: RequestBlock(true) / soltar: RequestBlock(false)
	  - Acerto de M1 puxa o atacante ~1 stud para a vítima (cliente dono da física).

	Feedback (tudo por nome em ReplicatedStorage.Assets, ver Assets.luau):
	  Animations.Shared: M1_1..M1_4, Downslam, Uppercut, Block (pose, loop), BlockHit (golpe absorvido), Parry, Hit
	  VFX.Shared:        Hit, Block, Parry, Crit, BlackFlash
	  Sounds.Shared:     Punch_Whoosh, Punch_Hit, Block, Parry, Death, Crit, BlackFlash
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local FX = require(Modules:WaitForChild("FX"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local Controls = require(Modules:WaitForChild("Controls"))
local SettingsController = require(script.Parent:WaitForChild("SettingsController"))
local RigAnimController = require(script.Parent:WaitForChild("RigAnimController"))
local MovementController = require(script.Parent:WaitForChild("MovementController"))

local CombatController = {}

local localPlayer = Players.LocalPlayer

local requestAttack: RemoteEvent
local requestBlock: RemoteEvent

local ATTACK_TOUCH = Enum.UserInputType.Touch
local SHARED = "Shared"

local blockHeld = false

--- Toque no mundo = soco (MobileController desliga quando há botões na tela)
CombatController.TouchAttackEnabled = true

-- Combo próprio (previsto no clique, confirmado pelo servidor via NotifyAttack): o especial só sai quando
-- o próximo é o 4º. myNextAttackAt/myStunnedUntil evitam animar/pedir golpe que o servidor vai recusar.
local myNextCombo = 1
local myLastAttackAt = -math.huge
local myNextAttackAt = 0
local myStunnedUntil = 0
local pendingAttacks = 0 -- socos previstos cuja confirmação (NotifyAttack) ainda não chegou

--- Animação + som do golpe (previsto no atacante local, NotifyAttack nos outros).
local function playAttackFx(attackerChar: Model, attackId: string, comboIndex: number)
	local attackDef = CombatConfig.Attacks[attackId]
	if attackerChar:GetAttribute("BossRig") ~= nil then
		RigAnimController.Pulse(attackerChar, if attackId == "M1" and comboIndex < 4 then 1 else 1.6) -- rig por peças: "mordida"
	end
	if attackId ~= "M1" then
		-- Downslam / Uppercut: animação com o próprio nome; o uppercut levanta o atacante junto
		FX.PlayAnimation(attackerChar, SHARED, attackId)
		FX.PlaySoundAt(attackerChar, SHARED, "Punch_Whoosh")
		FX.SpawnVFX(attackerChar, SHARED, attackId, true) -- Shared/Uppercut, Shared/Downslam (VFXLibrary)
		local up = attackDef and attackDef.AttackerUp
		if typeof(up) == "number" and up > 0 and attackerChar == localPlayer.Character then
			FX.Push(attackerChar, Vector3.new(0, up, 0), 0.2)
		end
		return
	end
	FX.PlayAnimation(attackerChar, SHARED, ("%s_%d"):format(attackId, comboIndex))
	FX.SpawnVFX(attackerChar, SHARED, ("Swing_%d"):format(comboIndex), true) -- rastro do braço (VFXLibrary)
	local attackerPlayer = Players:GetPlayerFromCharacter(attackerChar)
	local awakenedUntil = attackerPlayer and attackerPlayer:GetAttribute("AwakenedUntil")
	if typeof(awakenedUntil) == "number" and awakenedUntil > Workspace:GetServerTimeNow() then
		FX.SpawnVFX(attackerChar, SHARED, "AwakenedSwing", true) -- modo despertado: faíscas na cor
	end
	if attackDef and comboIndex >= attackDef.ComboLength then
		-- Finisher: som mais pesado + rajada de vento (cai no Punch_Whoosh se o som não existir)
		if not FX.PlaySoundAt(attackerChar, SHARED, "Finisher_Whoosh") then
			FX.PlaySoundAt(attackerChar, SHARED, "Punch_Whoosh")
		end
		FX.SpawnVFX(attackerChar, SHARED, "Finisher", true)
	else
		FX.PlaySoundAt(attackerChar, SHARED, "Punch_Whoosh")
	end
end

--- Soco (M1). Usado pelo input e pelos botões de toque. No ar CAINDO vira sempre Downslam (soco para
--- baixo); no ar SUBINDO vira Uppercut só no 4º golpe do combo (o servidor valida com a mesma regra).
function CombatController.Attack()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attackId = "M1"
	local m1 = CombatConfig.Attacks.M1
	local finisherNext = myNextCombo >= m1.ComboLength and os.clock() - myLastAttackAt <= m1.ComboResetTime
	if humanoid and root then
		local st = humanoid:GetState()
		local airborne = st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping
		if airborne then
			local rising = root.AssemblyLinearVelocity.Y > CombatConfig.AirRisingSpeed
			if rising then
				if finisherNext then
					attackId = "Uppercut" -- subindo só no 4º golpe do combo
				end
			else
				attackId = "Downslam" -- caindo: sempre o soco para baixo (dono 2026-09-17)
			end
		end
	end
	local now = os.clock()
	if not character or not root or now < myNextAttackAt or now < myStunnedUntil or localPlayer:GetAttribute("Ragdolled") == true then
		return
	end
	local attackCfg = CombatConfig.Attacks[attackId]
	-- Previsão: anima na hora do clique (sem esperar o servidor) e mantém o combo local
	local comboIndex = 1
	if attackId == "M1" then
		if now - myLastAttackAt > m1.ComboResetTime then
			myNextCombo = 1
		end
		comboIndex = myNextCombo
		local finisher = comboIndex >= m1.ComboLength
		myNextAttackAt = now + (if finisher then m1.ComboEndCooldown else m1.Cooldown)
		myNextCombo = if finisher then 1 else comboIndex + 1
	else
		myNextAttackAt = now + attackCfg.Cooldown
		myNextCombo = 1
	end
	myLastAttackAt = now
	pendingAttacks += 1
	playAttackFx(character, attackId, comboIndex)
	-- Wind-up aqui, com as posições exatas deste cliente; o servidor valida a lista numa caixa tolerante
	task.delay(attackCfg.HitDelay, function()
		if localPlayer.Character ~= character or os.clock() < myStunnedUntil then
			pendingAttacks = math.max(0, pendingAttacks - 1)
			return -- levou parry/stun durante o wind-up: o golpe não sai
		end
		local victims = Hitbox.InFront(character, attackCfg.Range, attackCfg.Width, attackCfg.Height, attackCfg.MaxTargets)
		requestAttack:FireServer(attackId, victims)
	end)
end

-- Segurar o botão = os 4 golpes saem sozinhos, no ritmo do Cooldown; depois do 4º o servidor
-- impõe ComboEndCooldown (sem combo infinito). O servidor continua validando cada pedido.
local attackHeld = false
local autoAttackConn: RBXScriptConnection? = nil
local nextAutoAttackAt = 0

local function stopAutoAttack()
	attackHeld = false
	if autoAttackConn then
		autoAttackConn:Disconnect()
		autoAttackConn = nil
	end
end

local function startAutoAttack()
	if attackHeld then
		return
	end
	attackHeld = true
	CombatController.Attack()
	nextAutoAttackAt = os.clock() + CombatConfig.Attacks.M1.Cooldown
	autoAttackConn = RunService.Heartbeat:Connect(function()
		if not attackHeld then
			return
		end
		if os.clock() >= nextAutoAttackAt then
			nextAutoAttackAt = os.clock() + CombatConfig.Attacks.M1.Cooldown
			CombatController.Attack() -- em cooldown/ComboEnd o servidor só ignora
		end
	end)
end

--- Botão de soco pressionado/solto (input, gamepad, toque). Com "AttackHold" desligado, cada
--- pressionar = um soco.
function CombatController.SetAttackHeld(held: boolean)
	if held then
		if SettingsController.Get("AttackHold") == true then
			startAutoAttack()
		else
			CombatController.Attack()
		end
	else
		stopAutoAttack()
	end
end

--- Botão de block pressionado/solto. Com "BlockToggle" ligado, pressionar alterna.
function CombatController.BlockInput(pressed: boolean)
	if SettingsController.Get("BlockToggle") == true then
		if pressed then
			CombatController.SetBlock(not blockHeld)
		end
	else
		CombatController.SetBlock(pressed)
	end
end

--- Segurar/soltar block. Idempotente.
function CombatController.SetBlock(active: boolean)
	if active and not blockHeld then
		blockHeld = true
		requestBlock:FireServer(true)
	elseif not active and blockHeld then
		blockHeld = false
		requestBlock:FireServer(false)
	end
end

local COLOR_HIT = Color3.fromRGB(255, 60, 60)
local COLOR_BLOCK = Color3.fromRGB(80, 160, 255)
local COLOR_PARRY = Color3.fromRGB(255, 255, 255)
local COLOR_NUMBER_HIT = Color3.fromRGB(255, 230, 90)
local COLOR_NUMBER_BLOCK = Color3.fromRGB(140, 190, 255)
local COLOR_GUARDBREAK = Color3.fromRGB(255, 140, 40)
local COLOR_FINISHER = Color3.fromRGB(255, 40, 40)
local COLOR_CRIT = Color3.fromRGB(255, 30, 30)
local COLOR_BLACKFLASH = Color3.fromRGB(20, 0, 30)

-- ---------------------------------------------------------------------------
-- Handlers do servidor
-- ---------------------------------------------------------------------------

local HITSTOP_LIGHT = 0.05
local HITSTOP_HEAVY = 0.09
local HITSTOP_FINISHER = 0.14

local function onNotifyAttack(attackerChar: Model?, attackId: string, comboIndex: number)
	if not attackerChar then
		return
	end
	if attackerChar == localPlayer.Character then
		-- confirmação do servidor: sincroniza o combo (o servidor manda); a animação já saiu no clique
		myNextCombo = if attackId == "M1" and comboIndex < CombatConfig.Attacks.M1.ComboLength then comboIndex + 1 else 1
		if pendingAttacks > 0 then
			pendingAttacks -= 1
			return
		end
		-- sem previsão pendente (ex.: golpe disparado por outro caminho): anima agora
	end
	playAttackFx(attackerChar, attackId, comboIndex)
end

local function onNotifyDamage(attackerChar: Model?, victimChar: Model?, amount: number, kind: string)
	if not victimChar then
		return
	end
	local isMe = victimChar == localPlayer.Character
	if kind == "immune" then
		-- alvo invencível (cutscene/agarrão/i-frames): só um brilho discreto, sem número nem reação
		FX.Flash(victimChar, Color3.fromRGB(200, 200, 200), 0.1)
		return
	elseif kind == "parry" then
		FX.DamageNumber(victimChar, "PARRY", COLOR_PARRY)
		FX.Flash(victimChar, COLOR_PARRY, 0.25)
		FX.SpawnVFX(victimChar, SHARED, "Parry", true)
		FX.PlaySoundAt(victimChar, SHARED, "Parry")
		FX.PlayAnimation(victimChar, SHARED, "Parry")
	elseif kind == "blocked" then
		FX.DamageNumber(victimChar, ("%d"):format(math.floor(amount + 0.5)), COLOR_NUMBER_BLOCK)
		FX.Flash(victimChar, COLOR_BLOCK, 0.15)
		FX.PlayAnimation(victimChar, SHARED, "BlockHit") -- impacto absorvido (por cima da pose Block)
		FX.SpawnVFX(victimChar, SHARED, "Block", true)
		FX.PlaySoundAt(victimChar, SHARED, "Block")
	elseif kind == "guardbreak" then
		-- Guarda quebrou: golpe entra cheio, vítima atordoada (VFX de tontura segue a cabeça)
		FX.DamageNumber(victimChar, "GUARDA QUEBRADA", COLOR_GUARDBREAK)
		FX.Flash(victimChar, COLOR_GUARDBREAK, 0.3)
		FX.Hitstop(victimChar, HITSTOP_HEAVY)
		if attackerChar then
			FX.Hitstop(attackerChar, HITSTOP_HEAVY)
		end
		FX.SpawnVFX(victimChar, SHARED, "GuardBreak", true)
		FX.SpawnVFX(victimChar, SHARED, "Stun", true)
		FX.PlaySoundAt(victimChar, SHARED, "GuardBreak")
		FX.PlayAnimation(victimChar, SHARED, "Hit")
		if isMe then
			FX.Shake(0.6, 0.25)
		end
	elseif kind == "crit" or kind == "blackflash" then
		-- Recompensa do parry: crítico ×3 (vermelho) / Black Flash ×6 (escuro, tela treme)
		local black = kind == "blackflash"
		FX.DamageNumber(victimChar, ("%s %d"):format(if black then "BLACK FLASH" else "CRÍTICO", math.floor(amount + 0.5)), if black then COLOR_FINISHER else COLOR_CRIT)
		FX.Flash(victimChar, if black then COLOR_BLACKFLASH else COLOR_CRIT, 0.35)
		FX.Hitstop(victimChar, HITSTOP_FINISHER)
		if attackerChar then
			FX.Hitstop(attackerChar, HITSTOP_FINISHER)
		end
		FX.SpawnVFX(victimChar, SHARED, if black then "BlackFlash" else "Crit", true)
		if not FX.PlaySoundAt(victimChar, SHARED, if black then "BlackFlash" else "Crit") then
			FX.PlaySoundAt(victimChar, SHARED, "Finisher_Hit")
		end
		FX.PlayAnimation(victimChar, SHARED, "Hit")
		if isMe or attackerChar == localPlayer.Character then
			FX.Shake(if black then 1.2 else 0.8, 0.35)
		end
	elseif kind == "wallsplat" then
		-- Bateu na parede: número extra, tela treme forte, efeito pesado no ponto
		FX.DamageNumber(victimChar, ("PAREDE %d"):format(math.floor(amount + 0.5)), COLOR_FINISHER)
		FX.Flash(victimChar, COLOR_FINISHER, 0.3)
		FX.SpawnVFX(victimChar, SHARED, "WallSplat", true)
		if not FX.PlaySoundAt(victimChar, SHARED, "WallSplat") then
			FX.PlaySoundAt(victimChar, SHARED, "Finisher_Hit")
		end
		if isMe or attackerChar == localPlayer.Character then
			FX.Shake(1.0, 0.35)
		end
	elseif kind == "finisher" then
		-- 4º golpe em alvo quase morto: peso máximo
		FX.DamageNumber(victimChar, ("%d"):format(math.floor(amount + 0.5)), COLOR_FINISHER)
		FX.Flash(victimChar, COLOR_FINISHER, 0.25)
		FX.Hitstop(victimChar, HITSTOP_FINISHER)
		if attackerChar then
			FX.Hitstop(attackerChar, HITSTOP_FINISHER)
		end
		FX.SpawnVFX(victimChar, SHARED, "FinisherHit", true)
		FX.PlaySoundAt(victimChar, SHARED, "Finisher_Hit")
		FX.PlayAnimation(victimChar, SHARED, "Hit")
		if isMe or attackerChar == localPlayer.Character then
			FX.Shake(0.8, 0.3)
		end
	else
		FX.DamageNumber(victimChar, ("%d"):format(math.floor(amount + 0.5)), COLOR_NUMBER_HIT)
		if isMe then
			FX.Shake(0.35, 0.15)
		end
		-- Hitstop: congela um instante quem bateu e quem apanhou (peso no golpe)
		local heavy = amount >= CombatConfig.Attacks.M1.ComboDamage[CombatConfig.Attacks.M1.ComboLength]
		local stop = if heavy then HITSTOP_HEAVY else HITSTOP_LIGHT
		FX.Hitstop(victimChar, stop)
		if attackerChar then
			FX.Hitstop(attackerChar, stop)
		end
		FX.Flash(victimChar, COLOR_HIT, 0.15)
		FX.SpawnVFX(victimChar, SHARED, "Hit", true)
		FX.PlaySoundAt(victimChar, SHARED, "Punch_Hit")
		FX.PlayAnimation(victimChar, SHARED, "Hit")
	end
	-- Puxão: quem acertou (soco não bloqueado) desliza ~PullStuds para a vítima
	if attackerChar and attackerChar == localPlayer.Character and (kind == "hit" or kind == "crit" or kind == "blackflash") then
		local aRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		local vRoot = victimChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if aRoot and vRoot then
			local to = vRoot.Position - aRoot.Position
			to = Vector3.new(to.X, 0, to.Z)
			if to.Magnitude > 3 then
				local pull = CombatConfig.Attacks.M1.PullStuds
				FX.Push(attackerChar, to.Unit * (pull / 0.08), 0.08)
			end
		end
	end
	if victimChar == localPlayer.Character or attackerChar == localPlayer.Character then
		Log.debug(("[CombatController] %s -> %s: %s (%.1f)"):format(
			attackerChar and attackerChar.Name or "?",
			victimChar.Name,
			kind,
			amount
		))
	end
end

local function onNotifyBlock(character: Model?, active: boolean)
	if not character then
		return
	end
	if active then
		FX.SetOutline(character, COLOR_BLOCK)
		FX.PlayAnimation(character, SHARED, "Block", true)
	else
		FX.SetOutline(character, nil)
		FX.StopAnimation(character, SHARED, "Block")
	end
end

local function onNotifyCooldown(reason: string, seconds: number)
	Log.debug(("[CombatController] cooldown: %s por %.2fs"):format(reason, seconds))
	-- espelho do stun do servidor: não prevê soco enquanto durar (e o wind-up pendente é cancelado)
	if reason ~= "crit_ready" then
		myStunnedUntil = math.max(myStunnedUntil, os.clock() + seconds)
		myNextAttackAt = math.max(myNextAttackAt, os.clock() + seconds)
	end
	if reason == "hit" or reason == "grabbed" or reason == "parried" or reason == "guardbreak" or reason == "stunned" then
		MovementController.CancelDash() -- levou golpe no meio do dash: o impulso para na hora
	end
	if (reason == "parried" or reason == "guardbreak") and blockHeld then
		blockHeld = false -- servidor cancelou o block; fica em sincronia
	end
	if reason == "parried" then
		local character = localPlayer.Character
		if character then
			FX.SpawnVFX(character, SHARED, "Stun", true) -- tontura em quem foi parryado
		end
	elseif reason == "crit_ready" then
		local character = localPlayer.Character
		if character then
			FX.SetOutline(character, COLOR_CRIT) -- parryou: próximo soco é crítico
			task.delay(seconds, function()
				if localPlayer.Character == character and not blockHeld then
					FX.SetOutline(character, nil)
				end
			end)
		end
	end
end

local function onNotifyKnockback(direction: Vector3, speed: number, duration: number, up: number?)
	local character = localPlayer.Character
	if character and typeof(direction) == "Vector3" then
		local vertical = if typeof(up) == "number" then up else speed * 0.25
		MovementController.CancelDash()
		FX.Push(character, direction * speed + Vector3.new(0, vertical, 0), duration)
		FX.Shake(0.5, 0.2)
	end
end

local function onNotifyKill(_killer: Player?, victim: Player)
	local character = victim.Character
	if character then
		FX.PlaySoundAt(character, SHARED, "Death")
		FX.SpawnVFX(character, SHARED, "Ragdoll", true) -- rastro de vento no corpo caindo
	end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local action = Controls.ActionOf(input)
	if action == "Attack" then
		CombatController.SetAttackHeld(true)
	elseif input.UserInputType == ATTACK_TOUCH and CombatController.TouchAttackEnabled then
		CombatController.SetAttackHeld(true)
	elseif action == "Block" then
		CombatController.BlockInput(true)
	end
end

local function onInputEnded(input: InputObject, _gameProcessed: boolean)
	local action = Controls.ActionOf(input)
	if action == "Attack" or input.UserInputType == ATTACK_TOUCH then
		CombatController.SetAttackHeld(false)
	elseif action == "Block" then
		CombatController.BlockInput(false)
	end
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function CombatController.Init()
	requestAttack = Remotes.GetEvent(Remotes.Events.RequestAttack)
	requestBlock = Remotes.GetEvent(Remotes.Events.RequestBlock)
end

function CombatController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyAttack).OnClientEvent:Connect(onNotifyAttack)
	Remotes.GetEvent(Remotes.Events.NotifyDamage).OnClientEvent:Connect(onNotifyDamage)
	Remotes.GetEvent(Remotes.Events.NotifyBlock).OnClientEvent:Connect(onNotifyBlock)
	Remotes.GetEvent(Remotes.Events.NotifyCooldown).OnClientEvent:Connect(onNotifyCooldown)
	Remotes.GetEvent(Remotes.Events.NotifyKill).OnClientEvent:Connect(onNotifyKill)
	Remotes.GetEvent(Remotes.Events.NotifyKnockback).OnClientEvent:Connect(onNotifyKnockback)

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)

	localPlayer.CharacterAdded:Connect(function()
		blockHeld = false
		stopAutoAttack()
	end)

	Log.debug("[CombatController] pronto. Mouse1/toque/R1 = soco, segurar F/L1 = block")
end

return CombatController
