--[[
	ModConfig — a FICHA do mod. Obrigatório em todo mod.
	Id: igual ao nome da pasta (minúsculas, números e _). Kind: rules | character | cosmetic | vfx | sfx | map.
	Rules (só Kind = rules): HealthMult (≤ 4), DamageMult (≤ 3), NoCooldown, Gravity, WalkSpeedMult (≤ 2), JumpMult,
	ClockHour (0–24), AllCharacters, NoAbilities, BossEveryMinutes, DestructionOff.
	Exclusive: nome de grupo — só um mod do grupo fica ligado por vez (ex.: "gravidade").
]]
return {
	Id = "exemplo_mod",
	Name = "Exemplo (personagem + capa + efeito)",
	Author = "SeuNick", -- aparece nos créditos do painel
	AuthorUserId = 0,
	Version = "1.0",
	Kind = "character", -- este exemplo traz um personagem; Cosmetics/VFX extras também carregam
	Desc = "Um personagem de exemplo com duas habilidades e uma ult, uma capa e um efeito.",
	-- Rules = { DamageMult = 1.5 }, -- só para Kind = "rules"
	-- Exclusive = "dano",
}
