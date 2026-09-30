--!strict
--[[
	MaterialConfig — materiais de farm/drop (item "mat:<id>" no inventário) e receitas da FORJA (dono, 30/09:
	"horas e horas pra valer a pena… comerciante com chance de vender tal item pra construir a katana rara").
	Drops: ProgressionConfig.Npcs[kind].Drops; Aço Estelar só no Mercador Errante (WorldEventsService).
	Receita = materiais + moedas → arma (BuildConfig.Weapons). Números iniciais para balancear no teste.
]]

local MaterialConfig = {}

export type Material = { Name: string, Desc: string, Color: Color3, Rarity: string }

MaterialConfig.Items = {
	nevoa = { Name = "Essência da Névoa", Rarity = "Comum", Color = Color3.fromRGB(170, 200, 220),
		Desc = "Névoa que não se desfaz na mão. Cai dos Vagantes dos Campos da Névoa. Material de forja." },
	couro_capataz = { Name = "Couro do Capataz", Rarity = "Incomum", Color = Color3.fromRGB(150, 110, 80),
		Desc = "Tira de couro curtido do Capataz da Névoa (miniboss dos Campos). Material de forja." },
	lasca_mascara = { Name = "Lasca de Máscara", Rarity = "Raro", Color = Color3.fromRGB(220, 200, 150),
		Desc = "Pedaço do artefato do Portador da Máscara. Ainda vibra de leve. Material de forja." },
	areia_negra = { Name = "Areia Negra", Rarity = "Incomum", Color = Color3.fromRGB(90, 80, 70),
		Desc = "Areia que não reflete luz, do Deserto do Sol. Material de forja." },
	aco_estelar = { Name = "Aço Estelar", Rarity = "Lendário", Color = Color3.fromRGB(150, 180, 255),
		Desc = "Metal que ninguém sabe de onde vem. Só o Mercador Errante vende, e nem sempre tem." },
	esfera = { Name = "Esfera Estrelada", Rarity = "Lendário", Color = Color3.fromRGB(255, 170, 60),
		Desc = "Uma esfera alaranjada com estrelas dentro. Dizem que juntar todas chama algo antigo." },
} :: { [string]: Material }

export type Recipe = { Id: string, Name: string, Weapon: string, Needs: { [string]: number }, Coins: number, MinLevel: number }

--- Forja (Ferreiro da vila). Needs usa o id do item no inventário ("mat:<id>").
MaterialConfig.Recipes = {
	{ Id = "katana_fratura", Name = "Katana da Fratura", Weapon = "katana_fratura", Coins = 600, MinLevel = 12,
		Needs = { ["mat:aco_estelar"] = 1, ["mat:lasca_mascara"] = 3, ["mat:couro_capataz"] = 6, ["mat:nevoa"] = 40 } },
	{ Id = "lamina_nevoa", Name = "Lâmina da Névoa", Weapon = "lamina_nevoa", Coins = 120, MinLevel = 5,
		Needs = { ["mat:nevoa"] = 15, ["mat:couro_capataz"] = 2 } },
} :: { Recipe }

function MaterialConfig.Get(id: string): Material?
	return MaterialConfig.Items[id]
end

function MaterialConfig.Recipe(id: string): Recipe?
	for _, r in MaterialConfig.Recipes do
		if r.Id == id then
			return r
		end
	end
	return nil
end

return MaterialConfig
