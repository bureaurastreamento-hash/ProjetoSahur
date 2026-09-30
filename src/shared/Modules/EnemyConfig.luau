--!strict
--[[
	EnemyConfig — força e inteligência dos NPCs inimigos da campanha por NÍVEL (tier) da região (dono, 30/09):
	"os primeiros NPCs estão muito fortes pra quem não sabe de nada e atacam de graça". Quanto mais longe na
	campanha, mais livre e esperto o NPC: passa de passivo a reativo a agressivo, ganha bloqueio/parry, dash,
	habilidades, revide (anti-2v1), R e por fim a ult. Os iniciais são HUMANOS (kit "Humano", sem Stand).

	Comportamento (BotService):
	  passive    — só luta se apanhar (e esfria depois de AggroSeconds)
	  reactive   — também ataca quem chegar a menos de TerritoryRadius dele (território)
	  aggressive — caça quem estiver até SeekRadius
	Tuning (números; 0/1 = desligado/ligado) sobrescreve BotService.Config por bot.
	Uso: EnemyConfig.Options(tier, { Name = ..., CFrame = ..., Attributes = {...} }) → SpawnOptions do BotService.
]]

local EnemyConfig = {}

export type Tier = {
	Name: string,
	Behavior: string,
	CharacterId: string?, -- nil = quem chama escolhe (tiers altos usam kits de Stand)
	MaxHealth: number,
	DamageMult: number,
	WalkSpeed: number,
	Tuning: { [string]: number },
}

EnemyConfig.Tiers = {
	-- Ilha 1, início (Campos da Névoa, treino): humano cru. Passivo, lento para reagir, sem ult/habilidade/bloqueio.
	[1] = {
		Name = "Iniciante", Behavior = "passive", CharacterId = "Humano",
		MaxHealth = 70, DamageMult = 0.5, WalkSpeed = 14,
		Tuning = { Tick = 0.3, AbilityChancePerTick = 0, BlockChancePerTick = 0, DashChancePerTick = 0.04,
			CancelChancePerTick = 0.05, CanAwaken = 0, CanCounter = 0, UsePassive = 0, AggroSeconds = 8 },
	},
	-- Ilha 1, fim (fundo dos Campos, capangas da Máscara): ainda humano e passivo, mas bloqueia às vezes.
	[2] = {
		Name = "Comum", Behavior = "passive", CharacterId = "Humano",
		MaxHealth = 110, DamageMult = 0.7, WalkSpeed = 15,
		Tuning = { Tick = 0.22, AbilityChancePerTick = 0.03, BlockChancePerTick = 0.06, DashChancePerTick = 0.1,
			CancelChancePerTick = 0.15, CanAwaken = 0, CanCounter = 0, UsePassive = 0, AggroSeconds = 10 },
	},
	-- Ilha 2 (Deserto do Sol): reativo (território), bloqueia/apara, usa habilidades, revida no 2v1. Sem ult.
	[3] = {
		Name = "Treinado", Behavior = "reactive",
		MaxHealth = 170, DamageMult = 0.9, WalkSpeed = 16,
		Tuning = { Tick = 0.15, TerritoryRadius = 14, AbilityChancePerTick = 0.08, BlockChancePerTick = 0.14,
			DashChancePerTick = 0.2, CancelChancePerTick = 0.25, CanAwaken = 0, CanCounter = 1, UsePassive = 1, AggroSeconds = 12 },
	},
	-- Ilha 3 (Rota do Eclipse): agressivo, Stand, ult liberada (rara).
	[4] = {
		Name = "Veterano", Behavior = "aggressive",
		MaxHealth = 230, DamageMult = 1.0, WalkSpeed = 16,
		Tuning = { Tick = 0.12, SeekRadius = 40, AbilityChancePerTick = 0.12, BlockChancePerTick = 0.2,
			DashChancePerTick = 0.25, CancelChancePerTick = 0.35, CanAwaken = 1, CanCounter = 1, UsePassive = 1, AggroSeconds = 12 },
	},
	-- Ilhas 4+ (Cidade Âmbar em diante): o bot completo, mais rápido e resistente.
	[5] = {
		Name = "Elite", Behavior = "aggressive",
		MaxHealth = 300, DamageMult = 1.1, WalkSpeed = 17,
		Tuning = { Tick = 0.1, SeekRadius = 55, AbilityChancePerTick = 0.15, BlockChancePerTick = 0.25,
			DashChancePerTick = 0.3, CancelChancePerTick = 0.4, CanAwaken = 1, CanCounter = 1, UsePassive = 1, AggroSeconds = 14 },
	},
} :: { [number]: Tier }

--- Chefes ficam um tier acima dos mobs da ilha e com mais vida (multiplicador).
EnemyConfig.BossHealthMult = 3

--- SpawnOptions do BotService para um inimigo do `tier`. `base` pode trazer Name/CFrame/Team/CharacterId/
--- Attributes (FXEnemy, StoryKillKind…) e Tuning extra; o que vier em `base` ganha do tier.
function EnemyConfig.Options(tierIndex: number, base: { [string]: any }): { [string]: any }
	local tier = EnemyConfig.Tiers[math.clamp(tierIndex, 1, #EnemyConfig.Tiers)]
	local opts = table.clone(base)
	opts.Behavior = base.Behavior or tier.Behavior
	opts.CharacterId = base.CharacterId or tier.CharacterId
	local attributes = { MaxHealth = tier.MaxHealth, DamageMult = tier.DamageMult, WalkSpeed = tier.WalkSpeed, EnemyTier = tierIndex }
	for k, v in base.Attributes or {} do
		attributes[k] = v
	end
	opts.Attributes = attributes
	local tuning = table.clone(tier.Tuning)
	for k, v in base.Tuning or {} do
		tuning[k] = v
	end
	opts.Tuning = tuning
	return opts
end

return EnemyConfig
