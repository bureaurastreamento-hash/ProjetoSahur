--!strict
--[[
	VfxPreviewController (cliente, só desenvolvedores)
	Lista todos os efeitos em ReplicatedStorage.Assets.VFX.Packs e toca no próprio
	personagem ao clicar (FX.SpawnVFXTemplate). Só visual local, nada vai ao servidor.
	Abre pelo botão "Preview VFX" do menu Dev (DevController) ou F7.
	O caminho clicado é impresso no Output ([VfxPreview] Packs/...) para colar em
	Assets.VFXPack.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local VFXLibrary = require(Modules:WaitForChild("VFXLibrary"))
local FX = require(Modules:WaitForChild("FX"))
local Log = require(Modules:WaitForChild("Log"))

local VfxPreviewController = {}

local TOGGLE_KEY = Enum.KeyCode.F7
local MAX_DEPTH = 5
local MAX_ROWS = 400

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local panel: Frame
local list: ScrollingFrame
local template: TextButton
local search: TextBox
local countLabel: TextLabel

type Entry = { path: string, inst: Instance?, weight: number, composed: string? }
local entries: { Entry } = {}
local rows: { TextButton } = {}

VfxPreviewController.LastPath = ""

local function get(parent: Instance, name: string): Instance
	local inst = parent:FindFirstChild(name)
	assert(inst, ("[VfxPreviewController] faltando %s em %s"):format(name, parent:GetFullName()))
	return inst
end

-- Mesmo critério de tools/…/listar_vfx: filhos de Folder (ou até 2 níveis) que contêm emissores/beams/meshes
local function scan()
	table.clear(entries)
	local packs = ReplicatedStorage:FindFirstChild("Assets")
	packs = packs and packs:FindFirstChild("VFX")
	packs = packs and packs:FindFirstChild("Packs")
	if not packs then
		return
	end
	local function weightOf(inst: Instance): number
		local n = 0
		if inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("MeshPart") then
			n += 1
		end
		for _, d in inst:GetDescendants() do
			if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("MeshPart") then
				n += 1
			end
		end
		return n
	end
	local function walk(inst: Instance, path: string, depth: number)
		for _, c in inst:GetChildren() do
			local isContainer = c:IsA("Folder") or c:IsA("Model") or c:IsA("BasePart") or c:IsA("Attachment")
			if not isContainer then
				continue
			end
			local p = path .. "/" .. c.Name
			local w = weightOf(c)
			if w > 0 and (inst:IsA("Folder") or depth <= 2) then
				table.insert(entries, { path = p, inst = c, weight = w })
			end
			if depth < MAX_DEPTH and (c:IsA("Folder") or c:IsA("Model")) then
				walk(c, p, depth + 1)
			end
		end
	end
	walk(packs, "Packs", 1)
	-- composições por código (VFXLibrary): aparecem primeiro, como "Lib/Pasta/Nome"
	for _, key in VFXLibrary.Keys() do
		local eff = VFXLibrary.Effects[key]
		table.insert(entries, { path = "Lib/" .. key, inst = nil, weight = #eff.layers, composed = key })
	end
	table.sort(entries, function(a, b)
		return a.path < b.path
	end)
end

local function play(entry: Entry)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	local at = if shift then root.Position + root.CFrame.LookVector * 12 else nil
	if entry.composed then
		local folder, name = entry.composed:match("^([^/]+)/(.+)$")
		if folder and name then
			FX.SpawnVFX(character, folder, name, true, at)
		end
	elseif entry.inst then
		FX.SpawnVFXTemplate(character, entry.inst, at)
	end
	VfxPreviewController.LastPath = entry.path
	warn(("[VfxPreview] %s  (%d emissores/beams/meshes)"):format(entry.path, entry.weight))
end

local function refresh()
	local filter = search.Text:lower()
	local shown = 0
	for _, row in rows do
		row:Destroy()
	end
	table.clear(rows)
	for i, entry in entries do
		if filter ~= "" and not entry.path:lower():find(filter, 1, true) then
			continue
		end
		shown += 1
		if shown > MAX_ROWS then
			break
		end
		local row = template:Clone()
		row.Name = tostring(i)
		row.Text = ("%s  [%d]"):format((entry.path:gsub("^Packs/", "")), entry.weight)
		row.LayoutOrder = shown
		row.Visible = true
		row.MouseButton1Click:Connect(function()
			play(entry)
		end)
		row.Parent = list
		table.insert(rows, row)
	end
	countLabel.Text = ("%d de %d efeitos%s"):format(math.min(shown, MAX_ROWS), #entries, if shown > MAX_ROWS then " (filtre mais)" else "")
end

function VfxPreviewController.SetOpen(open: boolean)
	panel.Visible = open
	if open then
		if #entries == 0 then
			scan()
		end
		refresh()
	end
end

function VfxPreviewController.Init()
	local gui = playerGui:WaitForChild("VfxPreviewGui", 15)
	assert(gui, "[VfxPreviewController] StarterGui.VfxPreviewGui não chegou (Rojo conectado?)")
	panel = get(gui, "Panel") :: Frame
	list = get(panel, "List") :: ScrollingFrame
	template = get(list, "Template") :: TextButton
	search = get(panel, "Search") :: TextBox
	countLabel = get(panel, "Count") :: TextLabel
end

function VfxPreviewController.Start()
	local close = get(panel, "Close") :: TextButton
	close.MouseButton1Click:Connect(function()
		VfxPreviewController.SetOpen(false)
	end)
	search:GetPropertyChangedSignal("Text"):Connect(refresh)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or input.KeyCode ~= TOGGLE_KEY then
			return
		end
		if localPlayer:GetAttribute("IsDeveloper") == true then
			VfxPreviewController.SetOpen(not panel.Visible)
		end
	end)
	Log.debug("[VfxPreviewController] pronto (F7 para devs)")
end

return VfxPreviewController
