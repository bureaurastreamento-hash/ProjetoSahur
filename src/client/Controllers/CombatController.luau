--!strict
--[[
	CombatController (cliente)
	Só captura input e mostra feedback. NUNCA decide dano.
	  - Botão esquerdo do mouse: RequestAttack("M1")
	  - Segurar F: RequestBlock(true) / soltar: RequestBlock(false)

	Feedback (tudo por nome em ReplicatedStorage.Assets, ver Assets.luau):
	  Animations.Shared: M1_1..M1_4, Block (loop), Parry, Hit
	  VFX.Shared:        Hit, Block, Parry
	  Sounds.Shared:     Punch_Whoosh, Punch_Hit, Block, Parry, Death
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local FX = require(Modules:WaitForChild("FX"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))

local CombatController = {}

local localPlayer = Players.LocalPlayer

local requestAttack: RemoteEvent
local requestBlock: RemoteEvent

local ATTACK_KEY = Enum.UserInputType.MouseButton1
local ATTACK_TOUCH = Enum.UserInputType.Touch
local BLOCK_KEY = Enum.KeyCode.F
local BLOCK_GAMEPAD = Enum.KeyCode.ButtonL1
local ATTACK_GAMEPAD = Enum.KeyCode.ButtonR1
local SHARED = "Shared"

local blockHeld = false

--- Toque no mundo = soco (MobileController desliga quando há botões na tela)
CombatController.TouchAttackEnabled = true

--- Soco (M1). Usado pelo input e pelos botões de toque.
function CombatController.Attack()
	requestAttack:FireServer("M1")
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
	FX.PlayAnimation(attackerChar, SHARED, ("%s_%d"):format(attackId, comboIndex))
	local attackDef = CombatConfig.Attacks[attackId]
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

local function onNotifyDamage(attackerChar: Model?, victimChar: Model?, amount: number, kind: string)
	if not victimChar then
		return
	end
	local isMe = victimChar == localPlayer.Character
	if kind == "parry" then
		FX.DamageNumber(victimChar, "PARRY", COLOR_PARRY)
		FX.Flash(victimChar, COLOR_PARRY, 0.25)
		FX.SpawnVFX(victimChar, SHARED, "Parry", true)
		FX.PlaySoundAt(victimChar, SHARED, "Parry")
		FX.PlayAnimation(victimChar, SHARED, "Parry")
	elseif kind == "blocked" then
		FX.DamageNumber(victimChar, ("%d"):format(math.floor(amount + 0.5)), COLOR_NUMBER_BLOCK)
		FX.Flash(victimChar, COLOR_BLOCK, 0.15)
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
		local stop = if amount >= CombatConfig.Attacks.M1.FinisherDamage then HITSTOP_HEAVY else HITSTOP_LIGHT
		FX.Hitstop(victimChar, stop)
		if attackerChar then
			FX.Hitstop(attackerChar, stop)
		end
		FX.Flash(victimChar, COLOR_HIT, 0.15)
		FX.SpawnVFX(victimChar, SHARED, "Hit", true)
		FX.PlaySoundAt(victimChar, SHARED, "Punch_Hit")
		FX.PlayAnimation(victimChar, SHARED, "Hit")
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
	if (reason == "parried" or reason == "guardbreak") and blockHeld then
		blockHeld = false -- servidor cancelou o block; fica em sincronia
	end
	if reason == "parried" then
		local character = localPlayer.Character
		if character then
			FX.SpawnVFX(character, SHARED, "Stun", true) -- tontura em quem foi parryado
		end
	end
end

local function onNotifyKnockback(direction: Vector3, speed: number, duration: number)
	local character = localPlayer.Character
	if character and typeof(direction) == "Vector3" then
		FX.Push(character, direction * speed + Vector3.new(0, speed * 0.25, 0), duration)
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
	if input.UserInputType == ATTACK_KEY or input.KeyCode == ATTACK_GAMEPAD then
		CombatController.Attack()
	elseif input.UserInputType == ATTACK_TOUCH and CombatController.TouchAttackEnabled then
		CombatController.Attack()
	elseif input.KeyCode == BLOCK_KEY or input.KeyCode == BLOCK_GAMEPAD then
		CombatController.SetBlock(true)
	end
end

local function onInputEnded(input: InputObject, _gameProcessed: boolean)
	if input.KeyCode == BLOCK_KEY or input.KeyCode == BLOCK_GAMEPAD then
		CombatController.SetBlock(false)
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
	end)

	Log.debug("[CombatController] pronto. Mouse1/toque/R1 = soco, segurar F/L1 = block")
end

return CombatController
