--!strict
--[[
	CombatConfig
	Números do combate. Lido pelo servidor (autoridade) e pelo cliente (só feedback/timing).
	Rig alvo: R6.
]]

local CombatConfig = {}

CombatConfig.MaxHealth = 100
CombatConfig.RespawnTime = 3
CombatConfig.WalkSpeed = 16

-- Ataques disponíveis. Chave = attackId enviado pelo cliente em RequestAttack.
CombatConfig.Attacks = {
	M1 = {
		Damage = 8, -- dano dos golpes normais do combo
		FinisherDamage = 15, -- dano do último golpe do combo
		ComboLength = 4,
		Cooldown = 0.35, -- entre golpes do combo
		ComboEndCooldown = 0.9, -- depois do finisher
		ComboResetTime = 1.2, -- sem golpear por esse tempo, combo volta pro 1
		HitDelay = 0.15, -- tempo entre o pedido e a checagem da hitbox (wind-up)
		-- Hitbox (studs) à frente do HumanoidRootPart do atacante
		Range = 7,
		Width = 5,
		Height = 6,
		MaxTargets = 3,
	},
}

CombatConfig.Block = {
	DamageMultiplier = 0.3, -- dano que passa enquanto bloqueia
	WalkSpeed = 8,
	ParryWindow = 0.2, -- segundos após iniciar o block em que um golpe recebido vira parry
	ParryStun = 1.0, -- tempo que o atacante fica sem poder agir após ser parryado
	Cooldown = 0.4, -- tempo mínimo entre soltar e voltar a bloquear (evita spam de parry)
}

-- Animações são buscadas por NOME em ReplicatedStorage.Assets.Animations.Shared
-- (ver Assets.luau): M1_1, M1_2, M1_3, M1_4, Block, Parry, Hit

return CombatConfig
