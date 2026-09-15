--!strict
--[[
	TopbarController (cliente)
	Ícones do topo com TopbarPlus (ReplicatedStorage.Shared.Packages.Icon):
	  Personagens (V) -> CharacterSelect.Panel
	  Perfil (P)      -> ProfileGui.Panel (stats/moedas vindos de NotifyProfile)
	  Placar (Tab)    -> HUD.Scoreboard (substitui a lista de jogadores padrão)
	  Controles       -> HelpGui.Panel
	Só reflete estado do servidor; não decide nada.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local Log = require(Modules:WaitForChild("Log"))
local Icon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Icon"))

local TopbarController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local profilePanel: Frame
local statsList: Frame
local statsTemplate: TextLabel
local profileCoins: TextLabel
local profileWarning: TextLabel
local profileCharacters: TextLabel
local profileTop: TextLabel
local charactersIcon: any
local notifiedAffordable = false

local STAT_LABELS = {
	{ "wins", "Vitórias" },
	{ "losses", "Derrotas" },
	{ "kills", "Eliminações" },
	{ "deaths", "Mortes" },
	{ "matches", "Partidas" },
}

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[TopbarController] '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function renderProfile(profile: any, sessionOnly: boolean)
	profileCoins.Text = ("%d moedas"):format(profile.coins or 0)
	profileWarning.Text = if sessionOnly then "Sem conexão com os dados: esta sessão não será salva." else ""
	for _, child in statsList:GetChildren() do
		if child:IsA("TextLabel") and child ~= statsTemplate then
			child:Destroy()
		end
	end
	local stats = profile.stats or {}
	for i, pair in STAT_LABELS do
		local row = statsTemplate:Clone()
		row.Visible = true
		row.LayoutOrder = i
		row.Text = ("%s: %d"):format(pair[2], stats[pair[1]] or 0)
		row.Parent = statsList
	end
	local kd = if (stats.deaths or 0) > 0 then (stats.kills or 0) / stats.deaths else (stats.kills or 0)
	local row = statsTemplate:Clone()
	row.Visible = true
	row.LayoutOrder = 99
	row.Text = ("K/D: %.2f"):format(kd)
	row.Parent = statsList

	local owned = {}
	for _, id in CharacterDefs.Order do
		local def = CharacterDefs.Get(id)
		if def and (def.UnlockCost <= 0 or table.find(profile.unlockedCharacters or {}, id)) then
			table.insert(owned, def.DisplayName)
		end
	end
	profileCharacters.Text = ("Personagens: %s"):format(table.concat(owned, ", "))

	-- Avisa no ícone quando dá para desbloquear algo novo
	if not notifiedAffordable then
		for _, id in CharacterDefs.Order do
			local def = CharacterDefs.Get(id)
			if def and def.UnlockCost > 0 and not table.find(profile.unlockedCharacters or {}, id) and (profile.coins or 0) >= def.UnlockCost then
				notifiedAffordable = true
				charactersIcon:notify()
				break
			end
		end
	end
end

function TopbarController.Init()
	local profileGui = get(playerGui, "ProfileGui")
	profilePanel = get(profileGui, "Panel") :: Frame
	profileCoins = get(profilePanel, "Coins") :: TextLabel
	profileWarning = get(profilePanel, "Warning") :: TextLabel
	profileCharacters = get(profilePanel, "Characters") :: TextLabel
	profileTop = get(profilePanel, "Top") :: TextLabel
	statsList = get(profilePanel, "Stats") :: Frame
	statsTemplate = get(statsList, "Template") :: TextLabel
end

function TopbarController.Start()
	local selectPanel = get(get(playerGui, "CharacterSelect"), "Panel") :: Frame
	local scoreboard = get(get(playerGui, "HUD"), "Scoreboard") :: Frame
	local helpPanel = get(get(playerGui, "HelpGui"), "Panel") :: Frame

	-- Nossa lista substitui a PlayerList padrão (Tab)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	charactersIcon = Icon.new()
		:setLabel("Personagens")
		:setCaption("Trocar personagem")
		:setCaptionHint(Enum.KeyCode.V)
		:bindToggleKey(Enum.KeyCode.V)
		:bindToggleItem(selectPanel)
		:setOrder(1)
		:autoDeselect(false)

	Icon.new()
		:setLabel("Perfil")
		:setCaption("Estatísticas e moedas")
		:setCaptionHint(Enum.KeyCode.P)
		:bindToggleKey(Enum.KeyCode.P)
		:bindToggleItem(profilePanel)
		:setOrder(2)

	Icon.new()
		:setLabel("Placar")
		:setCaption("Kills da sessão")
		:setCaptionHint(Enum.KeyCode.Tab)
		:bindToggleKey(Enum.KeyCode.Tab)
		:bindToggleItem(scoreboard)
		:setOrder(3)

	Icon.new()
		:setLabel("Controles")
		:setCaption("Como jogar")
		:bindToggleItem(helpPanel)
		:setOrder(4)

	Remotes.GetEvent(Remotes.Events.NotifyProfile).OnClientEvent:Connect(function(profile: any, sessionOnly: boolean)
		if typeof(profile) == "table" then
			renderProfile(profile, sessionOnly == true)
		end
	end)

	Remotes.GetEvent(Remotes.Events.NotifyLeaderboard).OnClientEvent:Connect(function(rows: any)
		if typeof(rows) ~= "table" then
			return
		end
		local lines = {}
		for i, row in ipairs(rows) do
			table.insert(lines, ("%2d. %-16s %d"):format(i, tostring(row.name), tonumber(row.kills) or 0))
		end
		profileTop.Text = if #lines > 0 then table.concat(lines, "\n") else "ninguém ainda"
	end)

	Log.debug("[TopbarController] pronto (TopbarPlus)")
end

return TopbarController
