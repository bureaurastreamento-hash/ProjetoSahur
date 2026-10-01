--!strict
local ProgressionConfig = require(script.Parent.ProgressionConfig)
local Config = {}
Config.BossRespawns = {
	fx_capataz = 600, fx_mascara_boss = 600, fx_cap1_boss = 900,
	fx_solnegro_boss = 900, fx_sol_boss = 900, fx_ambar_boss = 900,
	fx_costa_boss = 1800, fx_mare_colapso_boss = 900, fx_mare_avatar = 1800,
} :: { [string]: number }
Config.MobRespawn = 20
Config.MobRegen = { Delay = 15, Fraction = .02 }
Config.BossRegen = { Delay = 30, Fraction = .0035 }
function Config.IsBoss(kind: any): boolean
	local reward = if typeof(kind) == "string" then ProgressionConfig.Npcs[kind] else nil
	return reward ~= nil and reward.Boss == true
end
function Config.Respawn(kind: any, override: any): number
	local boss = Config.IsBoss(kind)
	if typeof(override) == "number" and override == override and override < math.huge then
		return math.clamp(override, if boss then 600 else 10, if boss then 1800 else 30)
	end
	return if boss then Config.BossRespawns[kind] or 900 else Config.MobRespawn
end
return Config
