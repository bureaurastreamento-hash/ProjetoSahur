--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local FX = require(Modules.FX)
local WorldConfig = require(Modules.WorldConfig)
local NpcLifecycle = require(Modules.NpcLifecycleConfig)
local Settings = require(script.Parent.SettingsController)
local Controller = {}
local player = Players.LocalPlayer
function Controller.Start()
	task.spawn(function()
		while true do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local track = "Village"
			if root and root:IsA("BasePart") then
				if not WorldConfig.IslandAt(root.Position) then track = "Sea" end
				for _, model in Workspace:GetChildren() do
					if not model:IsA("Model") then continue end
					if not NpcLifecycle.IsBoss(model:GetAttribute("StoryKillKind")) and not model:GetAttribute("BossRig") then continue end
					local humanoid = model:FindFirstChildOfClass("Humanoid")
					local bossRoot = model:FindFirstChild("HumanoidRootPart")
					if humanoid and humanoid.Health > 0 and bossRoot and bossRoot:IsA("BasePart") and (root.Position - bossRoot.Position).Magnitude < 65 then track = "Boss"; break end
				end
			end
			local volume = tonumber(Settings.Get("MusicVolume")) or .35
			FX.SetMusic(if volume <= 0 then "" else track, volume)
			task.wait(3)
		end
	end)
end
return Controller
