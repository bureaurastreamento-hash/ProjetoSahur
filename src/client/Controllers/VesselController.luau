--!strict
local Players = game:GetService("Players")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules.RemoteEvents)
local FX = require(Modules.FX)
local Assets = require(Modules.Assets)
local Controller = {}
local player = Players.LocalPlayer
function Controller.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then continue end
			local folder = workspace:FindFirstChild("PortosStrength")
			local template = Assets.GetVFXPath("CC0.Wake")
			if not folder or not template then continue end
			for _, model in folder:GetChildren() do
				if model:IsA("Model") and model:GetAttribute("Vessel") and (tonumber(model:GetAttribute("Speed")) or 0) > 3 and (model:GetPivot().Position - root.Position).Magnitude < 250 then
					FX.SpawnVFXTemplate(model, template, (model:GetPivot() * CFrame.new(0, 2, 12)).Position)
				end
			end
		end
	end)
	Remotes.GetEvent(Remotes.Events.NotifyVessel).OnClientEvent:Connect(function(model: Model, cruise: boolean)
		if not cruise or not model or not model:IsA("Model") then return end
		local root = model:FindFirstChild("Leme")
		if root and root:IsA("BasePart") then
			FX.PlaySoundAtPosition(root.Position, "CC0", "bong_001")
			local template = Assets.GetVFXPath("CC0.Strength")
			if template then FX.SpawnVFXTemplate(model, template, model:GetPivot().Position + Vector3.new(0, 6, 0)) end
		end
	end)
	task.spawn(function()
		local request = Remotes.GetEvent(Remotes.Events.RequestVesselInput)
		while true do
			task.wait(.1)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local seat = humanoid and humanoid.SeatPart
			if seat and seat:IsA("VehicleSeat") and seat:GetAttribute("VesselHelm") == true then
				request:FireServer(seat.ThrottleFloat, seat.SteerFloat)
			end
		end
	end)
end
return Controller
