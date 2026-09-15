--!strict
--[[
	Assets
	Localiza assets de arte/animação por NOME em ReplicatedStorage.Assets.
	A árvore é criada pelo Rojo a partir de src/assets/:
	  - Animations.model.json: todas as instâncias Animation (o AnimationId de
	    cada uma é preenchido aqui no repositório quando a animação é publicada).
	  - VFX/<pasta>/: pastas com ignoreUnknownInstances, então a equipe de arte
	    pode montar VFX direto no Studio dentro delas sem o Rojo apagar.
	  - VFX/Shared/Placeholder: efeito genérico usado quando o específico não existe.

	ReplicatedStorage.Assets
	├── Animations
	│   ├── Shared         (Animation) M1_1, M1_2, M1_3, M1_4, Block, Parry, Hit
	│   └── <CharacterId>  (Animation) <AbilityId>   ex: Brawler/ShoulderBash
	├── VFX
	│   ├── Shared         Hit, Block, Parry, Placeholder
	│   └── <CharacterId>  (Model|BasePart|Attachment) <AbilityId>, <AbilityId>_Hit
	└── Sounds
	    ├── Shared         (Sound) Punch_Whoosh, Punch_Hit, Block, Parry, Death
	    ├── Match          (Sound) RoundStart, Victory, Defeat
	    └── <CharacterId>  (Sound) <AbilityId>, <AbilityId>_Hit
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(script.Parent:WaitForChild("Log"))

local Assets = {}

local ROOT = "Assets"
local warned: { [string]: boolean } = {}

local function find(...: string): Instance?
	local current: Instance? = ReplicatedStorage:FindFirstChild(ROOT)
	for _, name in { ... } do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function warnOnce(path: string)
	if not warned[path] then
		warned[path] = true
		Log.debug(("[Assets] não encontrado: ReplicatedStorage.%s.%s (seguindo sem)"):format(ROOT, path))
	end
end

--- Animation em Assets.Animations.<folder>.<name>. nil se não existir ou se o AnimationId ainda estiver vazio.
function Assets.GetAnimation(folder: string, name: string): Animation?
	local inst = find("Animations", folder, name)
	if inst and inst:IsA("Animation") and inst.AnimationId ~= "" then
		return inst
	end
	warnOnce(("Animations.%s.%s (sem AnimationId)"):format(folder, name))
	return nil
end

-- Enquanto a arte não entrega o VFX com o nome exato, usamos efeitos dos packs:
--   "Wind"                          -> Particle Pack (Assets.VFX.Packs.ParticlePack.<nome>)
--   "Packs/OfficialJJS/Damage/HitGlow" -> caminho completo dentro de Assets.VFX
-- Um VFX com o nome exato na pasta do personagem sempre tem prioridade sobre o alias.
local PACK = { "Packs", "ParticlePack", "[Shiro Dev Patreon] - Particle Set" }
Assets.VFXAliases = {
	["Brawler/ShoulderBash"] = "Wind",
	["Brawler/ShoulderBash_Hit"] = "Slashes",
	["Brawler/GroundSlam"] = "Smoke V.2",
	["Brawler/GroundSlam_Hit"] = "Stripes",
	["Brawler/Rampage"] = "Fire V.2",
	["Swift/Blink"] = "Flare",
	["Swift/SweepKick"] = "Wind",
	["Swift/SweepKick_Hit"] = "Slashes",
	["Swift/Tempest"] = "Stripes",
	["Swift/Tempest_Hit"] = "Slashes",
	["Mystic/ArcaneBolt"] = "Flare",
	["Mystic/ArcaneBolt_Hit"] = "Yellow Plasma",
	["Mystic/Mend"] = "Sphere",
	["Mystic/Meteor"] = "Sun Portal",
	["Mystic/Meteor_Hit"] = "Fire V.1",
	["Guardian/ShieldBash"] = "Wind",
	["Guardian/ShieldBash_Hit"] = "Slashes",
	["Guardian/Fortify"] = "Sphere",
	["Guardian/Quake"] = "Smoke V.2",
	["Guardian/Quake_Hit"] = "Stripes",
}

local function findPackVFX(name: string): Instance?
	local current: Instance? = find("VFX", PACK[1], PACK[2])
	if current then
		current = current:FindFirstChild(PACK[3]) or current
		return current:FindFirstChild(name)
	end
	return nil
end

--- Template de VFX em Assets.VFX.<folder>.<name>. Fallbacks: alias do Particle Pack, depois VFX.Shared.Placeholder.
-- Escolha explícita de VFX dos packs por habilidade (tem prioridade sobre o VFX gerado/nomeado).
-- Valor = caminho dentro de Assets.VFX, ou { Path, Follow?, Lifetime? } (aura que segue / dura mais).
-- Para trocar: use o Preview de VFX no menu Dev, copie o caminho, edite aqui e rode
-- `lune run tools/podar_vfx.luau` (só o que está listado aqui é replicado; packs completos em packs/VFX).
export type PackChoice = string | { Path: string, Follow: boolean?, Lifetime: number? }
Assets.VFXPack = {
	["Shared/Hit"] = "Packs/OfficialJJS/Misc/C/M1/Hit1",
	["Shared/Block"] = "Packs/OfficialJJS/Charles/ParryFX",
	["Shared/Parry"] = "Packs/OfficialJJS/Megumi/Mahoraga/Parry",
	["Shared/Finisher"] = "Packs/OfficialJJS/Itadori/RushWind",
	["Shared/FinisherHit"] = "Packs/OfficialJJS/Todo/HeavyHit",
	["Shared/GuardBreak"] = "Packs/OfficialJJS/Misc/S/HeavyHit",
	["Shared/Stun"] = { Path = "Packs/OfficialJJS/Damage/Dizzy", Follow = true, Lifetime = 1.2 },
	["Shared/Ragdoll"] = { Path = "Packs/OfficialJJS/Damage/RagdollWind", Follow = true, Lifetime = 1.5 },
	["Brawler/ShoulderBash"] = "Packs/OfficialJJS/Mahito/CrushingRushdown/Dash",
	["Brawler/ShoulderBash_Hit"] = "Packs/OfficialJJS/Misc/M/DashHit",
	["Brawler/GroundSlam"] = "Packs/ShadowBattlegroundsfull/Brute/slam",
	["Brawler/GroundSlam_Hit"] = "Packs/OfficialJJS/Hakari/RoughImpact",
	["Brawler/Rampage"] = { Path = "Packs/OfficialJJS/Todo/Awakening/Aura", Follow = true, Lifetime = 8 },
	["Swift/Blink"] = "Packs/OfficialJJS/Gojo/Teleport",
	["Swift/SweepKick"] = "Packs/ShadowBattlegroundsfull/ShadowFist/Skick1",
	["Swift/SweepKick_Hit"] = "Packs/ShadowBattlegroundsfull/Garou/punchhit",
	["Swift/Tempest"] = { Path = "Packs/ShadowBattlegroundsfull/Garou/Spin", Lifetime = 2.5 },
	["Swift/Tempest_Hit"] = "Packs/OfficialJJS/Misc/M/Hit",
	["Mystic/ArcaneStep"] = "Packs/OfficialJJS/Yuta/Veilstep/CEImpact",
	["Mystic/ArcaneStep_Hit"] = "Packs/OfficialJJS/Misc/M/DashHit",
	["Mystic/ArcaneBolt"] = "Packs/OfficialJJS/Misc/S/Orb",
	["Mystic/ArcaneBolt_Hit"] = "Packs/OfficialJJS/Yuta/Veilstep/CEImpact",
	["Mystic/Mend"] = "Packs/OfficialJJS/Yuta/SecondWind",
	-- Mystic/Meteor (aviso no chão) continua o gerado: precisa do anel no ponto certo
	["Mystic/Meteor_Hit"] = { Path = "Packs/ShadowBattlegroundsfull/MeteoricCombination/FinalImpact2", Lifetime = 3 },
	["Guardian/ShieldBash"] = "Packs/OfficialJJS/Mechamaru/BoostOnVFX/BoostDash",
	["Guardian/ShieldBash_Hit"] = "Packs/OfficialJJS/Todo/HeavyHit",
	["Guardian/Fortify"] = { Path = "Packs/OfficialJJS/Mechamaru/Offload/Aura", Follow = true, Lifetime = 6 },
	["Guardian/Quake"] = { Path = "Packs/OfficialJJS/Locust/Slam", Lifetime = 2.5 },
	["Guardian/Quake_Hit"] = "Packs/OfficialJJS/Hakari/RoughSlam",
	-- Boss reaproveita efeitos já podados (tools/podar_vfx.luau só gera os caminhos citados aqui)
	["Boss/Swipe_Hit"] = "Packs/OfficialJJS/Todo/HeavyHit",
	["Boss/Slam"] = "Packs/ShadowBattlegroundsfull/Brute/slam",
	["Boss/Slam_Hit"] = "Packs/OfficialJJS/Hakari/RoughSlam",
	["Boss/Charge"] = "Packs/OfficialJJS/Mechamaru/BoostOnVFX/BoostDash",
	["Boss/Charge_Hit"] = "Packs/OfficialJJS/Hakari/RoughImpact",
	["Boss/Roar"] = { Path = "Packs/OfficialJJS/Todo/Awakening/Aura", Follow = true, Lifetime = 3 },
} :: { [string]: PackChoice }

local function findPath(path: string): Instance?
	return find("VFX", table.unpack(path:split("/")))
end

local function packChoice(folder: string, name: string): Instance?
	local choice = Assets.VFXPack[folder .. "/" .. name]
	if not choice then
		return nil
	end
	local path = if typeof(choice) == "string" then choice else choice.Path
	local inst = findPath(path)
	if not inst then
		warnOnce(("VFXPack %s/%s -> %s (não existe)"):format(folder, name, path))
		return nil
	end
	if typeof(choice) == "table" then
		-- atributos que FX.SpawnVFX entende (aplicados no template, só neste cliente)
		if choice.Follow then
			inst:SetAttribute("Follow", true)
		end
		if choice.Lifetime then
			inst:SetAttribute("Lifetime", choice.Lifetime)
		end
	end
	return inst
end

function Assets.GetVFX(folder: string, name: string): Instance?
	local chosen = packChoice(folder, name)
	if chosen then
		return chosen
	end
	local inst = find("VFX", folder, name)
	if inst then
		return inst
	end
	local alias = Assets.VFXAliases[folder .. "/" .. name]
	if alias then
		-- "Packs/OfficialJJS/Damage/HitGlow" = caminho dentro de Assets.VFX; sem "/" = Particle Pack
		local packInst = if alias:find("/") then findPath(alias) else findPackVFX(alias)
		if packInst then
			return packInst
		end
	end
	warnOnce(("VFX.%s.%s (usando Placeholder)"):format(folder, name))
	return find("VFX", "Shared", "Placeholder")
end

--- Sound em Assets.Sounds.<folder>.<name>. nil se não existir ou se o SoundId estiver vazio.
function Assets.GetSound(folder: string, name: string): Sound?
	local inst = find("Sounds", folder, name)
	if inst and inst:IsA("Sound") and inst.SoundId ~= "" then
		return inst
	end
	warnOnce(("Sounds.%s.%s (sem SoundId)"):format(folder, name))
	return nil
end

--- Existe VFX específico ou alias (sem cair no Placeholder)?
function Assets.HasVFX(folder: string, name: string): boolean
	if packChoice(folder, name) ~= nil or find("VFX", folder, name) ~= nil then
		return true
	end
	local alias = Assets.VFXAliases[folder .. "/" .. name]
	if not alias then
		return false
	end
	return (if alias:find("/") then findPath(alias) else findPackVFX(alias)) ~= nil
end

return Assets
