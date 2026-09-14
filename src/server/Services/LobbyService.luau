--!strict
--[[
	LobbyService (servidor)
	Fila de espera. Todo jogador entra na fila ao conectar; pode sair/voltar com
	RequestQueue(bool). MatchService consome a fila para montar o round.
	A seleção de personagem em si é do AbilityService (RequestSelectCharacter);
	aqui só controlamos QUANDO ela é permitida (fora de round) e quem está na fila.

	Atributos no Player: InQueue (boolean), CanFight (false enquanto no lobby).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local MatchConfig = require(Modules:WaitForChild("MatchConfig"))

local LobbyService = {}

local queue: { [Player]: boolean } = {}
local queueOrder: { Player } = {}

--- Disparado quando a fila muda: (count: number)
LobbyService.QueueChanged = Instance.new("BindableEvent")

local function setInQueue(player: Player, inQueue: boolean)
	if (queue[player] == true) == inQueue then
		return
	end
	if inQueue then
		queue[player] = true
		table.insert(queueOrder, player)
	else
		queue[player] = nil
		local idx = table.find(queueOrder, player)
		if idx then
			table.remove(queueOrder, idx)
		end
	end
	player:SetAttribute("InQueue", inQueue)
	LobbyService.QueueChanged:Fire(#queueOrder)
	-- TODO(launch): reduzir log
	print(("[LobbyService] %s %s da fila (%d na fila)"):format(player.Name, inQueue and "entrou" or "saiu", #queueOrder))
end

--- Jogadores na fila, em ordem de chegada.
function LobbyService.GetQueue(): { Player }
	local result = {}
	for _, p in queueOrder do
		if p.Parent == Players then
			table.insert(result, p)
		end
	end
	return result
end

function LobbyService.GetQueueCount(): number
	return #LobbyService.GetQueue()
end

--- Remove até `max` jogadores da fila (ordem de chegada) para um round.
function LobbyService.TakeFromQueue(max: number): { Player }
	local taken = {}
	for _, p in LobbyService.GetQueue() do
		if #taken >= max then
			break
		end
		table.insert(taken, p)
	end
	for _, p in taken do
		setInQueue(p, false)
	end
	return taken
end

--- Coloca o jogador no estado "lobby": sem combate, na fila (se quiser).
function LobbyService.SendToLobby(player: Player, autoQueue: boolean?)
	player:SetAttribute("CanFight", MatchConfig.AllowLobbyCombat == true)
	player:SetAttribute("InMatch", false)
	player:SetAttribute("TeamId", nil)
	if autoQueue ~= false then
		setInQueue(player, true)
	end
end

function LobbyService.Init()
	Players.PlayerAdded:Connect(function(player)
		LobbyService.SendToLobby(player, true)
	end)
	for _, player in Players:GetPlayers() do
		LobbyService.SendToLobby(player, true)
	end
	Players.PlayerRemoving:Connect(function(player)
		setInQueue(player, false)
	end)
end

function LobbyService.Start()
	Remotes.GetEvent(Remotes.Events.RequestQueue).OnServerEvent:Connect(function(player, inQueue)
		if typeof(inQueue) ~= "boolean" then
			return
		end
		if player:GetAttribute("InMatch") == true then
			return -- não mexe na fila durante o round
		end
		setInQueue(player, inQueue)
	end)
end

return LobbyService
