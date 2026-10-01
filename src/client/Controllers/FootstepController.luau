--!strict
local Players = game:GetService("Players")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local FX = require(Modules.FX)
local Assets = require(Modules.Assets)
local Controller = {}
function Controller.Start()
	task.spawn(function()
		local step = 0
		while true do
			task.wait(.32)
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not character or not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 or humanoid.SeatPart
				or humanoid.MoveDirection.Magnitude < .1 or humanoid.FloorMaterial == Enum.Material.Air or humanoid:GetState() == Enum.HumanoidStateType.Swimming then continue end
			step += 1
			local sound = if humanoid.FloorMaterial == Enum.Material.Concrete or humanoid.FloorMaterial == Enum.Material.Slate then "footstep_concrete_000" else ("footstep_carpet_%03d"):format(step % 4 + 1)
			local template = Assets.GetSound("CC0", sound)
			if not template then continue end
			local running = root:FindFirstChild("Running")
			if running and running:IsA("Sound") then running.Volume = 0 end
			FX.PlaySoundAt(character, "CC0", sound)
			if step % 3 == 0 and (humanoid.FloorMaterial == Enum.Material.Sand or humanoid.FloorMaterial == Enum.Material.Ground) then
				local dust = Assets.GetVFXPath("CC0.Dust")
				if dust then FX.SpawnVFXTemplate(character, dust, root.Position - Vector3.new(0, 2.8, 0)) end
			end
		end
	end)
end
return Controller
