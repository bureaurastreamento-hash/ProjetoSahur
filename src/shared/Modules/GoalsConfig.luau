--!strict
-- Apresentação de metas reais do perfil, sem novas recompensas ou decisões no cliente.
local Progression = require(script.Parent.ProgressionConfig)
local Materials = require(script.Parent.MaterialConfig)
local Stands = require(script.Parent.StandConfig)
local Factions = require(script.Parent.FactionConfig)
local Bounty = require(script.Parent.BountyConfig)
local Config = {}
export type Row = { title: string, text: string }
function Config.Rows(profile: any): { Row }
	local rows: { Row } = {}
	if profile.level < Progression.MaxLevel then
		table.insert(rows, { title = "Próximo nível", text = ("Nível %d → %d · XP %d/%d. Treine nos Campos, enfrente chefes ou continue a campanha.")
			:format(profile.level, profile.level + 1, profile.xp, Progression.XPForLevel(profile.level)) })
	end
	if Stands.IsStand(profile.power or "") then
		local xp = profile.mastery[profile.power] or 0
		local level = Progression.MasteryLevel(xp)
		local nextLevel: number? = nil
		local nextSlots = {}
		for slot = 1, 5 do
			local required = Stands.RequiredMastery(profile.power, slot)
			if required and required > level then
				if not nextLevel or required < nextLevel then nextLevel = required; nextSlots = {} end
				if required == nextLevel then table.insert(nextSlots, if slot == 5 then "R" else tostring(slot)) end
			end
		end
		if nextLevel then
			table.insert(rows, { title = "Próxima habilidade do Stand", text = ("Maestria %d → %d · teclas %s · faltam %d XP de maestria. Use esse Stand contra inimigos válidos.")
				:format(level, nextLevel, table.concat(nextSlots, ", "), math.max(0, (nextLevel - 1) * Progression.Mastery.PerLevel - xp)) })
		end
	end
	local recipes = table.clone(Materials.Recipes)
	table.sort(recipes, function(a, b) return a.MinLevel < b.MinLevel end)
	for _, recipe in recipes do
		if profile.build.weapon ~= recipe.Weapon and (profile.inventory["arma:" .. recipe.Weapon] or 0) == 0 then
			local lines = { ("Nível %d/%d · Moedas %d/%d · Forja no Ferreiro da Vila Nova."):format(profile.level, recipe.MinLevel, profile.coins, recipe.Coins) }
			if recipe.RequiresFlag and not profile.story.flags[recipe.RequiresFlag] then table.insert(lines, recipe.SecretHint or "Descubra o projeto secreto.") end
			local keys = {}; for item in recipe.Needs do table.insert(keys, item) end; table.sort(keys)
			for _, item in keys do
				local info = Materials.Get(item:sub(5))
				table.insert(lines, ("%s: %d/%d%s"):format(if info then info.Name else item, profile.inventory[item] or 0, recipe.Needs[item],
					if info then " · " .. info.Desc else ""))
			end
			table.insert(rows, { title = "Forjar " .. recipe.Name, text = table.concat(lines, "\n") })
		end
	end
	local government = profile.faction == Factions.Government
	local points = if government then profile.honor.points else profile.bounty.points
	for _, tier in Bounty.Tiers do
		if tier.Points > points then
			table.insert(rows, { title = "Próximo título de " .. (if government then "honra" else "bounty"),
				text = ("%s · %d/%d. Vitórias válidas %s. Contratos estão no menu Caçadas."):format(
					if government then Factions.HonorTitle(tier.Points) else tier.Title, points, tier.Points,
					if government then "contra Fora da Lei de nível próximo" else "no PvP de mundo aberto com nível próximo") })
			break
		end
	end
	table.insert(rows, { title = "Explorar além da campanha", text = "Procure Rastros e investigações opcionais. Confira o Mural de Rumores da Vila Nova para os eventos deste servidor: Mercador Errante, esferas e ilhas secretas." })
	return rows
end
return Config
