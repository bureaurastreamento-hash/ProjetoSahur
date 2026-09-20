--!strict
--[[
	ModsConfig — CATÁLOGO de mods APROVADOS (dono, 2026-09-22).
	Só o que está aqui existe para o jogo: nada vem do cliente. Mods entram assim: a comunidade cria na place
	de criação (kit oficial, ver MODS_KIT.md), manda a place + ficha pelo Discord, a equipe confere a lista de
	exigências, sobe os assets para o GRUPO e adiciona a entrada aqui (+ pasta ServerStorage.Mods.<Id> quando
	o mod traz asset). Só o DONO do servidor privado escolhe os mods da sala dele (ModService); em servidor
	privado NADA salva. Créditos ao autor aparecem no painel.

	Kind:
	  "rules"     — regras de sala (só números/flags; sem asset). Rules = { Chave = valor } aplicadas pelo
	                ModService: HealthMult, DamageMult, NoCooldown, Gravity, WalkSpeedMult, JumpMult,
	                ClockHour (hora congelada), AllCharacters, NoAbilities (só socos), BossEveryMinutes,
	                DestructionOff, StreakAuraFrom.
	  "character" — personagem novo (ServerStorage.Mods.<Id>.CharacterDef + rig/animações) — em breve
	  "cosmetic"  — skin/cosmético (ServerStorage.Mods.<Id>.Cosmetics) — em breve
	  "vfx"/"sfx" — efeitos (VFXLibrary/Sounds do mod) — em breve
	  "map"       — mapa/props (ServerStorage.Mods.<Id>.Map) — em breve
	`Exclusive` = só um mod desse grupo ativo por vez (ex.: dois "gravidade" não fazem sentido).
]]

local ModsConfig = {}

export type Mod = {
	Id: string,
	Name: string,
	Author: string, -- nick de quem fez (créditos no painel)
	AuthorUserId: number?,
	Version: string,
	Desc: string,
	Kind: string,
	Rules: { [string]: any }?,
	Exclusive: string?,
	Approved: string, -- data da aprovação (YYYY-MM-DD)
}

ModsConfig.Catalog = {
	{ Id = "vida_dobrada", Name = "Vida dobrada", Author = "FX_Bacons", Version = "1.0", Kind = "rules", Approved = "2026-09-22",
		Desc = "Todo mundo com o dobro de vida. Lutas mais longas.", Rules = { HealthMult = 2 }, Exclusive = "vida" },
	{ Id = "vida_metade", Name = "Morte súbita", Author = "FX_Bacons", Version = "1.0", Kind = "rules", Approved = "2026-09-22",
		Desc = "Metade da vida. Um combo decide.", Rules = { HealthMult = 0.5 }, Exclusive = "vida" },
	{ Id = "dano_x2", Name = "Dano x2", Author = "FX_Bacons", Version = "1.0", Kind = "rules", Approved = "2026-09-22",
		Desc = "Todo golpe causa o dobro.", Rules = { DamageMult = 2 }, Exclusive = "dano" },
	{ Id = "sem_cooldown", Name = "Sem cooldown", Author = "FX_Bacons", Version = "1.0", Kind = "rules", Approved = "2026-09-22",
		Desc = "Habilidades e dash sem espera. Caos.", Rules = { NoCooldown = true } },
	{ Id = "so_socos", Name = "Só na mão", Author = "FX_Bacons", Version = "1.0", Kind = "rules", Approved = "2026-09-22",
		Desc = "Sem habilidades nem ult: só M1, block, parry e dash.", Rules = { NoAbilities = true } },
	{ Id = "gravidade_lua", Name = "Gravidade da Lua", Author = "FX_Bacons", Version = "1.0", Kind = "rules", Approved = "2026-09-22",
		Desc = "Pulos altos, quedas lentas. Combos aéreos.", Rules = { Gravity = 60, JumpMult = 1.4 }, Exclusive = "gravidade" },
	{ Id = "velocidade", Name = "Modo acelerado", Author = "FX_Bacons", Version = "1.0", Kind = "rules", Approved = "2026-09-22",
		Desc = "Todo mundo 40% mais rápido.", Rules = { WalkSpeedMult = 1.4 } },
	{ Id = "noite_eterna", Name = "Noite eterna", Author = "FX_Bacons", Version = "1.0", Kind = "rules", Approved = "2026-09-22",
		Desc = "Sempre noite: o altar aceita a flecha a qualquer hora.", Rules = { ClockHour = 22 }, Exclusive = "hora" },
	{ Id = "meio_dia", Name = "Meio-dia eterno", Author = "FX_Bacons", Version = "1.0", Kind = "rules", Approved = "2026-09-22",
		Desc = "Sempre dia, sem ritual.", Rules = { ClockHour = 13 }, Exclusive = "hora" },
	{ Id = "todos_personagens", Name = "Todos os personagens", Author = "FX_Bacons", Version = "1.0", Kind = "rules", Approved = "2026-09-22",
		Desc = "Todo mundo pode usar qualquer personagem (só nesta sala; nada é salvo).", Rules = { AllCharacters = true } },
	{ Id = "boss_frequente", Name = "Boss a cada 10 min", Author = "FX_Bacons", Version = "1.0", Kind = "rules", Approved = "2026-09-22",
		Desc = "O Big C.H.O.P. nasce no santuário a cada 10 minutos.", Rules = { BossEveryMinutes = 10 } },
	{ Id = "cenario_fixo", Name = "Cenário indestrutível", Author = "FX_Bacons", Version = "1.0", Kind = "rules", Approved = "2026-09-22",
		Desc = "Casas e árvores não quebram.", Rules = { DestructionOff = true } },
} :: { Mod }

function ModsConfig.Get(id: string): Mod?
	for _, mod in ModsConfig.Catalog do
		if mod.Id == id then
			return mod
		end
	end
	return nil
end

return ModsConfig
