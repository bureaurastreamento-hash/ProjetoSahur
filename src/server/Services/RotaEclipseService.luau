--!strict
--[[
	Ilha 3 do Capítulo 1 — ROTA DO ECLIPSE (Parte 3; BIBLIA_CAMPANHA_CAP1_v0.1.md, Missões 11–15).
	Hoje é o trecho do deserto egípcio (FXSolPartidoIsland; id "ilha_sol_partido" mantido). A rota cresce depois com
	porto, vilas, cidade e a mansão. Missão 11 "Manifestação" = chegar (StoryService.ArriveRegion).
]]
local Workspace = game:GetService("Workspace")
local BotService = require(script.Parent:WaitForChild("BotService"))
local StoryService = require(script.Parent:WaitForChild("StoryService"))

local RotaEclipseService = {}

local function populate(island: Model)
	local pads = island:FindFirstChild("Inimigos")
	if pads then
		for _, pad in pads:GetChildren() do
			if pad:IsA("BasePart") and pad.Name:match("^EnemyPad") then
				BotService.Spawn({ CharacterId = "Swift", Name = "Caçador de Recompensa", CFrame = pad.CFrame * CFrame.new(0,3,0), Behavior = "aggressive", Team = "fx_sol", Attributes = { FXEnemy = true, StoryKillKind = "fx_sol_enemy", MaxHealth = 130 }, Tuning = { SeekRadius = 40, DashChancePerTick = .3 } })
			end
		end
	end
	local marker = island:FindFirstChild("TempleMarker", true)
	if marker and marker:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText = "Ler", "Registro antigo"
		prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 1, 10, false
		prompt.Parent = marker
		prompt.Triggered:Connect(function(player) StoryService.DiscoverTrace(player, "carlos_eclipse01") end)
	end
	local boss = island:FindFirstChild("SolarBossSpawn", true)
	if boss and boss:IsA("BasePart") then
		-- Missão 15: O Observador (usuário de manifestação espiritual; kit provisório do Jotaro)
		BotService.Spawn({ CharacterId = "Jotaro", Name = "O Observador", CFrame = boss.CFrame * CFrame.new(0,3,0), Behavior = "aggressive", Team = "fx_sentinel", Attributes = { FXEnemy = true, StoryKillKind = "fx_sol_boss", MaxHealth = 550, DamageMult = 1.45 }, Tuning = { SeekRadius = 65, AbilityChancePerTick = .22, BlockChancePerTick = .3 } })
	end
end

function RotaEclipseService.Start()
	task.defer(function()
		local sahur = Workspace:FindFirstChild("Sahur")
		local island = sahur and sahur:FindFirstChild("FXSolPartidoIsland")
		if island and island:IsA("Model") then populate(island) end
	end)
end
return RotaEclipseService
