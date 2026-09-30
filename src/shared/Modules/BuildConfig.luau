--!strict
-- Build inicial da campanha. IDs de maestria não colidem com CharacterDefs.
local BuildConfig = {}
BuildConfig.WeaponId = "espada_inicial" -- arma da rota "arma" (Missão 2)
BuildConfig.StyleId = "tecnica_corporal"
BuildConfig.WeaponName = "Espada de treino"
BuildConfig.StyleName = "Técnica corporal"
BuildConfig.Routes = { tecnica = true, manifestacao = true, arma = true } :: { [string]: boolean }
-- Valores iniciais para teste; não alteram alcance, cooldown, parry ou habilidades de Stand.
BuildConfig.WeaponDamage = 1.15
BuildConfig.StyleDamage = { 1.1, 1.2 }
BuildConfig.StyleIncoming = { 0.95, 0.9 }

-- Catálogo de armas (dono 30/09: "katana rara foda demais"). A equipada fica em profile.build.weapon; as outras
-- ficam na mochila como item "arma:<id>" (usar = equipar; a anterior volta para a mochila). Forja: MaterialConfig.
-- Visual provisório feito em runtime (Handle + lâmina); a arte pode trocar por modelo com o mesmo id depois.
export type Weapon = {
	Name: string,
	Rarity: string,
	Desc: string,
	Damage: number, -- multiplicador do M1 com a arma equipada
	Color: Color3,
	Material: Enum.Material,
	Length: number, -- comprimento da lâmina
	Glow: boolean?, -- lâmina com brilho (lendárias)
}
BuildConfig.Weapons = {
	espada_inicial = { Name = "Espada de treino", Rarity = "Comum", Damage = 1.15, Color = Color3.fromRGB(144, 103, 66),
		Material = Enum.Material.Wood, Length = 3.5, Desc = "Madeira dura. Serve para aprender." },
	lamina_nevoa = { Name = "Lâmina da Névoa", Rarity = "Raro", Damage = 1.3, Color = Color3.fromRGB(175, 205, 225),
		Material = Enum.Material.Metal, Length = 4, Desc = "Forjada com Essência da Névoa. Leve e fria." },
	katana_fratura = { Name = "Katana da Fratura", Rarity = "Lendário", Damage = 1.6, Color = Color3.fromRGB(150, 180, 255),
		Material = Enum.Material.Neon, Length = 4.8, Glow = true,
		Desc = "Aço Estelar dobrado com lascas da Máscara. A lâmina parece cortar um pouco de outro lugar." },
} :: { [string]: Weapon }

function BuildConfig.Weapon(id: string): Weapon?
	return BuildConfig.Weapons[id]
end

function BuildConfig.MasteryKey(kind: string, id: string): string
	return kind .. ":" .. id
end

return BuildConfig
