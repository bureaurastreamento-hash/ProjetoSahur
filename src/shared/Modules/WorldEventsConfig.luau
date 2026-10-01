--!strict
--[[
	WorldEventsConfig — coisas que só acontecem com o SERVIDOR de pé por horas (dono, 30/09: "servidor tem que ter
	6 horas pra um comerciante aparecer… ilhas fantasmas depois de puzzle do server todo… com aviso na tela/mural
	da vila pra não ficar impossível"). Tudo é do servidor (WorldEventsService); o relógio é o tempo desde que o
	servidor abriu (Workspace.ServerStartTime) + o que o DEV pular (Workspace.WorldEventsSkew).

	  Mercador Errante  — aparece às 6 h e depois a cada 3 h, fica 25 min num dos pontos; estoque sorteado na
	                      chegada (Aço Estelar só às vezes). Limite por jogador por visita.
	  Esferas Estreladas — a partir de 2 h, 7 esferas escondidas pelas 3 ilhas. Quem achar pega; quando o SERVIDOR
	                      juntar as 7, a Ilhota do Mestre (Kame) aparece como ilha fantasma por 30 min.
	  Obeliscos do Sol  — a partir de 4 h, 4 obeliscos no Deserto acendem SÓ À NOITE e ficam acesos 75 s: os 4 ao
	                      mesmo tempo (cooperação) abrem o Cânion Fantasma no céu por 30 min (portal no Deserto).
	  Mural de Rumores  — placa na praça da vila com dicas e contadores (simples, para não ficar impossível).
	Posições são XZ; o serviço acha o chão livre por raycast em volta de cada ponto.
]]

local WorldEventsConfig = {}

local H, M = 3600, 60

WorldEventsConfig.Merchant = {
	Name = "Mercador Errante",
	FirstAt = 6 * H,
	Every = 3 * H,
	Stay = 25 * M,
	Range = 14,
	Spots = {
		{ Name = "cais do Porto da Névoa", XZ = Vector2.new(-10, 225) },
		{ Name = "planície oeste do Deserto do Sol", XZ = Vector2.new(760, -380) },
		{ Name = "estrada da Rota do Eclipse", XZ = Vector2.new(1780, -200) },
	},
	-- Chance = de ESTAR no estoque desta visita; Limit = quantas vezes cada jogador compra por visita.
	Stock = {
		{ Id = "aco_estelar", Item = "mat:aco_estelar", Amount = 1, Price = 1500, Chance = 0.25, Limit = 1 },
		{ Id = "flecha", Item = "flecha", Amount = 1, Price = 900, Chance = 0.5, Limit = 1 },
		{ Id = "lasca", Item = "mat:lasca_mascara", Amount = 1, Price = 350, Chance = 0.4, Limit = 2 },
		{ Id = "couro", Item = "mat:couro_capataz", Amount = 2, Price = 180, Chance = 0.8, Limit = 3 },
		{ Id = "nevoa", Item = "mat:nevoa", Amount = 10, Price = 120, Chance = 0.9, Limit = 3 },
	},
}

WorldEventsConfig.Orbs = {
	UnlockAt = 2 * H,
	Count = 7,
	IslandStay = 30 * M, -- quanto tempo a Ilhota do Mestre fica visível
	Cooldown = 3 * H, -- depois que ela some, quanto até as esferas voltarem
	Reward = { Coins = 300, Items = { flecha = 1 } }, -- baú da ilhota (1x por jogador por aparição)
}

WorldEventsConfig.Obelisks = {
	UnlockAt = 4 * H,
	Count = 4,
	LitSeconds = 75,
	CanyonStay = 30 * M,
	Cooldown = 2 * H,
	-- baú do Cânion (1x por jogador por abertura); Aço Estelar é raro
	Reward = { Coins = 250, Items = { ["mat:areia_negra"] = 5 }, Rare = { Item = "mat:aco_estelar", Chance = 0.1 } },
	PortalXZ = Vector2.new(720, -470), -- perto do Deserto (o serviço procura chão livre em volta)
	Enemies = 6, -- Espectros do Cânion (tier 4) em volta dos spawns do evento
}

WorldEventsConfig.Forge = {
	Name = "Ferreiro",
	XZ = Vector2.new(100, 160), -- vila do Porto da Névoa
	Range = 12,
}

WorldEventsConfig.Mural = {
	XZ = Vector2.new(-5, 110), -- praça da vila
}

--- Ilha secreta do Mestre (Kame): tudo do Workspace dentro desta elipse some no início e volta na aparição.
WorldEventsConfig.Kame = { Center = Vector2.new(-450, 560), RadiusX = 330, RadiusZ = 170 }

function WorldEventsConfig.FormatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m = seconds // 3600, (seconds % 3600) // 60
	if h > 0 then
		return ("%dh%02d"):format(h, m)
	end
	return ("%d min"):format(math.max(1, m))
end

require(script.Parent.IslandLayout).TranslateTable(WorldEventsConfig)
return WorldEventsConfig
