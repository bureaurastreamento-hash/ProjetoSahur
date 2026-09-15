--!strict
--[[
	CosmeticsConfig
	Cosméticos (skins, capas, auras) e emotes/cenas. Só visual: NUNCA dão buff.
	Aquisição = ROLETA da sorte: RollCost pontos (ganhos jogando) = 1 giro -> item aleatório que
	o jogador ainda não tem (peso = Weight; VIP fica fora da roleta). Com Robux: giros (ShopConfig
	roll_1/roll_5) ou "pick" = escolher um item específico. Weight 0 = de todos (não entra na roleta).
	Servidor (CosmeticsService) valida compra/equipar e replica por atributos no Player:
	  CosmeticSkin / CosmeticCape / CosmeticAura (id do item ou "")
	Cliente (CosmeticsController) desenha capa/aura por atributo e toca emotes (NotifyEmote).

	Assets esperados (por nome, ver Assets.luau; tudo opcional):
	  Animations.Emotes.<EmoteId>   (id vazio = não toca, mas a cena ainda mostra a aura)
	  VFX.Emotes.<EmoteId>          (cena: efeito extra além da aura)
	  Skins: a equipe de arte fornece; até lá "skin" = cores do corpo (BodyColors).
]]

local CosmeticsConfig = {}

export type Item = {
	Id: string,
	Name: string,
	Category: string, -- "skin" | "cape" | "aura"
	Weight: number, -- peso na roleta (maior = mais comum); 0 = todo mundo tem
	Color: Color3?, -- capa/aura: cor; skin: cor do corpo
	Access: string?, -- nil = moedas | "vip" = passe VIP
}

CosmeticsConfig.Items = {
	-- skins (placeholder: cor do corpo até a arte chegar)
	{ Id = "skin_default", Name = "Padrão", Category = "skin", Weight = 0 },
	{ Id = "skin_shadow", Name = "Sombra", Category = "skin", Weight = 6, Color = Color3.fromRGB(40, 40, 50) },
	{ Id = "skin_ember", Name = "Brasa", Category = "skin", Weight = 3, Color = Color3.fromRGB(200, 70, 30) },
	{ Id = "skin_gold", Name = "Dourado", Category = "skin", Weight = 0, Access = "vip", Color = Color3.fromRGB(230, 190, 60) },
	-- capas
	{ Id = "cape_red", Name = "Capa Vermelha", Category = "cape", Weight = 8, Color = Color3.fromRGB(180, 30, 30) },
	{ Id = "cape_blue", Name = "Capa Azul", Category = "cape", Weight = 8, Color = Color3.fromRGB(40, 80, 200) },
	{ Id = "cape_black", Name = "Capa Negra", Category = "cape", Weight = 3, Color = Color3.fromRGB(20, 20, 25) },
	{ Id = "cape_gold", Name = "Capa Dourada", Category = "cape", Weight = 0, Access = "vip", Color = Color3.fromRGB(230, 190, 60) },
	-- auras
	{ Id = "aura_blue", Name = "Aura Azul", Category = "aura", Weight = 4, Color = Color3.fromRGB(90, 160, 255) },
	{ Id = "aura_purple", Name = "Aura Roxa", Category = "aura", Weight = 4, Color = Color3.fromRGB(180, 90, 255) },
	{ Id = "aura_green", Name = "Aura Verde", Category = "aura", Weight = 4, Color = Color3.fromRGB(110, 255, 140) },
	{ Id = "aura_gold", Name = "Aura Dourada", Category = "aura", Weight = 0, Access = "vip", Color = Color3.fromRGB(255, 210, 80) },
} :: { Item }

CosmeticsConfig.Categories = { "skin", "cape", "aura" }
CosmeticsConfig.CategoryNames = { skin = "Skins", cape = "Capas", aura = "Auras" }

export type Emote = {
	Id: string,
	Name: string,
	Kind: string, -- "emote" (só animação) | "scene" (animação + aura/VFX por Duration s)
	Weight: number, -- peso na roleta; 0 = de todos (o "wave" é o padrão)
	Duration: number?, -- cena: s da aura (a animação manda se existir)
	Color: Color3?, -- cena: cor da aura
}

-- Roda de emotes (B): até 8 posições, na ordem abaixo.
CosmeticsConfig.Emotes = {
	{ Id = "wave", Name = "Acenar", Kind = "emote", Weight = 0 },
	{ Id = "taunt", Name = "Provocar", Kind = "emote", Weight = 8 },
	{ Id = "dance", Name = "Dançar", Kind = "emote", Weight = 6 },
	{ Id = "bow", Name = "Reverência", Kind = "emote", Weight = 6 },
	{ Id = "flex", Name = "Músculo", Kind = "emote", Weight = 6 },
	{ Id = "scene_power", Name = "Cena: Despertar", Kind = "scene", Weight = 2, Duration = 5, Color = Color3.fromRGB(255, 220, 80) },
	{ Id = "scene_dark", Name = "Cena: Trevas", Kind = "scene", Weight = 2, Duration = 5, Color = Color3.fromRGB(120, 40, 200) },
	{ Id = "scene_storm", Name = "Cena: Tempestade", Kind = "scene", Weight = 2, Duration = 5, Color = Color3.fromRGB(90, 200, 255) },
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
