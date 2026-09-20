--!strict
--[[
	TeamBoardService (servidor)
	Mural dos DESENVOLVEDORES na Taberna (dono, 2026-09-22): só mostra a equipe (TeamConfig = membros do
	grupo FX_Bacons) com foto (headshot), nome, cargo, função e um agradecimento especial. Igual para todo
	mundo, então a SurfaceGui é montada aqui no servidor (replica pronta). Nada de interação.
	Posição: parede LESTE da Taberna (x 381), virada para dentro (oeste), entre o pilar de z 124 e a tocha de z 104.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))
local TeamConfig = require(Modules:WaitForChild("TeamConfig"))

local TeamBoardService = {}

TeamBoardService.FolderName = "QuestBoards"
TeamBoardService.BoardCFrame = CFrame.new(380.1, 8, 114) * CFrame.Angles(0, math.rad(90), 0) -- face frontal para -x (dentro)
TeamBoardService.BoardSize = Vector3.new(16, 13, 0.4)

local COLOR_BG = Color3.fromRGB(28, 22, 18)
local COLOR_TITLE = Color3.fromRGB(255, 214, 120)
local COLOR_TEXT = Color3.fromRGB(240, 232, 220)
local COLOR_SUB = Color3.fromRGB(190, 180, 165)

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, textSize: number, color: Color3, font: Enum.Font, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = text
	l.TextSize = textSize
	l.TextColor3 = color
	l.Font = font
	l.TextWrapped = true
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end

local function build()
	local folder = Workspace:FindFirstChild(TeamBoardService.FolderName) or Instance.new("Folder")
	folder.Name = TeamBoardService.FolderName
	folder.Parent = Workspace
	local old = folder:FindFirstChild("TeamBoard")
	if old then
		old:Destroy()
	end
	local board = Instance.new("Part")
	board.Name = "TeamBoard"
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.Size = TeamBoardService.BoardSize
	board.CFrame = TeamBoardService.BoardCFrame
	board.Material = Enum.Material.Wood
	board.Color = Color3.fromRGB(40, 28, 18)
	board.Parent = folder

	local gui = Instance.new("SurfaceGui")
	gui.Name = "TeamGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.6
	gui.Parent = board
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = COLOR_BG
	bg.BorderSizePixel = 0
	bg.Parent = gui

	label(bg, ("EQUIPE %s"):format(TeamConfig.GroupName:upper()), UDim2.new(1, 0, 0, 60), UDim2.fromOffset(0, 12), 44, COLOR_TITLE, Enum.Font.GothamBlack)
	label(bg, "quem faz o Sahur acontecer", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 68), 20, COLOR_SUB, Enum.Font.Gotham)

	local members = TeamConfig.Members
	local cols = math.min(#members, 3)
	local rows = math.ceil(#members / cols)
	local cardW, cardH = 200, 140
	local totalW = cols * cardW + (cols - 1) * 12
	local x0 = (TeamBoardService.BoardSize.X * gui.PixelsPerStud - totalW) / 2
	for i, m in members do
		local c, r = (i - 1) % cols, (i - 1) // cols
		local card = Instance.new("Frame")
		card.Size = UDim2.fromOffset(cardW, cardH)
		card.Position = UDim2.fromOffset(x0 + c * (cardW + 12), 108 + r * (cardH + 10))
		card.BackgroundColor3 = Color3.fromRGB(44, 34, 28)
		card.BorderSizePixel = 0
		card.Parent = bg
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = card
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromOffset(72, 72)
		img.Position = UDim2.new(0.5, -36, 0, 8)
		img.BackgroundColor3 = Color3.fromRGB(60, 48, 40)
		img.BorderSizePixel = 0
		img.Parent = card
		local ic = Instance.new("UICorner")
		ic.CornerRadius = UDim.new(1, 0)
		ic.Parent = img
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(m.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if ok and url then
				img.Image = url
			end
		end)
		label(card, m.DisplayName, UDim2.new(1, -8, 0, 24), UDim2.fromOffset(4, 84), 20, COLOR_TEXT, Enum.Font.GothamBold)
		label(card, ("%s · %s"):format(m.Role, m.Function), UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 108), 14, COLOR_SUB, Enum.Font.Gotham)
		if m.Quote ~= "" then
			label(card, ("“%s”"):format(m.Quote), UDim2.new(1, -8, 0, 20), UDim2.fromOffset(4, 126), 13, COLOR_SUB, Enum.Font.GothamMedium)
		end
	end
	local yThanks = 108 + rows * (cardH + 10) + 6
	label(bg, "AGRADECIMENTO ESPECIAL", UDim2.new(1, 0, 0, 26), UDim2.fromOffset(0, yThanks), 20, COLOR_TITLE, Enum.Font.GothamBlack)
	label(bg, TeamConfig.Thanks, UDim2.new(1, -60, 0, 44), UDim2.fromOffset(30, yThanks + 26), 17, COLOR_TEXT, Enum.Font.Gotham)
	Log.debug(("[TeamBoardService] mural com %d membros"):format(#members))
end

function TeamBoardService.Start()
	task.spawn(build)
end

return TeamBoardService
