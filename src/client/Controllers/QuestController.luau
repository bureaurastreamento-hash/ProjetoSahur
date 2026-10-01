--!strict
--[[
	QuestController (cliente)
	História em capítulos (QuestService): só reflete NotifyQuest.
	  - "state": capítulo atual/objetivos → chip discreto no HUD (canto) + mural das quests na Taberna
	    (SurfaceGui no PlayerGui com Adornee = Workspace.QuestBoards.QuestBoard, conteúdo por jogador) +
	    marcador "!" só no NPC do capítulo atual (os outros ficam sem).
	  - "dialog": caixa de diálogo do NPC (foto + nome + texto), fecha com clique/E/tempo.
	  - "progress": toast discreto (HUDController.ShowToast) quando um objetivo fecha.
	UI montada em código (sem model.json): é pequena e toda dinâmica.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local QuestConfig = require(Modules:WaitForChild("QuestConfig"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))

local QuestController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local COLOR_BG = Color3.fromRGB(20, 20, 26)
local COLOR_TITLE = Color3.fromRGB(255, 214, 120)
local COLOR_TEXT = Color3.fromRGB(235, 235, 240)
local COLOR_SUB = Color3.fromRGB(170, 170, 180)
local COLOR_OK = Color3.fromRGB(120, 220, 140)

local gui: ScreenGui
local chip: Frame
local chipTitle: TextLabel
local chipLines: TextLabel
local dialogFrame: Frame
local dialogName: TextLabel
local dialogText: TextLabel
local dialogSub: TextLabel
local dialogImage: ImageLabel
local dialogToken = 0
local boardGui: SurfaceGui? = nil
local boardText: TextLabel? = nil
local lastState: { [string]: any }? = nil

local function mk(class: string, props: { [string]: any }, parent: Instance?): Instance
	local inst = Instance.new(class)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function buildGui()
	gui = mk("ScreenGui", { Name = "QuestGui", ResetOnSpawn = false, DisplayOrder = 6, IgnoreGuiInset = true }, playerGui) :: ScreenGui
	-- chip do capítulo (canto direito, abaixo do topbar; discreto)
	chip = mk("Frame", { Name = "Chip", Size = UDim2.fromOffset(300, 20), Position = UDim2.fromOffset(18,58), BackgroundColor3 = COLOR_BG, BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false }, gui) :: Frame
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, chip)
	chipTitle = mk("TextLabel", { Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = COLOR_TITLE, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "" }, chip) :: TextLabel
	chipLines = mk("TextLabel", { Visible=false, Size = UDim2.new(1, -16, 1, -30), Position = UDim2.fromOffset(8, 26), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COLOR_TEXT, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = "" }, chip) :: TextLabel
	-- diálogo (embaixo, centro)
	dialogFrame = mk("Frame", { Name = "Dialog", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -24, 0, 190), Position = UDim2.new(0.5, 0, 1, -90), BackgroundColor3 = COLOR_BG, BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false }, gui) :: Frame
	mk("UISizeConstraint", { MaxSize = Vector2.new(620, 190) }, dialogFrame)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, dialogFrame)
	mk("UIStroke", { Color = COLOR_TITLE, Thickness = 1.5, Transparency = 0.5 }, dialogFrame)
	dialogImage = mk("ImageLabel", { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(12, 16), BackgroundColor3 = Color3.fromRGB(40, 40, 50), BorderSizePixel = 0 }, dialogFrame) :: ImageLabel
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, dialogImage)
	dialogName = mk("TextLabel", { Size = UDim2.new(1, -144, 0, 24), Position = UDim2.fromOffset(88, 12), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = COLOR_TITLE, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, dialogFrame) :: TextLabel
	local textScroll = mk("ScrollingFrame", { Name = "TextScroll", Size = UDim2.new(1, -104, 1, -82), Position = UDim2.fromOffset(88, 42), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, dialogFrame)
	dialogText = mk("TextLabel", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 15, TextColor3 = COLOR_TEXT, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = "" }, textScroll) :: TextLabel
	dialogSub = mk("TextLabel", { Size = UDim2.new(1, -24, 0, 24), Position = UDim2.new(0, 12, 1, -32), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = COLOR_SUB, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "" }, dialogFrame) :: TextLabel
	local close = mk("TextButton", { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -44, 0, 4), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = COLOR_SUB, Text = "X" }, dialogFrame) :: TextButton
	close.Activated:Connect(function()
		dialogFrame.Visible = false
	end)
end

-- ---------------------------------------------------------------------------
-- Estado / chip / mural / marcadores
-- ---------------------------------------------------------------------------

local function objectiveLines(state: { [string]: any }, long: boolean): string
	local lines = {}
	for _, obj in state.objectives or {} do
		local done = obj.progress >= obj.goal
		local desc = tostring(obj.desc):format(obj.goal)
		table.insert(lines, ("%s %s (%d/%d)"):format(if done then "✔" else "•", desc, obj.progress, obj.goal))
	end
	if #lines == 0 then
		return if long then "Sem objetivos." else ""
	end
	return table.concat(lines, "\n")
end

local function renderChip(state: { [string]: any })
	if state.finished then
		chip.Visible = false
		return
	end
	chip.Visible = true
	if state.locked then
		chipTitle.Text = ("Cap. %d — %s"):format(state.chapter, state.title)
		chipLines.Text = "Em breve..."
		return
	end
	chipTitle.Text = ("Cap. %d — %s"):format(state.chapter, state.title)
	if not state.active then
		chipLines.Text = ("Fale com %s (%s)"):format(state.npc, state.where)
		chipLines.TextColor3 = COLOR_SUB
	elseif state.complete then
		chipLines.Text = ("Objetivos completos! Volte em %s (%s)"):format(state.npc, state.where)
		chipLines.TextColor3 = COLOR_OK
	else
		chipLines.Text = objectiveLines(state, false)
		chipLines.TextColor3 = COLOR_TEXT
	end
end

local function ensureBoard()
	if boardGui and boardGui.Parent then
		return
	end
	local folder = Workspace:FindFirstChild("QuestBoards")
	local board = folder and folder:FindFirstChild("QuestBoard")
	if not board then
		return
	end
	boardGui = mk("SurfaceGui", { Name = "QuestBoardGui", Adornee = board, Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50, LightInfluence = 0.6, ResetOnSpawn = false }, playerGui) :: SurfaceGui
	local bg = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(28, 22, 18), BorderSizePixel = 0 }, boardGui)
	mk("TextLabel", { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 10), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 40, TextColor3 = COLOR_TITLE, Text = "A HISTÓRIA DO SAHUR" }, bg)
	boardText = mk("TextLabel", { Size = UDim2.new(1, -60, 1, -80), Position = UDim2.fromOffset(30, 70), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 19, TextColor3 = COLOR_TEXT, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, RichText = true, Text = "" }, bg) :: TextLabel
end

local function renderBoard(state: { [string]: any })
	ensureBoard()
	if not boardText then
		return
	end
	local lines = {}
	for i, ch in QuestConfig.Chapters do
		local spot = QuestConfig.Spots[ch.Spot]
		local status
		if state.done and state.done[ch.Id] then
			status = '<font color="#78DC8C">✔ concluído</font>'
		elseif i == state.chapter then
			status = if state.active then '<font color="#FFD678">▶ em andamento</font>' else '<font color="#FFD678">▶ fale com o NPC</font>'
		elseif ch.Locked then
			status = '<font color="#9A9AA6">🔒 em breve</font>'
		else
			status = '<font color="#9A9AA6">trancado</font>'
		end
		table.insert(lines, ("<b>Cap. %d — %s</b>   %s\n   NPC: %s · %s"):format(i, ch.Title, status, state.chapter == i and state.npc or (ch.NpcUserId and "DEV" or "???"), if spot then spot.Label else ""))
		if i == state.chapter and state.active then
			table.insert(lines, "   " .. objectiveLines(state, true):gsub("\n", "\n   "))
		end
	end
	boardText.Text = table.concat(lines, "\n")
end

local function renderMarkers(state: { [string]: any })
	local folder = Workspace:FindFirstChild("QuestNpcs")
	if not folder then
		return
	end
	local current = QuestConfig.Chapters[state.chapter]
	local wantedId = if current and not current.Locked then current.NpcUserId else nil
	for _, npc in folder:GetChildren() do
		local marker = npc:FindFirstChild("QuestMarker") :: BillboardGui?
		if marker then
			local mine = npc:GetAttribute("QuestNpc") == wantedId
			marker.Enabled = mine
			local label = marker:FindFirstChildOfClass("TextLabel")
			if label then
				label.Text = if state.complete then "?" else "!"
				label.TextColor3 = if state.complete then COLOR_OK else COLOR_TITLE
			end
		end
	end
end

local function onState(state: { [string]: any })
	lastState = state
	renderChip(state)
	renderBoard(state)
	renderMarkers(state)
end

-- ---------------------------------------------------------------------------
-- Diálogo
-- ---------------------------------------------------------------------------

local function showDialog(data: { [string]: any })
	dialogToken += 1
	local token = dialogToken
	dialogName.Text = tostring(data.npc or "Habitante")
	dialogText.Text = tostring(data.text)
	;(dialogFrame:FindFirstChild("TextScroll") :: ScrollingFrame).CanvasPosition = Vector2.zero
	local sub = ""
	if data.kind == "accept" then
		sub = ("Capítulo aceito: %s"):format(tostring(data.title))
	elseif data.kind == "done" then
		sub = ("Recompensa: %s%s"):format(tostring(data.reward), if data.next then "   ·   " .. tostring(data.next) else "")
		HUDController.ShowToast("Capítulo concluído", tostring(data.title), COLOR_OK)
	elseif data.kind == "progress" then
		sub = "Campanha F/X · confira seus objetivos na tela."
	end
	dialogSub.Text = sub
	dialogImage.Image = ""
	local userId = tonumber(data.userId)
	if userId then
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if ok and url and dialogToken == token then
				dialogImage.Image = url
			end
		end)
	end
	dialogFrame.Visible = true
	task.delay(math.clamp(#dialogText.Text / 14, if data.kind == "done" then 12 else 8, 35), function()
		if dialogToken == token then
			dialogFrame.Visible = false
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function QuestController.Init()
	buildGui()
end

function QuestController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyQuest).OnClientEvent:Connect(function(event: string, data: any)
		data = if typeof(data) == "table" then data else {}
		if event == "state" then
			if QuestConfig.Enabled then onState(data) end
		elseif event == "dialog" then
			showDialog(data)
		elseif event == "toast" then
			HUDController.ShowToast(tostring(data.title), tostring(data.text), COLOR_TITLE)
		elseif event == "progress" then
			if data.complete then
				HUDController.ShowToast("Objetivos completos", ("Volte em %s (%s)"):format(tostring(data.npc), tostring(data.where)), COLOR_OK)
			else
				HUDController.ShowToast("Quest", tostring(data.text), COLOR_TITLE)
			end
		end
	end)
	-- NPCs/mural chegam depois do state às vezes: reaplica quando a pasta aparecer
	Workspace.ChildAdded:Connect(function(child)
		if (child.Name == "QuestNpcs" or child.Name == "QuestBoards") and lastState then
			task.delay(1, function()
				if lastState then
					onState(lastState)
				end
			end)
		end
	end)
	local npcFolder = Workspace:FindFirstChild("QuestNpcs")
	if npcFolder then
		npcFolder.ChildAdded:Connect(function()
			if lastState then
				task.delay(0.5, function()
					if lastState then
						renderMarkers(lastState)
					end
				end)
			end
		end)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and dialogFrame.Visible and input.KeyCode == Enum.KeyCode.E then
			-- E de novo perto do NPC reabre pelo prompt; aqui só fecha
			dialogFrame.Visible = false
		end
	end)
end

return QuestController
