--!strict
--[[
	CharacterDefs
	Definição de cada personagem/estilo de luta e suas habilidades ativas.
	Lido pelo servidor (autoridade: cooldown, energia, efeito) e pelo cliente
	(só teclas, nomes e feedback).

	Decisão do dono (2026-09-15): NÃO existe "energia" para habilidades — Q/E/R são só cooldown
	(EnergyCost = 0). A barra "Energy" virou a CARGA DA ULT (0..Max): enche dando/recebendo dano
	durante a luta; a ultimate (slot 3, T) custa Max. HUD mostra como "ULT".

	Assets esperados (por nome, ver Assets.luau):
	  Animations.<CharacterId>.<AbilityId>
	  VFX.<CharacterId>.<AbilityId>

	Slots: 1 = E, 2 = R, 3 = T (ultimate, EnergyCost = Max). O dash universal fica no Q e é de
	TODOS os personagens (CombatConfig.Dash, MovementService) — não é habilidade daqui.

	Tipos de efeito (implementados em AbilityService):
	  Dash        { Speed, Duration, Damage, Range, Width, Height }  -> investida COM dano (movimento no cliente, hitbox no servidor)
	  Teleport    { Distance }                                       -> servidor move o HRP para frente (com raycast contra parede)
	  AreaDamage  { Radius, Damage, Delay, StunSeconds?, Knockback?, Offset? }
	                                                                 -> dano em esfera após Delay; Offset = studs à frente do lançador
	                                                                    Knockback = { Speed, Duration, Ragdoll? } (Ragdoll = segundos caído)
	  MultiHitArea{ Radius, Damage, Hits, Interval }                 -> vários ticks de AreaDamage
	  DamageBuff  { Multiplier, Duration }                           -> multiplica dano dos socos/habilidades
	  Projectile  { Speed, Range, Radius, Damage, Knockback? }       -> esfera simulada no servidor, acerta o 1º alvo
	  Heal        { Amount }                                         -> cura o próprio lançador
	  Shield      { Multiplier, Duration }                           -> multiplica dano RECEBIDO (0.5 = metade)
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
	UnlockCost: number, -- moedas; 0 = todos começam com ele (só vale com Access = "coins"/nil)
	Access: string?, -- nil/"coins" = moedas | "vip" = passe VIP (ShopConfig) | "early" = acesso antecipado (bloqueado; só devs)
	Tagline: string?, -- subtítulo no cartão da seleção
	Color: Color3?, -- cor do personagem (cartão, rastro do dash)
	Image: string?, -- rbxassetid:// do retrato no cartão (vazio = placeholder com a inicial)
	Abilities: { AbilityDef }, -- índice = slot (1 = E, 2 = R, 3 = T = ultimate)
}

local CharacterDefs = {}

CharacterDefs.Energy = {
	Max = 100,
	GainOnHitDealt = 6,
	GainOnHitTaken = 4,
}

CharacterDefs.DefaultCharacter = "Brawler"

--- Afinação global de dash (dash universal do Q e Effect.Type = "Dash"). Duration × escala conforme a
--- direção. O cliente move; o servidor amostra a hitbox por Duration × ForwardScale (o maior).
CharacterDefs.DashTuning = {
	ForwardScale = 1.4, -- frente/trás
	SideScale = 1.0, -- lados
	SteerRate = 8, -- rad/s de correção pelo WASD durante o dash
	MinDistanceHold = true, -- bateu em parede/jogador: a duração continua contando (sem "dash grátis")
}

--- Trocar de personagem faz respawn; só é permitido depois deste tempo sem levar dano.
CharacterDefs.SwapOutOfCombatSeconds = 10

CharacterDefs.Characters = {
	Brawler = {
		Id = "Brawler",
		DisplayName = "Brawler",
		UnlockCost = 0,
		Tagline = "Força bruta e pressão",
		Color = Color3.fromRGB(255, 150, 60),
		Image = "",
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
				EnergyCost = 0,
				CastTime = 0.6,
				Effect = { Type = "AreaDamage", Radius = 12, Damage = 20, Delay = 0.4, Knockback = { Speed = 40, Duration = 0.25, Ragdoll = 1.5 } },
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
		UnlockCost = 100,
		Tagline = "Velocidade e teleporte",
		Color = Color3.fromRGB(110, 230, 255),
		Image = "",
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
				EnergyCost = 0,
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

	Mystic = {
		Id = "Mystic",
		DisplayName = "Mystic",
		UnlockCost = 250,
		Tagline = "Distância, cura e meteoro",
		Color = Color3.fromRGB(170, 110, 255),
		Image = "",
		Abilities = {
			{
				Id = "ArcaneBolt",
				DisplayName = "Projétil Arcano",
				Cooldown = 4,
				EnergyCost = 0,
				CastTime = 0.3,
				Effect = { Type = "Projectile", Speed = 90, Range = 70, Radius = 3, Damage = 14, Knockback = { Speed = 25, Duration = 0.15 } },
			},
			{
				Id = "Mend",
				DisplayName = "Restaurar",
				Cooldown = 16,
				EnergyCost = 0,
				CastTime = 0.6,
				Effect = { Type = "Heal", Amount = 30 },
			},
			{
				Id = "Meteor",
				DisplayName = "Meteoro",
				Cooldown = 30,
				EnergyCost = 100,
				CastTime = 0.8,
				Effect = { Type = "AreaDamage", Radius = 14, Damage = 45, Delay = 1.2, Offset = 16, Knockback = { Speed = 55, Duration = 0.3, Ragdoll = 2 } },
			},
		},
	} :: CharacterDef,

	Guardian = {
		Id = "Guardian",
		DisplayName = "Guardian",
		UnlockCost = 0,
		Access = "vip", -- exclusivo do passe VIP (ou "Todos os personagens")
		Tagline = "Tanque: escudo e terremoto",
		Color = Color3.fromRGB(255, 205, 80),
		Image = "",
		Abilities = {
			{
				Id = "ShieldBash",
				DisplayName = "Golpe de Escudo",
				Cooldown = 7,
				EnergyCost = 0,
				CastTime = 0.4,
				Effect = { Type = "Dash", Speed = 55, Duration = 0.2, Damage = 10, Range = 6, Width = 7, Height = 6, StunSeconds = 0.6 },
			},
			{
				Id = "Fortify",
				DisplayName = "Fortificar",
				Cooldown = 18,
				EnergyCost = 0,
				CastTime = 0.3,
				Effect = { Type = "Shield", Multiplier = 0.4, Duration = 6 },
			},
			{
				Id = "Quake",
				DisplayName = "Terremoto",
				Cooldown = 30,
				EnergyCost = 100,
				CastTime = 1.2,
				Effect = { Type = "MultiHitArea", Radius = 16, Damage = 12, Hits = 3, Interval = 0.4, Knockback = { Speed = 35, Duration = 0.2 } },
			},
		},
	} :: CharacterDef,

	-- Acesso antecipado: aparece bloqueado na lista; só devs (IsDeveloper) conseguem usar para testar.
	Sahur = {
		Id = "Sahur",
		DisplayName = "Sahur",
		UnlockCost = 0,
		Access = "early",
		Tagline = "O ritmo que esmaga",
		Color = Color3.fromRGB(120, 255, 160),
		Image = "",
		Abilities = {
			{
				Id = "Bombo",
				DisplayName = "Bombo",
				Cooldown = 9,
				EnergyCost = 0,
				CastTime = 0.5,
				Effect = { Type = "AreaDamage", Radius = 10, Damage = 18, Delay = 0.35, Knockback = { Speed = 45, Duration = 0.25, Ragdoll = 1.5 } },
			},
			{
				Id = "Toque",
				DisplayName = "Toque de Guerra",
				Cooldown = 18,
				EnergyCost = 0,
				CastTime = 0.6,
				Effect = { Type = "DamageBuff", Multiplier = 1.5, Duration = 6 },
			},
			{
				Id = "Ritmo",
				DisplayName = "Ritmo Final",
				Cooldown = 30,
				EnergyCost = 100,
				CastTime = 1.5,
				Effect = { Type = "MultiHitArea", Radius = 12, Damage = 9, Hits = 6, Interval = 0.25, Knockback = { Speed = 30, Duration = 0.15 } },
			},
		},
	} :: CharacterDef,
}

--- Lista ordenada de ids (ordem na seleção de personagem)
CharacterDefs.Order = { "Brawler", "Swift", "Mystic", "Guardian", "Sahur" }

--- "coins" | "vip" | "early"
function CharacterDefs.AccessOf(def: CharacterDef): string
	return def.Access or "coins"
end

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
