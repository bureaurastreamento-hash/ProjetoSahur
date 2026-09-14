--!strict
--[[
	CombatController (cliente)
	Só captura input e mostra feedback. NUNCA decide dano.
	  - Botão esquerdo do mouse: RequestAttack("M1")
	  - Segurar F: RequestBlock(true) / soltar: RequestBlock(false)
	Feedback: animações (se existirem em ReplicatedStorage.Assets), Highlight
	rápido em quem foi atingido, contorno azul em quem está bloqueando.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Assets = require(Modules:WaitForChild("Assets"))

local CombatController = {}

local localPlayer = Players.LocalPlayer

local requestAttack: RemoteEvent
local requestBlock: RemoteEvent

local ATTACK_KEY = Enum.UserInputType.MouseButton1
local BLOCK_KEY = Enum.KeyCode.F

local blockHeld = false
local blockHighlights: { [Model]: Highlight } = {}
local animCache: { [string]: AnimationTrack } = {}

-- ---------------------------------------------------------------------------
-- Feedback visual
-- ---------------------------------------------------------------------------

local function flash(character: Model, color: Color3, duration: number)
	local hl = Instance.new("Highlight")
	hl.FillColor = color
	hl.FillTransparency = 0.4
	hl.OutlineTransparency = 1
	hl.Parent = character
	task.delay(duration, function()
		hl:Destroy()
	end)
end

local function setBlockVisual(character: Model, active: boolean)
	local existing = blockHighlights[character]
	if active and not existing then
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineColor = Color3.fromRGB(80, 160, 255)
		hl.OutlineTransparency = 0
		hl.Parent = character
		blockHighlights[character] = hl
	elseif not active and existing then
		existing:Destroy()
		blockHighlights[character] = nil
	end
end

local function playAnim(character: Model, animName: string)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local key = tostring(character) .. "/" .. animName
	local track = animCache[key]
	if not track then
		local anim = Assets.GetAnimation("Shared", animName)
		if not anim then
			return
		end
		track = animator:LoadAnimation(anim)
		animCache[key] = track
	end
	track:Play()
end

-- ---------------------------------------------------------------------------
-- Handlers do servidor
-- ---------------------------------------------------------------------------

local function onNotifyAttack(attackerChar: Model?, attackId: string, comboIndex: number)
	if not attackerChar then
		return
	end
	playAnim(attackerChar, ("%s_%d"):format(attackId, comboIndex))
end

local function onNotifyDamage(attackerChar: Model?, victimChar: Model?, amount: number, kind: string)
	if not victimChar then
		return
	end
	if kind == "parry" then
		flash(victimChar, Color3.fromRGB(255, 255, 255), 0.25)
		playAnim(victimChar, "Parry")
	elseif kind == "blocked" then
		flash(victimChar, Color3.fromRGB(80, 160, 255), 0.15)
	else
		flash(victimChar, Color3.fromRGB(255, 60, 60), 0.15)
		playAnim(victimChar, "Hit")
	end

	if victimChar == localPlayer.Character or attackerChar == localPlayer.Character then
		-- TODO(launch): reduzir log
		print(("[CombatController] %s -> %s: %s (%.1f)"):format(
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
	setBlockVisual(character, active)
	if active then
		playAnim(character, "Block")
	end
end

local function onNotifyCooldown(reason: string, seconds: number)
	-- TODO(launch): reduzir log
	print(("[CombatController] cooldown: %s por %.2fs"):format(reason, seconds))
	if reason == "parried" and blockHeld then
		-- servidor cancelou o block; solta localmente pra ficar em sincronia
		blockHeld = false
	end
end

local function onNotifyHealth(current: number, max: number)
	-- TODO(launch): reduzir log; substituir por HUD
	print(("[CombatController] HP %.0f/%.0f"):format(current, max))
end

local function onNotifyKill(killer: Player?, victim: Player)
	-- TODO(launch): reduzir log; substituir por kill feed
	print(("[CombatController] %s matou %s"):format(killer and killer.Name or "ninguém", victim.Name))
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.UserInputType == ATTACK_KEY then
		requestAttack:FireServer("M1")
	elseif input.KeyCode == BLOCK_KEY and not blockHeld then
		blockHeld = true
		requestBlock:FireServer(true)
	end
end

local function onInputEnded(input: InputObject, _gameProcessed: boolean)
	if input.KeyCode == BLOCK_KEY and blockHeld then
		blockHeld = false
		requestBlock:FireServer(false)
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
	Remotes.GetEvent(Remotes.Events.NotifyHealth).OnClientEvent:Connect(onNotifyHealth)
	Remotes.GetEvent(Remotes.Events.NotifyKill).OnClientEvent:Connect(onNotifyKill)

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)

	-- Ao morrer/respawnar, limpa estado local
	localPlayer.CharacterAdded:Connect(function()
		blockHeld = false
		for _, hl in blockHighlights do
			hl:Destroy()
		end
		table.clear(blockHighlights)
		table.clear(animCache)
	end)

	-- TODO(launch): reduzir log
	print("[CombatController] pronto. Mouse1 = soco (combo 4), segurar F = block (parry nos primeiros 0.2s)")
end

return CombatController
