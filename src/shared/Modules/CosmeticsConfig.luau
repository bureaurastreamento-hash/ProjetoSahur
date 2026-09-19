--!strict
--[[
	CosmeticsConfig
	Cosméticos (capas, auras) e emotes/cenas. Só visual: NUNCA dão buff.
	`Limited = true` + `Season = "<id>"`: item de PASSE (AchievementsConfig) — sai só pelas conquistas
	daquela temporada, nunca pela roleta; acabou o passe, ninguém mais ganha (só um DEV dá).
	Aquisição = ROLETA da sorte: RollCost pontos (ganhos jogando) = 1 giro -> item aleatório que
	o jogador ainda não tem (peso = Weight; VIP fica fora da roleta). Com Robux: giros (ShopConfig
	roll_1/roll_5) ou "pick" = escolher um item específico. Weight 0 = de todos (não entra na roleta).
	Servidor (CosmeticsService) valida compra/equipar e replica por atributos no Player:
	  CosmeticCape / CosmeticAura (id do item ou "")
	Cliente (CosmeticsController) desenha capa/aura por atributo e toca emotes (NotifyEmote).

	Assets esperados (por nome, ver Assets.luau; tudo opcional):
	  Animations.Emotes.<EmoteId>   (id vazio = não toca, mas a cena ainda mostra a aura)
	  VFX.Emotes.<EmoteId>          (cena: efeito extra além da aura)
]]

local CosmeticsConfig = {}

export type Item = {
	Id: string,
	Name: string,
	Category: string, -- "cape" | "aura"
	Weight: number, -- peso na roleta (maior = mais comum); 0 = todo mundo tem
	Color: Color3?, -- capa/aura: cor
	Style: string?, -- aura: wisps | flame | smoke | sparkle | electric
	Access: string?, -- nil = moedas | "vip" = passe VIP
	Season: string?, -- LIMITADO: id da temporada (AchievementsConfig) que solta este item
	Limited: boolean?, -- true = nunca entra na roleta; acabou a temporada, só um DEV dá
}

CosmeticsConfig.Items = {
	-- (skins que pintavam o corpo saíram a pedido do dono em 2026-09-19: cosmético não muda a cor do avatar;
	--  skins de verdade entram quando a arte trouxer modelos)
	-- capas
	{ Id = "cape_red", Name = "Capa Vermelha", Category = "cape", Weight = 8, Color = Color3.fromRGB(180, 30, 30) },
	{ Id = "cape_blue", Name = "Capa Azul", Category = "cape", Weight = 8, Color = Color3.fromRGB(40, 80, 200) },
	{ Id = "cape_black", Name = "Capa Negra", Category = "cape", Weight = 3, Color = Color3.fromRGB(20, 20, 25) },
	{ Id = "cape_gold", Name = "Capa Dourada", Category = "cape", Weight = 0, Access = "vip", Color = Color3.fromRGB(230, 190, 60) },
	-- auras (Style = desenho: wisps = fiapos subindo, flame = chamas, smoke = fumaça densa, sparkle = brilhos,
	--        electric = faíscas elétricas; ver FX.SetCosmeticAura)
	{ Id = "aura_blue", Name = "Aura Azul", Category = "aura", Weight = 4, Color = Color3.fromRGB(90, 160, 255), Style = "wisps" },
	{ Id = "aura_purple", Name = "Aura Roxa", Category = "aura", Weight = 4, Color = Color3.fromRGB(180, 90, 255), Style = "electric" },
	{ Id = "aura_green", Name = "Aura Verde", Category = "aura", Weight = 4, Color = Color3.fromRGB(110, 255, 140), Style = "sparkle" },
	{ Id = "aura_ember", Name = "Aura de Brasa", Category = "aura", Weight = 0, Color = Color3.fromRGB(255, 120, 40), Style = "flame" },
	{ Id = "aura_shadow", Name = "Aura das Sombras", Category = "aura", Weight = 0, Color = Color3.fromRGB(60, 40, 80), Style = "smoke" },
	{ Id = "aura_gold", Name = "Aura Dourada", Category = "aura", Weight = 0, Access = "vip", Color = Color3.fromRGB(255, 210, 80), Style = "flame" },
	-- LIMITADOS do Passe 1 (só pelas conquistas da temporada; depois só DEV dá)
	{ Id = "s1_cape_arrow", Name = "Capa da Flecha (Passe 1)", Category = "cape", Weight = 0, Season = "s1", Limited = true, Color = Color3.fromRGB(90, 60, 170) },
	{ Id = "s1_aura_arrow", Name = "Aura da Flecha (Passe 1)", Category = "aura", Weight = 0, Season = "s1", Limited = true, Color = Color3.fromRGB(160, 110, 255), Style = "wisps" },
	{ Id = "s1_aura_arrow_gold", Name = "Aura da Flecha Dourada (Passe 1)", Category = "aura", Weight = 0, Season = "s1", Limited = true, Color = Color3.fromRGB(255, 200, 90), Style = "sparkle" },
} :: { Item }

CosmeticsConfig.Categories = { "cape", "aura" }
CosmeticsConfig.CategoryNames = { cape = "Capas", aura = "Auras" }

export type Emote = {
	Id: string,
	Name: string,
	Kind: string, -- "emote" (só animação) | "scene" (animação + aura/VFX por Duration s)
	Weight: number, -- peso na roleta; 0 = de todos (o "wave" é o padrão)
	Duration: number?, -- cena: s da aura (a animação manda se existir)
	Color: Color3?, -- cena: cor da aura
	Theme: string?, -- cena: tema de efeitos/câmera (CutsceneController THEMES: rock, lightning, arcane, stone, drums, void, flesh)
	Season: string?, -- LIMITADO: temporada que solta este emote
	Limited: boolean?, -- true = fora da roleta; acabou a temporada, só um DEV dá
}

-- Roda de emotes (B): até 8 posições, na ordem abaixo.
CosmeticsConfig.Emotes = {
	{ Id = "wave", Name = "Acenar", Kind = "emote", Weight = 0 },
	{ Id = "taunt", Name = "Provocar", Kind = "emote", Weight = 8 },
	{ Id = "dance", Name = "Dançar", Kind = "emote", Weight = 6 },
	{ Id = "bow", Name = "Reverência", Kind = "emote", Weight = 6 },
	{ Id = "flex", Name = "Músculo", Kind = "emote", Weight = 6 },
	{ Id = "sit", Name = "Sentar", Kind = "emote", Weight = 6 },
	{ Id = "scene_power", Name = "Cena: Despertar", Kind = "scene", Weight = 2, Duration = 5, Color = Color3.fromRGB(255, 220, 80), Theme = "rock" },
	{ Id = "scene_dark", Name = "Cena: Trevas", Kind = "scene", Weight = 2, Duration = 5, Color = Color3.fromRGB(120, 40, 200), Theme = "void" },
	{ Id = "scene_storm", Name = "Cena: Tempestade", Kind = "scene", Weight = 2, Duration = 5, Color = Color3.fromRGB(90, 200, 255), Theme = "lightning" },
	{ Id = "s1_emote_arrow", Name = "Flecha ao Alto (Passe 1)", Kind = "scene", Weight = 0, Duration = 4, Season = "s1", Limited = true, Color = Color3.fromRGB(160, 110, 255), Theme = "arcane" },
} :: { Emote }

CosmeticsConfig.RollCost = 100 -- pontos por giro
CosmeticsConfig.EmoteCooldown = 1.5 -- s entre emotes
CosmeticsConfig.EmoteMoveCancels = true -- andar cancela

function CosmeticsConfig.GetItem(id: string): Item?
	for _, item in CosmeticsConfig.Items do
		if item.Id == id then
			return item
		end
	end
	return nil
end

function CosmeticsConfig.GetEmote(id: string): Emote?
	for _, emote in CosmeticsConfig.Emotes do
		if emote.Id == id then
			return emote
		end
	end
	return nil
end

return CosmeticsConfig
