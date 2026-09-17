--!strict
--[[
	AchievementService (servidor)
	CONQUISTAS no lugar das missões diárias (dono, 2026-09-17). Guarda contadores que só sobem no
	perfil (`profile.achievements`) e paga UMA vez cada conquista de AchievementsConfig:
	pontos, XP, cosmético, emote ou personagem.

	Dois conjuntos de contadores:
	  - permanentes  (`counters`)         -> conquistas sem `Season`
	  - do passe     (`season.counters`)  -> conquistas da temporada no ar; zeram quando o passe muda
	Itens LIMITADOS (CosmeticsConfig com `Limited`) só saem por conquista da temporada; depois que o
	passe acaba ninguém mais ganha — só um DEV entregando (AdminService).

	Quem alimenta: ProgressionService (kill/duelo/boss/tempo/nível/maestria) chamando Progress/SetCounter.
	Cliente: FetchAchievements (lista) e NotifyAchievement ("done" na hora que conclui).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local DataConfig = require(Modules:WaitForChild("DataConfig"))
local AchievementsConfig = require(Modules:WaitForChild("AchievementsConfig"))
local CosmeticsConfig = require(Modules:WaitForChild("CosmeticsConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local CosmeticsService = require(script.Parent:WaitForChild("CosmeticsService"))

local AchievementService = {}

local notifyAchievement: RemoteEvent
-- ProgressionService.AddXP: setado no Init pelo próprio ProgressionService (evita require circular)
AchievementService.AddXP = function(_player: Player, _amount: number, _reason: string) end

local function notify(player: Player, event: string, data: { [string]: any })
	if player.Parent == Players then
		notifyAchievement:FireClient(player, event, data)
	end
end

--- Garante que o bloco do passe é o da temporada NO AR (passe novo = contadores do passe zerados).
local function ensureSeason(profile: DataConfig.Profile): boolean
	local season = AchievementsConfig.ActiveSeason()
	local id = if season then season.Id else ""
	if profile.achievements.season.id ~= id then
		profile.achievements.season = { id = id, counters = {} }
		return true
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Recompensas
-- ---------------------------------------------------------------------------

--- Paga a recompensa da conquista. Devolve o texto do que foi entregue (para o aviso na tela).
local function payReward(player: Player, ach: AchievementsConfig.Achievement): string
	local parts: { string } = {}
	local reward = ach.Reward
	if reward.Coins and reward.Coins > 0 then
		local coins = DataService.RewardCoins(player, reward.Coins)
		table.insert(parts, ("%d pontos"):format(coins))
	end
	if reward.XP and reward.XP > 0 then
		AchievementService.AddXP(player, reward.XP, "achievement")
		table.insert(parts, ("%d XP"):format(reward.XP))
	end
	if reward.Cosmetic then
		local item = CosmeticsConfig.GetItem(reward.Cosmetic)
		if item and CosmeticsService.Grant(player, reward.Cosmetic, "achievement:" .. ach.Id) then
			table.insert(parts, item.Name)
		end
	end
	if reward.Emote then
		local emote = CosmeticsConfig.GetEmote(reward.Emote)
		if emote and CosmeticsService.Grant(player, reward.Emote, "achievement:" .. ach.Id) then
			table.insert(parts, emote.Name)
		end
	end
	if reward.Character then
		local def = CharacterDefs.Get(reward.Character)
		if def and DataService.GrantCharacter(player, reward.Character) then
			table.insert(parts, def.DisplayName)
		end
	end
	return table.concat(parts, " + ")
end

-- ---------------------------------------------------------------------------
-- Avaliação
-- ---------------------------------------------------------------------------

local function counterFor(profile: DataConfig.Profile, ach: AchievementsConfig.Achievement): number
	if ach.Season then
		return profile.achievements.season.counters[ach.Kind] or 0
	end
	return profile.achievements.counters[ach.Kind] or 0
end

--- Quantas conquistas de um grupo já foram concluídas (alimenta "zerou" e "passe completo").
local function countDone(profile: DataConfig.Profile, seasonId: string?): number
	local n = 0
	for _, a in AchievementsConfig.List do
		if a.Id ~= "zerou" and a.Kind ~= "achievements" and a.Kind ~= "season_achievements" then
			if (seasonId == nil and a.Season == nil) or (seasonId ~= nil and a.Season == seasonId) then
				if profile.achievements.done[a.Id] then
					n += 1
				end
			end
		end
	end
	return n
end

--- Confere TODAS as conquistas ativas e paga as que fecharam. Devolve true se mexeu no perfil.
local function evaluate(player: Player, profile: DataConfig.Profile): boolean
	local changed = false
	local season = AchievementsConfig.ActiveSeason()
	-- contadores derivados (conquistas que contam outras conquistas)
	profile.achievements.counters.achievements = countDone(profile, nil)
	if season then
		profile.achievements.season.counters.season_achievements = countDone(profile, season.Id)
	end
	for _, ach in AchievementsConfig.Active() do
		if not profile.achievements.done[ach.Id] and counterFor(profile, ach) >= ach.Goal then
			profile.achievements.done[ach.Id] = true
			changed = true
			local what = payReward(player, ach)
			Log.debug(("[AchievementService] %s concluiu '%s' (%s)"):format(player.Name, ach.Name, what))
			notify(player, "done", { id = ach.Id, name = ach.Name, reward = what, season = ach.Season })
		end
	end
	return changed
end

-- ---------------------------------------------------------------------------
-- API para os outros services
-- ---------------------------------------------------------------------------

--- Soma `amount` no contador `kind` (permanente e o do passe) e confere as conquistas.
function AchievementService.Progress(player: Player, kind: string, amount: number)
	local profile = DataService.GetProfile(player)
	if not profile or amount <= 0 then
		return
	end
	local changed = ensureSeason(profile)
	local counters = profile.achievements.counters
	counters[kind] = (counters[kind] or 0) + amount
	if profile.achievements.season.id ~= "" then
		local sc = profile.achievements.season.counters
		sc[kind] = (sc[kind] or 0) + amount
	end
	changed = evaluate(player, profile) or changed
	DataService.MarkDirty(player)
	if changed then
		-- nada a mais: o perfil já foi marcado
	end
end

--- Contadores que não somam, valem o MAIOR já alcançado (nível, maestria, coleção).
function AchievementService.SetCounter(player: Player, kind: string, value: number)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	ensureSeason(profile)
	local counters = profile.achievements.counters
	if (counters[kind] or 0) >= value then
		return
	end
	counters[kind] = value
	if profile.achievements.season.id ~= "" then
		local sc = profile.achievements.season.counters
		if (sc[kind] or 0) < value then
			sc[kind] = value
		end
	end
	evaluate(player, profile)
	DataService.MarkDirty(player)
end

--- Reconta o que dá para saber sozinho (coleção de cosméticos) e confere tudo. Chamado no login e
--- depois de ganhar cosmético.
function AchievementService.Refresh(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	ensureSeason(profile)
	local owned = #profile.cosmetics.owned + #profile.emotes
	if (profile.achievements.counters.cosmetics or 0) < owned then
		profile.achievements.counters.cosmetics = owned
	end
	if (profile.achievements.counters.level or 0) < profile.level then
		profile.achievements.counters.level = profile.level
	end
	if evaluate(player, profile) then
		DataService.MarkDirty(player)
	end
end

--- Lista para a tela de Conquistas.
function AchievementService.List(player: Player): { [string]: any }
	local profile = DataService.GetProfile(player)
	local season = AchievementsConfig.ActiveSeason()
	local out: { { [string]: any } } = {}
	if profile then
		ensureSeason(profile)
		profile.achievements.counters.achievements = countDone(profile, nil)
		if season then
			profile.achievements.season.counters.season_achievements = countDone(profile, season.Id)
		end
		for _, ach in AchievementsConfig.Active() do
			local reward: { string } = {}
			if ach.Reward.Coins then
				table.insert(reward, ("%d pontos"):format(ach.Reward.Coins))
			end
			if ach.Reward.XP and ach.Reward.XP > 0 then
				table.insert(reward, ("%d XP"):format(ach.Reward.XP))
			end
			for _, id in { ach.Reward.Cosmetic, ach.Reward.Emote } do
				if id then
					local item = CosmeticsConfig.GetItem(id)
					local emote = if item then nil else CosmeticsConfig.GetEmote(id)
					local limited = (item and item.Limited) or (emote and emote.Limited)
					local name = (item and item.Name) or (emote and emote.Name) or id
					table.insert(reward, if limited then name .. " (limitado)" else name)
				end
			end
			if ach.Reward.Character then
				local def = CharacterDefs.Get(ach.Reward.Character)
				table.insert(reward, (if def then def.DisplayName else ach.Reward.Character) .. " (personagem)")
			end
			table.insert(out, {
				id = ach.Id,
				name = ach.Name,
				desc = ach.Desc:format(ach.Goal),
				progress = math.min(counterFor(profile, ach), ach.Goal),
				goal = ach.Goal,
				done = profile.achievements.done[ach.Id] == true,
				season = ach.Season,
				reward = table.concat(reward, " + "),
			})
		end
	end
	return {
		season = if season then { id = season.Id, name = season.Name, daysLeft = AchievementsConfig.SeasonDaysLeft() } else nil,
		list = out,
	}
end

--- Entrega um item/emote/personagem "na mão" (DEV). Não marca conquista nenhuma.
function AchievementService.GrantReward(player: Player, id: string): (boolean, string)
	if CosmeticsConfig.GetItem(id) or CosmeticsConfig.GetEmote(id) then
		local ok = CosmeticsService.Grant(player, id, "dev")
		return ok, if ok then "entregue" else "já tinha"
	end
	if CharacterDefs.Get(id) then
		local ok = DataService.GrantCharacter(player, id)
		return ok, if ok then "entregue" else "já tinha"
	end
	return false, "id desconhecido"
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function AchievementService.Init()
	notifyAchievement = Remotes.GetEvent(Remotes.Events.NotifyAchievement)
	Remotes.GetFunction(Remotes.Functions.FetchAchievements).OnServerInvoke = function(player: Player)
		return AchievementService.List(player)
	end
	DataService.ProfileLoaded.Event:Connect(function(player: Player)
		AchievementService.Refresh(player)
	end)
end

function AchievementService.Start()
	local season = AchievementsConfig.ActiveSeason()
	Log.debug(("[AchievementService] %d conquista(s); passe: %s"):format(
		#AchievementsConfig.List,
		if season then ("%s (%d dia(s))"):format(season.Name, AchievementsConfig.SeasonDaysLeft()) else "nenhum no ar"
	))
end

return AchievementService
