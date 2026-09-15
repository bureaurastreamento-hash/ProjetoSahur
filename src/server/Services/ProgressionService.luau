--!strict
--[[
	ProgressionService (servidor)
	XP/nível, recompensa diária e missões diárias, tudo salvo no perfil do DataService
	(campos xp/level/daily/missions) e replicado pelo NotifyProfile normal.

	Fontes de progresso:
	  - kill de jogador (HealthService.Died)            -> XP.Kill, missão "kills"
	  - duelo (DuelService chama OnDuelResult)          -> XP.DuelWin/DuelLoss, missões "duels"/"duel_wins"
	  - boss derrotado (BossService chama OnBossDefeated)-> XP por dano, missões "boss_damage"/"boss_kills"
	  - tempo jogado (loop de 60 s)                     -> missão "playtime"
	Ao subir de nível: moedas (ProgressionConfig.LevelUpCoins) + NotifyProgression("levelup").
	Missão concluída: recompensa na hora + NotifyProgression("mission_done").
	Recompensa diária: ao carregar o perfil, 1x por dia UTC, com streak.
	Atributo Level no Player (para HUD/placar).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local DataConfig = require(Modules:WaitForChild("DataConfig"))
local ProgressionConfig = require(Modules:WaitForChild("ProgressionConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))

local ProgressionService = {}

local notifyProgression: RemoteEvent
local missionById: { [string]: ProgressionConfig.MissionDef } = {}
for _, def in ProgressionConfig.MissionPool do
	missionById[def.id] = def
end

local function notify(player: Player, event: string, data: { [string]: any })
	if player.Parent == Players then
		notifyProgression:FireClient(player, event, data)
	end
end

-- ---------------------------------------------------------------------------
-- XP / nível
-- ---------------------------------------------------------------------------

function ProgressionService.AddXP(player: Player, amount: number, reason: string)
	local profile = DataService.GetProfile(player)
	if not profile or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	profile.xp += amount
	local leveled = false
	while profile.level < ProgressionConfig.MaxLevel do
		local need = ProgressionConfig.XPForLevel(profile.level)
		if profile.xp < need then
			break
		end
		profile.xp -= need
		profile.level += 1
		leveled = true
		local coins = ProgressionConfig.LevelUpCoins(profile.level)
		profile.coins += coins
		Log.debug(("[Progression] %s subiu para o nível %d (+%d moedas)"):format(player.Name, profile.level, coins))
		notify(player, "levelup", { level = profile.level, coins = coins })
	end
	if profile.level >= ProgressionConfig.MaxLevel then
		profile.xp = math.min(profile.xp, ProgressionConfig.XPForLevel(profile.level) - 1)
	end
	player:SetAttribute("Level", profile.level)
	if not leveled then
		notify(player, "xp", { amount = amount, reason = reason })
	end
	DataService.MarkDirty(player)
end

-- ---------------------------------------------------------------------------
-- Missões diárias
-- ---------------------------------------------------------------------------

local function rollMissions(player: Player, profile: DataConfig.Profile, day: number)
	local rng = Random.new(day * 7919 + player.UserId)
	local pool = table.clone(ProgressionConfig.MissionPool)
	local list: { DataConfig.Mission } = {}
	local usedKinds: { [string]: boolean } = {}
	while #list < ProgressionConfig.MissionsPerDay and #pool > 0 do
		local i = rng:NextInteger(1, #pool)
		local def = table.remove(pool, i) :: ProgressionConfig.MissionDef
		if not usedKinds[def.kind] then
			usedKinds[def.kind] = true
			table.insert(list, { id = def.id, progress = 0, done = false })
		end
	end
	profile.missions = { day = day, list = list }
end

--- Garante que as missões são do dia de hoje (sorteia de novo se virou o dia).
local function ensureMissions(player: Player, profile: DataConfig.Profile): boolean
	local day = ProgressionConfig.DayIndex()
	if profile.missions.day ~= day or #profile.missions.list == 0 then
		rollMissions(player, profile, day)
		return true
	end
	return false
end

--- Avança as missões de um tipo. amount = quanto somar (1 para eventos, dano para boss_damage).
function ProgressionService.Progress(player: Player, kind: string, amount: number)
	local profile = DataService.GetProfile(player)
	if not profile or amount <= 0 then
		return
	end
	local changed = ensureMissions(player, profile)
	for _, m in profile.missions.list do
		local def = missionById[m.id]
		if def and def.kind == kind and not m.done then
			m.progress = math.min(def.goal, m.progress + amount)
			changed = true
			if m.progress >= def.goal then
				m.done = true
				profile.coins += def.coins
				notify(player, "mission_done", { id = def.id, text = def.text:format(def.goal), coins = def.coins, xp = def.xp })
				Log.debug(("[Progression] %s concluiu a missão %s"):format(player.Name, def.id))
				ProgressionService.AddXP(player, def.xp, "mission")
			end
		end
	end
	if changed then
		DataService.MarkDirty(player)
	end
end

-- ---------------------------------------------------------------------------
-- Recompensa diária
-- ---------------------------------------------------------------------------

local function claimDaily(player: Player, profile: DataConfig.Profile)
	local day = ProgressionConfig.DayIndex()
	if profile.daily.lastDay == day then
		return
	end
	local cfg = ProgressionConfig.Daily
	local streak = if profile.daily.lastDay == day - 1 then profile.daily.streak + 1 else 1
	streak = math.clamp(streak, 1, cfg.MaxStreak)
	local coins = cfg.Base + cfg.PerStreak * (streak - 1)
	profile.daily = { lastDay = day, streak = streak }
	profile.coins += coins
	Log.debug(("[Progression] %s: recompensa diária +%d (dia %d da sequência)"):format(player.Name, coins, streak))
	notify(player, "daily", { coins = coins, streak = streak, maxStreak = cfg.MaxStreak })
end

-- ---------------------------------------------------------------------------
-- Ganchos chamados por outros services
-- ---------------------------------------------------------------------------

function ProgressionService.OnDuelResult(player: Player, won: boolean)
	ProgressionService.AddXP(player, if won then ProgressionConfig.XP.DuelWin else ProgressionConfig.XP.DuelLoss, "duel")
	ProgressionService.Progress(player, "duels", 1)
	if won then
		ProgressionService.Progress(player, "duel_wins", 1)
	end
end

--- damage = dano causado pelo jogador; share = fração do dano total (0..1); top = maior dano.
function ProgressionService.OnBossDefeated(player: Player, damage: number, share: number, top: boolean)
	local xp = math.max(ProgressionConfig.XP.BossMin, math.floor(ProgressionConfig.XP.BossPool * share))
	if top then
		xp += ProgressionConfig.XP.BossTopBonus
	end
	ProgressionService.AddXP(player, xp, "boss")
	ProgressionService.Progress(player, "boss_damage", math.floor(damage))
	ProgressionService.Progress(player, "boss_kills", 1)
end

--- Snapshot das missões de hoje com definição (para admin/debug).
function ProgressionService.GetMissions(player: Player): { { [string]: any } }
	local profile = DataService.GetProfile(player)
	local out = {}
	if profile then
		ensureMissions(player, profile)
		for _, m in profile.missions.list do
			local def = missionById[m.id]
			if def then
				table.insert(out, { id = m.id, text = def.text:format(def.goal), progress = m.progress, goal = def.goal, done = m.done })
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function ProgressionService.Init()
	notifyProgression = Remotes.GetEvent(Remotes.Events.NotifyProgression)
	-- Conectado no Init para pegar perfis que carregam durante o Start dos outros services.
	DataService.ProfileLoaded.Event:Connect(function(player: Player, profile: DataConfig.Profile, sessionOnly: boolean)
		player:SetAttribute("Level", profile.level)
		local changed = ensureMissions(player, profile)
		if not sessionOnly then
			claimDaily(player, profile)
			changed = true
		end
		if changed then
			DataService.MarkDirty(player)
		end
	end)
end

function ProgressionService.Start()
	HealthService.Died.Event:Connect(function(victim: Player, killer: Player?)
		if killer and killer ~= victim and killer.Parent == Players then
			ProgressionService.AddXP(killer, ProgressionConfig.XP.Kill, "kill")
			ProgressionService.Progress(killer, "kills", 1)
		end
	end)
	-- tempo jogado (minutos) para a missão "playtime"
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				ProgressionService.Progress(player, "playtime", 1)
			end
		end
	end)
	Log.debug("[ProgressionService] pronto (XP/nível, diária, missões)")
end

return ProgressionService
