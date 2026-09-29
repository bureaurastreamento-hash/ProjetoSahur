--!strict
--[[
	StandService — Stand ativo, raça e inventário (StandConfig; leva "Stands e raças", 2026-09-29).
	  - Ao carregar o perfil: sorteio de nascimento ("abençoado", uma vez) e aplica o Stand ativo (ou Humano).
	  - Flecha: chance FIXA por raridade (StandConfig.Roll). Sem Stand → vira o Stand na hora. Já tem Stand →
	    o jogador escolhe: "usar" (PERDE o atual) ou "guardar" (vira Disco de Stand no inventário).
	  - Disco de Stand / Essência de raça: usar troca o atual (o atual é perdido). Maestria de cada Stand fica salva.
	  - Recompensas de história/loot entram por StandService.Give (ou DataService.GrantCharacter para Stands).
	Nunca confia no cliente: o item precisa existir no inventário salvo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local StandConfig = require(Modules:WaitForChild("StandConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AbilityService = require(script.Parent:WaitForChild("AbilityService"))

local StandService = {}

local notifyStand: RemoteEvent
local rng = Random.new()
local useLimiter = RateLimiter.new(3, 1)
local pendingRoll: { [Player]: string } = {} -- Stand sorteado (já guardado como disco) esperando "usar"/"guardar"

local function displayName(id: string): string?
	local def = CharacterDefs.Get(id)
	return def and def.DisplayName
end

local function standPayload(standId: string): { [string]: any }
	local rarity = StandConfig.RarityOf(standId)
	return { id = standId, name = displayName(standId) or standId, rarity = rarity and rarity.Name or "?",
		color = rarity and rarity.Color or Color3.new(1, 1, 1) }
end

--- Aplica o kit do Stand ativo (ou Humano) no jogador — respawna se mudou.
local function applyPower(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local id = if profile.power ~= "" then profile.power else StandConfig.Human
	player:SetAttribute("Stand", if profile.power ~= "" then profile.power else nil)
	player:SetAttribute("Race", profile.race)
	if player:GetAttribute("CharacterId") ~= id then
		AbilityService.ForceCharacter(player, id)
	end
end

--- Troca o Stand ativo (o anterior é PERDIDO). Maestria de cada um continua em profile.mastery.
function StandService.SetStand(player: Player, standId: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile or (standId ~= "" and not StandConfig.IsStand(standId)) then return false end
	profile.power = standId
	DataService.MarkDirty(player)
	applyPower(player)
	return true
end

function StandService.SetRace(player: Player, raceId: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile or not StandConfig.GetRace(raceId) then return false end
	profile.race = raceId
	DataService.MarkDirty(player)
	player:SetAttribute("Race", raceId)
	notifyStand:FireClient(player, "race", { id = raceId, name = (StandConfig.GetRace(raceId) :: any).Name })
	return true
end

--- Dá itens (história, loot, DEV). `items` = { [itemId] = quantidade }.
function StandService.Give(player: Player, items: { [string]: number }, reason: string?)
	for itemId, amount in items do
		if DataService.AddItem(player, itemId, amount) then
			local info = StandConfig.ItemInfo(itemId, displayName)
			notifyStand:FireClient(player, "item", { id = itemId, name = info and info.Name or itemId, amount = amount, reason = reason })
		end
	end
end

-- Flecha: sorteia; sem Stand = equipa já; com Stand = espera a escolha do jogador.
local function useArrow(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile or not DataService.TakeItem(player, "flecha", 1) then return end
	local standId = StandConfig.Roll(rng)
	Log.debug(("[StandService] %s usou uma Flecha: %s"):format(player.Name, standId))
	if profile.power == "" then
		StandService.SetStand(player, standId)
		notifyStand:FireClient(player, "roll", { stand = standPayload(standId), equipped = true })
	elseif profile.power == standId then
		-- repetido: nada a escolher, vira disco na mochila (dá para trocar com alguém)
		DataService.AddItem(player, "stand:" .. standId, 1)
		notifyStand:FireClient(player, "roll", { stand = standPayload(standId), equipped = true, repeated = true })
	else
		-- já entra no inventário como disco (sair do jogo sem escolher não perde nada); "usar" consome o disco
		DataService.AddItem(player, "stand:" .. standId, 1)
		pendingRoll[player] = standId
		notifyStand:FireClient(player, "roll", { stand = standPayload(standId), equipped = false, current = standPayload(profile.power) })
	end
end

--- Usa um item da mochila (validado contra o perfil salvo). Remote RequestUseItem, DEV e testes.
function StandService.UseItem(player: Player, itemId: any)
	if typeof(itemId) ~= "string" then return end
	local profile = DataService.GetProfile(player)
	if not profile or (profile.inventory[itemId] or 0) < 1 then return end
	local info = StandConfig.ItemInfo(itemId)
	if not info then return end
	if info.Kind == "arrow" then
		useArrow(player)
	elseif info.Kind == "stand" and info.Ref then
		if profile.power == info.Ref then
			notifyStand:FireClient(player, "denied", { text = "Esse já é o seu Stand." })
			return
		end
		if DataService.TakeItem(player, itemId, 1) then
			StandService.SetStand(player, info.Ref)
			notifyStand:FireClient(player, "equip", { stand = standPayload(info.Ref) })
		end
	elseif info.Kind == "race" and info.Ref then
		if profile.race == info.Ref then
			notifyStand:FireClient(player, "denied", { text = "Essa já é a sua raça." })
			return
		end
		if DataService.TakeItem(player, itemId, 1) then
			StandService.SetRace(player, info.Ref)
		end
	end
end

--- Resposta ao sorteio quando já havia Stand: "usar" (perde o atual) | "guardar" (disco fica na mochila).
function StandService.ArrowChoice(player: Player, choice: any)
	local standId = pendingRoll[player]
	if not standId or (choice ~= "usar" and choice ~= "guardar") then return end
	pendingRoll[player] = nil
	if choice == "usar" and DataService.TakeItem(player, "stand:" .. standId, 1) then
		StandService.SetStand(player, standId)
		notifyStand:FireClient(player, "equip", { stand = standPayload(standId) })
	end -- "guardar": o disco já está no inventário
end

-- Primeiro login: quase todo mundo nasce humano comum; sorte absurda = "abençoado".
local function birth(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile or profile.born then return end
	profile.born = true
	if rng:NextNumber() < StandConfig.Blessed.Stand then
		profile.power = StandConfig.Roll(rng)
		notifyStand:FireClient(player, "roll", { stand = standPayload(profile.power), equipped = true, blessed = true })
	end
	if rng:NextNumber() < StandConfig.Blessed.Race then
		local others = {}
		for _, race in StandConfig.Races do
			if race.Access ~= "default" then table.insert(others, race.Id) end
		end
		profile.race = others[rng:NextInteger(1, #others)]
	end
	DataService.MarkDirty(player)
end

function StandService.Init()
	notifyStand = Remotes.GetEvent(Remotes.Events.NotifyStand)
end

function StandService.Start()
	Remotes.GetEvent(Remotes.Events.RequestUseItem).OnServerEvent:Connect(function(player: Player, itemId: any)
		if useLimiter:Allow(player) then StandService.UseItem(player, itemId) end
	end)
	Remotes.GetEvent(Remotes.Events.RequestArrowChoice).OnServerEvent:Connect(function(player: Player, choice: any)
		if useLimiter:Allow(player) then StandService.ArrowChoice(player, choice) end
	end)
	DataService.ProfileLoaded.Event:Connect(function(player: Player)
		birth(player)
		applyPower(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		pendingRoll[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if DataService.GetProfile(player) then
			birth(player)
			applyPower(player)
		end
	end
end

return StandService
