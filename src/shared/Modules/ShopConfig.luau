--!strict
--[[
	ShopConfig
	Catálogo da loja (ShopService no servidor, ShopController/ShopGui no cliente).
	  Products: Developer Products (compra repetível) que dão moedas.
	  Passes:   Game Passes (compra única) com um perk cada.
	Ids = 0 -> item aparece como "em breve" e não pode ser comprado. O dono cria os
	produtos/passes no Creator Dashboard (jogo do GRUPO) e cola os ids aqui.
	Personagens continuam sendo comprados com moedas (CharacterDefs.UnlockCost).
]]

export type Product = {
	key: string,
	productId: number,
	coins: number,
	name: string,
}

export type Pass = {
	key: string,
	gamepassId: number,
	name: string,
	desc: string,
}

local ShopConfig = {}

ShopConfig.Products = ({
	{ key = "coins_500", productId = 0, coins = 500, name = "Punhado" },
	{ key = "coins_1500", productId = 0, coins = 1500, name = "Saco" },
	{ key = "coins_4000", productId = 0, coins = 4000, name = "Baú" },
}) :: { Product }

ShopConfig.Passes = ({
	{ key = "double_coins", gamepassId = 0, name = "Moedas x2", desc = "Dobra as moedas de kills, duelos, boss e missões" },
	{ key = "all_characters", gamepassId = 0, name = "Todos os personagens", desc = "Desbloqueia todos os personagens (inclui o Guardian VIP)" },
	{ key = "vip", gamepassId = 0, name = "VIP", desc = "Personagem Guardian, tag VIP no nome e +25% de XP" },
}) :: { Pass }

--- Perks lidos por outros services (via atributos Pass_<key> = true no Player).
ShopConfig.DoubleCoinsMultiplier = 2
ShopConfig.VipXpMultiplier = 1.25

function ShopConfig.GetProduct(key: string): Product?
	for _, p in ShopConfig.Products do
		if p.key == key then
			return p
		end
	end
	return nil
end

function ShopConfig.GetPass(key: string): Pass?
	for _, p in ShopConfig.Passes do
		if p.key == key then
			return p
		end
	end
	return nil
end

return ShopConfig
