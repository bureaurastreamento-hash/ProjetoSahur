--!strict
--[[
	TournamentController (cliente)
	Torneio "Último de pé" (D3): barra centro-alto (StarterGui.TournamentGui.Bar) com fase, timer, vivos e o
	botão ENTRAR/SAIR na inscrição; banner (HUDController) no início e no vencedor; toast discreto por eliminação.
	Só reflete NotifyTournament; toda decisão é do TournamentService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))

local TournamentController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local bar: Frame
local title: TextLabel
local sub: TextLabel
local timerLabel: TextLabel
local aliveLabel: TextLabel
local joinButton: TextButton
local request: RemoteEvent

local state: { [string]: any }? = nil
local GOLD = Color3.fromRGB(255, 204, 77)
local RED = Color3.fromRGB(230, 90, 90)

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[TournamentController] '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function fmt(seconds: number): string
	local s = math.max(0, math.floor(seconds + 0.5))
	return ("%d:%02d"):format(s // 60, s % 60)
end

local function render()
	local st = state
	if not st or st.phase == "idle" then
		bar.Visible = false
		return
	end
	bar.Visible = true
	local phase = st.phase
	if phase == "signup" then
		title.Text = ("TORNEIO · ÚLTIMO DE PÉ · %s"):format(tostring(st.modeLabel))
		sub.Text = ("%d inscrito(s) · prêmio: %s"):format(tonumber(st.players) or 0, tostring(st.reward))
		joinButton.Visible = true
		joinButton.Text = if st.joined then "SAIR" else "ENTRAR"
		joinButton.BackgroundColor3 = if st.joined then Color3.fromRGB(120, 55, 55) else Color3.fromRGB(64, 140, 90)
		aliveLabel.Text = ""
	elseif phase == "countdown" then
		title.Text = ("COMEÇANDO · %s"):format(tostring(st.modeLabel))
		sub.Text = if st.inGame then "Você está dentro. Quem morre, sai." else "Você está de fora (assistindo)."
		joinButton.Visible = false
		aliveLabel.Text = ("%d jogador(es) · %d time(s)"):format(tonumber(st.alive) or 0, tonumber(st.teamsAlive) or 0)
	else
		title.Text = ("ÚLTIMO DE PÉ · %s"):format(tostring(st.modeLabel))
		sub.Text = if st.inGame then "Sobreviva. Quem morre, sai." else "Você está de fora (assistindo)."
		joinButton.Visible = false
		aliveLabel.Text = ("%d vivo(s) · %d time(s)"):format(tonumber(st.alive) or 0, tonumber(st.teamsAlive) or 0)
	end
end

local function onNotify(event: string, data: any)
	if event == "state" then
		state = if typeof(data) == "table" then data else nil
		render()
	elseif event == "start" then
		HUDController.ShowBanner("ÚLTIMO DE PÉ — COMEÇOU!", 3)
	elseif event == "eliminated" then
		if typeof(data) == "table" then
			local isMe = data.name == localPlayer.DisplayName
			HUDController.ShowToast(if isMe then "Você foi eliminado" else ("%s eliminado"):format(tostring(data.name)), ("%d vivo(s) · %s"):format(tonumber(data.alive) or 0, tostring(data.reason or "")), if isMe then RED else nil)
		end
	elseif event == "end" then
		state = nil
		render()
		if typeof(data) == "table" then
			if data.cancelled then
				HUDController.ShowToast("Torneio encerrado", tostring(data.message or ""))
			elseif data.winner then
				local mine = false
				for _, n in (data.winners or {}) :: { string } do
					if n == localPlayer.DisplayName then
						mine = true
					end
				end
				HUDController.ShowBanner(if mine then "VOCÊ É O ÚLTIMO DE PÉ!" else ("ÚLTIMO DE PÉ: %s"):format(tostring(data.winner)), 5)
				HUDController.ShowToast(if mine then "Prêmio do torneio" else "Torneio encerrado", tostring(data.reward or ""), GOLD)
			else
				HUDController.ShowBanner("ÚLTIMO DE PÉ: EMPATE", 4)
			end
		end
	elseif event == "denied" then
		HUDController.ShowToast("Torneio", if typeof(data) == "table" then tostring(data.message) else "", RED)
	end
end

function TournamentController.Init()
	local gui = get(playerGui, "TournamentGui")
	bar = get(gui, "Bar") :: Frame
	title = get(bar, "Title") :: TextLabel
	sub = get(bar, "Sub") :: TextLabel
	timerLabel = get(bar, "Timer") :: TextLabel
	aliveLabel = get(bar, "Alive") :: TextLabel
	joinButton = get(bar, "Join") :: TextButton
	request = Remotes.GetEvent(Remotes.Events.RequestTournament)
end

function TournamentController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyTournament).OnClientEvent:Connect(onNotify)
	joinButton.MouseButton1Click:Connect(function()
		local st = state
		if st and st.phase == "signup" then
			request:FireServer(if st.joined then "leave" else "join")
		end
	end)
	RunService.Heartbeat:Connect(function()
		local st = state
		if not st or not bar.Visible then
			return
		end
		local endsAt = tonumber(st.endsAt) or 0
		timerLabel.Text = if endsAt > 0 then fmt(endsAt - Workspace:GetServerTimeNow()) else ""
	end)
	request:FireServer("refresh")
	Log.debug("[TournamentController] pronto")
end

return TournamentController
