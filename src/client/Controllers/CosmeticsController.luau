--!strict
--[[
	CosmeticsController (cliente)
	  - Painel "Cosméticos" (K, TopbarPlus): abas Skins/Capas/Auras/Emotes; clique = equipar (o que
	    você tem) ou "escolher com Robux" (o que não tem). Botões: GIRAR (pontos) e giros com Robux.
	  - Roda de emotes (B): 8 posições (CosmeticsConfig.Emotes); clique = RequestEmote; à direita
	    o botão GIRAR (roleta da sorte com pontos).
	  - Desenha em TODO personagem o que o servidor replicou por atributo do Player:
	    CosmeticCape (Part fina soldada ao Torso) e CosmeticAura (FX.SetAura "Cosmetic").
	  - NotifyEmote: animação Assets.Animations.Emotes.<Id>; cena = aura temporária + VFX.Emotes.<Id>.
	    Andar cancela a animação (a cena continua até o fim).
	Nada aqui decide compra/posse: o servidor valida.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local FX = require(Modules:WaitForChild("FX"))
local CosmeticsConfig = require(Modules:WaitForChild("CosmeticsConfig"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))

local CosmeticsController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local EMOTE_KEY = Enum.KeyCode.B
local EMOTES = "Emotes"
local AURA_NAME = "Cosmetic"
local SCENE_AURA = "Scene"

local requestCosmetic: RemoteEvent
local requestEmote: RemoteEvent
local requestShop: RemoteEvent
local hintLabel: TextLabel

local panel: Frame
local coinsLabel: TextLabel
local list: Frame
local rowTemplate: TextButton
local tabButtons: { [string]: TextButton } = {}
local wheel: Frame
local currentTab = "skin"
local profile: any = nil

local function get(parent: Instance, name: string): Instance
	local inst = parent:FindFirstChild(name)
	assert(inst, ("[CosmeticsController] faltando %s em %s"):format(name, parent:GetFullName()))
	return inst
end

-- ---------------------------------------------------------------------------
-- Capa / aura por atributo (todos os jogadores)
-- ---------------------------------------------------------------------------

local function applyCape(character: Model, id: string)
	local torso = character:FindFirstChild("Torso") :: BasePart?
	if not torso then
		return
	end
	local existing = torso:FindFirstChild("Cape")
	local item = if id ~= "" then CosmeticsConfig.GetItem(id) else nil
	if not item then
		if existing then
			existing:Destroy()
		end
		return
	end
	local cape: BasePart = if existing and existing:IsA("BasePart") then existing else Instance.new("Part")
	cape.Name = "Cape"
	cape.Size = Vector3.new(2, 2.6, 0.12)
	cape.Color = item.Color or Color3.fromRGB(200, 40, 40)
	cape.Material = Enum.Material.Fabric
	cape.CanCollide = false
	cape.CanQuery = false
	cape.CanTouch = false
	cape.Massless = true
	cape.CastShadow = false
	if not existing then
		local weld = Instance.new("Weld")
		weld.Part0 = torso
		weld.Part1 = cape
		weld.C0 = CFrame.new(0, -0.3, 0.6) * CFrame.Angles(math.rad(-8), 0, 0)
		weld.Parent = cape
		cape.Parent = torso
	end
end

local function applyAura(character: Model, id: string)
	local item = if id ~= "" then CosmeticsConfig.GetItem(id) else nil
	FX.SetAura(character, if item then item.Color else nil, AURA_NAME)
end

local function refreshPlayer(p: Player)
	local character = p.Character
	if not character or not character:FindFirstChild("Torso") then
		return
	end
	local cape = p:GetAttribute("CosmeticCape")
	local aura = p:GetAttribute("CosmeticAura")
	applyCape(character, if typeof(cape) == "string" then cape else "")
	applyAura(character, if typeof(aura) == "string" then aura else "")
end

local function watchPlayer(p: Player)
	for _, attr in { "CosmeticCape", "CosmeticAura", "CosmeticSkin" } do
		p:GetAttributeChangedSignal(attr):Connect(function()
			refreshPlayer(p)
		end)
	end
	p.CharacterAdded:Connect(function(character)
		character:WaitForChild("Torso", 10)
		task.wait(0.6)
		refreshPlayer(p)
	end)
	if p.Character then
		task.delay(1, refreshPlayer, p)
	end
end

-- ---------------------------------------------------------------------------
-- Painel
-- ---------------------------------------------------------------------------

local function ownsItem(item: CosmeticsConfig.Item): boolean
	if item.Weight <= 0 and item.Access == nil then
		return true
	end
	local inProfile = profile ~= nil and typeof(profile.cosmetics) == "table" and table.find(profile.cosmetics.owned or {}, item.Id) ~= nil
	if item.Access == "vip" then
		return localPlayer:GetAttribute("Pass_vip") == true or inProfile
	end
	return inProfile
end

local function ownsEmote(emote: CosmeticsConfig.Emote): boolean
	return emote.Weight <= 0 or (profile ~= nil and table.find(profile.emotes or {}, emote.Id) ~= nil)
end

local function equippedId(category: string): string
	if profile and typeof(profile.cosmetics) == "table" and typeof(profile.cosmetics.equipped) == "table" then
		return profile.cosmetics.equipped[category] or ""
	end
	return ""
end

local function clearList()
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") and child ~= rowTemplate then
			child:Destroy()
		end
	end
end

local function addRow(order: number, name: string, color: Color3?, state: string, stateColor: Color3, onClick: () -> ())
	local row = rowTemplate:Clone()
	row.Visible = true
	row.LayoutOrder = order
	;(row:FindFirstChild("Name") :: TextLabel).Text = name
	local stateLabel = row:FindFirstChild("State") :: TextLabel
	stateLabel.Text = state
	stateLabel.TextColor3 = stateColor
	local swatch = row:FindFirstChild("Swatch") :: Frame
	swatch.Visible = color ~= nil
	if color then
		swatch.BackgroundColor3 = color
	end
	row.Activated:Connect(onClick)
	row.Parent = list
end

local COLOR_OWNED = Color3.fromRGB(150, 150, 160)
local COLOR_EQUIPPED = Color3.fromRGB(90, 205, 130)
local COLOR_PRICE = Color3.fromRGB(255, 200, 70)

local function refreshList()
	clearList()
	for tab, b in tabButtons do
		b.BackgroundColor3 = if tab == currentTab then Color3.fromRGB(60, 120, 200) else Color3.fromRGB(26, 26, 31)
	end
	if currentTab == "emote" then
		for i, emote in CosmeticsConfig.Emotes do
			local owned = ownsEmote(emote)
			addRow(i, ("%d. %s"):format(i, emote.Name), emote.Color, if owned then "na roda (B)" else "roleta · Robux", if owned then COLOR_OWNED else COLOR_PRICE, function()
				if not owned then
					requestCosmetic:FireServer("pick_robux", emote.Id)
				else
					requestEmote:FireServer(emote.Id)
				end
			end)
		end
		return
	end
	local order = 0
	local equipped = equippedId(currentTab)
	for _, item in CosmeticsConfig.Items do
		if item.Category ~= currentTab then
			continue
		end
		order += 1
		local owned = ownsItem(item)
		local isEquipped = equipped == item.Id
		local state, color
		if isEquipped then
			state, color = "EQUIPADO", COLOR_EQUIPPED
		elseif owned then
			state, color = "equipar", COLOR_OWNED
		elseif item.Access == "vip" then
			state, color = "VIP", COLOR_PRICE
		else
			state, color = "roleta · Robux", COLOR_PRICE
		end
		addRow(order, item.Name, item.Color, state, color, function()
			if isEquipped then
				requestCosmetic:FireServer("unequip", item.Id)
			elseif owned then
				requestCosmetic:FireServer("equip", item.Id)
			elseif item.Access ~= "vip" then
				requestCosmetic:FireServer("pick_robux", item.Id) -- escolher com Robux
			end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Roda de emotes
-- ---------------------------------------------------------------------------

local function setWheel(visible: boolean)
	wheel.Visible = visible
	if visible then
		for i = 1, 8 do
			local b = wheel:FindFirstChild("Slot" .. i) :: TextButton?
			local emote = CosmeticsConfig.Emotes[i]
			if b then
				b.Visible = emote ~= nil
				if emote then
					local owned = ownsEmote(emote)
					b.Text = if owned then emote.Name else emote.Name .. " 🔒"
					b.TextColor3 = if owned then Color3.fromRGB(235, 235, 240) else Color3.fromRGB(130, 130, 140)
				end
			end
		end
	end
end

local function onNotifyEmote(character: Model?, emoteId: string, active: boolean)
	if not character or not active then
		return
	end
	local emote = CosmeticsConfig.GetEmote(emoteId)
	if not emote then
		return
	end
	local track = FX.PlayAnimation(character, EMOTES, emote.Id, false, Enum.AnimationPriority.Action4)
	if emote.Kind == "scene" then
		local duration = emote.Duration or 5
		FX.SetAura(character, emote.Color, SCENE_AURA)
		FX.SpawnVFX(character, EMOTES, emote.Id, true)
		FX.Flash(character, emote.Color or Color3.fromRGB(255, 255, 255), 0.4)
		FX.PlaySoundAt(character, EMOTES, emote.Id)
		task.delay(duration, function()
			FX.SetAura(character, nil, SCENE_AURA)
		end)
	end
	-- andar cancela a animação do emote
	if track and CosmeticsConfig.EmoteMoveCancels then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local conn: RBXScriptConnection
			conn = humanoid.Running:Connect(function(speed: number)
				if speed > 0.5 then
					track:Stop(0.2)
					conn:Disconnect()
				end
			end)
			task.delay(math.max(track.Length, 1) + 0.5, function()
				conn:Disconnect()
			end)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function CosmeticsController.Init()
	requestCosmetic = Remotes.GetEvent(Remotes.Events.RequestCosmetic)
	requestEmote = Remotes.GetEvent(Remotes.Events.RequestEmote)
	requestShop = Remotes.GetEvent(Remotes.Events.RequestShop)
	local gui = playerGui:WaitForChild("CosmeticsGui", 15)
	assert(gui, "[CosmeticsController] StarterGui.CosmeticsGui não chegou (Rojo conectado?)")
	panel = get(gui, "Panel") :: Frame
	coinsLabel = get(panel, "Coins") :: TextLabel
	list = get(panel, "List") :: Frame
	hintLabel = get(panel, "Hint") :: TextLabel
	rowTemplate = get(list, "Template") :: TextButton
	local tabs = get(panel, "Tabs")
	tabButtons = {
		skin = get(tabs, "TabSkin") :: TextButton,
		cape = get(tabs, "TabCape") :: TextButton,
		aura = get(tabs, "TabAura") :: TextButton,
		emote = get(tabs, "TabEmote") :: TextButton,
	}
	local emoteGui = playerGui:WaitForChild("EmoteGui", 15)
	assert(emoteGui, "[CosmeticsController] StarterGui.EmoteGui não chegou")
	wheel = get(emoteGui, "Wheel") :: Frame
end

--- Painel (TopbarController liga no ícone "Cosméticos").
function CosmeticsController.GetPanel(): Frame
	return panel
end

function CosmeticsController.Start()
	for tab, b in tabButtons do
		b.Activated:Connect(function()
			currentTab = tab
			refreshList()
		end)
	end
	for i = 1, 8 do
		local b = wheel:FindFirstChild("Slot" .. i) :: TextButton?
		if b then
			b.Activated:Connect(function()
				local emote = CosmeticsConfig.Emotes[i]
				if emote then
					requestEmote:FireServer(emote.Id)
				end
				setWheel(false)
			end)
		end
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == EMOTE_KEY or input.KeyCode == Enum.KeyCode.DPadUp then
			setWheel(not wheel.Visible)
		end
	end)
	local rollBtn = get(panel, "Roll") :: TextButton
	rollBtn.Text = ("GIRAR — %d pontos"):format(CosmeticsConfig.RollCost)
	rollBtn.Activated:Connect(function()
		requestCosmetic:FireServer("roll")
	end)
	;(get(panel, "Roll1") :: TextButton).Activated:Connect(function()
		requestShop:FireServer("product", "roll_1")
	end)
	;(get(panel, "Roll5") :: TextButton).Activated:Connect(function()
		requestShop:FireServer("product", "roll_5")
	end)
	local wheelRoll = get(wheel, "Roll") :: TextButton
	wheelRoll.Text = ("GIRAR\n%d pts"):format(CosmeticsConfig.RollCost)
	wheelRoll.Activated:Connect(function()
		requestCosmetic:FireServer("roll")
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			refreshList()
		end
	end)
	Remotes.GetEvent(Remotes.Events.NotifyProfile).OnClientEvent:Connect(function(p: any)
		if typeof(p) == "table" then
			profile = p
			coinsLabel.Text = ("%d pontos"):format(tonumber(p.coins) or 0)
			if panel.Visible then
				refreshList()
			end
		end
	end)
	Remotes.GetEvent(Remotes.Events.NotifyCosmetics).OnClientEvent:Connect(function(event: string, data: any)
		if event == "denied" and typeof(data) == "table" then
			local msgs = { coins = "Pontos insuficientes para girar", vip = "Exclusivo do passe VIP", locked = "Você não tem este item", not_loaded = "Dados ainda carregando", already_owned = "Você já tem", all_owned = "Você já tem tudo da roleta!" }
			Log.debug(("[CosmeticsController] negado: %s"):format(tostring(data.reason)))
			hintLabel.Text = msgs[data.reason] or tostring(data.reason)
		elseif event == "rolled" and typeof(data) == "table" and typeof(data.items) == "table" then
			local names = {}
			for _, it in data.items do
				table.insert(names, tostring(it.name))
			end
			hintLabel.Text = ("Roleta: %s!"):format(table.concat(names, ", "))
			HUDController.ShowBanner(("ROLETA: %s"):format(table.concat(names, ", ")), 3)
			FX.PlaySoundUI("Shared", "UltReady")
			local character = localPlayer.Character
			if character then
				FX.Flash(character, Color3.fromRGB(255, 220, 90), 0.4)
			end
			if panel.Visible then
				task.delay(0.3, refreshList)
			end
		elseif event == "pick_pending" and typeof(data) == "table" then
			hintLabel.Text = "Abrindo compra do cosmético escolhido..."
			requestShop:FireServer("product", "pick")
		end
	end)
	Remotes.GetEvent(Remotes.Events.NotifyEmote).OnClientEvent:Connect(onNotifyEmote)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Log.debug("[CosmeticsController] pronto (K = cosméticos, B = roda de emotes)")
end

return CosmeticsController
