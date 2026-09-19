--!strict
--[[
	DevController (cliente)
	Menu de desenvolvedor (StarterGui.DevGui, gerado por tools/gerar_devgui.py).
	Só aparece para Players com atributo IsDeveloper (AdminService, nicks em AdminConfig).
	Nenhuma decisão aqui: cada botão vira RequestAdminCommand(nomeDoBotão, args) e o
	servidor valida; o resultado volta por NotifyAdminResult(ok, msg, state) e o painel
	redesenha os toggles com o estado real do alvo.

	Abrir: ícone "Dev" no topbar (TopbarPlus) ou F8.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local Log = require(Modules:WaitForChild("Log"))
local ContentProvider = game:GetService("ContentProvider")
local PackSounds = require(Modules:WaitForChild("PackSounds"))
local VfxPreviewController = require(script.Parent:WaitForChild("VfxPreviewController"))
local TopbarController = require(script.Parent:WaitForChild("TopbarController"))
local Icon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Icon"))

local DevController = {}

local TOGGLE_KEY = Enum.KeyCode.F8
local MAX_LOG_LINES = 5
local ALL = "*"

local COLOR_OFF = Color3.fromRGB(33, 33, 43)
local COLOR_ON = Color3.fromRGB(60, 140, 90)
local COLOR_SELECTED = Color3.fromRGB(90, 165, 255)

-- Botão -> comando com o valor de qual TextBox (nil = sem args)
local NUMBER_COMMANDS: { [string]: string } = {
	SetCoins = "Coins",
	AddCoins = "Coins",
	SetEnergy = "Energy",
	SetHealth = "Health",
	SetSpeed = "Speed",
	SetDamageMult = "DamageMult",
	AddXP = "XP",
	SetTime = "Time",
	SetStreak = "Streak",
}
local SIMPLE_COMMANDS = {
	"InfiniteEnergy", "NoCooldown", "God", "ClearFlags", "ResetCooldowns", "Heal", "Respawn", "Kill", "CompleteAchievements",
	"GrantAll", "RevokeAll", "Teleport", "Bring", "Kick", "ResetData",
	"RespawnDummies", "ToggleDummies", "BringDummy", "RefreshLeaderboard", "ServerInfo", "ListPlayers", "GetState", "TestSounds",
	"Fly", "Awaken", "Ragdoll", "ClearAntiExploit", "GrantCosmetics", "ResetCosmetics", "SummonBoss", "DespawnBoss", "InspectBoss",
	"SetDay", "SetNight", "TimeAuto", "GiveArrow", "RespawnArrow", "BecomeBoss", "EndBossForm", "Trailer", "TrailerStop",
	"TeleportArena", "Spectate", "GetReports",
}
-- Botão -> comando que manda o texto da caixa "Message" (e os dias da caixa "BanDays" no Ban)
local TEXT_COMMANDS = { "AnnounceGlobal", "AnnounceServer", "Announce", "Ban", "Unban", "JoinPlayerServer", "GetReportsByName" }
local TOGGLE_BUTTONS: { [string]: string } = { InfiniteEnergy = "infiniteEnergy", NoCooldown = "noCooldown", God = "god", Fly = "fly" }

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local panel: ScrollingFrame
local targetsList: ScrollingFrame
local targetTemplate: TextButton
local charactersList: Frame
local charTemplate: TextButton
local stateLabel: TextLabel
local logLabel: TextLabel

local loggedIn = false
local selectedTarget: string? = nil -- nil = eu; "*" = todos; senão nome
local logLines: { string } = {}
local requestCommand: RemoteEvent
local devIcon: any = nil

local function get(parent: Instance, name: string): Instance
	local inst = parent:FindFirstChild(name)
	assert(inst, ("[DevController] faltando %s em %s"):format(name, parent:GetFullName()))
	return inst
end

local function appendLog(ok: boolean, message: string)
	if message == "" then
		return
	end
	table.insert(logLines, 1, (if ok then "✔ " else "✖ ") .. message)
	while #logLines > MAX_LOG_LINES do
		table.remove(logLines)
	end
	logLabel.Text = table.concat(logLines, "\n")
	logLabel.TextColor3 = if ok then Color3.fromRGB(190, 230, 190) else Color3.fromRGB(240, 170, 160)
end

local function send(command: string, args: { [string]: any }?)
	local payload: { [string]: any } = args or {}
	payload.target = selectedTarget
	requestCommand:FireServer(command, payload)
end

local function requestState()
	if selectedTarget ~= ALL then
		send("GetState")
	else
		stateLabel.Text = "alvo: TODOS os jogadores"
	end
end

-- ---------------------------------------------------------------------------
-- Estado do alvo
-- ---------------------------------------------------------------------------

local function renderState(state: { [string]: any })
	local unlocked = if typeof(state.unlocked) == "table" then table.concat(state.unlocked, ",") else "?"
	stateLabel.Text = ("%s (%d)%s · %s · pontos %d · kills %d · vida %d/%d · energia %s · speed %d · dano x%s\npersonagens: %s"):format(
		tostring(state.name), tonumber(state.userId) or 0, if state.sessionOnly then " [SEM SAVE]" else "",
		tostring(state.characterId), tonumber(state.coins) or 0, tonumber(state.kills) or 0,
		math.floor(tonumber(state.health) or 0), math.floor(tonumber(state.maxHealth) or 0),
		tostring(state.energy), math.floor(tonumber(state.speed) or 0), tostring(state.damageMult),
		unlocked
	)
	for buttonName, key in TOGGLE_BUTTONS do
		local b = panel:FindFirstChild(buttonName) :: TextButton?
		if b then
			b.BackgroundColor3 = if state[key] == true then COLOR_ON else COLOR_OFF
		end
	end
	for _, id in CharacterDefs.Order do
		local b = charactersList:FindFirstChild(id) :: TextButton?
		if b then
			local owned = typeof(state.unlocked) == "table" and table.find(state.unlocked, id) ~= nil
			local def = CharacterDefs.Get(id)
			owned = owned or (def ~= nil and def.UnlockCost <= 0)
			b.BackgroundColor3 = if state.characterId == id then COLOR_SELECTED elseif owned then COLOR_ON else COLOR_OFF
		end
	end
end

-- ---------------------------------------------------------------------------
-- Alvos / personagens
-- ---------------------------------------------------------------------------

local function refreshTargets()
	for _, child in targetsList:GetChildren() do
		if child:IsA("TextButton") and child ~= targetTemplate then
			child:Destroy()
		end
	end
	local function add(text: string, value: string?, order: number)
		local b = targetTemplate:Clone()
		b.Name = value or "me"
		b.Text = text
		b.LayoutOrder = order
		b.Visible = true
		b.BackgroundColor3 = if selectedTarget == value then COLOR_SELECTED else COLOR_OFF
		b.MouseButton1Click:Connect(function()
			selectedTarget = value
			refreshTargets()
			requestState()
		end)
		b.Parent = targetsList
	end
	add("Eu (" .. localPlayer.Name .. ")", nil, 0)
	add("TODOS", ALL, 1)
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	for i, p in list do
		if p ~= localPlayer then
			add(p.Name, p.Name, i + 1)
		end
	end
end

local function buildCharacters()
	for _, id in CharacterDefs.Order do
		local def = CharacterDefs.Get(id)
		if not def then
			continue
		end
		local b = charTemplate:Clone()
		b.Name = id
		b.Text = def.DisplayName
		b.Visible = true
		b.MouseButton1Click:Connect(function()
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
				send("GrantCharacter", { characterId = id })
			elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
				send("RevokeCharacter", { characterId = id })
			else
				send("SetCharacter", { characterId = id })
			end
		end)
		b.Parent = charactersList
	end
end

-- ---------------------------------------------------------------------------
-- Teste de sons dos packs (quais ids a Roblox deixa este jogo tocar)
-- ---------------------------------------------------------------------------

local probing = false
local function probeSounds()
	if probing then
		return
	end
	probing = true
	task.spawn(function()
		local okCount, failCount = 0, 0
		local BATCH = 50
		for start = 1, #PackSounds, BATCH do
			local sounds: { Instance } = {}
			local byInstance: { [Instance]: any } = {}
			for i = start, math.min(start + BATCH - 1, #PackSounds) do
				local entry = PackSounds[i]
				local sound = Instance.new("Sound")
				sound.SoundId = "rbxassetid://" .. tostring(entry.id)
				table.insert(sounds, sound)
				byInstance[sound] = entry
			end
			pcall(function()
				ContentProvider:PreloadAsync(sounds, function(assetId: string, status: Enum.AssetFetchStatus)
					local id = assetId:match("(%d+)")
					for sound, entry in byInstance do
						if tostring(entry.id) == id then
							local ok = status == Enum.AssetFetchStatus.Success
							if ok then
								okCount += 1
							else
								failCount += 1
							end
							warn(("[SoundProbe] %s %s %d %s <%s>"):format(if ok then "OK" else "FAIL", entry.pack, entry.id, entry.name, entry.path))
							byInstance[sound] = nil
							break
						end
					end
				end)
			end)
			for _, sound in sounds do
				sound:Destroy()
			end
			appendLog(true, ("sons: %d/%d testados (ok %d, falha %d)"):format(math.min(start + BATCH - 1, #PackSounds), #PackSounds, okCount, failCount))
			task.wait(0.1)
		end
		warn(("[SoundProbe] FIM ok=%d falha=%d"):format(okCount, failCount))
		probing = false
	end)
end

-- ---------------------------------------------------------------------------
-- Abrir
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Voo (atributo DevFly do servidor): LinearVelocity no HRP seguindo a câmera/WASD, Espaço sobe,
-- Ctrl desce. PlatformStand evita o Humanoid brigar com a velocidade.
-- ---------------------------------------------------------------------------

local FLY_SPEED = 60
local flyConn: RBXScriptConnection? = nil
local flyVelocity: LinearVelocity? = nil

local function stopFly()
	if flyConn then
		flyConn:Disconnect()
		flyConn = nil
	end
	if flyVelocity then
		local att = flyVelocity.Attachment0
		flyVelocity:Destroy()
		if att then
			att:Destroy()
		end
		flyVelocity = nil
	end
	local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
end

local function startFly()
	stopFly()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = math.huge
	lv.VectorVelocity = Vector3.zero
	lv.Parent = root
	flyVelocity = lv
	humanoid.PlatformStand = true
	local UIS = game:GetService("UserInputService")
	flyConn = game:GetService("RunService").RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera or not root.Parent then
			stopFly()
			return
		end
		local move = humanoid.MoveDirection
		local dir = Vector3.new(move.X, 0, move.Z)
		-- WASD relativo à câmera já vem no MoveDirection; sobe/desce pelas teclas
		local up = (if UIS:IsKeyDown(Enum.KeyCode.Space) then 1 else 0) - (if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then 1 else 0)
		local look = camera.CFrame.LookVector
		if dir.Magnitude > 0.1 and math.abs(look.Y) > 0.3 then
			dir = dir + Vector3.new(0, look.Y * dir.Magnitude, 0) -- olhar para cima/baixo inclina o voo
		end
		lv.VectorVelocity = (dir + Vector3.new(0, up, 0)) * FLY_SPEED
		-- boneco de pé, virado para onde a câmera olha
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Assistir jogador (atributo SpectateTargetUserId do servidor): câmera solta acompanhando
-- o HumanoidRootPart do alvo, sem controlar o personagem dele. Some ao zerar o atributo.
-- ---------------------------------------------------------------------------

local spectateConn: RBXScriptConnection? = nil
local spectateCamera: Camera? = nil

local function stopSpectate()
	if spectateConn then
		spectateConn:Disconnect()
		spectateConn = nil
	end
	local camera = workspace.CurrentCamera
	if camera and spectateCamera == camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
	end
	spectateCamera = nil
end

local function startSpectate(userId: number)
	stopSpectate()
	local target = Players:GetPlayerByUserId(userId)
	local camera = workspace.CurrentCamera
	if not target or not camera then
		return
	end
	spectateCamera = camera
	local offset = Vector3.new(0, 4, 12)
	spectateConn = game:GetService("RunService").RenderStepped:Connect(function()
		local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not camera.Parent then
			stopSpectate()
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.new(root.Position + offset, root.Position)
	end)
end

local function setOpen(open: boolean)
	if not open then
		panel.Visible = false
		if devIcon then
			devIcon:deselect()
		end
		return
	end
	if not loggedIn then
		local ok, result = pcall(function()
			return Remotes.GetFunction(Remotes.Functions.FetchAdminLogin):InvokeServer()
		end)
		loggedIn = ok and result == true
		if not loggedIn then
			appendLog(false, "servidor recusou (nick não está em AdminConfig)")
		end
	end
	panel.Visible = true
	refreshTargets()
	requestState()
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function DevController.Init()
	requestCommand = Remotes.GetEvent(Remotes.Events.RequestAdminCommand)
	local gui = playerGui:WaitForChild("DevGui", 15)
	assert(gui, "[DevController] StarterGui.DevGui não chegou (Rojo conectado?)")
	panel = get(gui, "Panel") :: ScrollingFrame
	targetsList = get(panel, "Targets") :: ScrollingFrame
	targetTemplate = get(targetsList, "Template") :: TextButton
	charactersList = get(panel, "Characters") :: Frame
	charTemplate = get(charactersList, "Template") :: TextButton
	stateLabel = get(panel, "State") :: TextLabel
	logLabel = get(panel, "Log") :: TextLabel
end

function DevController.Start()
	local function enable()
		if devIcon then
			return
		end
		devIcon = Icon.new()
			:setLabel("Dev")
			:setCaption("Menu de desenvolvedor")
			:setCaptionHint(TOGGLE_KEY)
			:bindToggleKey(TOGGLE_KEY)
			:setOrder(9) -- autoDeselect padrão: abrir outro menu fecha o Dev (e vice-versa)
		TopbarController.AddToSettings(devIcon) -- fica dentro do dropdown Config (engrenagem)
		devIcon.toggled:Connect(function(isSelected: boolean)
			setOpen(isSelected)
		end)
		Log.debug("[DevController] jogador é desenvolvedor; ícone Dev ativo")
	end
	if localPlayer:GetAttribute("IsDeveloper") == true then
		enable()
	end
	localPlayer:GetAttributeChangedSignal("IsDeveloper"):Connect(function()
		if localPlayer:GetAttribute("IsDeveloper") == true then
			enable()
		end
	end)

	;(get(panel, "Close") :: TextButton).MouseButton1Click:Connect(function()
		setOpen(false)
	end)
	;(get(panel, "PreviewVfx") :: TextButton).MouseButton1Click:Connect(function()
		VfxPreviewController.SetOpen(true)
	end)
	for command, boxName in NUMBER_COMMANDS do
		local box = get(panel, boxName) :: TextBox
		;(get(panel, command) :: TextButton).MouseButton1Click:Connect(function()
			send(command, { amount = tonumber(box.Text) })
		end)
	end
	for _, command in SIMPLE_COMMANDS do
		(get(panel, command) :: TextButton).MouseButton1Click:Connect(function()
			send(command)
		end)
	end
	local messageBox = get(panel, "Message") :: TextBox
	local banDaysBox = get(panel, "BanDays") :: TextBox
	for _, command in TEXT_COMMANDS do
		(get(panel, command) :: TextButton).MouseButton1Click:Connect(function()
			send(command, { text = messageBox.Text, amount = tonumber(banDaysBox.Text) })
		end)
	end
	buildCharacters()

	-- voo: segue o atributo replicado (o servidor liga/desliga pelo comando Fly)
	localPlayer:GetAttributeChangedSignal("DevFly"):Connect(function()
		if localPlayer:GetAttribute("DevFly") == true then
			startFly()
		else
			stopFly()
		end
	end)
	localPlayer.CharacterAdded:Connect(function()
		stopFly()
		if localPlayer:GetAttribute("DevFly") == true then
			task.delay(1, startFly)
		end
	end)

	-- assistir: idem, mas com o alvo (comando Spectate)
	localPlayer:GetAttributeChangedSignal("SpectateTargetUserId"):Connect(function()
		local userId = localPlayer:GetAttribute("SpectateTargetUserId")
		if typeof(userId) == "number" then
			startSpectate(userId)
		else
			stopSpectate()
		end
	end)

	Remotes.GetEvent(Remotes.Events.NotifyAdminResult).OnClientEvent:Connect(function(ok: boolean, message: string, state: any)
		appendLog(ok == true, tostring(message))
		if typeof(state) == "table" and state.testSounds == true then
			probeSounds()
		elseif typeof(state) == "table" and selectedTarget ~= ALL then
			renderState(state)
		end
	end)
	-- Estado muda por fora (kill, pontos ganhas...): reflete nos toggles do alvo "eu"
	for _, attr in { "Energy", "Coins", "CharacterId", "Invulnerable", "DevInfiniteEnergy", "DevNoCooldown" } do
		localPlayer:GetAttributeChangedSignal(attr):Connect(function()
			if panel.Visible and selectedTarget == nil then
				requestState()
			end
		end)
	end
	Players.PlayerAdded:Connect(function()
		if panel.Visible then
			refreshTargets()
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		if selectedTarget == p.Name then
			selectedTarget = nil
		end
		if panel.Visible then
			refreshTargets()
		end
	end)
end

return DevController
