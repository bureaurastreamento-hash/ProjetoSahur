--!strict
--[[
	TournamentConfig — evento de admin "ÚLTIMO DE PÉ" (dono, D3 2026-09-23): o DEV abre a inscrição, quem entra
	luta no MAPA LIVRE mesmo (sem arena separada); quem morre por QUALQUER causa sai; sobra 1 grupo = vence.
	Modos: solo (cada um por si), duo (duplas formadas na ordem de inscrição), clan (time = clã; sem clã não entra).
	Prêmio: pontos + pontos de evento + XP (+ cosmético opcional, id de CosmeticsConfig). Robux/payout = FUTURO
	(só anotado; nada aqui). "Morte súbita" (área que encolhe) = FUTURO; hoje o limite de tempo empata (ninguém
	ganha, sem prêmio).
]]

local TournamentConfig = {}

export type Mode = "solo" | "duo" | "clan"
export type Reward = { Coins: number, EventPoints: number, XP: number, Cosmetic: string? }

TournamentConfig.Modes = {
	solo = { Label = "SOLO", TeamSize = 1 },
	duo = { Label = "DUPLAS", TeamSize = 2 },
	clan = { Label = "CLÃS", TeamSize = 0 }, -- 0 = time = clã inteiro (quem se inscrever)
} :: { [string]: { Label: string, TeamSize: number } }

TournamentConfig.SignupSeconds = 90 -- inscrição aberta
TournamentConfig.CountdownSeconds = 10 -- contagem depois de fechar (todos já marcados)
TournamentConfig.MaxSeconds = 600 -- duração máxima; estoura = empate (FUTURO: morte súbita)
TournamentConfig.MinTeams = 2 -- menos que isso ao iniciar = cancela
TournamentConfig.MinPlayers = 2

-- prêmio padrão (o DEV pode trocar pelo painel: `TournamentOpen { mode, coins, eventPoints, cosmetic }`)
TournamentConfig.DefaultReward = { Coins = 1500, EventPoints = 300, XP = 800 } :: Reward

-- Atributos no Player enquanto está inscrito/vivo (lidos por HealthService — dano entre companheiros não vale —
-- e pelo cliente): Tournament = true; TournamentTeam = "<id do time>".
TournamentConfig.AttrIn = "Tournament"
TournamentConfig.AttrTeam = "TournamentTeam"

return TournamentConfig
