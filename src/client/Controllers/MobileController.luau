--!strict
--[[
	MobileController (cliente)
	Botões de toque (StarterGui.MobileGui): SOCO, BLOCK (segurar), DASH (Q), E/R/T, CORRER.
	Só aparece quando há toque e não há teclado (celular/tablet). Não decide nada:
	chama CombatController / AbilityController, que mandam os Requests ao servidor.
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

local MobileController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local root: Frame

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

function MobileController.Init()
	local gui = playerGui:WaitForChild("MobileGui", 15)
	assert(gui, "[MobileController] StarterGui.MobileGui não chegou (Rojo conectado?)")
	root = get(gui, "Root") :: Frame
end

function MobileController.Start()
	local attack = get(root, "Attack") :: TextButton
	local block = get(root, "Block") :: TextButton
	local sprint = get(root, "Sprint") :: TextButton

	local sprintOn = false
	sprint.MouseButton1Click:Connect(function()
		sprintOn = not sprintOn
		MovementController.SetSprint(sprintOn)
		sprint.BackgroundColor3 = if sprintOn then Color3.fromRGB(70, 160, 100) else Color3.fromRGB(77, 77, 97)
	end)
	localPlayer.CharacterAdded:Connect(function()
		sprintOn = false
		sprint.BackgroundColor3 = Color3.fromRGB(77, 77, 97)
	end)

	attack.MouseButton1Down:Connect(function()
		CombatController.Attack()
	end)
	block.MouseButton1Down:Connect(function()
		CombatController.SetBlock(true)
	end)
	block.MouseButton1Up:Connect(function()
		CombatController.SetBlock(false)
	end)
	block.MouseLeave:Connect(function()
		CombatController.SetBlock(false)
	end)
	local dash = get(root, "Dash") :: TextButton
	dash.MouseButton1Down:Connect(function()
		MovementController.Dash()
	end)
	for slot = 1, 3 do
		local b = get(root, "Slot" .. slot) :: TextButton
		b.MouseButton1Down:Connect(function()
			AbilityController.Use(slot)
		end)
	end

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
