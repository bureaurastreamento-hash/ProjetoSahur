--!strict
--[[
	TopbarController (cliente)
	Topo com TopbarPlus (ReplicatedStorage.Shared.Packages.Icon): 5 botões, cada um com DROPDOWN
	(estrutura pedida pelo dono em 2026-09-19):
	  Personagens (V) -> um item por personagem (clique = usar / comprar / abrir loja se VIP)
	  Jogar           -> Duelo (J), Clã (C), Placar (Tab)
	  Loja (L)        -> abre o painel direto (sem dropdown)
	  Perfil          -> Cosméticos (K), Perfil (P), Conquistas (AchievementsController via AddToProfile),
	                     Denunciar (ReportController via AddToProfile)
	  Config          -> Configurações (SettingsGui), Controles (HelpGui), Dev (DevController via AddToSettings)
	Abrir um dos 5 fecha os outros (TopbarPlus desliga o autoDeselect de quem tem dropdown; a gente
	refaz isso à mão em closeParents). As teclas continuam abrindo os painéis direto.
	API: TopbarController.AddToSettings(icon) / AddToProfile(icon, nome?) / Toggle(nome).
	HUD estilo Blox Fruits (2026-09-29): no TOPO só fica o Config (menus "sérios": configurações, controles,
	novidades, denúncia, dev). Personagens/Jogar/Loja/Perfil continuam existindo (teclas e painéis), mas ESCONDIDOS:
	quem abre é o menu lateral na tela (MenuController → TopbarController.Toggle).
	Só reflete estado do servidor; não decide nada.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local ModRegistry = require(Modules:WaitForChild("ModRegistry"))
local BountyConfig = require(Modules.BountyConfig)
local FactionConfig = require(Modules.FactionConfig)
local ProgressionConfig = require(Modules:WaitForChild("ProgressionConfig"))
local Log = require(Modules:WaitForChild("Log"))
local Icon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Icon"))
local Controls = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Controls"))
-- Gamepad: D-pad direita navega os ícones do topo (D-pad cima é o despertar)
local IconAny: any = Icon
IconAny.highlightKey = Controls.Gamepad.Menus
IconAny.modifyBaseTheme({ { "IconCorners", "CornerRadius", UDim.new(0, 0) :: any } })
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local CosmeticsController = require(script.Parent:WaitForChild("CosmeticsController"))

local TopbarController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local profilePanel: Frame
local statsList: ScrollingFrame
local statsTemplate: TextLabel
local profileCoins: TextLabel
local profileWarning: TextLabel
local profileCharacters: TextLabel
local profileTop: TextLabel
local profileTopRating: TextLabel
local profileLevel: TextLabel
local xpFill: Frame
local charactersIcon: any
local shopIcon: any
local profileIcon: any -- pai do dropdown de Perfil
local pendingProfile: { any } = {}
local settingsIcon: any -- pai do dropdown de Config (engrenagem)
local pendingSettings: { any } = {} -- ícones pedidos antes do pai existir (DevController)
local settingsChildren: { any } = {}
local notifiedAffordable = false
local menuIcons: { [string]: any } = {} -- nome do menu lateral -> ícone (Toggle)

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

	-- A lista da direita (CONQUISTAS em andamento) é preenchida pelo AchievementsController, que já
	-- tem os dados do FetchAchievements — aqui não se mexe nela.
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
	profileCoins.Text = ("%d pontos · %d de evento · rating %d"):format(profile.coins or 0, profile.eventPoints or 0, profile.rating or 1000)
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

	local bounty = if typeof(profile.bounty) == "table" then tonumber(profile.bounty.points) or 0 else 0
	local bountyRow = statsTemplate:Clone()
	bountyRow.Visible = true
	bountyRow.LayoutOrder = 100
	local government = profile.faction == FactionConfig.Government
	local reputation = if government then (profile.honor and profile.honor.points or 0) else bounty
	bountyRow.TextWrapped, bountyRow.AutomaticSize, bountyRow.Size = true, Enum.AutomaticSize.Y, UDim2.new(1, -8, 0, 18)
	bountyRow.Text = ("%s\n%s: %d · %s"):format(FactionConfig.Name(profile.faction or ""),
		if government then "Honra" else "Bounty", reputation,
		if government then FactionConfig.HonorTitle(reputation) else BountyConfig.Title(reputation))
	bountyRow.Parent = statsList

	-- Stands (29/09): um Stand ativo + raça; o resto está na mochila (M)
	local standDef = if profile.power and profile.power ~= "" then CharacterDefs.Get(profile.power) else nil
	profileCharacters.Text = ("Stand: %s · Raça: %s"):format(if standDef then standDef.DisplayName else "nenhum (humano)", tostring(profile.race or "Humano"))

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
	-- A biblioteca pode aplicar temas próprios nos dropdowns; manter o mesmo canto levemente arredondado do resto da UI.
	for _, container in IconAny.container do
		local function corner(descendant: Instance)
			if not descendant:IsA("UICorner") then return end
			local function apply()
				if descendant.CornerRadius ~= UDim.new(0, 6) then descendant.CornerRadius = UDim.new(0, 6) end
			end
			apply()
			descendant:GetPropertyChangedSignal("CornerRadius"):Connect(apply)
		end
		for _, descendant in container:GetDescendants() do corner(descendant) end
		container.DescendantAdded:Connect(corner)
	end
	local profileGui = get(playerGui, "ProfileGui")
	profilePanel = get(profileGui, "Panel") :: Frame
	profileCoins = get(profilePanel, "Coins") :: TextLabel
	profileWarning = get(profilePanel, "Warning") :: TextLabel
	profileCharacters = get(profilePanel, "Characters") :: TextLabel
	profileTop = get(profilePanel, "Top") :: TextLabel
	profileTopRating = get(profilePanel, "TopRating") :: TextLabel
	statsList = get(profilePanel, "Stats") :: ScrollingFrame
	statsTemplate = get(statsList, "Template") :: TextLabel
	profileLevel = get(profilePanel, "Level") :: TextLabel
	xpFill = get(get(profilePanel, "XPBar"), "Fill") :: Frame
end

local parents: { any } = {} -- os 5 botões do topo (preenchido no Start)

--- Disparado quando algum menu do topo abre (VendorController fecha o painel do vendedor: mesmo canto).
TopbarController.MenuOpened = Instance.new("BindableEvent")

--- Fecha os dropdowns do topo (e os painéis abertos dentro deles), menos `keep`.
local function closeParents(keep: any?, keepChild: any?)
	if keep or keepChild then
		TopbarController.MenuOpened:Fire()
	end
	for _, parent in parents do
		-- keepChild pode ser um dos PAIS (Loja é item direto, sem dropdown): não fechar ele mesmo ao abrir —
		-- era isso que fazia a Loja abrir/fechar no mesmo clique (painel sobreposto e "não quer sair")
		if parent ~= keep and parent ~= keepChild and parent.isSelected then
			parent:deselect("Topbar", keep)
			for uid in parent.childIconsDict do
				local child = IconAny.getIconByUID(uid)
				if child and child ~= keepChild and child.isSelected and not child.oneClickEnabled then
					child:deselect("Topbar", keep)
				end
			end
		end
	end
end

--- Item que abre um painel: abrir (tecla ou clique) recolhe os dropdowns; o botão Close do painel
--- fecha o item (dono, 2026-09-19: "X pra sair em todos os menus", "abriu menu, dropbar fecha").
local registered: { [any]: boolean } = {}
local function registerItem(icon: any)
	if registered[icon] then
		return
	end
	registered[icon] = true
	icon.selected:Connect(function()
		closeParents(nil, icon)
	end)
	for item in icon.toggleItems do
		local close = item:FindFirstChild("Close")
		if close and close:IsA("GuiButton") then
			close.Activated:Connect(function()
				Log.debug(("[TopbarController] X fechou %s"):format(item:GetFullName()))
				icon:deselect("Close", icon)
				if item:IsA("GuiObject") then
					item.Visible = false -- garantia: mesmo se o ícone já estava "deselecionado" por fora
				end
			end)
		end
	end
end

--- Fecha todos os dropdowns e painéis do topo (VendorController: o painel do vendedor ocupa o mesmo canto).
function TopbarController.CloseAll()
	closeParents(nil)
end

--- Abre/fecha um painel pelo nome (menu lateral): "Loja", "Visual", "Perfil", "Conquistas", "Duelo", "Clã", "Placar".
function TopbarController.Toggle(name: string)
	local icon = menuIcons[name]
	if not icon then
		return
	end
	if icon.isSelected then
		icon:deselect()
	else
		icon:select()
	end
	-- garantia: o pai está escondido no topo; o painel segue o estado do ícone
	for item in icon.toggleItems do
		if item:IsA("GuiObject") then
			item.Visible = icon.isSelected
		end
	end
end

--- Pendura um ícone no dropdown de Perfil (AchievementsController: "Conquistas"). `name` = entra no menu lateral.
function TopbarController.AddToProfile(icon: any, name: string?)
	if name then
		menuIcons[name] = icon
	end
	registerItem(icon)
	if not profileIcon then
		table.insert(pendingProfile, icon)
		return
	end
	icon:joinDropdown(profileIcon)
end

--- Pendura um ícone no dropdown de Config (engrenagem). Chamado pelo DevController quando o jogador
--- é desenvolvedor; se o topbar ainda não montou, o ícone fica na fila e entra no Start.
function TopbarController.AddToSettings(icon: any)
	registerItem(icon)
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
	local settingsPanel = get(get(playerGui, "SettingsGui"), "Panel") :: Frame
	local duelPanel = get(get(playerGui, "DuelGui"), "Panel") :: Frame
	local clanPanel = get(get(playerGui, "ClanGui"), "Panel") :: Frame
	local shopPanel = get(get(playerGui, "ShopGui"), "Panel") :: Frame

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
			registerItem(icon)
		end
		return icon
	end

	-- Personagens: um item por personagem DENTRO do dropdown (sem painel próprio, pedido do dono 2026-09-19).
	local characterItems: { [string]: any } = {}
	local function makeCharacterItem(id: string, i: number)
		local icon = Icon.new():setOrder(i):oneClick(true)
		icon.selected:Connect(function()
			HUDController.ActivateCharacter(id)
			if charactersIcon then
				charactersIcon:deselect("Topbar", icon) -- recolhe o dropdown depois de escolher
			end
		end)
		characterItems[id] = icon
	end
	for i, id in CharacterDefs.Order do
		makeCharacterItem(id, i)
	end
	local function refreshCharacterItems()
		for id, icon in characterItems do
			local text, current, visible = HUDController.CharacterStatus(id)
			icon:setLabel(text)
			icon:setEnabled(visible)
			icon:modifyTheme({ "IconLabel", "TextColor3", (if current then Color3.fromRGB(120, 200, 255) else Color3.new(1, 1, 1)) :: any })
		end
	end

	local duelItem = item("Duelo", "Desafiar alguém para 1v1", Enum.KeyCode.J, duelPanel, 1)
	local clanItem = item("Clã", "Fundar ou entrar em um clã", Enum.KeyCode.C, clanPanel, 2)
	local scoreItem = item("Placar", "Kills da sessão", Enum.KeyCode.Tab, scoreboard, 3)
	scoreItem:bindToggleKey(Controls.Gamepad.Scoreboard)

	local cosmeticsItem = item("Cosméticos", "Skins, capas, auras e emotes (roda: B)", Enum.KeyCode.K, CosmeticsController.GetPanel(), 0)
	local profileItem = item("Perfil", "Estatísticas e pontos", Enum.KeyCode.P, profilePanel, 1)
	local settingsItem = item("Configurações", "Ajustes (salvam no perfil)", nil, settingsPanel, 0)
	local helpItem = item("Controles", "Como jogar", nil, helpPanel, 1)

	-- Os 5 botões que ficam no topo (ordem do dono: Personagens, Jogar, Loja, Perfil, Config)
	charactersIcon = Icon.new()
		:setLabel("Personagens")
		:setCaption("Trocar personagem")
		:setCaptionHint(Enum.KeyCode.V)
		:bindToggleKey(Enum.KeyCode.V)
		:setOrder(0)
	local characterList = {}
	for _, id in CharacterDefs.Order do
		table.insert(characterList, characterItems[id])
	end
	charactersIcon:setDropdown(characterList)
	refreshCharacterItems()
	-- mods de personagem (servidor privado) entram e saem da lista em tempo real. Nunca chamar setDropdown de
	-- novo (o TopbarPlus DESTRÓI todos os ícones antigos): entra com joinDropdown, sai com leave + destroy.
	ModRegistry.Changed.Event:Connect(function(modId: string, active: boolean)
		if active then
			for _, id in ModRegistry.CharactersOf(modId) do
				if not characterItems[id] then
					makeCharacterItem(id, table.find(CharacterDefs.Order, id) or #CharacterDefs.Order)
					characterItems[id]:joinDropdown(charactersIcon)
				end
			end
		else
			for id, icon in characterItems do
				if not CharacterDefs.Get(id) then
					pcall(function()
						icon:leave()
						icon:destroy()
					end)
					characterItems[id] = nil
				end
			end
		end
		refreshCharacterItems()
	end)
	HUDController.CharactersChanged.Event:Connect(refreshCharacterItems)
	localPlayer:GetAttributeChangedSignal("IsDeveloper"):Connect(refreshCharacterItems)

	local playIcon = Icon.new()
		:setLabel("Jogar")
		:setCaption("Duelo, clã e placar")
		:setOrder(1)
		:setDropdown({ duelItem, clanItem, scoreItem })

	shopIcon = item("Loja", "Pontos e passes", Enum.KeyCode.L, shopPanel, 2)

	profileIcon = Icon.new()
		:setLabel("Perfil")
		:setCaption("Cosméticos, estatísticas, conquistas e denúncias")
		:setOrder(3)
	profileIcon:setDropdown({ cosmeticsItem, profileItem })
	for _, icon in pendingProfile do
		TopbarController.AddToProfile(icon)
	end
	table.clear(pendingProfile)

	settingsIcon = Icon.new()
		:setLabel("Config")
		:setCaption("Configurações, controles e dev")
		:setOrder(4)
	settingsChildren = { settingsItem, helpItem }
	settingsIcon:setDropdown(settingsChildren)
	for _, icon in pendingSettings do
		TopbarController.AddToSettings(icon)
	end
	table.clear(pendingSettings)

	-- TopbarPlus desliga o autoDeselect de quem tem dropdown (Utility.joinFeature), então um pai
	-- aberto não fechava quando outro pai abria. Aqui: abriu um dos 5, os outros fecham (e os
	-- filhos deles também, para não sobrar painel aberto de um menu recolhido).
	parents = { charactersIcon, playIcon, shopIcon, profileIcon, settingsIcon }
	-- HUD estilo Blox Fruits: no topo só o Config; o resto abre pelo menu lateral (MenuController)
	menuIcons.Loja, menuIcons.Visual, menuIcons.Perfil = shopIcon, cosmeticsItem, profileItem
	menuIcons.Duelo, menuIcons["Clã"], menuIcons.Placar = duelItem, clanItem, scoreItem
	for _, hidden in { charactersIcon, playIcon, shopIcon, profileIcon } do
		hidden:setEnabled(false)
	end
	for _, parent in parents do
		parent.selected:Connect(function()
			closeParents(parent)
		end)
	end

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
