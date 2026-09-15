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

-- Enquanto a arte não entrega o VFX com o nome exato, usamos efeitos do
-- Particle Pack (Assets.VFX.Packs.ParticlePack.<nome>). Um VFX com o nome exato
-- na pasta do personagem sempre tem prioridade sobre o alias.
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
function Assets.GetVFX(folder: string, name: string): Instance?
	local inst = find("VFX", folder, name)
	if inst then
		return inst
	end
	local alias = Assets.VFXAliases[folder .. "/" .. name]
	if alias then
		local packInst = findPackVFX(alias)
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
	if find("VFX", folder, name) ~= nil then
		return true
	end
	local alias = Assets.VFXAliases[folder .. "/" .. name]
	return alias ~= nil and findPackVFX(alias) ~= nil
end

return Assets
