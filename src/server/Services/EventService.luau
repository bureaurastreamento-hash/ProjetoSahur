--!strict
--[[
	EventService (servidor)
	Área de EVENTO = modelo `ServerStorage.EventMaps.canion` (dono, 2026-09-19: mapa grande para boss grande + mini
	eventos interativos). Por enquanto: levar todo mundo para lá e trazer de volta (comandos DEV
	StartEvent/EndEvent → Begin/Finish); os mini eventos entram depois em cima disto.

	Spawns do evento: BaseParts chamadas `EventSpawn*` em qualquer lugar dentro do modelo (pasta EventSpawns,
	8 parts verdes criadas via MCP; o dono move). Sem nenhuma, usa o centro do modelo com raycast até o chão.
	Os spawns ficam invisíveis no jogo (Transparency 1 ao clonar).
	Workspace.EventActive (atributo) = true enquanto o evento está rolando (HUD/outros serviços leem).
	Quem entra no servidor durante o evento vai para lá também; quem morre renasce no evento.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))

local EventService = {}

EventService.MapName = "canion"
EventService.SpawnPrefix = "EventSpawn"

local active = false

-- O canion NÃO fica no mapa (dono, 2026-09-19): mora em ServerStorage.EventMaps e é clonado para o
-- Workspace só durante o evento (na mesma posição em que a arte deixou), sumindo ao encerrar.
local STORE_FOLDER = "EventMaps"
local live: Model? = nil

local function template(): Model?
	local store = ServerStorage:FindFirstChild(STORE_FOLDER)
	local m = store and store:FindFirstChild(EventService.MapName)
	if m and m:IsA("Model") then
		return m
	end
	-- alguém deixou no Workspace (edição antiga): usa dali mesmo
	local w = Workspace:FindFirstChild(EventService.MapName, true)
	return if w and w:IsA("Model") then w else nil
end

local function eventModel(): Model?
	return live or template()
end

--- Pontos de spawn do evento (CFrames com 3 studs de folga do chão).
function EventService.GetSpawnCFrames(): { CFrame }
	local model = eventModel()
	if not model then
		return {}
	end
	local out: { CFrame } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name:sub(1, #EventService.SpawnPrefix) == EventService.SpawnPrefix then
			table.insert(out, d.CFrame + Vector3.new(0, d.Size.Y / 2 + 3, 0))
		end
	end
	if #out == 0 then
		local cf, size = model:GetBoundingBox()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { model }
		local hit = Workspace:Raycast(cf.Position + Vector3.new(0, size.Y / 2 + 10, 0), Vector3.new(0, -(size.Y + 40), 0), params)
		local y = if hit then hit.Position.Y + 3 else cf.Position.Y
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			table.insert(out, CFrame.new(cf.Position.X + math.cos(a) * 12, y, cf.Position.Z + math.sin(a) * 12))
		end
	end
	return out
end

local function moveTo(player: Player, cf: CFrame)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	AntiExploitService.Grace(player, 3)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = cf
end

local function sendToEvent(player: Player)
	local spawns = EventService.GetSpawnCFrames()
	if #spawns == 0 then
		return
	end
	moveTo(player, spawns[math.random(1, #spawns)])
end

local function sendToArena(player: Player)
	moveTo(player, CharacterService.PickSpawn(player) * CFrame.new(0, 3.05, 0))
end

function EventService.IsActive(): boolean
	return active
end

--- Leva todo mundo para o evento. Retorna ok, mensagem. (Não é o Start() do boot.)
function EventService.Begin(): (boolean, string)
	local tpl = template()
	if not tpl then
		return false, ("modelo '%s' não está em ServerStorage.%s"):format(EventService.MapName, STORE_FOLDER)
	end
	if not live then
		if tpl.Parent == Workspace then
			live = tpl
		else
			local clone = tpl:Clone()
			for _, d in clone:GetDescendants() do
				if d:IsA("BasePart") and d.Name:sub(1, #EventService.SpawnPrefix) == EventService.SpawnPrefix then
					d.Transparency = 1
				end
			end
			clone.Parent = Workspace
			live = clone
		end
	end
	active = true
	Workspace:SetAttribute("EventActive", true)
	local n = 0
	for _, p in Players:GetPlayers() do
		sendToEvent(p)
		n += 1
	end
	Log.debug(("[EventService] evento começou: %d jogador(es) no %s"):format(n, EventService.MapName))
	return true, ("evento no %s: %d jogador(es) levados (spawns: %d)"):format(EventService.MapName, n, #EventService.GetSpawnCFrames())
end

--- Encerra e devolve todo mundo para a arena.
function EventService.Finish(): (boolean, string)
	if not active then
		return false, "nenhum evento rolando"
	end
	active = false
	Workspace:SetAttribute("EventActive", nil)
	for _, p in Players:GetPlayers() do
		sendToArena(p)
	end
	if live and live.Parent == Workspace and ServerStorage:FindFirstChild(STORE_FOLDER) then
		live:Destroy() -- era clone; o original continua em ServerStorage
	end
	live = nil
	Log.debug("[EventService] evento encerrado")
	return true, "evento encerrado: todos de volta à arena"
end

function EventService.Init()
	Workspace:SetAttribute("EventActive", nil)
end

function EventService.Start()
	-- durante o evento, quem entra/renasce vai para lá (depois do CharacterService posicionar)
	local function onCharacter(player: Player)
		if active then
			task.delay(0.5, function()
				if active and player.Character then
					sendToEvent(player)
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
	end
end

return EventService
