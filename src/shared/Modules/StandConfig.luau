--!strict
--[[
	StandConfig — Stands, raças, raridade e itens de inventário (leva "Stands e raças", 2026-09-29).
	Decisões do dono (PROGRESSO 28/09 + BIZARRE_DIRECAO.md "Junções"):
	  - Todo mundo nasce HUMANO (kit "Humano": só M1/dash/block). Sorte absurda no primeiro login = "abençoado".
	  - A FLECHA sorteia um Stand por RARIDADE com chance FIXA por uso — sem pity, sem acúmulo.
	  - Trocar de Stand/raça PERDE o anterior (a não ser que ele esteja guardado no inventário); a maestria de cada
	    Stand fica salva (profile.mastery[id]) e LIBERA as habilidades (SlotUnlock).
	  - Raças só por missões especiais (Access = "mission"); tudo guardável no inventário.
	Stand = um kit de CharacterDefs com Access = "stand". O servidor é quem sorteia/decide (StandService).
]]

local StandConfig = {}

StandConfig.Human = "Humano" -- CharacterDefs id do kit sem Stand

export type Rarity = { Id: string, Name: string, Color: Color3, Chance: number }

-- Chance em % por uso da Flecha (soma 100). Faixa sem Stand cadastrado cai para a faixa de BAIXO mais próxima.
StandConfig.Rarities = {
	{ Id = "comum", Name = "Comum", Color = Color3.fromRGB(190, 190, 190), Chance = 55 },
	{ Id = "incomum", Name = "Incomum", Color = Color3.fromRGB(110, 200, 110), Chance = 26 },
	{ Id = "raro", Name = "Raro", Color = Color3.fromRGB(80, 150, 255), Chance = 12 },
	{ Id = "epico", Name = "Épico", Color = Color3.fromRGB(170, 90, 240), Chance = 5 },
	{ Id = "lendario", Name = "Lendário", Color = Color3.fromRGB(255, 180, 40), Chance = 1.6 },
	{ Id = "reliquia", Name = "Relíquia", Color = Color3.fromRGB(255, 90, 90), Chance = 0.35 },
	{ Id = "anomalo", Name = "Anômalo", Color = Color3.fromRGB(60, 240, 230), Chance = 0.05 }, -- "menor que o sol explodir"
} :: { Rarity }

-- Stands que a Flecha pode dar (kits de CharacterDefs). Rick é do boss (Access "drop"), fora da Flecha.
StandConfig.Stands = {
	Swift = "comum", -- Bruno Gollini
	Jotaro = "incomum",
	Kira = "raro",
	Dio = "lendario",
} :: { [string]: string }

-- Nível de MAESTRIA do Stand (ProgressionConfig.MasteryLevel) que libera cada tecla.
-- 1..4 = ataques, 5 = R (suporte), "G" = despertar/ultimate (e o kit desperto).
StandConfig.SlotUnlock = { [1] = 1, [2] = 2, [3] = 4, [4] = 6, [5] = 3 } :: { [number]: number }
StandConfig.AwakenUnlock = 8

-- Primeiro login: chance (0..1) de nascer "abençoado".
StandConfig.Blessed = { Stand = 0.002, Race = 0.001 }

export type Race = { Id: string, Name: string, Access: string, Desc: string, Color: Color3 }
StandConfig.Races = {
	{ Id = "Humano", Name = "Humano", Access = "default", Desc = "Sem bônus. Aprende qualquer coisa.", Color = Color3.fromRGB(220, 200, 170) },
	{ Id = "Vampiro", Name = "Vampiro", Access = "mission", Desc = "Máscara de pedra. (efeitos em breve)", Color = Color3.fromRGB(170, 30, 50) },
	{ Id = "HomemDePedra", Name = "Homem de Pedra", Access = "mission", Desc = "Despertou cedo demais. (efeitos em breve)", Color = Color3.fromRGB(150, 140, 120) },
} :: { Race }

--- Itens do inventário: "flecha", "stand:<CharacterId>" (Disco de Stand), "raca:<RaceId>" (Essência).
export type ItemInfo = { Id: string, Kind: string, Name: string, Desc: string, Color: Color3, Ref: string? }

function StandConfig.RarityOf(standId: string): Rarity?
	local id = StandConfig.Stands[standId]
	for _, r in StandConfig.Rarities do
		if r.Id == id then
			return r
		end
	end
	return nil
end

function StandConfig.IsStand(characterId: string): boolean
	return StandConfig.Stands[characterId] ~= nil
end

function StandConfig.GetRace(id: string): Race?
	for _, race in StandConfig.Races do
		if race.Id == id then
			return race
		end
	end
	return nil
end

--- Nível de maestria exigido pela tecla (nil = livre). slot 0 = despertar (G).
function StandConfig.RequiredMastery(characterId: string, slot: number): number?
	if not StandConfig.IsStand(characterId) then
		return nil
	end
	if slot == 0 then
		return StandConfig.AwakenUnlock
	end
	return StandConfig.SlotUnlock[slot]
end

function StandConfig.ItemInfo(itemId: string, displayNameOf: ((string) -> string?)?): ItemInfo?
	if itemId == "flecha" then
		return { Id = itemId, Kind = "arrow", Name = "Flecha", Desc = "Sorteia um Stand (chance fixa por raridade).", Color = Color3.fromRGB(230, 190, 90) }
	end
	local kind, ref = itemId:match("^(%a+):(.+)$")
	if kind == "stand" and ref and StandConfig.IsStand(ref) then
		local rarity = StandConfig.RarityOf(ref)
		local name = (displayNameOf and displayNameOf(ref)) or ref
		return { Id = itemId, Kind = "stand", Ref = ref, Name = "Disco de Stand: " .. name,
			Desc = ("%s. Usar troca o seu Stand atual (o atual é perdido)."):format(rarity and rarity.Name or "?"),
			Color = if rarity then rarity.Color else Color3.new(1, 1, 1) }
	elseif kind == "raca" and ref then
		local race = StandConfig.GetRace(ref)
		if race then
			return { Id = itemId, Kind = "race", Ref = ref, Name = "Essência: " .. race.Name,
				Desc = race.Desc .. " Usar troca a sua raça atual.", Color = race.Color }
		end
	end
	return nil
end

--- Sorteio da Flecha (servidor). `rng` = Random. Retorna o CharacterId do Stand.
function StandConfig.Roll(rng: Random): string
	local roll = rng:NextNumber() * 100
	local tierIndex = #StandConfig.Rarities
	local acc = 0
	for i, r in StandConfig.Rarities do
		acc += r.Chance
		if roll < acc then
			tierIndex = i
			break
		end
	end
	for i = tierIndex, 1, -1 do -- faixa vazia cai para a de baixo
		local pool = {}
		for standId, rarityId in StandConfig.Stands do
			if rarityId == StandConfig.Rarities[i].Id then
				table.insert(pool, standId)
			end
		end
		if #pool > 0 then
			table.sort(pool)
			return pool[rng:NextInteger(1, #pool)]
		end
	end
	return "Swift"
end

return StandConfig
