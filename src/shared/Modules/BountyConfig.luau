--!strict
-- Limiares da ESTRUTURA_JOGO.md; ganho inicial ajustável após testes jogáveis.
local Config = {}
export type State = { points: number, recentVictims: { [string]: number } }
Config.KillGain = 5000
Config.MaxPoints = 1000000000
Config.RepeatSeconds = 300
Config.MaxRecentVictims = 256
Config.MaxLevelGap = 10
Config.Tiers = {
	{ Points = 50000, Title = "Procurado" },
	{ Points = 250000, Title = "Perigoso" },
	{ Points = 1000000, Title = "Ameaça Regional" },
	{ Points = 5000000, Title = "Calamidade" },
	{ Points = 10000000, Title = "Anomalia" },
}
function Config.Title(points: number): string
	local title = "Sem título"
	for _, tier in Config.Tiers do
		if points >= tier.Points then title = tier.Title end
	end
	return title
end
function Config.Normalize(raw: any, now: number): State
	local result: State = { points = 0, recentVictims = {} }
	if typeof(raw) ~= "table" then return result end
	local points = raw.points
	if typeof(points) == "number" and points == points and math.abs(points) < math.huge then
		result.points = math.clamp(math.floor(points), 0, Config.MaxPoints)
	end
	if typeof(raw.recentVictims) == "table" then
		local count = 0
		for id, at in raw.recentVictims do
			if typeof(id) == "string" and #id <= 16 and id:match("^%d+$")
				and typeof(at) == "number" and at == math.floor(at)
				and at > now - Config.RepeatSeconds and at <= now + Config.RepeatSeconds then
				result.recentVictims[id] = at
				count += 1
				if count >= Config.MaxRecentVictims then break end
			end
		end
	end
	return result
end
-- Recompensa adicional em moeda normal; não usa multiplicadores para a bounty.
function Config.DefeatBonus(points: number): number
	return math.min(20, math.max(0, math.floor(points / 50000)))
end
return Config
