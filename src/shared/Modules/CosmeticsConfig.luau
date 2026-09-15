--!strict
--[[
	CosmeticsConfig
	Cosméticos (skins, capas, auras) e emotes/cenas. Só visual: NUNCA dão buff.
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
	Cost: number, -- moedas; 0 = todo mundo tem
	Color: Color3?, -- capa/aura: cor; skin: cor do corpo
	Access: string?, -- nil = moedas | "vip" = passe VIP
}

CosmeticsConfig.Items = {
	-- skins (placeholder: cor do corpo até a arte chegar)
	{ Id = "skin_default", Name = "Padrão", Category = "skin", Cost = 0 },
	{ Id = "skin_shadow", Name = "Sombra", Category = "skin", Cost = 150, Color = Color3.fromRGB(40, 40, 50) },
	{ Id = "skin_ember", Name = "Brasa", Category = "skin", Cost = 300, Color = Color3.fromRGB(200, 70, 30) },
	{ Id = "skin_gold", Name = "Dourado", Category = "skin", Cost = 0, Access = "vip", Color = Color3.fromRGB(230, 190, 60) },
	-- capas
	{ Id = "cape_red", Name = "Capa Vermelha", Category = "cape", Cost = 100, Color = Color3.fromRGB(180, 30, 30) },
	{ Id = "cape_blue", Name = "Capa Azul", Category = "cape", Cost = 100, Color = Color3.fromRGB(40, 80, 200) },
	{ Id = "cape_black", Name = "Capa Negra", Category = "cape", Cost = 250, Color = Color3.fromRGB(20, 20, 25) },
	{ Id = "cape_gold", Name = "Capa Dourada", Category = "cape", Cost = 0, Access = "vip", Color = Color3.fromRGB(230, 190, 60) },
	-- auras
	{ Id = "aura_blue", Name = "Aura Azul", Category = "aura", Cost = 200, Color = Color3.fromRGB(90, 160, 255) },
	{ Id = "aura_purple", Name = "Aura Roxa", Category = "aura", Cost = 200, Color = Color3.fromRGB(180, 90, 255) },
	{ Id = "aura_green", Name = "Aura Verde", Category = "aura", Cost = 200, Color = Color3.fromRGB(110, 255, 140) },
	{ Id = "aura_gold", Name = "Aura Dourada", Category = "aura", Cost = 0, Access = "vip", Color = Color3.fromRGB(255, 210, 80) },
} :: { Item }

CosmeticsConfig.Categories = { "skin", "cape", "aura" }
CosmeticsConfig.CategoryNames = { skin = "Skins", cape = "Capas", aura = "Auras" }

export type Emote = {
	Id: string,
	Name: string,
	Kind: string, -- "emote" (só animação) | "scene" (animação + aura/VFX por Duration s)
	Cost: number,
	Duration: number?, -- cena: s da aura (a animação manda se existir)
	Color: Color3?, -- cena: cor da aura
}

-- Roda de emotes (B): até 8 posições, na ordem abaixo.
CosmeticsConfig.Emotes = {
	{ Id = "wave", Name = "Acenar", Kind = "emote", Cost = 0 },
	{ Id = "taunt", Name = "Provocar", Kind = "emote", Cost = 0 },
	{ Id = "dance", Name = "Dançar", Kind = "emote", Cost = 50 },
	{ Id = "bow", Name = "Reverência", Kind = "emote", Cost = 50 },
	{ Id = "flex", Name = "Músculo", Kind = "emote", Cost = 50 },
	{ Id = "scene_power", Name = "Cena: Despertar", Kind = "scene", Cost = 300, Duration = 5, Color = Color3.fromRGB(255, 220, 80) },
	{ Id = "scene_dark", Name = "Cena: Trevas", Kind = "scene", Cost = 300, Duration = 5, Color = Color3.fromRGB(120, 40, 200) },
	{ Id = "scene_storm", Name = "Cena: Tempestade", Kind = "scene", Cost = 300, Duration = 5, Color = Color3.fromRGB(90, 200, 255) },
} :: { Emote }

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
