--!strict
--[[
	BossLootService (servidor)
	Loot do boss por posição no ranking de dano (BossConfig.Loot). Usado pelo BossService (boss NPC) e
	pelo BossFormService (jogador-boss): `Distribute(damageBy, exclude)` paga pontos e sorteia os drops,
	devolvendo a lista de recompensas ordenada (para o NotifyBoss "defeated") e o top de dano.
	  1º–3º: Loot.Top  (chance de super raro: personagem exclusivo, aura/capa/cena do boss, pontos de evento)
	  4º–5º: Loot.Good (pontos de evento, giro grátis, bolada de pontos)
	  6º+:   Loot.Basic (só pontos)
	Item que o jogador já tem sai da mesa; sem nada para dar, cai no Fallback (pontos).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))
local BossConfig = require(Modules:WaitForChild("BossConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local CosmeticsConfig = require(Modules:WaitForChild("CosmeticsConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local CosmeticsService = require(script.Parent:WaitForChild("CosmeticsService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))

local BossLootService = {}

export type Reward = { name: string, coins: number, damage: number, rank: number, drop: string? }

local rng = Random.new()

local function canReceive(player: Player, e: BossConfig.LootEntry): boolean
	if e.kind == "character" then
		local id = e.id or ""
		return CharacterDefs.Get(id) ~= nil and not DataService.HasCharacter(player, id)
	elseif e.kind == "cosmetic" or e.kind == "emote" then
		return not CosmeticsService.Owns(player, e.id or "")
	end
	return true
end

--- Sorteia uma entrada da mesa entre as que o jogador ainda pode receber. nil = nada sobrou.
local function pick(player: Player, list: { BossConfig.LootEntry }): BossConfig.LootEntry?
	local pool: { BossConfig.LootEntry } = {}
	local total = 0
	for _, e in list do
		if canReceive(player, e) then
			table.insert(pool, e)
			total += e.weight
		end
	end
	if #pool == 0 then
		return nil
	end
	local r = rng:NextNumber() * total
	for _, e in pool do
		r -= e.weight
		if r <= 0 then
			return e
		end
	end
	return pool[#pool]
end

--- Entrega a entrada; devolve o texto do drop para a tela (nil = nada).
local function give(player: Player, e: BossConfig.LootEntry): string?
	if e.kind == "character" then
		if DataService.GrantCharacter(player, e.id :: string) then
			local def = CharacterDefs.Get(e.id :: string)
			return ("PERSONAGEM %s"):format(if def then def.DisplayName else e.id :: string)
		end
	elseif e.kind == "cosmetic" or e.kind == "emote" then
		if CosmeticsService.Grant(player, e.id :: string, "boss") then
			local item = CosmeticsConfig.GetItem(e.id :: string)
			local emote = CosmeticsConfig.GetEmote(e.id :: string)
			return if item then item.Name elseif emote then emote.Name else e.id :: string
		end
	elseif e.kind == "eventpoints" then
		DataService.AddEventPoints(player, e.amount or 0)
		return ("%d pontos de evento"):format(e.amount or 0)
	elseif e.kind == "roll" then
		local name = CosmeticsService.FreeRoll(player, "boss")
		return if name then ("roleta: %s"):format(name) else nil
	elseif e.kind == "coins" then
		local got = DataService.RewardCoins(player, e.amount or 0)
		return ("+%d pontos extras"):format(got)
	end
	return nil
end

local function rewardFor(player: Player, rank: number, scale: number): (number, string?)
	local loot = BossConfig.Loot
	local tier, idx
	if rank <= #loot.Top.Coins then
		tier, idx = loot.Top, rank
	elseif rank <= #loot.Top.Coins + #loot.Good.Coins then
		tier, idx = loot.Good, rank - #loot.Top.Coins
	else
		return DataService.RewardCoins(player, loot.Basic.Coins * scale), nil
	end
	local coins = DataService.RewardCoins(player, tier.Coins[idx] * scale)
	-- boss forte (flecha): chance de item também sobe (x2 por dobro de força, teto 90%)
	local chance = math.min(0.9, tier.Chance[idx] * (1 + (scale - 1) * 0.5))
	if rng:NextNumber() >= chance then
		return coins, nil
	end
	local e = pick(player, tier.Table)
	if not e then
		local extra = DataService.RewardCoins(player, tier.Fallback * scale)
		return coins + extra, ("+%d pontos (já tem tudo)"):format(extra)
	end
	local text = give(player, e)
	if not text then
		local extra = DataService.RewardCoins(player, tier.Fallback * scale)
		return coins + extra, nil
	end
	return coins, text
end

--- Paga todo mundo que bateu (menos `exclude`, o jogador-boss). Retorna (lista ordenada, top).
function BossLootService.Distribute(damageBy: { [Player]: number }, exclude: Player?, scale: number?): ({ Reward }, Player?)
	local rewardScale = scale or 1
	local total = 0
	local ranked: { { player: Player, dmg: number } } = {}
	for player, dmg in damageBy do
		if player ~= exclude and player.Parent == Players and dmg > 0 then
			total += dmg
			table.insert(ranked, { player = player, dmg = dmg })
		end
	end
	table.sort(ranked, function(a, b)
		return a.dmg > b.dmg
	end)
	local rewards: { Reward } = {}
	local top: Player? = if ranked[1] then ranked[1].player else nil
	for rank, entry in ranked do
		local coins, drop = rewardFor(entry.player, rank, rewardScale)
		ProgressionService.OnBossDefeated(entry.player, entry.dmg, entry.dmg / total, rank == 1)
		table.insert(rewards, { name = entry.player.Name, coins = coins, damage = math.floor(entry.dmg), rank = rank, drop = drop })
		if drop then
			Log.debug(("[BossLootService] %s (%dº) ganhou %s"):format(entry.player.Name, rank, drop))
		end
	end
	return rewards, top
end

return BossLootService
