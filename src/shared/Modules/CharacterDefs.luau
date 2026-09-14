--!strict
--[[
	CharacterDefs
	Definição de cada personagem/estilo de luta e suas habilidades ativas.
	Lido pelo servidor (autoridade: cooldown, energia, efeito) e pelo cliente
	(só teclas, nomes e feedback).

	Energia: 0..MaxEnergy. Ganha ao dar/receber dano (ver Energy abaixo).
	Ultimate = habilidade com EnergyCost = MaxEnergy.

	Assets esperados (por nome, ver Assets.luau):
	  Animations.<CharacterId>.<AbilityId>
	  VFX.<CharacterId>.<AbilityId>

	Tipos de efeito (implementados em AbilityService):
	  Dash        { Speed, Duration, Damage, Range, Width, Height }  -> movimento no cliente, hitbox no servidor ao fim
	  Teleport    { Distance }                                       -> servidor move o HRP para frente (com raycast contra parede)
	  AreaDamage  { Radius, Damage, Delay, StunSeconds? }            -> dano em esfera após Delay
	  MultiHitArea{ Radius, Damage, Hits, Interval }                 -> vários ticks de AreaDamage
	  DamageBuff  { Multiplier, Duration }                           -> multiplica dano dos socos/habilidades
]]

export type Effect = {
	Type: string,
	[string]: any,
}

export type AbilityDef = {
	Id: string,
	DisplayName: string,
	Cooldown: number,
	EnergyCost: number,
	CastTime: number, -- tempo em que o jogador fica "ocupado" (não pode usar outra habilidade)
	Effect: Effect,
}

export type CharacterDef = {
	Id: string,
	DisplayName: string,
	Abilities: { AbilityDef }, -- índice = slot (1, 2, 3...)
}

local CharacterDefs = {}

CharacterDefs.Energy = {
	Max = 100,
	GainOnHitDealt = 6,
	GainOnHitTaken = 4,
}

CharacterDefs.DefaultCharacter = "Brawler"

CharacterDefs.Characters = {
	Brawler = {
		Id = "Brawler",
		DisplayName = "Brawler",
		Abilities = {
			{
				Id = "ShoulderBash",
				DisplayName = "Investida",
				Cooldown = 6,
				EnergyCost = 0,
				CastTime = 0.35,
				Effect = { Type = "Dash", Speed = 70, Duration = 0.25, Damage = 15, Range = 7, Width = 6, Height = 6 },
			},
			{
				Id = "GroundSlam",
				DisplayName = "Pancada no Chão",
				Cooldown = 10,
				EnergyCost = 30,
				CastTime = 0.6,
				Effect = { Type = "AreaDamage", Radius = 12, Damage = 20, Delay = 0.4 },
			},
			{
				Id = "Rampage",
				DisplayName = "Fúria",
				Cooldown = 30,
				EnergyCost = 100,
				CastTime = 0.5,
				Effect = { Type = "DamageBuff", Multiplier = 2, Duration = 8 },
			},
		},
	} :: CharacterDef,

	Swift = {
		Id = "Swift",
		DisplayName = "Swift",
		Abilities = {
			{
				Id = "Blink",
				DisplayName = "Piscar",
				Cooldown = 5,
				EnergyCost = 0,
				CastTime = 0.15,
				Effect = { Type = "Teleport", Distance = 18 },
			},
			{
				Id = "SweepKick",
				DisplayName = "Rasteira",
				Cooldown = 8,
				EnergyCost = 25,
				CastTime = 0.4,
				Effect = { Type = "AreaDamage", Radius = 8, Damage = 12, Delay = 0.2, StunSeconds = 0.8 },
			},
			{
				Id = "Tempest",
				DisplayName = "Tempestade",
				Cooldown = 30,
				EnergyCost = 100,
				CastTime = 1.5,
				Effect = { Type = "MultiHitArea", Radius = 10, Damage = 6, Hits = 5, Interval = 0.3 },
			},
		},
	} :: CharacterDef,
}

--- Lista ordenada de ids (para ciclar na seleção de debug)
CharacterDefs.Order = { "Brawler", "Swift" }

function CharacterDefs.Get(characterId: string): CharacterDef?
	return CharacterDefs.Characters[characterId]
end

function CharacterDefs.GetAbility(characterId: string, slot: number): AbilityDef?
	local def = CharacterDefs.Characters[characterId]
	if not def then
		return nil
	end
	return def.Abilities[slot]
end

return CharacterDefs
