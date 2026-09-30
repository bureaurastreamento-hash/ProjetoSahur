--!strict
-- Build inicial da campanha. IDs de maestria não colidem com CharacterDefs.
local BuildConfig = {}
BuildConfig.WeaponId = "espada_inicial"
BuildConfig.StyleId = "tecnica_corporal"
BuildConfig.WeaponName = "Espada de treino"
BuildConfig.StyleName = "Técnica corporal"
BuildConfig.Routes = { tecnica = true, manifestacao = true, arma = true } :: { [string]: boolean }
-- Valores iniciais para teste; não alteram alcance, cooldown, parry ou habilidades de Stand.
BuildConfig.WeaponDamage = 1.15
BuildConfig.StyleDamage = { 1.1, 1.2 }
BuildConfig.StyleIncoming = { 0.95, 0.9 }

function BuildConfig.MasteryKey(kind: string, id: string): string
	return kind .. ":" .. id
end

return BuildConfig
