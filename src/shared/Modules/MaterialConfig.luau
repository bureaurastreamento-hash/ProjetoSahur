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
	fibra_antiga = { Name = "Fibra Antiga", Rarity = "Raro", Color = Color3.fromRGB(179, 153, 98), Desc = "Cai raramente dos inimigos fortes do acampamento dos Campos da Névoa." },
	nucleo_marinho = { Name = "Núcleo Marinho", Rarity = "Relíquia", Color = Color3.fromRGB(85, 207, 210), Desc = "Recompensa única do enigma das lentes, na costa do Porto da Névoa. O diário junto das lentes contém a pista." },
	selo_solar = { Name = "Selo Solar", Rarity = "Relíquia", Color = Color3.fromRGB(245, 190, 84), Desc = "Recompensa única por alinhar os mecanismos da Câmara do Deserto do Sol." },
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

export type Recipe = { Id: string, Name: string, Weapon: string, Needs: { [string]: number }, Coins: number, MinLevel: number, RequiresFlag: string?, SecretHint: string? }

--- Forja (Ferreiro da vila). Needs usa o id do item no inventário ("mat:<id>").
MaterialConfig.Recipes = {
	{ Id = "sabre_portuario", Name = "Sabre Portuário", Weapon = "sabre_portuario", Coins = 80, MinLevel = 3, Needs = { ["mat:nevoa"] = 8 } },
	{ Id = "espada_caramujo", Name = "Espada do Caramujo", Weapon = "espada_caramujo", Coins = 280, MinLevel = 8, Needs = { ["mat:fibra_antiga"] = 3, ["mat:couro_capataz"] = 4, ["mat:nevoa"] = 25 } },
	{ Id = "lamina_mares", Name = "Lâmina das Marés", Weapon = "lamina_mares", Coins = 1200, MinLevel = 15,
		RequiresFlag = "relic_lentes_solved", SecretHint = "Resolva o diário das três lentes na costa do Porto da Névoa.",
		Needs = { ["mat:nucleo_marinho"] = 1, ["mat:fibra_antiga"] = 8, ["mat:lasca_mascara"] = 5, ["mat:nevoa"] = 80 } },
	{ Id = "espada_sol_selado", Name = "Espada do Sol Selado", Weapon = "espada_sol_selado", Coins = 1800, MinLevel = 22,
		RequiresFlag = "camara_transferencia_preparada", SecretHint = "Alinhe os mecanismos da Câmara do Deserto.",
		Needs = { ["mat:selo_solar"] = 1, ["mat:aco_estelar"] = 2, ["mat:areia_negra"] = 60, ["mat:lasca_mascara"] = 8 } },
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
