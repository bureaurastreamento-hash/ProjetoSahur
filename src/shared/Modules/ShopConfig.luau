--!strict
--[[
	ShopConfig
	Catálogo da loja (ShopService no servidor, ShopController/ShopGui no cliente).
	  Products: Developer Products (compra repetível): giros da roleta de cosméticos (rolls) ou
	            "escolher cosmético" (pick = 1: o item pendente em CosmeticsService); coins > 0 daria
	            pontos, mas a moeda do jogo é PONTOS ganhos jogando (kills/duelos/boss) — não se vende.
	  Passes:   Game Passes (compra única) com um perk cada.
	Ids = 0 -> item aparece como "em breve" e não pode ser comprado. O dono cria os
	produtos/passes no Creator Dashboard (jogo do GRUPO) e cola os ids aqui.
	Personagens continuam sendo comprados com pontos (CharacterDefs.UnlockCost).
]]

export type Product = {
	key: string,
	productId: number,
	coins: number, -- pontos dados (0 = nenhum)
	name: string,
	rolls: number?, -- giros da roleta de cosméticos
	pick: boolean?, -- cosmético à escolha (CosmeticsService.pendingPick)
}

export type Pass = {
	key: string,
	gamepassId: number,
	name: string,
	desc: string,
}

local ShopConfig = {}

ShopConfig.Products = ({
	{ key = "roll_1", productId = 0, coins = 0, rolls = 1, name = "1 giro da roleta" },
	{ key = "roll_5", productId = 0, coins = 0, rolls = 5, name = "5 giros da roleta" },
	{ key = "pick", productId = 0, coins = 0, pick = true, name = "Cosmético à escolha" },
}) :: { Product }

ShopConfig.Passes = ({
	{ key = "double_coins", gamepassId = 0, name = "Pontos x2", desc = "Dobra os pontos de kills, duelos, boss e missões" },
	{ key = "all_characters", gamepassId = 0, name = "Todos os personagens", desc = "Desbloqueia todos os personagens (inclui o Guardian VIP)" },
	{ key = "vip", gamepassId = 0, name = "VIP", desc = "Personagem Guardian, tag VIP no nome e +25% de XP" },
	{ key = "private_plus", gamepassId = 0, name = "Servidor privado+", desc = "No SEU servidor privado: sem cooldowns e bonecos à vontade (treino)" },
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
