--!strict
--[[ Conteúdo PvE da segunda ilha do Capítulo 1. ]]
local Workspace = game:GetService("Workspace")
local BotService = require(script.Parent:WaitForChild("BotService"))
local StoryService = require(script.Parent:WaitForChild("StoryService"))

local SolPartidoService = {}

local function populate(island: Model)
	local pads = island:FindFirstChild("Inimigos")
	if pads then
		for _, pad in pads:GetChildren() do
			if pad:IsA("BasePart") and pad.Name:match("^EnemyPad") then
				BotService.Spawn({ CharacterId = "Swift", Name = "Saqueador Solar", CFrame = pad.CFrame * CFrame.new(0,3,0), Behavior = "aggressive", Team = "fx_sol", Attributes = { FXEnemy = true, StoryKillKind = "fx_sol_enemy", MaxHealth = 130 }, Tuning = { SeekRadius = 40, DashChancePerTick = .3 } })
			end
		end
	end
	local marker = island:FindFirstChild("TempleMarker", true)
	if marker and marker:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText = "Tocar", "Altar Solar"
		prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 1, 10, false
		prompt.Parent = marker
		prompt.Triggered:Connect(function(player) StoryService.Progress(player, "fx_sol_temple", 1) end)
	end
	local boss = island:FindFirstChild("SolarBossSpawn", true)
	if boss and boss:IsA("BasePart") then
		BotService.Spawn({ CharacterId = "Dio", Name = "Sentinela Solar", CFrame = boss.CFrame * CFrame.new(0,3,0), Behavior = "aggressive", Team = "fx_sentinel", Attributes = { FXEnemy = true, StoryKillKind = "fx_sol_boss", MaxHealth = 550, DamageMult = 1.45 }, Tuning = { SeekRadius = 65, AbilityChancePerTick = .22, BlockChancePerTick = .3 } })
	end
end

function SolPartidoService.Start()
	task.defer(function()
		local sahur = Workspace:FindFirstChild("Sahur")
		local island = sahur and sahur:FindFirstChild("FXSolPartidoIsland")
		if island and island:IsA("Model") then populate(island) end
	end)
end
return SolPartidoService
