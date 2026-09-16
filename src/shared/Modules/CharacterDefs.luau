--!strict
--[[
	CharacterDefs
	Definição de cada personagem/estilo de luta e suas habilidades ativas.
	Lido pelo servidor (autoridade: cooldown, energia, efeito) e pelo cliente
	(só teclas, nomes e feedback).

	Decisão do dono (2026-09-15): NÃO existe "energia" para habilidades — teclas 1/2/3/4 são só
	cooldown (EnergyCost = 0). A barra "Energy" é a CARGA DA ULT (0..Max): enche dando/recebendo dano
	e parryando; cheia, G dispara a ULTIMATE (a Ability com EnergyCost = Max, última da lista) e ativa o
	AWAKENING (CombatConfig.Awakening: 20 s com +dano/+velocidade). HUD mostra "ULT".

	Assets esperados (por nome, ver Assets.luau):
	  Animations.<CharacterId>.<AbilityId>
	  VFX.<CharacterId>.<AbilityId>

	Slots: índice = tecla (1..4); a ultimate (EnergyCost = Max) fica por último e sai pelo G. O dash
	universal fica no Q e é de TODOS os personagens (CombatConfig.Dash, MovementService).

	Tipos de efeito (implementados em AbilityService):
	  Dash        { Speed, Duration, Damage, Range, Width, Height }  -> investida COM dano (movimento no cliente, hitbox no servidor)
	  Grab        { Speed, Duration, Range, Width, Height, Carry, Damage, Knockback?, StunSeconds?, Finish? }
	                                                                 -> investida; ao encostar SEGURA o alvo por Carry s (ele vai junto,
	                                                                    sem poder agir; o atacante não é interrompido) e solta com o golpe.
	                                                                    Finish: "Slam" (padrão) | "Throw" (arremessa para onde olha; Knockback.Up)
	                                                                    | "Chokeslam" (Lift studs erguido; esmaga + área SlamRadius/SlamDamage/SlamKnockback?)
	                                                                    | "Spin" (gira Spin voltas/s; SpinRadius/SpinDamage/SpinInterval/SpinKnockback? em
	                                                                      quem chega perto; solta na tangente)
	  Teleport    { Distance }                                       -> servidor move o HRP Distance studs para frente ATRAVESSANDO o que
	                                                                    estiver no caminho e encaixando no chão (MovementService.Teleport)
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
	AwakenedEffect: Effect?, -- versão DESPERTA (durante o Awakening); sem ela, só o buff de dano/velocidade
}

export type CharacterDef = {
	Id: string,
	DisplayName: string,
	UnlockCost: number, -- moedas; 0 = todos começam com ele (só vale com Access = "coins"/nil)
	Access: string?, -- nil/"coins" = pontos | "vip" = passe VIP (ShopConfig) | "early" = acesso antecipado (bloqueado; só devs) | "admin" = só devs, escondido dos outros
	Tagline: string?, -- subtítulo no cartão da seleção
	Color: Color3?, -- cor do personagem (cartão, rastro do dash)
	Image: string?, -- rbxassetid:// do retrato no cartão (vazio = placeholder com a inicial)
	Abilities: { AbilityDef }, -- índice = tecla (1..4); a última com EnergyCost = Max é a ultimate (G)
	DashOverride: AbilityDef?, -- substitui o dash universal (Q) por esta habilidade (Swift: Piscar); só Effect Teleport hoje
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
	SteerRate = 14, -- rad/s de correção pelo WASD durante o dash (liberdade de curvar)
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
				DisplayName = "Arremesso",
				Cooldown = 8,
				EnergyCost = 0,
				CastTime = 0.4,
				-- agarra, carrega 0,8 s e esmaga no chão
				Effect = { Type = "Grab", Finish = "Throw", Speed = 70, Duration = 0.25, Range = 6, Width = 6, Height = 6, Carry = 0.8, Damage = 16, Knockback = { Speed = 70, Duration = 0.35, Ragdoll = 1.8, Up = 25 } },
			},
			{
				Id = "GroundSlam",
				DisplayName = "Pancada no Chão",
				Cooldown = 10,
				EnergyCost = 0,
				CastTime = 0.6,
				Effect = { Type = "AreaDamage", Radius = 12, Damage = 20, Delay = 0.4, Knockback = { Speed = 40, Duration = 0.25, Ragdoll = 1.5 } },
				AwakenedEffect = { Type = "AreaDamage", Radius = 18, Damage = 26, Delay = 0.3, Knockback = { Speed = 55, Duration = 0.3, Ragdoll = 2 } },
			},
			{
				Id = "Rampage",
				DisplayName = "Fúria",
				Cooldown = 30,
				EnergyCost = 100,
				CastTime = 0.6,
				-- ultimate = golpe (o buff de dano já é do Awakening): pancada devastadora em área
				Effect = { Type = "AreaDamage", Radius = 10, Damage = 30, Delay = 0.5, Knockback = { Speed = 50, Duration = 0.3, Ragdoll = 2 } },
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
		-- Swift não tem dash: o Q é o Piscar (teleport curto, decisão do dono 2026-09-16)
		DashOverride = {
			Id = "Blink",
			DisplayName = "Piscar",
			Cooldown = 5,
			EnergyCost = 0,
			CastTime = 0.15,
			Effect = { Type = "Teleport", Distance = 18 },
		},
		Abilities = {
			{
				Id = "SweepKick",
				DisplayName = "Rasteira",
				Cooldown = 8,
				EnergyCost = 0,
				CastTime = 0.4,
				Effect = { Type = "AreaDamage", Radius = 8, Damage = 12, Delay = 0.2, StunSeconds = 0.8 },
				AwakenedEffect = { Type = "AreaDamage", Radius = 11, Damage = 16, Delay = 0.15, StunSeconds = 1.2, Knockback = { Speed = 30, Duration = 0.2, Ragdoll = 1.2 } },
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
				AwakenedEffect = { Type = "Projectile", Speed = 110, Range = 90, Radius = 5, Damage = 22, Knockback = { Speed = 45, Duration = 0.25, Ragdoll = 1.2 } },
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
				DisplayName = "Esmagar",
				Cooldown = 8,
				EnergyCost = 0,
				CastTime = 0.4,
				-- chokeslam: ergue no escudo 0,8 s e esmaga no chão; quem está perto do impacto toma área
				Effect = { Type = "Grab", Finish = "Chokeslam", Lift = 5, Speed = 55, Duration = 0.22, Range = 6, Width = 7, Height = 6, Carry = 0.8, Damage = 14, Knockback = { Speed = 10, Duration = 0.15, Ragdoll = 1.5 }, SlamRadius = 8, SlamDamage = 10, SlamKnockback = { Speed = 35, Duration = 0.2 } },
			},
			{
				Id = "Fortify",
				DisplayName = "Fortificar",
				Cooldown = 18,
				EnergyCost = 0,
				CastTime = 0.3,
				Effect = { Type = "Shield", Multiplier = 0.4, Duration = 6 },
				AwakenedEffect = { Type = "Shield", Multiplier = 0.2, Duration = 8 },
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
				AwakenedEffect = { Type = "AreaDamage", Radius = 15, Damage = 24, Delay = 0.25, Knockback = { Speed = 60, Duration = 0.3, Ragdoll = 2 } },
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

	-- Personagem de ADMIN (Access = "admin"): só devs veem/usam; números absurdos para testar sistemas.
	Overlord = {
		Id = "Overlord",
		DisplayName = "Overlord",
		UnlockCost = 0,
		Access = "admin",
		Tagline = "Só admin: teste de sistemas",
		Color = Color3.fromRGB(255, 80, 200),
		Image = "",
		Abilities = {
			{
				Id = "Smite",
				DisplayName = "Golpe Divino",
				Cooldown = 1,
				EnergyCost = 0,
				CastTime = 0.1,
				Effect = { Type = "AreaDamage", Radius = 20, Damage = 60, Delay = 0.1, Knockback = { Speed = 60, Duration = 0.3, Ragdoll = 2 } },
			},
			{
				Id = "Warp",
				DisplayName = "Teleporte Longo",
				Cooldown = 1,
				EnergyCost = 0,
				CastTime = 0.1,
				Effect = { Type = "Teleport", Distance = 60 },
			},
			{
				Id = "Clutch",
				DisplayName = "Giro Devastador",
				Cooldown = 2,
				EnergyCost = 0,
				CastTime = 0.2,
				Effect = { Type = "Grab", Finish = "Spin", Spin = 1.25, Speed = 90, Duration = 0.4, Range = 10, Width = 10, Height = 8, Carry = 1.6, Damage = 30, Knockback = { Speed = 80, Duration = 0.35, Ragdoll = 2.5, Up = 15 }, SpinRadius = 9, SpinDamage = 6, SpinInterval = 0.3, SpinKnockback = { Speed = 30, Duration = 0.15 } },
			},
			{
				Id = "Cataclysm",
				DisplayName = "Cataclismo",
				Cooldown = 5,
				EnergyCost = 100,
				CastTime = 0.5,
				Effect = { Type = "MultiHitArea", Radius = 30, Damage = 25, Hits = 4, Interval = 0.3, Knockback = { Speed = 70, Duration = 0.3, Ragdoll = 2 } },
			},
		},
	} :: CharacterDef,
	-- FORMA DE BOSS (ritual da flecha, BossFormService): não aparece na seleção (fora de Order, Access "form").
	-- O jogador vira o Notorious B.I.G. (rig por peças, BossRigs) com muita vida; todo mundo caça ele.
	NotoriousBIG = {
		Id = "NotoriousBIG",
		DisplayName = "Notorious B.I.G.",
		UnlockCost = 0,
		Access = "form",
		Tagline = "Stand de carne — não morre, só cresce",
		Color = Color3.fromRGB(196, 66, 108),
		Image = "",
		Abilities = {
			{
				Id = "Devour",
				DisplayName = "Devorar",
				Cooldown = 6,
				EnergyCost = 0,
				CastTime = 0.5,
				-- investida pesada: quem está na frente é atropelado e cai
				Effect = { Type = "Dash", Speed = 62, Duration = 0.45, Damage = 24, Range = 10, Width = 12, Height = 10, Knockback = { Speed = 55, Duration = 0.3, Ragdoll = 1.6 } },
			},
			{
				Id = "Crush",
				DisplayName = "Esmagar",
				Cooldown = 9,
				EnergyCost = 0,
				CastTime = 0.7,
				Effect = { Type = "AreaDamage", Radius = 16, Damage = 30, Delay = 0.5, Knockback = { Speed = 60, Duration = 0.3, Ragdoll = 1.8 } },
			},
			{
				Id = "FleshWave",
				DisplayName = "Onda de Carne",
				Cooldown = 14,
				EnergyCost = 0,
				CastTime = 0.8,
				-- anel de choque: expulsa quem fica colado batendo
				Effect = { Type = "AreaDamage", Radius = 22, Damage = 22, Delay = 0.7, Knockback = { Speed = 75, Duration = 0.35, Ragdoll = 2 } },
			},
			{
				Id = "Frenzy",
				DisplayName = "Frenesi",
				Cooldown = 30,
				EnergyCost = 100,
				CastTime = 0.6,
				-- ultimate: mordidas em sequência em volta
				Effect = { Type = "MultiHitArea", Radius = 14, Damage = 9, Hits = 6, Interval = 0.3 },
			},
		},
	} :: CharacterDef,
}

CharacterDefs.Order = { "Brawler", "Swift", "Mystic", "Guardian", "Sahur", "Overlord" }

--- "coins" | "vip" | "early" | "admin" | "form" (só via ritual, nunca selecionável)
function CharacterDefs.AccessOf(def: CharacterDef): string
	return def.Access or "coins"
end

function CharacterDefs.Get(characterId: string): CharacterDef?
	return CharacterDefs.Characters[characterId]
end

--- Habilidade que substitui o dash universal (Q) deste personagem, se houver.
function CharacterDefs.GetDashOverride(characterId: string): AbilityDef?
	local def = CharacterDefs.Get(characterId)
	return def and def.DashOverride
end

function CharacterDefs.GetAbility(characterId: string, slot: number): AbilityDef?
	local def = CharacterDefs.Characters[characterId]
	if not def then
		return nil
	end
	return def.Abilities[slot]
end

return CharacterDefs
