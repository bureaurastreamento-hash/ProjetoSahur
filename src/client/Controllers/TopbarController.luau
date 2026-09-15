--!strict
--[[
	TopbarController (cliente)
	Ícones do topo com TopbarPlus (ReplicatedStorage.Shared.Packages.Icon):
	  Loja (B)        -> ShopGui.Panel (conteúdo no ShopController)
	  Personagens (V) -> DROPDOWN abaixo do ícone com um sub-ícone por personagem (usar/comprar);
	                     a tela CharacterSelect ficou como reserva (não é mais aberta)
	  Perfil (P)      -> ProfileGui.Panel (stats/moedas/nível/missões vindos de NotifyProfile)
	  Placar (Tab)    -> HUD.Scoreboard (substitui a lista de jogadores padrão)
	  Controles       -> HelpGui.Panel
	  Duelo (J)       -> DuelGui.Panel (lógica no DuelController)
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
local profileLevel: TextLabel
local xpFill: Frame
local missionsList: Frame
local missionTemplate: TextLabel
local charactersIcon: any
local shopIcon: any
local characterIcons: { [string]: any } = {}
local profileCache: any = nil
local notifiedAffordable = false
local requestSelectCharacter: RemoteEvent
local requestUnlockCharacter: RemoteEvent

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
		progress.Text = ("%d/%d · +%d moedas · +%d XP"):format(tonumber(m.progress) or 0, def.goal, def.coins, def.xp)
		local fill = (row:FindFirstChild("Bar") :: Frame):FindFirstChild("Fill") :: Frame
		fill.Size = UDim2.fromScale(math.clamp((tonumber(m.progress) or 0) / def.goal, 0, 1), 1)
		row.Parent = missionsList
	end
end

--- Espelha DataService.HasCharacter (o servidor é quem decide; isto é só para o rótulo).
local function ownsCharacter(id: string): boolean
	local def = CharacterDefs.Get(id)
	if not def then
		return false
	end
	if profileCache ~= nil and table.find(profileCache.unlockedCharacters or {}, id) ~= nil then
		return true
	end
	local access = CharacterDefs.AccessOf(def)
	local dev = localPlayer:GetAttribute("IsDeveloper") == true
	if access == "early" then
		return dev
	elseif access == "vip" then
		return dev or localPlayer:GetAttribute("Pass_vip") == true or localPlayer:GetAttribute("Pass_all_characters") == true
	end
	return def.UnlockCost <= 0
end

--- Rótulo de cada sub-ícone: "● Brawler" (selecionado), "Swift", "Mystic · 250 moedas",
--- "Guardian · VIP", "Sahur · em breve".
local function refreshCharacterIcons()
	local currentId = localPlayer:GetAttribute("CharacterId")
	for id, icon in characterIcons do
		local def = CharacterDefs.Get(id)
		local name = if def then def.DisplayName else id
		local access = if def then CharacterDefs.AccessOf(def) else "coins"
		if id == currentId then
			icon:setLabel("● " .. name)
		elseif ownsCharacter(id) then
			icon:setLabel(name)
		elseif access == "vip" then
			icon:setLabel(name .. " · VIP")
		elseif access == "early" then
			icon:setLabel(name .. " · em breve")
		else
			icon:setLabel(("%s · %d moedas"):format(name, if def then def.UnlockCost else 0))
		end
	end
end

local function buildCharacterDropdown()
	local children = {}
	for i, id in CharacterDefs.Order do
		local icon = Icon.new()
			:setName("Char_" .. id)
			:setLabel(id)
			:setWidth(190)
			:setOrder(i)
			:oneClick()
		icon.selected:Connect(function()
			local def = CharacterDefs.Get(id)
			local access = if def then CharacterDefs.AccessOf(def) else "coins"
			if ownsCharacter(id) then
				requestSelectCharacter:FireServer(id)
			elseif access == "vip" and shopIcon then
				shopIcon:select() -- VIP se compra na loja
			else
				requestUnlockCharacter:FireServer(id) -- moedas (ou "early": o servidor responde e a HUD avisa)
			end
		end)
		characterIcons[id] = icon
		table.insert(children, icon)
	end
	charactersIcon:setDropdown(children)
	-- joinFeature (Utility) desliga o autoDeselect de quem tem dropdown; religa para o
	-- "Personagens" fechar quando outro menu abre (e vice-versa)
	task.defer(function()
		charactersIcon:autoDeselect(true)
	end)
	refreshCharacterIcons()
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
	profileCache = profile
	refreshCharacterIcons()
	profileCoins.Text = ("%d moedas"):format(profile.coins or 0)
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
		if def and (def.UnlockCost <= 0 or table.find(profile.unlockedCharacters or {}, id)) then
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
	requestSelectCharacter = Remotes.GetEvent(Remotes.Events.RequestSelectCharacter)
	requestUnlockCharacter = Remotes.GetEvent(Remotes.Events.RequestUnlockCharacter)
	local profileGui = get(playerGui, "ProfileGui")
	profilePanel = get(profileGui, "Panel") :: Frame
	profileCoins = get(profilePanel, "Coins") :: TextLabel
	profileWarning = get(profilePanel, "Warning") :: TextLabel
	profileCharacters = get(profilePanel, "Characters") :: TextLabel
	profileTop = get(profilePanel, "Top") :: TextLabel
	statsList = get(profilePanel, "Stats") :: Frame
	statsTemplate = get(statsList, "Template") :: TextLabel
	profileLevel = get(profilePanel, "Level") :: TextLabel
	xpFill = get(get(profilePanel, "XPBar"), "Fill") :: Frame
	missionsList = get(profilePanel, "Missions") :: Frame
	missionTemplate = get(missionsList, "Template") :: TextLabel
end

function TopbarController.Start()
	local scoreboard = get(get(playerGui, "HUD"), "Scoreboard") :: Frame
	local helpPanel = get(get(playerGui, "HelpGui"), "Panel") :: Frame
	local duelPanel = get(get(playerGui, "DuelGui"), "Panel") :: Frame
	local shopPanel = get(get(playerGui, "ShopGui"), "Panel") :: Frame

	-- Nossa lista substitui a PlayerList padrão (Tab)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	shopIcon = Icon.new()
		:setLabel("Loja")
		:setCaption("Moedas e passes")
		:setCaptionHint(Enum.KeyCode.B)
		:bindToggleKey(Enum.KeyCode.B)
		:bindToggleItem(shopPanel)
		:setOrder(0)

	charactersIcon = Icon.new()
		:setLabel("Personagens")
		:setCaption("Trocar personagem")
		:setCaptionHint(Enum.KeyCode.V)
		:bindToggleKey(Enum.KeyCode.V)
		:setOrder(1)
	buildCharacterDropdown()
	localPlayer:GetAttributeChangedSignal("CharacterId"):Connect(refreshCharacterIcons)
	for _, attr in { "IsDeveloper", "Pass_vip", "Pass_all_characters" } do
		localPlayer:GetAttributeChangedSignal(attr):Connect(refreshCharacterIcons)
	end

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
		:setLabel("Duelo")
		:setCaption("Desafiar alguém para 1v1")
		:setCaptionHint(Enum.KeyCode.J)
		:bindToggleKey(Enum.KeyCode.J)
		:bindToggleItem(duelPanel)
		:setOrder(4)

	Icon.new()
		:setLabel("Controles")
		:setCaption("Como jogar")
		:bindToggleItem(helpPanel)
		:setOrder(5)

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

	Remotes.GetEvent(Remotes.Events.RequestProfile):FireServer() -- o 1º NotifyProfile pode ter saído antes do boot
	task.delay(5, reportForeignTopbar)
	Log.debug("[TopbarController] pronto (TopbarPlus)")
end

return TopbarController
