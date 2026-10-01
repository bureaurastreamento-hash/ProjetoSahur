--!strict
--[[
	LaunchConfig — modo PRÉ-LANÇAMENTO (dono, 2026-10-01).
	Antes do lançamento o jogo NÃO é jogável: quem entra vê a tela de título com "Play Intro" (trailer ao vivo, só no
	cliente de quem clicou) e depois fica no LOBBY DE TESTES no Coliseu do Deserto — testa o combate e os Stands
	contra bonecos, vê o que vem aí e pode doar Robux para o desenvolvimento. O resto do mapa fica fechado (quem sai do
	Coliseu volta), história/facção/objetivos ficam desligados. Devs (AdminConfig) jogam normal; o botão DEV
	"Ver como jogador" liga o modo para o próprio dev testar. A tela inicial também aparece para devs,
	com acesso ao mundo e ao lobby; o servidor valida a alternância pelo RequestLaunch.
	Lançou → PreLaunch = false e o jogo inteiro volta, sem mais nada para mudar.
	Nada daqui mexe no perfil salvo: o Stand de teste vale só na sessão.
]]

local LaunchConfig = {}

LaunchConfig.PreLaunch = true

-- Lobby = Coliseu do Deserto (WorldConfig.Regions.arena_pvp)
LaunchConfig.LobbyRegion = "arena_pvp"
LaunchConfig.LobbyCheckpoint = "praca"
LaunchConfig.LobbyCenter = Vector3.new(901, 0, -339)
LaunchConfig.LobbyRadius = 112 -- arena + arquibancada (XZ); fora disso volta para o centro
LaunchConfig.LobbyBots = 4 -- bonecos de treino (bots com o combate real, só revidam)

-- Stands que dá para testar no lobby (kits de CharacterDefs; só na sessão)
LaunchConfig.TestKits = { "Humano", "Swift", "Jotaro", "Kira", "Dio" }

-- Doações (Developer Products do GRUPO: o dono cria no Creator Hub e cola o id; 0 = "em breve")
export type Donation = { key: string, amount: number, productId: number }
LaunchConfig.Donations = {
	{ key = "donate_10", amount = 10, productId = 3715867985 },
	{ key = "donate_50", amount = 50, productId = 3715867991 },
	{ key = "donate_100", amount = 100, productId = 3715867993 },
	{ key = "donate_500", amount = 500, productId = 3715868000 },
	{ key = "donate_1000", amount = 1000, productId = 3715868004 },
} :: { Donation }
LaunchConfig.DonationStore = "Donations_v1" -- total por jogador + recibos (idempotente)
LaunchConfig.DonationBoard = "DonationsTop_v1" -- OrderedDataStore do placar
LaunchConfig.BoardSize = 10

LaunchConfig.Title = "BIZARRE SHOWDOWN F/X"
LaunchConfig.Tagline = "EM DESENVOLVIMENTO  ·  LOBBY DE TESTES"

-- Transparência (dono, 2026-10-01)
LaunchConfig.Notice = {
	"Por enquanto usamos IA para criar as imagens (capas e miniaturas). Com mais orçamento, vamos contratar artistas.",
	"A ideia do jogo e do grupo é totalmente original, com inspirações assumidas.",
}

-- "O que vem aí" (painel do lobby)
LaunchConfig.Features = {
	"Campanha do Capítulo 1: 6 ilhas e 31 missões",
	"Stands pela Flecha: 7 raridades, sem pity",
	"Combate de battlegrounds: combo, parry, Black Flash, despertar",
	"Chefes do mundo com loot por ranking de dano",
	"Facções: Fora da Lei x Governo, bounty e caçadores",
	"Barcos entre as ilhas, forja de armas e segredos",
	"Eventos do mundo: mercador, ilhas fantasmas, obeliscos",
}

--- Jogador está preso ao lobby? (pré-lançamento e não é dev — ou dev com "Ver como jogador" ligado)
function LaunchConfig.Locked(player: Player): boolean
	if not LaunchConfig.PreLaunch then
		return false
	end
	if player:GetAttribute("PreLaunchView") == true then
		return true
	end
	return player:GetAttribute("IsDeveloper") ~= true
end

function LaunchConfig.GetDonation(key: string): Donation?
	for _, d in LaunchConfig.Donations do
		if d.key == key then
			return d
		end
	end
	return nil
end

function LaunchConfig.DonationByProduct(productId: number): Donation?
	for _, d in LaunchConfig.Donations do
		if d.productId > 0 and d.productId == productId then
			return d
		end
	end
	return nil
end

return LaunchConfig
