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

--- Template de VFX em Assets.VFX.<folder>.<name>. Se não existir, usa VFX.Shared.Placeholder.
function Assets.GetVFX(folder: string, name: string): Instance?
	local inst = find("VFX", folder, name)
	if inst then
		return inst
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

--- Existe VFX específico (sem fallback)?
function Assets.HasVFX(folder: string, name: string): boolean
	return find("VFX", folder, name) ~= nil
end

return Assets
