--!strict
-- Parede de runtime: apenas corpos do lobby colidem. O mundo livre atravessa normalmente.
local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")
local Config = require(game:GetService("ReplicatedStorage").Shared.Modules.LaunchConfig)
local Containment = {}
local variants = { PreLaunchPlayers = "Players", PreLaunchDash = "Dashing", PreLaunchGrabbed = "Grabbed" }
function Containment.Init()
	for _, name in { "Players", "Dashing", "Grabbed", "PreLaunchPlayers", "PreLaunchDash", "PreLaunchGrabbed", "PreLaunchBarrier" } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then PhysicsService:RegisterCollisionGroup(name) end
	end
end
function Containment.Start()
	if not Config.PreLaunch then return end
	-- Copia a política normal após os Init de física, acrescentando só a parede do lobby.
	for group, original in variants do
		for _, entry in PhysicsService:GetRegisteredCollisionGroups() do
			local other = variants[entry.name] or entry.name
			if other ~= "PreLaunchBarrier" then
				PhysicsService:CollisionGroupSetCollidable(group, entry.name, PhysicsService:CollisionGroupsAreCollidable(original, other))
			end
		end
	end
	for _, entry in PhysicsService:GetRegisteredCollisionGroups() do
		PhysicsService:CollisionGroupSetCollidable("PreLaunchBarrier", entry.name, variants[entry.name] ~= nil)
	end
	local model = Instance.new("Model")
	model.Name = "PreLaunchContainment"
	local function wall(name: string, size: Vector3, cf: CFrame)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, cf
		p.Anchored, p.Transparency, p.CastShadow = true, 1, false
		p.CanCollide, p.CanTouch, p.CanQuery = true, false, false
		p.CollisionGroup = "PreLaunchBarrier"
		p.Parent = model
	end
	local radius, height, segments = Config.LobbyRadius - 8, 90, 32
	for i = 1, segments do
		local angle = i * math.pi * 2 / segments
		local position = Config.LobbyCenter + Vector3.new(math.cos(angle) * radius, height / 2 - 10, math.sin(angle) * radius)
		wall("Parede", Vector3.new(2 * radius * math.tan(math.pi / segments) + 2, height, 3), CFrame.lookAt(position, Config.LobbyCenter + Vector3.new(0, position.Y - Config.LobbyCenter.Y, 0)))
	end
	wall("Teto", Vector3.new(radius * 2 + 8, 3, radius * 2 + 8), CFrame.new(Config.LobbyCenter + Vector3.new(0, height - 10, 0)))
	model.Parent = Workspace
end
function Containment.Refresh(player: Player)
	local character = player.Character
	if not character then return end
	local locked = player:GetAttribute("PreLaunchLocked") == true
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") then
			local original = variants[item.CollisionGroup] or item.CollisionGroup
			if original == "Players" or original == "Dashing" or original == "Grabbed" or original == "Default" then
				item.CollisionGroup = if locked then (if original == "Dashing" then "PreLaunchDash" elseif original == "Grabbed" then "PreLaunchGrabbed" else "PreLaunchPlayers") else (if original == "Default" then "Players" else original)
			end
		end
	end
end
return Containment
