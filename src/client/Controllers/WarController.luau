--!strict
--[[
	WarController (cliente)
	Guerra de clã (dominação): placar no topo (StarterGui.WarGui.Bar: clãs, pontos, timer, pontos A/B/C
	coloridos pelo dono com barra de captura) e banner de início/fim. O botão GUERRA fica no ClanGui
	(ClanController chama WarController.Toggle). Só reflete NotifyWar; decisões no WarService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local FX = require(Modules:WaitForChild("FX"))
local WarConfig = require(Modules:WaitForChild("WarConfig"))

local WarController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local bar: Frame
local banner: TextLabel
local teamA: TextLabel
local teamB: TextLabel
local scoreA: TextLabel
local scoreB: TextLabel
local timerLabel: TextLabel
local chips: { [string]: Frame } = {}
local requestWar: RemoteEvent

local endsAtServerTime: number? = nil
local bannerToken = 0
local queued = false
local queuedTag: string? = nil

WarController.QueueChanged = Instance.new("BindableEvent") -- (queued: boolean, tag: string?, position: number?)

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[WarController] '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function showBanner(text: string, seconds: number)
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.Visible = true
	task.delay(seconds, function()
		if bannerToken == token then
			banner.Visible = false
		end
	end)
end

local function myTeam(): number
	return tonumber(localPlayer:GetAttribute("TeamId")) or 0
end

local function render(data: any)
	local tags = if typeof(data.tags) == "table" then data.tags else {}
	local names = if typeof(data.names) == "table" then data.names else {}
	local scores = if typeof(data.scores) == "table" then data.scores else { 0, 0 }
	local mine = myTeam()
	teamA.Text = ("[%s] %s%s"):format(tostring(tags[1] or "?"), tostring(names[1] or ""), if mine == 1 then "  (você)" else "")
	teamB.Text = ("%s%s [%s]"):format(if mine == 2 then "(você)  " else "", tostring(names[2] or ""), tostring(tags[2] or "?"))
	scoreA.Text = tostring(math.floor(tonumber(scores[1]) or 0))
	scoreB.Text = tostring(math.floor(tonumber(scores[2]) or 0))
	if typeof(data.zones) == "table" then
		for _, z in data.zones do
			local chip = chips[tostring(z.name)]
			if chip then
				local owner = tonumber(z.owner) or 0
				chip.BackgroundColor3 = WarConfig.TeamColors[owner] or WarConfig.NeutralColor
				local progress = chip:FindFirstChild("Progress") :: Frame?
				if progress then
					local pt = tonumber(z.progressTeam) or 0
					progress.Size = UDim2.new(math.clamp(tonumber(z.progress) or 0, 0, 1), 0, 0, 3)
					progress.BackgroundColor3 = WarConfig.TeamColors[pt] or Color3.new(1, 1, 1)
				end
			end
		end
	end
	endsAtServerTime = tonumber(data.endsAtServerTime)
end

local function onNotifyWar(event: string, data: any)
	data = if typeof(data) == "table" then data else {}
	if event == "queue" then
		queued = data.queued == true
		queuedTag = if typeof(data.tag) == "string" then data.tag else nil
		WarController.QueueChanged:Fire(queued, queuedTag, tonumber(data.position))
		if queued and data.by then
			showBanner(("%s colocou o clã na fila de GUERRA"):format(tostring(data.by)), 4)
		end
	elseif event == "start" then
		render(data)
		bar.Visible = true
		showBanner(("GUERRA: [%s] x [%s] — domine os pontos A, B e C!"):format(tostring(data.tags and data.tags[1]), tostring(data.tags and data.tags[2])), tonumber(data.countdown) or 5)
		FX.PlaySoundUI("Match", "RoundStart")
		queued = false
		WarController.QueueChanged:Fire(false, nil, nil)
	elseif event == "state" then
		render(data)
		bar.Visible = true
	elseif event == "end" then
		render(data)
		local winner = tonumber(data.winnerTeam) or -1
		local mine = myTeam()
		if winner == -1 then
			showBanner("EMPATE", WarConfig.EndTime)
		elseif winner == mine then
			showBanner(("VITÓRIA DO CLÃ [%s]!  +%d pontos"):format(tostring(data.winnerTag), WarConfig.Rewards.WinnerCoins), WarConfig.EndTime)
			FX.PlaySoundUI("Match", "Victory")
		else
			showBanner(("Derrota. [%s] venceu."):format(tostring(data.winnerTag)), WarConfig.EndTime)
		end
		task.delay(WarConfig.EndTime, function()
			bar.Visible = false
			endsAtServerTime = nil
		end)
	elseif event == "denied" then
		showBanner(tostring(data.reason), 3)
	elseif event == "info" then
		showBanner(tostring(data.message), 3)
	end
end

--- Botão GUERRA do ClanGui: entra/sai da fila.
function WarController.Toggle()
	requestWar:FireServer(if queued then "leave" else "queue")
end

function WarController.IsQueued(): boolean
	return queued
end

function WarController.Start()
	local gui = get(playerGui, "WarGui")
	bar = get(gui, "Bar") :: Frame
	banner = get(gui, "Banner") :: TextLabel
	teamA = get(bar, "TeamA") :: TextLabel
	teamB = get(bar, "TeamB") :: TextLabel
	scoreA = get(bar, "ScoreA") :: TextLabel
	scoreB = get(bar, "ScoreB") :: TextLabel
	timerLabel = get(bar, "Timer") :: TextLabel
	for _, name in { "A", "B", "C" } do
		chips[name] = get(bar, name) :: Frame
	end
	requestWar = Remotes.GetEvent(Remotes.Events.RequestWar)
	Remotes.GetEvent(Remotes.Events.NotifyWar).OnClientEvent:Connect(onNotifyWar)
	RunService.Heartbeat:Connect(function()
		if not bar.Visible or not endsAtServerTime then
			return
		end
		local left = math.max(0, endsAtServerTime - Workspace:GetServerTimeNow())
		timerLabel.Text = ("%d:%02d"):format(left // 60, left % 60)
	end)
	requestWar:FireServer("refresh")
	Log.debug("[WarController] pronto")
end

return WarController
