--!strict
--[[
	AchievementsController (cliente)
	Tela de CONQUISTAS (StarterGui.AchievementsGui.Panel): lista com progresso, recompensa e o passe
	no ar (nome + dias que faltam). Abre pelo dropdown "Perfil" do topo.
	  FetchAchievements  -> { season = { id, name, daysLeft }?, list = { { id, name, desc, progress, goal, done, season, reward } } }
	  NotifyAchievement  -> "done" (conquista concluída agora): aviso no HUD + recarrega a lista
	Não decide nada: quem conta e paga é o AchievementService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local Icon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Icon"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local TopbarController = require(script.Parent:WaitForChild("TopbarController"))

local AchievementsController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local panel: Frame
local list: ScrollingFrame
local template: Frame
local summary: TextLabel
local seasonLabel: TextLabel
local rows: { Frame } = {}
local loading = false
-- coluna "CONQUISTAS" do painel Perfil (ProfileGui): as que estão mais perto de fechar
local profilePanel: Frame?
local profileList: Frame?
local profileTemplate: TextLabel?
local profileRows: { TextLabel } = {}

local DONE_COLOR = Color3.fromRGB(90, 200, 130)
local SEASON_COLOR = Color3.fromRGB(200, 150, 255)

local function get(parent: Instance, name: string): Instance
	local child = parent:FindFirstChild(name)
	assert(child, ("[AchievementsController] %s.%s não existe"):format(parent:GetFullName(), name))
	return child
end

local function clearRows()
	for _, row in rows do
		row:Destroy()
	end
	table.clear(rows)
end

--- Resumo no painel Perfil: as 4 conquistas não concluídas mais perto da meta.
local function renderProfileColumn(entries: { any })
	local listFrame, rowTemplate = profileList, profileTemplate
	if not listFrame or not rowTemplate then
		return
	end
	for _, row in profileRows do
		row:Destroy()
	end
	table.clear(profileRows)
	local pending: { any } = {}
	for _, entry in entries do
		if not entry.done then
			table.insert(pending, entry)
		end
	end
	table.sort(pending, function(a, b)
		local ga = math.max(1, tonumber(a.goal) or 1)
		local gb = math.max(1, tonumber(b.goal) or 1)
		return (tonumber(a.progress) or 0) / ga > (tonumber(b.progress) or 0) / gb
	end)
	for i = 1, math.min(4, #pending) do
		local entry = pending[i]
		local goal = math.max(1, tonumber(entry.goal) or 1)
		local progress = math.clamp(tonumber(entry.progress) or 0, 0, goal)
		local row = rowTemplate:Clone()
		row.Visible = true
		row.LayoutOrder = i
		row.Text = tostring(entry.name)
		local sub = row:FindFirstChild("Progress") :: TextLabel?
		if sub then
			sub.Text = ("%d/%d · %s"):format(progress, goal, tostring(entry.reward or ""))
		end
		local bar = row:FindFirstChild("Bar") :: Frame?
		local fill = if bar then bar:FindFirstChild("Fill") :: Frame? else nil
		if fill then
			fill.Size = UDim2.fromScale(progress / goal, 1)
		end
		row.Parent = listFrame
		table.insert(profileRows, row)
	end
end

local function render(data: any)
	if typeof(data) ~= "table" or typeof(data.list) ~= "table" then
		return
	end
	clearRows()
	local done, total = 0, 0
	for i, entry in ipairs(data.list) do
		local row = template:Clone()
		row.Name = "Ach_" .. tostring(entry.id)
		row.Visible = true
		row.LayoutOrder = (if entry.done then 1000 else 0) + i
		local goal = math.max(1, tonumber(entry.goal) or 1)
		local progress = math.clamp(tonumber(entry.progress) or 0, 0, goal)
		local nameLabel = get(row, "Name") :: TextLabel
		local descLabel = get(row, "Desc") :: TextLabel
		local rewardLabel = get(row, "Reward") :: TextLabel
		local progressLabel = get(row, "Progress") :: TextLabel
		local fill = get(get(row, "Bar"), "Fill") :: Frame
		nameLabel.Text = tostring(entry.name)
		descLabel.Text = tostring(entry.desc)
		rewardLabel.Text = tostring(entry.reward or "")
		progressLabel.Text = if entry.done then "concluída" else ("%d / %d"):format(progress, goal)
		fill.Size = UDim2.fromScale(progress / goal, 1)
		if entry.done then
			fill.BackgroundColor3 = DONE_COLOR
			nameLabel.TextColor3 = DONE_COLOR
		elseif entry.season then
			nameLabel.TextColor3 = SEASON_COLOR
		end
		row.Parent = list
		table.insert(rows, row)
		total += 1
		if entry.done then
			done += 1
		end
	end
	renderProfileColumn(data.list)
	summary.Text = ("%d de %d concluídas"):format(done, total)
	if typeof(data.season) == "table" then
		seasonLabel.Text = ("%s — %d dia(s)"):format(tostring(data.season.name), tonumber(data.season.daysLeft) or 0)
	else
		seasonLabel.Text = "sem passe no ar"
	end
end

--- Pede a lista ao servidor (o painel abre já mostrando o que tiver).
function AchievementsController.Refresh()
	if loading then
		return
	end
	loading = true
	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.GetFunction(Remotes.Functions.FetchAchievements):InvokeServer()
		end)
		loading = false
		if ok then
			render(data)
		else
			Log.debug("[AchievementsController] FetchAchievements falhou: " .. tostring(data))
		end
	end)
end

function AchievementsController.Init()
	local gui = playerGui:WaitForChild("AchievementsGui", 15)
	assert(gui, "[AchievementsController] StarterGui.AchievementsGui não chegou (Rojo conectado?)")
	panel = get(gui, "Panel") :: Frame
	list = get(panel, "List") :: ScrollingFrame
	template = get(list, "Template") :: Frame
	summary = get(panel, "Summary") :: TextLabel
	seasonLabel = get(panel, "Season") :: TextLabel
	local profileGui = playerGui:WaitForChild("ProfileGui", 15)
	if profileGui then
		profilePanel = profileGui:FindFirstChild("Panel") :: Frame?
		local pl = profilePanel and profilePanel:FindFirstChild("Missions")
		profileList = pl :: Frame?
		profileTemplate = if pl then pl:FindFirstChild("Template") :: TextLabel? else nil
	end
end

function AchievementsController.Start()
	local icon = Icon.new()
		:setLabel("Conquistas")
		:setCaption("O que falta para zerar o jogo")
		:bindToggleItem(panel)
		:setOrder(2)
	icon.toggled:Connect(function(isSelected: boolean)
		if isSelected then
			AchievementsController.Refresh()
		end
	end)
	TopbarController.AddToProfile(icon)

	-- abriu o Perfil: atualiza a coluna de conquistas dele
	local pp = profilePanel
	if pp then
		pp:GetPropertyChangedSignal("Visible"):Connect(function()
			if pp.Visible then
				AchievementsController.Refresh()
			end
		end)
	end
	AchievementsController.Refresh()

	Remotes.GetEvent(Remotes.Events.NotifyAchievement).OnClientEvent:Connect(function(event: string, data: any)
		if event ~= "done" or typeof(data) ~= "table" then
			return
		end
		local reward = if typeof(data.reward) == "string" and data.reward ~= "" then " · " .. data.reward else ""
		HUDController.ShowBanner(("CONQUISTA: %s%s"):format(tostring(data.name), reward), 3)
		if panel.Visible then
			AchievementsController.Refresh()
		end
	end)
	Log.debug("[AchievementsController] pronto")
end

return AchievementsController
