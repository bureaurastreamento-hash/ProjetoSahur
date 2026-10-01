--!strict
--[[
	HUDController (cliente)
	Liga as telas de StarterGui (HUD, CharacterSelect — criadas via Rojo em src/ui/)
	ao estado que vem do servidor. NÃO calcula vida nem cooldown: só mostra o que
	chegou por RemoteEvent ou por atributo replicado do servidor.

	Fontes de verdade:
	  NotifyHealth(current, max)                 -> barra de vida própria
	  Player attr Energy / CharacterId           -> barra de carga da ult, slots, seleção
	  NotifyAbilityCooldown (via AbilityController.CooldownChanged) -> overlay dos slots
	  NotifyAbilityDenied                        -> pisca o slot
	  NotifyMatchState(state, data)              -> topo, placar, banner, tela de seleção
	  NotifyKill(killer, victim)                 -> killfeed
	  Humanoid.Health dos outros (replicado)     -> barra sobre a cabeça
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local StandConfig = require(Modules:WaitForChild("StandConfig"))
local AwakeningDefs = require(Modules:WaitForChild("AwakeningDefs"))
local ModRegistry = require(Modules:WaitForChild("ModRegistry"))
local Controls = require(Modules:WaitForChild("Controls"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local ProgressionConfig = require(Modules:WaitForChild("ProgressionConfig"))
local PvpConfig = require(Modules:WaitForChild("PvpConfig"))
local MatchConfig = require(Modules:WaitForChild("MatchConfig"))
local FX = require(Modules:WaitForChild("FX"))
local HudLayout = require(Modules.HudLayout)
local AbilityController = require(script.Parent:WaitForChild("AbilityController"))
local MovementController = require(script.Parent:WaitForChild("MovementController"))

local HUDController = {}

--- Disparado quando um cartão VIP é clicado (TopbarController abre a Loja).
HUDController.OpenShop = Instance.new("BindableEvent")
--- Disparado quando muda algo que altera os rótulos de personagem (perfil, personagem atual, pontos).
HUDController.CharactersChanged = Instance.new("BindableEvent")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local SLOT_KEYS = { "1", "2", "3", "4", "R" } -- 4 ataques + R (suporte); Q = dash universal (frames "Dash"/"DashSide"); G = ultimate (frame "Ult")
local KILLFEED_MAX = 5
local KILLFEED_LIFETIME = 6

local STATE_TEXT = {
	FreeRoam = "Mapa livre — lute!",
	Waiting = "Aguardando jogadores",
	Selecting = "Escolha seu personagem",
	InProgress = "Round em andamento",
	Ending = "Fim do round",
}

-- refs de UI
local hud: ScreenGui
local selectGui: ScreenGui
local topBar: Frame
local stateLabel: TextLabel
local timerLabel: TextLabel
local healthFill: Frame
local healthText: TextLabel
local energyFill: Frame
local energyText: TextLabel
local counterBar: Frame -- barra "Revide" (anti-2v1): só aparece em desvantagem (CounterService)
local counterFill: Frame
local counterText: TextLabel
local characterNameLabel: TextLabel
local slots: { Frame } = {}
local dashSlot: Frame -- Q frente/trás (caído: ragdoll cancel)
local dashSideSlot: Frame -- Q lateral
local ultSlot: Frame -- G
local killFeed: Frame
local killTemplate: TextLabel
local scoreboard: Frame
local scoreList: Frame
local scoreTemplate: TextLabel
local banner: TextLabel
local toasts: Frame
local toastTemplate: Frame
local comboLabel: TextLabel
local comboToken = 0
local selectList: Frame
local selectTemplate: TextButton
local selectHint: TextLabel
local queueButton: TextButton
local coinsLabel: TextLabel
local levelValue: TextLabel -- selo de nível (HUD estilo Blox Fruits, 29/09)
local xpFill: Frame
local xpText: TextLabel
local reputationText: TextLabel
local selectCoinsLabel: TextLabel
local characterButtons: { [string]: TextButton } = {}
local profile: any = nil
local cardRefreshers: { () -> () } = {} -- cartões de personagem: reescrever maestria quando o perfil chega

local CARD_SELECTED = Color3.fromRGB(90, 190, 255)
local CARD_ACTION = Color3.fromRGB(240, 240, 245)
local CARD_LOCKED = Color3.fromRGB(255, 204, 77)
local CARD_EARLY = Color3.fromRGB(180, 120, 255)
local CARD_MUTED = Color3.fromRGB(158, 158, 173)

--- Espelha DataService.HasCharacter (servidor decide; aqui é só para o cartão).
local function ownsCharacter(id: string): boolean
	local def = CharacterDefs.Get(id)
	if not def then
		return false
	end
	local access = CharacterDefs.AccessOf(def)
	local dev = localPlayer:GetAttribute("IsDeveloper") == true
	if access == "human" then
		return true
	elseif access == "stand" then
		return dev or localPlayer:GetAttribute("AllCharacters") == true or (profile ~= nil and profile.power == id)
	end
	if profile ~= nil and table.find(profile.unlockedCharacters or {}, id) ~= nil then
		return true
	end
	if access == "early" or access == "admin" or access == "drop" then
		return dev
	elseif access == "vip" then
		return dev or localPlayer:GetAttribute("Pass_vip") == true or localPlayer:GetAttribute("Pass_all_characters") == true
	end
	return def.UnlockCost <= 0
end

local currentState = if MatchConfig.FreeRoam then "FreeRoam" else "Waiting"
local stateData: { [string]: any } = {}
local overheads: { [Model]: BillboardGui } = {}

local requestSelectCharacter: RemoteEvent
local requestQueue: RemoteEvent
local requestUnlockCharacter: RemoteEvent

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[HUDController] elemento '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function setBar(fill: Frame, text: TextLabel, current: number, max: number)
	local ratio = if max > 0 then math.clamp(current / max, 0, 1) else 0
	TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(ratio, 1) }):Play()
	text.Text = ("%d / %d"):format(math.floor(current + 0.5), max)
end

local showBanner: (string, number) -> ()
--- Aviso grande no centro-alto (outros controllers usam).
function HUDController.ShowBanner(text: string, seconds: number)
	showBanner(text, seconds)
end
showBanner = function(text: string, seconds: number)
	banner.Text = text
	banner.Visible = true
	task.delay(seconds, function()
		if banner.Text == text then
			banner.Visible = false
		end
	end)
end

--- Pop-up minimalista no canto direito (nível, maestria, conquista, item): sem som, some sozinho
--- (dono, 2026-09-20: "no máximo um pop-up minimalista no canto sem atrapalhar").
local toastOrder = 0
function HUDController.ShowToast(title: string, sub: string?, color: Color3?)
	toastOrder += 1
	local t = toastTemplate:Clone()
	t.Visible = true
	t.LayoutOrder = toastOrder
	;(t:FindFirstChild("Title") :: TextLabel).Text = title
	;(t:FindFirstChild("Sub") :: TextLabel).Text = sub or ""
	if color then
		(t:FindFirstChild("Stripe") :: Frame).BackgroundColor3 = color
	end
	-- entra deslizando da direita, some com fade
	t.Position = UDim2.new(0, 60, 0, 0)
	t.BackgroundTransparency = 1
	t.Parent = toasts
	TweenService:Create(t, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.25 }):Play()
	task.delay(3.5, function()
		local tween = TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		for _, d in t:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			elseif d:IsA("Frame") or d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.4), if d:IsA("UIStroke") then { Transparency = 1 } else { BackgroundTransparency = 1 }):Play()
			end
		end
		tween:Play()
		tween.Completed:Wait()
		t:Destroy()
	end)
	-- no máximo 4 na tela
	local alive = {}
	for _, c in toasts:GetChildren() do
		if c:IsA("Frame") and c ~= toastTemplate then
			table.insert(alive, c)
		end
	end
	if #alive > 4 then
		table.sort(alive, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		alive[1]:Destroy()
	end
end

-- ---------------------------------------------------------------------------
-- Slots de habilidade
-- ---------------------------------------------------------------------------

--- Slots 1..4 + G. A ULTIMATE é uma habilidade numérica que só funciona DESPERTO (AbilityService):
--- ela aparece no slot dela sempre — apagada com "(desperto)" fora do modo, acesa e dourada durante —
--- senão ninguém descobre que existe (dono, 2026-09-17). O G é o DESPERTAR (a transformação).
local ULT_SLOT_COLOR = Color3.fromRGB(255, 200, 70)
local slotBaseColor: Color3? = nil

local function refreshSlots()
	local characterId = localPlayer:GetAttribute("CharacterId")
	local def = if typeof(characterId) == "string" then CharacterDefs.Get(characterId) else nil
	characterNameLabel.Text = if def then def.DisplayName else ""
	local now = Workspace:GetServerTimeNow()
	local awakenedUntil = localPlayer:GetAttribute("AwakenedUntil")
	local awakened = typeof(awakenedUntil) == "number" and awakenedUntil > now
	if not slotBaseColor and slots[1] then
		slotBaseColor = slots[1].BackgroundColor3
	end
	local base = slotBaseColor or Color3.fromRGB(30, 30, 30)
	-- 1–4 = kit ativo (desperto troca os 4 e pinta com a cor do personagem); 5 = R (suporte, não muda)
	for i, slot in slots do
		local ability = if typeof(characterId) == "string" then CharacterDefs.GetAbility(characterId, i, awakened) else nil
		local nameLabel = slot:FindFirstChild("Name") :: TextLabel
		if ability then
			slot.Visible = true
			nameLabel.Text = ability.DisplayName
			local isAwakenedSlot = awakened and i <= 4 and def ~= nil and #def.AwakenedAbilities > 0
			slot.BackgroundColor3 = if isAwakenedSlot then (def and def.Color or ULT_SLOT_COLOR):Lerp(base, 0.6) else base
			slot.BackgroundTransparency = 0.1
			nameLabel.TextTransparency = 0
		else
			slot.Visible = false
		end
	end
	ultSlot.Visible = def ~= nil and #def.AwakenedAbilities > 0 -- Humano (sem Stand) não desperta
	local awDef = if typeof(characterId) == "string" then AwakeningDefs.Get(characterId) else nil
	;(ultSlot:FindFirstChild("Name") :: TextLabel).Text = if awDef and awDef.UltName then awDef.UltName else "Despertar"
end

--- Stand: nível de maestria que ainda falta para a tecla (nil = liberada). slot 0 = G. Espelha o AbilityService.
local function masteryLock(characterId: any, slot: number): number?
	if typeof(characterId) ~= "string" or localPlayer:GetAttribute("DevNoCooldown") == true then
		return nil
	end
	local required = StandConfig.RequiredMastery(characterId, slot)
	if not required then
		return nil
	end
	local xp = if profile ~= nil and profile.mastery then profile.mastery[characterId] or 0 else 0
	return if ProgressionConfig.MasteryLevel(xp) < required then required else nil
end

local function setCooldownOverlay(slot: Frame, remaining: number, total: number)
	local overlay = slot:FindFirstChild("Cooldown") :: Frame
	local text = slot:FindFirstChild("CooldownText") :: TextLabel
	if remaining > 0 then
		overlay.Size = UDim2.fromScale(1, math.clamp(remaining / math.max(total, remaining), 0, 1))
		text.Text = ("%.1f"):format(remaining)
	else
		overlay.Size = UDim2.fromScale(1, 0)
		text.Text = ""
	end
end

local function updateCooldowns()
	local now = Workspace:GetServerTimeNow()
	local cooldowns = AbilityController.GetCooldowns()
	local characterId = localPlayer:GetAttribute("CharacterId")
	local awakenedUntil = localPlayer:GetAttribute("AwakenedUntil")
	local awakened = typeof(awakenedUntil) == "number" and awakenedUntil > now
	local byId = AbilityController.GetCooldownsById()
	for i, slot in slots do
		local ability = if typeof(characterId) == "string" then CharacterDefs.GetAbility(characterId, i, awakened) else nil
		local cd = if ability then byId[ability.Id] else cooldowns[i]
		local remaining = if cd then cd.readyAt - now else 0
		setCooldownOverlay(slot, remaining, if ability then ability.Cooldown else remaining)
		local lock = masteryLock(characterId, i)
		if lock then -- trancada por maestria do Stand
			(slot:FindFirstChild("Cooldown") :: Frame).Size = UDim2.fromScale(1, 1);
			(slot:FindFirstChild("CooldownText") :: TextLabel).Text = ("Maestria\n%d"):format(lock)
		end
	end
	-- Ultimate (G): trancada até a carga encher; no Awakening mostra o tempo restante do modo
	local e = localPlayer:GetAttribute("Energy")
	local charged = typeof(e) == "number" and e >= CharacterDefs.Energy.Max
	local ultOverlay = ultSlot:FindFirstChild("Cooldown") :: Frame
	local ultText = ultSlot:FindFirstChild("CooldownText") :: TextLabel
	local awakenedDuration = tonumber(localPlayer:GetAttribute("AwakenedDuration")) or CombatConfig.Awakening.Duration
	local ultLock = masteryLock(characterId, 0)
	if awakened then
		ultOverlay.Size = UDim2.fromScale(1, math.clamp((awakenedUntil - now) / awakenedDuration, 0, 1))
		ultText.Text = ("%d"):format(math.ceil(awakenedUntil - now))
	elseif ultLock then
		ultOverlay.Size = UDim2.fromScale(1, 1)
		ultText.Text = ("Maestria\n%d"):format(ultLock)
	elseif charged then
		ultOverlay.Size = UDim2.fromScale(1, 0)
		ultText.Text = ""
	else
		ultOverlay.Size = UDim2.fromScale(1, 1)
		ultText.Text = if typeof(e) == "number" then ("%d%%"):format(math.floor(100 * e / CharacterDefs.Energy.Max + 0.5)) else ""
	end
	-- Awakening: a barra da ult vira contagem regressiva dourada
	if awakened then
		energyFill.Size = UDim2.fromScale(math.clamp((awakenedUntil - now) / awakenedDuration, 0, 1), 1)
		energyText.Text = ("DESPERTO %ds"):format(math.ceil(awakenedUntil - now))
	end
	-- Dash universal (Q): frente/trás e lateral têm cooldowns próprios; caído, o 1º mostra o ragdoll cancel
	local dashCds = MovementController.GetDashCooldowns()
	local ragdolled = localPlayer:GetAttribute("Ragdolled") == true
	local cd = if ragdolled then dashCds.cancel else dashCds.forward
	local remaining = if cd then cd.readyAt - now else 0
	setCooldownOverlay(dashSlot, remaining, if cd then cd.total else remaining)
	local nameLabel = dashSlot:FindFirstChild("Name") :: TextLabel
	-- personagem sem dash (Swift): o Q é o DashOverride (Piscar); um cooldown só, o slot lateral some
	local override = if typeof(characterId) == "string" then CharacterDefs.GetDashOverride(characterId) else nil
	nameLabel.Text = if ragdolled then "Levantar" elseif override then override.DisplayName else "Dash ↑↓"
	-- chips só aparecem enquanto recarregam (dono, 2026-09-19)
	dashSlot.Visible = remaining > 0
	local side = dashCds.side
	local sideRemaining = if side then side.readyAt - now else 0
	dashSideSlot.Visible = override == nil and sideRemaining > 0
	setCooldownOverlay(dashSideSlot, sideRemaining, if side then side.total else sideRemaining)
	;(dashSideSlot:FindFirstChild("Name") :: TextLabel).Text = "Dash ←→"
end

local function flashSlot(slot: number, color: Color3)
	local frame = slots[slot]
	if not frame then
		return
	end
	local original = frame.BackgroundColor3
	frame.BackgroundColor3 = color
	task.delay(0.15, function()
		frame.BackgroundColor3 = original
	end)
end

-- ---------------------------------------------------------------------------
-- Partida / placar / seleção
-- ---------------------------------------------------------------------------

local function refreshScoreboard()
	for _, child in scoreList:GetChildren() do
		if child:IsA("TextLabel") and child ~= scoreTemplate then
			child:Destroy()
		end
	end
	local scores = stateData.scores
	if MatchConfig.FreeRoam then
		scores = {}
		for _, p in Players:GetPlayers() do
			local k = p:GetAttribute("SessionKills")
			table.insert(scores, { name = p.Name, kills = if typeof(k) == "number" then k else 0, alive = true })
		end
		table.sort(scores, function(a, b)
			if a.kills ~= b.kills then
				return a.kills > b.kills
			end
			return a.name < b.name
		end)
		while #scores > 6 do
			table.remove(scores)
		end
	end
	local visible = typeof(scores) == "table" and #scores > 0 and (currentState == "InProgress" or currentState == "Ending" or currentState == "FreeRoam")
	if not MatchConfig.FreeRoam then
		scoreboard.Visible = visible -- no mapa livre quem controla é o ícone "Placar" do topbar
	end
	if not visible then
		return
	end
	for i, entry in scores do
		local row = scoreTemplate:Clone()
		row.Visible = true
		row.LayoutOrder = i
		row.Text = ("%s  %d"):format(entry.name, entry.kills)
		row.TextColor3 = if entry.alive then Color3.new(1, 1, 1) else Color3.fromRGB(140, 140, 140)
		if entry.name == localPlayer.Name then
			row.TextColor3 = if entry.alive then Color3.fromRGB(120, 200, 255) else Color3.fromRGB(80, 120, 150)
		end
		row.Parent = scoreList
	end
end

local function refreshMatchUI()
	stateLabel.Text = STATE_TEXT[currentState] or currentState
	if currentState == "Waiting" and stateData.needed then
		stateLabel.Text ..= ("  (%s/%d)"):format(tostring(stateData.queued or 0), stateData.needed)
	elseif currentState == "InProgress" and stateData.alive then
		stateLabel.Text ..= ("  vivos: %d"):format(stateData.alive)
	end

	local inMatch = localPlayer:GetAttribute("InMatch") == true
	selectGui.Enabled = not inMatch and (currentState == "FreeRoam" or currentState == "Waiting" or currentState == "Selecting")
	queueButton.Visible = not MatchConfig.FreeRoam
	queueButton.Text = if localPlayer:GetAttribute("InQueue") == true then "Sair da fila" else "Entrar na fila"
	queueButton.BackgroundColor3 = if localPlayer:GetAttribute("InQueue") == true then Color3.fromRGB(160, 60, 60) else Color3.fromRGB(40, 140, 80)
	selectHint.Text = if MatchConfig.FreeRoam then "Seu Stand vem da Flecha (mochila, M). Trocar faz respawn (fora de combate)." elseif currentState == "Selecting" then "O round começa em instantes" else "Aguardando jogadores na fila"

	local currentId = localPlayer:GetAttribute("CharacterId")
	for id, b in characterButtons do
		local def = CharacterDefs.Get(id)
		local access = if def then CharacterDefs.AccessOf(def) else "coins"
		local owned = ownsCharacter(id)
		local status = b:FindFirstChild("Status") :: TextLabel
		local badge = b:FindFirstChild("Badge") :: TextLabel
		local stroke = b:FindFirstChildOfClass("UIStroke")
		local color = if def and def.Color then def.Color else CARD_SELECTED
		if access == "stand" then
			b.Visible = owned -- Stand só aparece se for o SEU (a Flecha decide; StandConfig)
		end
		if id == currentId then
			status.Text = "SELECIONADO"
			status.TextColor3 = color
			status.BackgroundTransparency = 0.75
		elseif owned then
			status.Text = "USAR"
			status.TextColor3 = CARD_ACTION
			status.BackgroundTransparency = 0.85
		elseif access == "vip" then
			status.Text = "ABRIR LOJA"
			status.TextColor3 = CARD_LOCKED
			status.BackgroundTransparency = 0.85
		elseif access == "early" then
			status.Text = "BLOQUEADO"
			status.TextColor3 = CARD_MUTED
			status.BackgroundTransparency = 0.92
		else
			status.Text = ("COMPRAR · %d"):format(if def then def.UnlockCost else 0)
			status.TextColor3 = CARD_LOCKED
			status.BackgroundTransparency = 0.85
		end
		local rarity = if access == "stand" then StandConfig.RarityOf(id) else nil
		if rarity then
			badge.Text = "STAND " .. string.upper(rarity.Name)
			badge.TextColor3 = rarity.Color
		elseif access == "human" then
			badge.Text = "HUMANO"
			badge.TextColor3 = CARD_MUTED
		elseif access == "vip" then
			badge.Text = "VIP"
			badge.TextColor3 = CARD_LOCKED
		elseif access == "early" then
			badge.Text = "ACESSO ANTECIPADO"
			badge.TextColor3 = CARD_EARLY
		elseif def and def.UnlockCost > 0 then
			badge.Text = if owned then "SEU" else ("%d PONTOS"):format(def.UnlockCost)
			badge.TextColor3 = if owned then CARD_MUTED else CARD_LOCKED
		else
			badge.Text = "GRÁTIS"
			badge.TextColor3 = CARD_MUTED
		end
		if stroke then
			stroke.Color = if id == currentId then color else Color3.new(1, 1, 1)
			stroke.Transparency = if id == currentId then 0.1 else 0.86
		end
	end
	local coins = localPlayer:GetAttribute("Coins")
	local coinsText = if typeof(coins) == "number" then ("$ %d"):format(coins) else ""
	coinsLabel.Text = coinsText
	selectCoinsLabel.Text = coinsText
	refreshScoreboard()
	HUDController.CharactersChanged:Fire()
end

--- Texto curto de um personagem para o dropdown "Personagens" do topbar + se é o atual + se aparece.
function HUDController.CharacterStatus(id: string): (string, boolean, boolean)
	local def = CharacterDefs.Get(id)
	if not def then
		return id, false, false
	end
	local access = CharacterDefs.AccessOf(def)
	local dev = localPlayer:GetAttribute("IsDeveloper") == true
	local visible = (access ~= "admin" or dev) and (access ~= "stand" or ownsCharacter(id))
	local current = localPlayer:GetAttribute("CharacterId") == id
	local suffix
	if current then
		suffix = "em uso"
	elseif ownsCharacter(id) then
		suffix = ""
	elseif access == "vip" then
		suffix = "VIP"
	elseif access == "early" then
		suffix = "em breve"
	elseif access == "drop" then
		suffix = "drop do boss"
	else
		suffix = ("%d pts"):format(def.UnlockCost)
	end
	return if suffix == "" then def.DisplayName else ("%s · %s"):format(def.DisplayName, suffix), current, visible
end

--- Clique num personagem (dropdown ou cartão): usar se tem, loja se é VIP, senão pede desbloqueio.
function HUDController.ActivateCharacter(id: string)
	local def = CharacterDefs.Get(id)
	local access = if def then CharacterDefs.AccessOf(def) else "coins"
	if ownsCharacter(id) then
		requestSelectCharacter:FireServer(id)
	elseif access == "vip" then
		HUDController.OpenShop:Fire()
	else
		requestUnlockCharacter:FireServer(id) -- pontos; "early" o servidor nega e o banner avisa
	end
end

local function updateTimer()
	local endsAt = stateData.endsAt
	if typeof(endsAt) == "number" then
		local remaining = math.max(0, endsAt - Workspace:GetServerTimeNow())
		timerLabel.Text = ("%d:%02d"):format(remaining // 60, math.floor(remaining % 60))
	else
		timerLabel.Text = ""
	end
end

local function onNotifyMatchState(state: string, data: any)
	currentState = state
	stateData = if typeof(data) == "table" then data else {}
	if state == "Ending" then
		local winners = stateData.winners
		local text = if typeof(winners) == "table" and #winners > 0 then "Vencedor: " .. table.concat(winners, ", ") else "Empate"
		showBanner(text, 6)
		if localPlayer:GetAttribute("InMatch") == true then
			local won = typeof(winners) == "table" and table.find(winners, localPlayer.Name) ~= nil
			FX.PlaySoundUI("Match", if won then "Victory" else "Defeat")
		end
	elseif state == "InProgress" and stateData.eliminated == localPlayer.Name then
		showBanner("Você foi eliminado", 3)
	elseif state == "InProgress" and stateData.mapName and not stateData.eliminated then
		showBanner("LUTEM!", 2)
		if localPlayer:GetAttribute("InMatch") == true then
			FX.PlaySoundUI("Match", "RoundStart")
		end
	end
	refreshMatchUI()
end

-- ---------------------------------------------------------------------------
-- Killfeed
-- ---------------------------------------------------------------------------

local function onNotifyKill(killer: Player?, victim: Player)
	local entry = killTemplate:Clone()
	entry.Visible = true
	entry.Text = if killer then ("%s eliminou %s"):format(killer.Name, victim.Name) else ("%s morreu"):format(victim.Name)
	entry.LayoutOrder = os.clock() * 1000 // 1
	entry.Parent = killFeed
	local entries = {}
	for _, child in killFeed:GetChildren() do
		if child:IsA("TextLabel") and child ~= killTemplate then
			table.insert(entries, child)
		end
	end
	table.sort(entries, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #entries > KILLFEED_MAX do
		local oldest = table.remove(entries, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	task.delay(KILLFEED_LIFETIME, function()
		if entry.Parent then
			entry:Destroy()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Barra de vida dos outros jogadores (Humanoid.Health replicado do servidor)
-- ---------------------------------------------------------------------------

local overheadTemplate: BillboardGui?

local function attachOverhead(player: Player, character: Model)
	if player == localPlayer or not overheadTemplate then
		return
	end
	local head = character:WaitForChild("Head", 5)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not head or not humanoid then
		return
	end
	local gui = overheadTemplate:Clone()
	gui.Adornee = head
	gui.Parent = character
	overheads[character] = gui
	local nameLabel = gui:FindFirstChild("Name") :: TextLabel
	local fill = (gui:FindFirstChild("Bar") :: Frame):FindFirstChild("Fill") :: Frame
	local function refreshName()
		local tag = player:GetAttribute("NameTag")
		nameLabel.Text = if typeof(tag) == "string" and tag ~= "" then ("[%s] %s"):format(tag, player.Name) else player.Name
	end
	refreshName()
	player:GetAttributeChangedSignal("NameTag"):Connect(refreshName)
	local function update()
		local ratio = if humanoid.MaxHealth > 0 then math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) else 0
		fill.Size = UDim2.fromScale(ratio, 1)
	end
	humanoid.HealthChanged:Connect(update)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		attachOverhead(player, character)
	end)
	player.CharacterRemoving:Connect(function(character)
		overheads[character] = nil
	end)
	if player.Character then
		attachOverhead(player, player.Character)
	end
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function HUDController.Init()
	requestSelectCharacter = Remotes.GetEvent(Remotes.Events.RequestSelectCharacter)
	requestQueue = Remotes.GetEvent(Remotes.Events.RequestQueue)
	requestUnlockCharacter = Remotes.GetEvent(Remotes.Events.RequestUnlockCharacter)

	hud = get(playerGui, "HUD") :: ScreenGui
	selectGui = get(playerGui, "CharacterSelect") :: ScreenGui

	topBar = get(hud, "TopBar") :: Frame
	stateLabel = get(topBar, "State") :: TextLabel
	timerLabel = get(topBar, "Timer") :: TextLabel
	topBar.Visible = not MatchConfig.FreeRoam -- no mapa livre não há round/timer para mostrar
	coinsLabel = get(hud, "Coins") :: TextLabel

	local vitals = get(hud, "Vitals") :: Frame
	local health = get(vitals, "Health")
	healthFill = get(health, "Fill") :: Frame
	healthText = get(health, "Text") :: TextLabel
	local energy = get(vitals, "Energy")
	energyFill = get(energy, "Fill") :: Frame
	energyText = get(energy, "Text") :: TextLabel
	counterBar = get(vitals, "Counter") :: Frame
	counterFill = get(counterBar, "Fill") :: Frame
	counterText = get(counterBar, "Text") :: TextLabel
	characterNameLabel = get(vitals, "CharacterName") :: TextLabel
	levelValue = get(get(vitals, "LevelBadge"), "Value") :: TextLabel
	-- toque: o canto inferior esquerdo é do analógico virtual → status sobe (embaixo do painel da missão)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		vitals.AnchorPoint = Vector2.new(0, 0);
		vitals.Position = UDim2.new(0, 16, 0, 196)
		coinsLabel.AnchorPoint = Vector2.new(0, 0)
		coinsLabel.Position = UDim2.new(0, 16, 0, 270)
	end
	xpFill = get(get(vitals, "XP"), "Fill") :: Frame
	xpText, reputationText = HudLayout.Apply(hud)
	local function layoutForDevice()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local scale = if touch then math.clamp(camera.ViewportSize.Y / 760, .65, .9) else math.clamp(camera.ViewportSize.X / 1440, .78, 1.1)
		local uiScale = vitals:FindFirstChild("HudScale") :: UIScale?
		if not uiScale then
			local created = Instance.new("UIScale")
			created.Name, created.Parent = "HudScale", vitals
			uiScale = created
		end
		(uiScale :: UIScale).Scale = scale
		vitals.AnchorPoint = if touch then Vector2.zero else Vector2.new(0, 1)
		vitals.Position = if touch then UDim2.fromOffset(14, 92) else UDim2.new(0, 18, 1, -20)
	end
	layoutForDevice()
	if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutForDevice) end
	local function reputation()
		local government = localPlayer:GetAttribute("Faction") == "governo"
		local points = tonumber(localPlayer:GetAttribute(if government then "Honor" else "Bounty")) or 0
		reputationText.Text = ("%s · %d"):format(if government then "HONRA" else "BOUNTY", points)
	end
	for _, attr in { "Faction", "Honor", "Bounty" } do localPlayer:GetAttributeChangedSignal(attr):Connect(reputation) end
	reputation()

	local abilities = get(hud, "Abilities")
	local dashChips = get(vitals, "DashChips")
	dashSlot = get(dashChips, "Dash") :: Frame
	dashSideSlot = get(dashChips, "DashSide") :: Frame
	ultSlot = get(abilities, "Ult") :: Frame
	for i = 1, #SLOT_KEYS do
		slots[i] = get(abilities, "Slot" .. i) :: Frame
	end
	-- rótulo de tecla/botão conforme o último dispositivo usado (teclado, gamepad; toque esconde)
	local function refreshKeyLabels()
		local device: Controls.Device = Controls.DeviceOf(UserInputService:GetLastInputType())
		local function setKey(frame: Frame, action: string)
			local label = frame:FindFirstChild("Key") :: TextLabel?
			if label then
				label.Text = if device == "touch" then "" else Controls.Label(action, device)
			end
		end
		for i, frame in slots do
			setKey(frame, "Slot" .. i)
		end
		setKey(dashSlot, "Dash")
		setKey(dashSideSlot, "Dash")
		setKey(ultSlot, "Awaken")
	end
	refreshKeyLabels()
	UserInputService.LastInputTypeChanged:Connect(refreshKeyLabels)

	killFeed = get(hud, "KillFeed") :: Frame
	killTemplate = get(killFeed, "Template") :: TextLabel
	scoreboard = get(hud, "Scoreboard") :: Frame
	scoreList = get(scoreboard, "List") :: Frame
	scoreTemplate = get(scoreList, "Template") :: TextLabel
	banner = get(hud, "Banner") :: TextLabel
	toasts = get(hud, "Toasts") :: Frame
	toastTemplate = get(toasts, "Template") :: Frame
	comboLabel = get(hud, "Combo") :: TextLabel

	local panel = get(selectGui, "Panel")
	selectList = get(panel, "List") :: Frame
	selectTemplate = get(selectList, "Template") :: TextButton
	selectHint = get(panel, "Hint") :: TextLabel
	queueButton = get(panel, "QueueButton") :: TextButton
	selectCoinsLabel = get(panel, "Coins") :: TextLabel

	local uiAssets = ReplicatedStorage:FindFirstChild("Assets")
	local uiFolder = uiAssets and uiAssets:FindFirstChild("UI")
	overheadTemplate = uiFolder and uiFolder:FindFirstChild("OverheadHealth") :: BillboardGui?
	if not overheadTemplate then
		warn("[HUDController] Assets.UI.OverheadHealth não encontrado; sem barra sobre a cabeça")
	end
end

function HUDController.Start()
	local lastCombatWarning = -math.huge
	localPlayer:GetAttributeChangedSignal("PvpCombatUntil"):Connect(function()
		local expires = localPlayer:GetAttribute("PvpCombatUntil")
		local now = Workspace:GetServerTimeNow()
		if typeof(expires) == "number" and expires > now and now - lastCombatWarning > PvpConfig.CombatSeconds then
			lastCombatWarning = now
			showBanner(("Combate PvP: sair em até %ds após o último golpe custa %d%% das moedas (máximo %d).")
				:format(PvpConfig.CombatSeconds, PvpConfig.LogoutCoinFraction * 100, PvpConfig.LogoutCoinCap), 7)
		end
	end)
	localPlayer:GetAttributeChangedSignal("SafeZone"):Connect(function()
		local zone = localPlayer:GetAttribute("SafeZone")
		showBanner(if typeof(zone) == "string" then "Zona segura · " .. zone else "Você saiu da zona segura · PvP aberto", 3)
	end)
	localPlayer:GetAttributeChangedSignal("PvpProtected"):Connect(function()
		if localPlayer:GetAttribute("PvpProtected") == true then
			showBanner(("Proteção de retorno · %ds sem dar ou receber dano PvP"):format(PvpConfig.RespawnProtection), 3)
		end
	end)
	-- anúncios da administração (global/servidor/só pra mim)
	Remotes.GetEvent(Remotes.Events.NotifyAnnouncement).OnClientEvent:Connect(function(text: string, scope: string, from: string)
		local prefix = if scope == "global" then "[GLOBAL] " elseif scope == "you" then "[Mensagem] " else ""
		showBanner(prefix .. tostring(text), 7)
		FX.PlaySoundUI("Match", "RoundStart")
	end)
	-- Botões de personagem (mods de personagem entram/saem em tempo real: ModRegistry.Changed)
	local function buildCard(id: string, i: number)
		local def = CharacterDefs.Get(id)
		local b = selectTemplate:Clone()
		-- personagem de admin: cartão só aparece para devs (atributo chega depois do boot)
		local adminOnly = def ~= nil and CharacterDefs.AccessOf(def) == "admin"
		b.Visible = not adminOnly or localPlayer:GetAttribute("IsDeveloper") == true
		if adminOnly then
			localPlayer:GetAttributeChangedSignal("IsDeveloper"):Connect(function()
				b.Visible = localPlayer:GetAttribute("IsDeveloper") == true
			end)
		end
		b.LayoutOrder = i
		local color = if def and def.Color then def.Color else CARD_SELECTED
		;(b:FindFirstChild("Name") :: TextLabel).Text = if def then def.DisplayName else id
		;(b:FindFirstChild("Tagline") :: TextLabel).Text = if def and def.Tagline then def.Tagline else ""
		;(b:FindFirstChild("Band") :: Frame).BackgroundColor3 = color
		local portraitBox = b:FindFirstChild("PortraitBox") :: Frame
		local portrait = portraitBox:FindFirstChild("Portrait") :: ImageLabel
		local initial = portraitBox:FindFirstChild("Initial") :: TextLabel
		if def and def.Image and def.Image ~= "" then
			portrait.Image = def.Image
			initial.Visible = false
		else
			initial.Text = (if def then def.DisplayName else id):sub(1, 1)
			initial.TextColor3 = color
		end
		local lines = {}
		if def then
			for slot, ability in def.Abilities do
				table.insert(lines, ("%s  %s"):format(SLOT_KEYS[slot] or "?", ability.DisplayName))
			end
			if def.Passive then
				table.insert(lines, ("R  %s"):format(def.Passive.DisplayName))
			end
			local awDef = AwakeningDefs.Get(id)
			table.insert(lines, ("G  %s"):format(awDef.UltName or "Despertar"))
		end
		local function renderAbilities()
			local xp = if profile and typeof(profile.mastery) == "table" then (tonumber(profile.mastery[id]) or 0) else 0
			local shown = table.clone(lines)
			table.insert(shown, ("Maestria %d · %d XP"):format(ProgressionConfig.MasteryLevel(xp), xp))
			;(b:FindFirstChild("Abilities") :: TextLabel).Text = table.concat(shown, "\n")
		end
		renderAbilities()
		table.insert(cardRefreshers, renderAbilities)
		b.Parent = selectList
		b.Activated:Connect(function()
			HUDController.ActivateCharacter(id)
		end)
		characterButtons[id] = b
	end
	for i, id in CharacterDefs.Order do
		buildCard(id, i)
	end
	ModRegistry.Changed.Event:Connect(function(modId: string, active: boolean)
		if active then
			for _, id in ModRegistry.CharactersOf(modId) do
				if not characterButtons[id] then
					buildCard(id, table.find(CharacterDefs.Order, id) or #CharacterDefs.Order)
				end
			end
		else
			for id, b in characterButtons do
				if not CharacterDefs.Get(id) then
					b:Destroy()
					characterButtons[id] = nil
				end
			end
		end
		HUDController.CharactersChanged:Fire()
	end)
	queueButton.Activated:Connect(function()
		requestQueue:FireServer(localPlayer:GetAttribute("InQueue") ~= true)
	end)

	-- Servidor -> HUD
	Remotes.GetEvent(Remotes.Events.NotifyHealth).OnClientEvent:Connect(function(current: number, max: number)
		setBar(healthFill, healthText, current, max)
		healthText.Text = "VIDA  " .. healthText.Text
	end)
	Remotes.GetEvent(Remotes.Events.NotifyMatchState).OnClientEvent:Connect(onNotifyMatchState)
	Remotes.GetEvent(Remotes.Events.NotifyKill).OnClientEvent:Connect(onNotifyKill)
	Remotes.GetEvent(Remotes.Events.NotifyKill).OnClientEvent:Connect(function(killer: Player?, victim: Player)
		if killer == localPlayer then
			showBanner(("Você eliminou %s"):format(victim.Name), 2)
		end
	end)
	Remotes.GetEvent(Remotes.Events.NotifyAttack).OnClientEvent:Connect(function(attackerChar: Model?, _attackId: string, comboIndex: number)
		if attackerChar ~= localPlayer.Character then
			return
		end
		comboLabel.Text = if comboIndex > 1 then ("x%d"):format(comboIndex) else ""
		comboToken += 1
		local token = comboToken
		task.delay(1.2, function()
			if comboToken == token then
				comboLabel.Text = ""
			end
		end)
	end)
	Remotes.GetEvent(Remotes.Events.NotifyProgression).OnClientEvent:Connect(function(event: string, data: any)
		data = if typeof(data) == "table" then data else {}
		-- progressão = pop-up discreto, sem som (dono, 2026-09-20)
		if event == "levelup" then
			HUDController.ShowToast(("Nível %d"):format(tonumber(data.level) or 0), ("+%d pontos"):format(tonumber(data.coins) or 0))
		elseif event == "mastery_up" then
			HUDController.ShowToast(("Maestria %d"):format(tonumber(data.level) or 0), tostring(data.characterId), Color3.fromRGB(90, 190, 255))
		elseif event == "mission_done" then
			HUDController.ShowToast("Missão concluída", ("%s · +%d pontos"):format(tostring(data.text), tonumber(data.coins) or 0))
		elseif event == "bounty" or event == "honor" then
			HUDController.ShowToast(("%s +%d"):format(if event == "honor" then "Honra" else "Bounty", tonumber(data.gain) or 0),
				("%s · %d%s"):format(tostring(data.title), tonumber(data.points) or 0,
					if (tonumber(data.coins) or 0) > 0 then (" · +%d moedas"):format(data.coins) else ""))
		elseif event == "npc_loot" then
			local extra = if data.arrow then " · +1 Flecha" else ""
			for _, drop in (if typeof(data.drops) == "table" then data.drops else {}) do
				local info = StandConfig.ItemInfo(tostring(drop.item))
				extra ..= (" · +%d %s"):format(tonumber(drop.n) or 1, if info then info.Name else tostring(drop.item))
			end
			HUDController.ShowToast(tostring(data.name), ("+%d moedas%s"):format(tonumber(data.coins) or 0, extra))
		end
	end)
	Remotes.GetEvent(Remotes.Events.NotifyProfile).OnClientEvent:Connect(function(data: any, sessionOnly: boolean)
		profile = data
		if typeof(data) == "table" and typeof(data.level) == "number" then
			levelValue.Text = "Nv. " .. tostring(data.level)
			local need = ProgressionConfig.XPForLevel(data.level)
			xpFill.Size = UDim2.fromScale(math.clamp((tonumber(data.xp) or 0) / need, 0, 1), 1)
			xpText.Text = ("%d / %d XP"):format(tonumber(data.xp) or 0, need)
		end
		if sessionOnly then
			showBanner("Sem conexão com os dados: progresso desta sessão não será salvo", 6)
		end
		refreshMatchUI()
		for _, fn in cardRefreshers do
			fn()
		end
	end)
	Remotes.GetEvent(Remotes.Events.NotifyUnlockDenied).OnClientEvent:Connect(function(characterId: string, reason: string)
		local msgs = { coins = "Pontos insuficientes", locked = "Personagem bloqueado", not_loaded = "Dados ainda carregando", already_owned = "Já desbloqueado",
			vip = "Exclusivo do passe VIP (Loja, tecla L)", early = "Acesso antecipado: ainda não liberado", drop = "Exclusivo: só cai do boss (top 3 de dano)" }
		local remaining = reason:match("^in_combat:(%d+)")
		if remaining then
			showBanner(("Em combate: fique %ss sem levar dano para trocar"):format(remaining), 2.5)
			return
		end
		showBanner(("%s: %s"):format(characterId, msgs[reason] or reason), 3)
	end)
	localPlayer:GetAttributeChangedSignal("Coins"):Connect(refreshMatchUI)
	Remotes.GetEvent(Remotes.Events.NotifyAbilityDenied).OnClientEvent:Connect(function(slot: number)
		flashSlot(slot, Color3.fromRGB(160, 40, 40))
	end)
	AbilityController.CooldownChanged.Event:Connect(function(slot: number)
		flashSlot(slot, Color3.fromRGB(60, 120, 200))
		updateCooldowns()
	end)
	MovementController.DashCooldownChanged.Event:Connect(function(kind: string)
		local frame = if kind == "side" then dashSideSlot else dashSlot
		local original = frame.BackgroundColor3
		frame.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
		task.delay(0.15, function()
			frame.BackgroundColor3 = original
		end)
		updateCooldowns()
	end)
	localPlayer:GetAttributeChangedSignal("Ragdolled"):Connect(function()
		if localPlayer:GetAttribute("Ragdolled") == true then
			showBanner("CAÍDO — Q para levantar", 1.2)
		end
		updateCooldowns()
	end)

	-- Atributos replicados do servidor
	local ENERGY_COLOR = energyFill.BackgroundColor3
	local ULT_COLOR = Color3.fromRGB(255, 200, 70)
	local ultPulse: Tween? = nil
	local wasFull = false
	local function refreshEnergy()
		local untilT = localPlayer:GetAttribute("AwakenedUntil")
		if typeof(untilT) == "number" and untilT > Workspace:GetServerTimeNow() then
			return -- no Awakening a barra é a contagem regressiva (updateCooldowns)
		end
		local e = localPlayer:GetAttribute("Energy")
		local energy = if typeof(e) == "number" then e else 0
		setBar(energyFill, energyText, energy, CharacterDefs.Energy.Max)
		energyText.Text = ("DESPERTAR  %d%%"):format(math.floor(100 * energy / CharacterDefs.Energy.Max + 0.5))
		-- Ult pronta: barra dourada pulsando + flash no slot da ult + som (uma vez por carga)
		local full = energy >= CharacterDefs.Energy.Max
		if full and not wasFull then
			energyFill.BackgroundColor3 = ULT_COLOR
			local pulse = TweenService:Create(energyFill, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.45 })
			pulse:Play()
			ultPulse = pulse
			ultSlot.BackgroundColor3 = ULT_COLOR
			task.delay(0.3, function()
				ultSlot.BackgroundColor3 = slots[1].BackgroundColor3
			end)
			-- sem som aqui (decisão do dono): os sons da ult tocam quando ATIVA (G), na cutscene
			showBanner("ULT PRONTA — G", 1.5)
		elseif not full and wasFull then
			if ultPulse then
				ultPulse:Cancel()
				ultPulse = nil
			end
			energyFill.BackgroundTransparency = 0
			energyFill.BackgroundColor3 = ENERGY_COLOR
		end
		wasFull = full
	end
	localPlayer:GetAttributeChangedSignal("Energy"):Connect(refreshEnergy)

	-- Revide (anti-2v1): barra vermelha discreta sob a da ult; some sem carga, pulsa e mostra a tecla quando cheia
	local counterPulse: Tween? = nil
	local counterWasFull = false
	local function refreshCounter()
		local cfg = CombatConfig.Counter
		local c = localPlayer:GetAttribute("CounterCharge")
		local charge = if typeof(c) == "number" then c else 0
		local full = charge >= cfg.Threshold
		counterBar.Visible = charge > 0
		TweenService:Create(counterFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(math.clamp(charge / cfg.Threshold, 0, 1), 1) }):Play()
		if full then
			local device: Controls.Device = Controls.DeviceOf(UserInputService:GetLastInputType())
			counterText.Text = if device == "touch" then "REVIDE" else ("REVIDE — %s"):format(Controls.Label("Counter", device))
		else
			counterText.Text = if charge > 0 then "em desvantagem" else ""
		end
		if full and not counterWasFull then
			local pulse = TweenService:Create(counterFill, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.5 })
			pulse:Play()
			counterPulse = pulse
		elseif not full and counterWasFull then
			if counterPulse then
				counterPulse:Cancel()
				counterPulse = nil
			end
			counterFill.BackgroundTransparency = 0
		end
		counterWasFull = full
	end
	localPlayer:GetAttributeChangedSignal("CounterCharge"):Connect(refreshCounter)
	refreshCounter()
	localPlayer:GetAttributeChangedSignal("AwakenedUntil"):Connect(function()
		local untilT = localPlayer:GetAttribute("AwakenedUntil")
		refreshSlots() -- acende/apaga o slot da ultimate
		if typeof(untilT) == "number" and untilT > Workspace:GetServerTimeNow() then
			energyFill.BackgroundColor3 = ULT_COLOR
			local characterId = localPlayer:GetAttribute("CharacterId")
			local awDef = if typeof(characterId) == "string" then AwakeningDefs.Get(characterId) else nil
			local dur = tonumber(localPlayer:GetAttribute("AwakenedDuration")) or CombatConfig.Awakening.Duration
			showBanner(("%s! %ds — 1/2/3/4 viraram os golpes despertos"):format(if awDef and awDef.UltName then awDef.UltName else "DESPERTAR", dur), 2.5)
		else
			energyFill.BackgroundColor3 = ENERGY_COLOR
			refreshEnergy()
		end
		updateCooldowns()
	end)
	localPlayer:GetAttributeChangedSignal("CharacterId"):Connect(function()
		refreshSlots()
		refreshMatchUI()
	end)
	for _, attr in { "InMatch", "InQueue", "IsDeveloper", "Pass_vip", "Pass_all_characters" } do
		localPlayer:GetAttributeChangedSignal(attr):Connect(refreshMatchUI)
	end

	-- Aviso do anti-exploit (1º calmo, 2º sério, 3º = kick)
	Remotes.GetEvent(Remotes.Events.NotifyWarning).OnClientEvent:Connect(function(kind: string, level: number, message: string)
		local color = if level >= 2 then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(255, 200, 70)
		banner.TextColor3 = color
		showBanner(tostring(message), if level >= 2 then 8 else 5)
		task.delay(if level >= 2 then 8 else 5, function()
			banner.TextColor3 = Color3.fromRGB(235, 235, 240)
		end)
		FX.Shake(0.3, 0.2)
	end)
	-- Kill streak: anúncio para todos + aura (atributo KillStreak replicado) em quem passa de AuraFrom
	local STREAK_COLOR = Color3.fromRGB(255, 220, 90)
	Remotes.GetEvent(Remotes.Events.NotifyStreak).OnClientEvent:Connect(function(event: string, who: Player, streak: number, data: any)
		local coins = if typeof(data) == "table" and typeof(data.coins) == "number" and data.coins > 0 and who == localPlayer then (" (+%d pontos)"):format(data.coins) else ""
		if event == "milestone" then
			showBanner(("%s: %d eliminações seguidas!%s"):format(if who == localPlayer then "VOCÊ" else who.Name, streak, coins), 2.5)
			FX.PlaySoundUI("Shared", "Streak")
		elseif event == "shutdown" and typeof(data) == "table" then
			showBanner(("%s encerrou a sequência de %s (%d)%s"):format(if who == localPlayer then "Você" else who.Name, tostring(data.victim), tonumber(data.ended) or 0, coins), 2.5)
		end
	end)
	local function refreshAura(p: Player)
		local character = p.Character
		if not character then
			return
		end
		local streak = p:GetAttribute("KillStreak")
		-- dono (2026-09-21): a partir de AuraFrom fica DOURADO em volta (contorno + manto) — a coroa vem do servidor
		local on = typeof(streak) == "number" and streak >= MatchConfig.KillStreak.AuraFrom
		FX.SetCosmeticAura(character, if on then STREAK_COLOR else nil, "flame", "StreakAura")
		if on then
			FX.SetOutline(character, STREAK_COLOR)
		end
	end
	-- Placar do mapa livre reage a kills e entradas/saídas
	local function watchKills(p: Player)
		p:GetAttributeChangedSignal("SessionKills"):Connect(refreshScoreboard)
		p:GetAttributeChangedSignal("KillStreak"):Connect(function()
			refreshAura(p)
		end)
		p.CharacterAdded:Connect(function()
			task.delay(0.5, refreshAura, p)
		end)
	end
	Players.PlayerAdded:Connect(function(p)
		watchKills(p)
		refreshScoreboard()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshScoreboard)
	end)
	for _, p in Players:GetPlayers() do
		watchKills(p)
	end

	-- Barras dos outros jogadores
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	-- Loop leve para timer e cooldowns
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			updateTimer()
			updateCooldowns()
		end
	end)

	refreshSlots()
	refreshEnergy()
	refreshMatchUI()
	Log.debug("[HUDController] pronto")
end

return HUDController
