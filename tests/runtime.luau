-- Adaptador mínimo para executar módulos reais de campanha no Lune, sem Studio/DataStore real.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Runtime = {}

function Runtime.Signal()
	local listeners = {}
	local event = {}
	function event:Connect(fn) table.insert(listeners, fn); return { Disconnect = function() end } end
	function event:Once(fn) return self:Connect(fn) end
	function event:Fire(...) for _, fn in listeners do fn(...) end end
	return event
end

function Runtime.new()
	local rt = { mocks = {}, loaded = {}, messages = {}, players = {}, profiles = {}, flags = {}, instances = {} }
	local nodes = {}
	local function node(path)
		if nodes[path] then return nodes[path] end
		local value = { path = path, Name = path:match("([^/]+)$") }
		function value:WaitForChild(name) return node(path .. "/" .. name) end
		setmetatable(value, { __index = function(_, key)
			if key == "Parent" then return node(path:match("^(.*)/[^/]+$") or "") end
			return node(path .. "/" .. key)
		end })
		nodes[path] = value
		return value
	end
	local playerService = { PlayerAdded = Runtime.Signal(), PlayerRemoving = Runtime.Signal() }
	function playerService:GetPlayers() return rt.players end
	function playerService:GetPlayerByUserId(id) for _, p in rt.players do if p.UserId == id then return p end end end
	local workspace = {}
	function workspace:GetServerTimeNow() return os.clock() end
	function workspace:FindFirstChild() return nil end
	local services = {
		MarketplaceService = {},
		Players = playerService, Workspace = workspace,
		ReplicatedStorage = { WaitForChild = function(_, name) assert(name == "Shared"); return node("src/shared") end },
	}
	rt.services = services
	local game = { GetService = function(_, name) return services[name] or {} end }
	local remotes = {}
	local function remote(name)
		if not remotes[name] then
			local r = { OnServerEvent = Runtime.Signal(), OnClientEvent = Runtime.Signal() }
			function r:FireServer() end
			function r:FireClient(player, event, data) table.insert(rt.messages, { player = player, event = event, data = data }) end
			remotes[name] = r
		end
		return remotes[name]
	end
	rt.mocks.RemoteEvents = { Events = setmetatable({}, { __index = function(_, key) return key end }), GetEvent = remote }
	rt.mocks.Log = { debug = function() end }
	rt.mocks.DataService = {
		GetProfile = function(player) return rt.profiles[player] end,
		MarkDirty = function() end,
		IsSessionOnly = function() return rt.flags.sessionOnly == true end,
		SaveNow = function() return not rt.flags.saveFailed end,
		AddCoins = function(player, amount) rt.profiles[player].coins += amount end,
		RewardCoins = function(player, amount) rt.profiles[player].coins += amount; return amount end,
		ProfileLoaded = { Event = Runtime.Signal() },
		TakeItem = function(player, item, amount)
			local inv = rt.profiles[player].inventory
			if (inv[item] or 0) < amount then return false end
			inv[item] -= amount
			return true
		end,
		AddItem = function(player, item, amount)
			local inv = rt.profiles[player].inventory
			inv[item] = (inv[item] or 0) + amount
			return true
		end,
	}
	rt.mocks.HealthService = {
		Died = { Event = Runtime.Signal() },
		PveParticipants = function() return rt.participants or {} end,
		FighterDied = { Event = Runtime.Signal() },
		IsAlive = function() return not rt.flags.dead end,
		SecondsSinceDamaged = function() return if rt.flags.combat then 0 else math.huge end,
	}
	rt.mocks.AchievementService = {
		OnProgress = function(fn) rt.achievementProgress = fn end,
		SetCounter = function() end, Progress = function() end,
	}
	rt.mocks.Combatant = {
		IsBot = function(v) return v.bot == true end,
		PlayerOf = function(v) return if v and v.isPlayer then v else nil end,
		Of = function(v) return v end,
		UserId = function(v) return v.UserId end,
	}
	rt.mocks.StandService = { Give = function(player, items)
		for id, count in items do rt.mocks.DataService.AddItem(player, id, count) end
	end }
	rt.mocks.AbilityService = {
		CanChangeCharacter = function() return not rt.flags.blocked, "bloqueado" end,
		ForceCharacter = function(player, id) player:SetAttribute("CharacterId", id) end,
	}
	rt.mocks.CombatService = {
		IsStunned = function() return rt.flags.stunned end,
		IsGrabbed = function() return rt.flags.grabbed end,
	}
	rt.mocks.RagdollService = { IsRagdolled = function() return rt.flags.ragdolled end }
	for _, name in { "CharacterService", "Hitbox", "AntiExploitService", "AdminService", "MovementService" } do rt.mocks[name] = {} end
	local random = { new = function()
		return { NextNumber = function() return 0.5 end, NextInteger = function(_, low) return low end }
	end }
	function rt:load(path)
		path = path:gsub("%.luau$", "")
		if self.loaded[path] then return self.loaded[path] end
		local env = {
			Instance = { new = function(class)
				if class ~= "BindableEvent" then
					assert(class == "Folder" or class == "Tool" or class == "Part" or class == "ProximityPrompt" or class == "WeldConstraint" or class == "HumanoidDescription" or class == "PointLight")
					local item = { CFrame = roblox.CFrame.new(), ClassName = class, Equipped = Runtime.Signal(), Unequipped = Runtime.Signal(), Triggered = Runtime.Signal() }
					table.insert(rt.instances, item)
					local attrs = {}
					function item:SetAttribute(key, value) attrs[key] = value end
					function item:GetAttribute(key) return attrs[key] end
					function item:IsA(name) return name == self.ClassName or (name == "BasePart" and self.ClassName == "Part") end
					function item:IsDescendantOf(ancestor) local parent = self.Parent; while parent do if parent == ancestor then return true end; parent = parent.Parent end; return false end
					function item:Destroy() self.Parent = nil end
					return item
				end
				local event = Runtime.Signal()
				return { Event = event, Fire = function(_, ...) event:Fire(...) end }
			end },
			script = node(path), game = game, workspace = workspace,
			Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame,
			RaycastParams = { new = function() return {} end },
			Color3 = roblox.Color3, Enum = roblox.Enum, Random = random,
			task = { defer = function(fn) fn() end, spawn = function() end, delay = function(_, fn) fn() end, wait = function() return 1 end },
			require = function(module)
				return self.mocks[module.Name] or self:load(module.path)
			end,
		}
		local value = luau.load(fs.readFile(path .. ".luau"), { environment = env, debugName = path })()
		self.loaded[path] = value
		return value
	end
	-- Campanha concede XP: reproduzir Init da progressão como no boot real.
	function rt:loadStory()
		self:load("src/server/Services/ProgressionService").Init()
		return self:load("src/server/Services/StoryService")
	end
	function rt:player(id, position)
		local attributes = { Level = 1 }
		local attributeSignals = {}
		local root = { Position = position or roblox.Vector3.new(150, 2, -40), IsA = function(_, name) return name == "BasePart" end }
		local player = {
			Name = "Player" .. id, DisplayName = "Player" .. id, UserId = id, Parent = playerService, isPlayer = true,
			CharacterAdded = Runtime.Signal(),
			Character = { FindFirstChild = function() return root end, FindFirstChildOfClass = function() return { Health = if rt.flags.dead then 0 else 100 } end },
		}
		function player:IsA(class) return class == "Player" end
		function player:FindFirstChildOfClass(class) return if class == "Backpack" then self.backpack else nil end
		function player:WaitForChild() return self.backpack end
		function player:GetAttribute(key) return attributes[key] end
		function player:GetAttributeChangedSignal(key)
			if not attributeSignals[key] then attributeSignals[key] = Runtime.Signal() end
			return attributeSignals[key]
		end
		function player:SetAttribute(key, value)
			local previous = attributes[key]; attributes[key] = value
			if previous ~= value and attributeSignals[key] then attributeSignals[key]:Fire() end
		end
		table.insert(self.players, player)
		self.profiles[player] = self:load("src/shared/Modules/DataConfig").DefaultProfile()
		return player, root
	end
	return rt
end

return Runtime
