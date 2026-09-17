--!strict
--[[
	TopbarController (cliente)
	Topo com TopbarPlus (ReplicatedStorage.Shared.Packages.Icon): 4 botões só, cada um com um
	DROPDOWN embaixo (decisão do dono, 2026-09-17: "tem muito menu lá em cima"):
	  Jogar  -> Personagens (V), Duelo (J), Clã (C), Placar (Tab)
	  Loja   -> Loja (L), Cosméticos (K)
	  Perfil -> Perfil (P)            [Conquistas entram aqui quando a leva delas chegar]
	  Config -> Controles, Dev (só para quem é desenvolvedor; DevController se pendura aqui)
	As teclas continuam abrindo os painéis direto, com ou sem o dropdown aberto.
	Painéis: ShopGui.Panel, CharacterSelect.Panel, ProfileGui.Panel, HUD.Scoreboard, HelpGui.Panel,
	DuelGui.Panel, ClanGui.Panel, CosmeticsController.GetPanel().
	API: TopbarController.AddToSettings(icon) — pendura um ícone no dropdown de Config (DevController).
	Só reflete estado do servidor; não decide nada.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local ProgressionConfig = require(Modules:WaitForChild("ProgressionConfig"))
local Log = require(Modules:WaitForChild("Log"))
local Icon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Icon"))
local Controls = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Controls"))
-- Gamepad: D-pad direita navega os ícones do topo (D-pad cima é o despertar)
local IconAny: any = Icon
IconAny.highlightKey = Controls.Gamepad.Menus
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local CosmeticsController = require(script.Parent:WaitForChild("CosmeticsController"))

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
local profileTopRating: TextLabel
local profileLevel: TextLabel
local xpFill: Frame
local missionsList: Frame
local missionTemplate: TextLabel
local charactersIcon: any
local shopIcon: any
local settingsIcon: any -- pai do dropdown de Config (engrenagem)
local pendingSettings: { any } = {} -- ícones pedidos antes do pai existir (DevController)
local settingsChildren: { any } = {}
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

local MISSION_DEFS: { [string]: ProgressionConfig.MissionDef } = {}
for _, def in ProgressionConfig.MissionPool do
	MISSION_DEFS[def.id] = def
end

local function renderProgression(profile: any)
	local level = tonumber(profile.level) or 1
	local xp = tonumber(profile.xp) or 0
	local need = ProgressionConfig.XPForLevel(level)
	if level >= ProgressionConfig.MaxLevel then
		profileLevel.Text = ("Nível %d (máximo)"):format(level)
		xpFill.Size = UDim2.fromScale(1, 1)
	else
		profileLevel.Text = ("Nível %d — %d/%d XP"):format(level, xp, need)
		xpFill.Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1)
	end

	for _, child in missionsList:GetChildren() do
		if child:IsA("TextLabel") and child ~= missionTemplate then
			child:Destroy()
		end
	end
	local missions = if typeof(profile.missions) == "table" and typeof(profile.missions.list) == "table" then profile.missions.list else {}
	for i, m in ipairs(missions) do
		local def = MISSION_DEFS[tostring(m.id)]
		if not def then
			continue
		end
		local row = missionTemplate:Clone()
		row.Visible = true
		row.LayoutOrder = i
		local done = m.done == true
		row.Text = (if done then "✓ " else "") .. def.text:format(def.goal)
		row.TextColor3 = if done then Color3.fromRGB(150, 230, 170) else Color3.fromRGB(255, 255, 255)
		local progress = row:FindFirstChild("Progress") :: TextLabel
		progress.Text = ("%d/%d · +%d pontos · +%d XP"):format(tonumber(m.progress) or 0, def.goal, def.coins, def.xp)
		local fill = (row:FindFirstChild("Bar") :: Frame):FindFirstChild("Fill") :: Frame
		fill.Size = UDim2.fromScale(math.clamp((tonumber(m.progress) or 0) / def.goal, 0, 1), 1)
		row.Parent = missionsList
	end
end

--- Diagnóstico: aponta cópias alheias do TopbarPlus/"Example" que vieram com o place.
local function reportForeignTopbar()
	local ours = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Packages")
	for _, inst in game:GetDescendants() do
		local name = inst.Name:lower()
		if inst:IsA("ModuleScript") and inst.Name == "Icon" and not (ours and inst:IsDescendantOf(ours)) then
			warn(("[TopbarController] outro TopbarPlus no place: %s — apague no Studio"):format(inst:GetFullName()))
		elseif name:find("example", 1, true) and (inst:IsA("LuaSourceContainer") or inst:IsA("GuiObject")) then
			warn(("[TopbarController] script/GUI 'Example' alheio: %s — apague no Studio"):format(inst:GetFullName()))
		end
	end
end

local function renderProfile(profile: any, sessionOnly: boolean)
	profileCoins.Text = ("%d pontos · rating %d"):format(profile.coins or 0, profile.rating or 1000)
	renderProgression(profile)
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
		if def and CharacterDefs.AccessOf(def) ~= "admin" and (def.UnlockCost <= 0 or table.find(profile.unlockedCharacters or {}, id)) then
			table.insert(owned, def.DisplayName)
		end
	end
	profileCharacters.Text = ("Personagens: %s"):format(table.concat(owned, ", "))

	-- Avisa no ícone quando dá para desbloquear algo novo
	if not notifiedAffordable then
		for _, id in CharacterDefs.Order do
			local def = CharacterDefs.Get(id)
			if def and CharacterDefs.AccessOf(def) == "coins" and def.UnlockCost > 0 and not table.find(profile.unlockedCharacters or {}, id) and (profile.coins or 0) >= def.UnlockCost then
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
	profileTopRating = get(profilePanel, "TopRating") :: TextLabel
	statsList = get(profilePanel, "Stats") :: Frame
	statsTemplate = get(statsList, "Template") :: TextLabel
	profileLevel = get(profilePanel, "Level") :: TextLabel
	xpFill = get(get(profilePanel, "XPBar"), "Fill") :: Frame
	missionsList = get(profilePanel, "Missions") :: Frame
	missionTemplate = get(missionsList, "Template") :: TextLabel
end

--- Pendura um ícone no dropdown de Config (engrenagem). Chamado pelo DevController quando o jogador
--- é desenvolvedor; se o topbar ainda não montou, o ícone fica na fila e entra no Start.
function TopbarController.AddToSettings(icon: any)
	if not settingsIcon then
		table.insert(pendingSettings, icon)
		return
	end
	-- joinDropdown e NÃO setDropdown: setDropdown destrói os ícones que já estão lá dentro
	table.insert(settingsChildren, icon)
	icon:joinDropdown(settingsIcon)
end

function TopbarController.Start()
	local scoreboard = get(get(playerGui, "HUD"), "Scoreboard") :: Frame
	local helpPanel = get(get(playerGui, "HelpGui"), "Panel") :: Frame
	local duelPanel = get(get(playerGui, "DuelGui"), "Panel") :: Frame
	local clanPanel = get(get(playerGui, "ClanGui"), "Panel") :: Frame
	local shopPanel = get(get(playerGui, "ShopGui"), "Panel") :: Frame
	local selectPanel = get(get(playerGui, "CharacterSelect"), "Panel") :: Frame

	-- Nossa lista substitui a PlayerList padrão (Tab)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	--- Item de dropdown: rótulo, dica, tecla (opcional) e o painel que ele abre.
	local function item(label: string, caption: string, key: Enum.KeyCode?, panel: Instance?, order: number): any
		local icon = Icon.new():setLabel(label):setCaption(caption):setOrder(order)
		if key then
			icon:setCaptionHint(key):bindToggleKey(key)
		end
		if panel then
			icon:bindToggleItem(panel)
		end
		return icon
	end

	charactersIcon = item("Personagens", "Trocar personagem", Enum.KeyCode.V, selectPanel, 1)
	local duelItem = item("Duelo", "Desafiar alguém para 1v1", Enum.KeyCode.J, duelPanel, 2)
	local clanItem = item("Clã", "Fundar ou entrar em um clã", Enum.KeyCode.C, clanPanel, 3)
	local scoreItem = item("Placar", "Kills da sessão", Enum.KeyCode.Tab, scoreboard, 4)
	scoreItem:bindToggleKey(Controls.Gamepad.Scoreboard)

	shopIcon = item("Loja", "Pontos e passes", Enum.KeyCode.L, shopPanel, 1)
	local cosmeticsItem = item("Cosméticos", "Skins, capas, auras e emotes (roda: B)", Enum.KeyCode.K, CosmeticsController.GetPanel(), 2)

	local profileItem = item("Perfil", "Estatísticas e pontos", Enum.KeyCode.P, profilePanel, 1)
	local helpItem = item("Controles", "Como jogar", nil, helpPanel, 1)

	-- Os 4 botões que ficam no topo
	Icon.new()
		:setLabel("Jogar")
		:setCaption("Personagem, duelo, clã e placar")
		:setOrder(0)
		:setDropdown({ charactersIcon, duelItem, clanItem, scoreItem })

	Icon.new()
		:setLabel("Loja")
		:setCaption("Pontos, passes e cosméticos")
		:setOrder(1)
		:setDropdown({ shopIcon, cosmeticsItem })

	Icon.new()
		:setLabel("Perfil")
		:setCaption("Suas estatísticas")
		:setOrder(2)
		:setDropdown({ profileItem })

	settingsIcon = Icon.new()
		:setLabel("Config")
		:setCaption("Controles e ajustes")
		:setOrder(3)
	settingsChildren = { helpItem }
	settingsIcon:setDropdown(settingsChildren)
	for _, icon in pendingSettings do
		TopbarController.AddToSettings(icon)
	end
	table.clear(pendingSettings)

	HUDController.OpenShop.Event:Connect(function()
		shopIcon:select() -- cartão VIP clicado
	end)

	Remotes.GetEvent(Remotes.Events.NotifyProfile).OnClientEvent:Connect(function(profile: any, sessionOnly: boolean)
		if typeof(profile) == "table" then
			renderProfile(profile, sessionOnly == true)
		end
	end)

	-- placares globais: { kills = rows, rating = rows }; o Perfil mostra os 5 primeiros de cada
	local function renderTop(label: TextLabel, rows: any)
		local lines = {}
		if typeof(rows) == "table" then
			for i, row in ipairs(rows) do
				if i > 5 then
					break
				end
				table.insert(lines, ("%d. %-14s %d"):format(i, tostring(row.name), tonumber(row.value) or 0))
			end
		end
		label.Text = if #lines > 0 then table.concat(lines, "\n") else "ninguém ainda"
	end
	Remotes.GetEvent(Remotes.Events.NotifyLeaderboard).OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		renderTop(profileTop, data.kills)
		renderTop(profileTopRating, data.rating)
	end)

	Remotes.GetEvent(Remotes.Events.RequestProfile):FireServer() -- o 1º NotifyProfile pode ter saído antes do boot
	task.delay(5, reportForeignTopbar)
	Log.debug("[TopbarController] pronto (TopbarPlus)")
end

return TopbarController
