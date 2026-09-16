--!strict
--[[
	MobileController (cliente)
	Botões de toque (StarterGui.MobileGui, tools/gerar_mobilegui.py), no padrão dos battlegrounds:
	SOCO (segurar = combo), BLOCK (segurar ou alternar), DASH (também levanta do ragdoll), 1/2/3/4,
	ULT (G), EMOTE (roda), LOCK (shift lock) e CORRER (alternar). Pulo é o botão nativo da Roblox.
	Só aparece quando há toque e não há teclado. Não decide nada: chama os controllers, que mandam os
	Requests ao servidor.
	Acessibilidade (SettingsController): TouchScale (UIScale), TouchOpacity, TouchMirror (canhoto:
	espelha pelos atributos BaseX/BaseY/Side de cada botão).
	Testar no Studio: Test > Device (emulador) com um aparelho de toque.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))
local CombatController = require(script.Parent:WaitForChild("CombatController"))
local AbilityController = require(script.Parent:WaitForChild("AbilityController"))
local MovementController = require(script.Parent:WaitForChild("MovementController"))
local CosmeticsController = require(script.Parent:WaitForChild("CosmeticsController"))
local SettingsController = require(script.Parent:WaitForChild("SettingsController"))

local MobileController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local root: Frame

local COLOR_OFF = Color3.fromRGB(77, 77, 97)
local COLOR_ON = Color3.fromRGB(70, 160, 100)

local function get(parent: Instance, name: string): Instance
	local inst = parent:FindFirstChild(name)
	assert(inst, ("[MobileController] faltando %s em %s"):format(name, parent:GetFullName()))
	return inst
end

local function shouldShow(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function refreshVisibility()
	local show = shouldShow()
	root.Visible = show
	-- Com botões na tela, tocar no mundo não soca (senão girar a câmera vira ataque)
	CombatController.TouchAttackEnabled = not show
end

--- Tamanho/opacidade/canhoto vindos das configurações.
local function applySettings()
	local scale = root:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = tonumber(SettingsController.Get("TouchScale")) or 1
	end
	local opacity = tonumber(SettingsController.Get("TouchOpacity")) or 0.65
	local mirror = SettingsController.Get("TouchMirror") == true
	for _, b in root:GetChildren() do
		if b:IsA("TextButton") then
			b.BackgroundTransparency = 1 - opacity
			local x, y = tonumber(b:GetAttribute("BaseX")), tonumber(b:GetAttribute("BaseY"))
			local side = b:GetAttribute("Side")
			if x and y and typeof(side) == "string" then
				local right = (side == "right") ~= mirror
				b.AnchorPoint = if right then Vector2.new(1, 1) else Vector2.new(0, 1)
				b.Position = if right then UDim2.new(1, -x, 1, -y) else UDim2.new(0, x, 1, -y)
			end
		end
	end
end

--- Botão de segurar: pressiona/solta (e solta se o dedo sair de cima).
local function bindHold(b: TextButton, onChange: (boolean) -> ())
	b.MouseButton1Down:Connect(function()
		onChange(true)
	end)
	b.MouseButton1Up:Connect(function()
		onChange(false)
	end)
	b.MouseLeave:Connect(function()
		onChange(false)
	end)
end

function MobileController.Init()
	local gui = playerGui:WaitForChild("MobileGui", 15)
	assert(gui, "[MobileController] StarterGui.MobileGui não chegou (Rojo conectado?)")
	root = get(gui, "Root") :: Frame
end

function MobileController.Start()
	local attack = get(root, "Attack") :: TextButton
	local block = get(root, "Block") :: TextButton
	local sprint = get(root, "Sprint") :: TextButton
	local lock = get(root, "Lock") :: TextButton
	local emote = get(root, "Emote") :: TextButton

	bindHold(attack, CombatController.SetAttackHeld)
	bindHold(block, function(pressed)
		if SettingsController.Get("BlockToggle") == true then
			if pressed then
				CombatController.BlockInput(true)
			end
		else
			CombatController.SetBlock(pressed)
		end
	end)

	local sprintOn = false
	sprint.MouseButton1Click:Connect(function()
		sprintOn = not sprintOn
		MovementController.SetSprint(sprintOn)
		sprint.BackgroundColor3 = if sprintOn then COLOR_ON else COLOR_OFF
	end)
	lock.MouseButton1Click:Connect(function()
		MovementController.SetShiftLock(not MovementController.IsShiftLocked())
		lock.BackgroundColor3 = if MovementController.IsShiftLocked() then COLOR_ON else COLOR_OFF
	end)
	emote.MouseButton1Click:Connect(function()
		CosmeticsController.ToggleWheel()
	end)
	localPlayer.CharacterAdded:Connect(function()
		sprintOn = false
		sprint.BackgroundColor3 = COLOR_OFF
		lock.BackgroundColor3 = if MovementController.IsShiftLocked() then COLOR_ON else COLOR_OFF
	end)

	local dash = get(root, "Dash") :: TextButton
	dash.MouseButton1Down:Connect(function()
		MovementController.Dash()
	end)
	local awaken = get(root, "Awaken") :: TextButton
	awaken.MouseButton1Down:Connect(function()
		AbilityController.Awaken()
	end)
	for slot = 1, 4 do
		local b = get(root, "Slot" .. slot) :: TextButton
		b.MouseButton1Down:Connect(function()
			AbilityController.Use(slot)
		end)
	end

	applySettings()
	SettingsController.Changed.Event:Connect(function(key: string)
		if key:sub(1, 5) == "Touch" then
			applySettings()
		end
	end)

	refreshVisibility()
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(refreshVisibility)
	UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(refreshVisibility)
	UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		-- Tablet com teclado bluetooth etc.: mostra quando a última interação foi toque
		if inputType == Enum.UserInputType.Touch and not root.Visible then
			root.Visible = true
			CombatController.TouchAttackEnabled = false
		end
	end)
	Log.debug(("[MobileController] pronto (visível=%s)"):format(tostring(root.Visible)))
end

return MobileController
