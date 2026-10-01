--!strict
-- Imagens CC0 Kenney Cursor Pack (Double/Basic), antialiasing da imagem em vez de linhas de Frames.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Assets = require(game:GetService("ReplicatedStorage").Shared.Modules.Assets)
local Controller = {}
function Controller.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = "CursorGui", true, false, 1000
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function cursor(name: string, id: string): ImageLabel
		local icon = Instance.new("ImageLabel")
		icon.Name, icon.Image, icon.BackgroundTransparency = name, id, 1
		icon.Size, icon.AnchorPoint, icon.ResampleMode = UDim2.fromOffset(32, 32), Vector2.new(.5, .5), Enum.ResamplerMode.Default
		icon.Visible, icon.Parent = false, gui
		return icon
	end
	local pointer = cursor("Triangulo", Assets.GetCursor("Pointer"))
	pointer.Rotation = 45 -- ponta do triângulo sólido voltada para cima
	local locked = cursor("Seta", Assets.GetCursor("MouseLock"))
	RunService:BindToRenderStep("SahurCursor", Enum.RenderPriority.Last.Value, function()
		local input = UIS:GetLastInputType()
		local own = not GuiService.MenuIsOpen and UIS.MouseEnabled and input ~= Enum.UserInputType.Touch and input.Name:sub(1, 7) ~= "Gamepad"
		UIS.MouseIconEnabled = not own
		local centered = UIS.MouseBehavior == Enum.MouseBehavior.LockCenter
		pointer.Visible, locked.Visible = own and not centered, own and centered
		if not own then return end
		local pos = if centered then gui.AbsoluteSize / 2 else UIS:GetMouseLocation()
		-- Hotspot na ponta, descontando margens transparentes das imagens originais.
		local offset = if centered then Vector2.new(0, -7) else Vector2.new(0, 11.3)
		local image = if centered then locked else pointer
		image.Position = UDim2.fromOffset(pos.X + offset.X, pos.Y + offset.Y)
	end)
end
return Controller
