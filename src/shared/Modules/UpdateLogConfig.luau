--!strict
--[[
	UpdateLogConfig
	LOG DE ATUALIZAÇÃO do jogo (D4, dono 2026-09-23): a cada atualização grande o dev escreve aqui a versão
	e a lista de novidades; depois escolhe QUANDO mostrar pelo menu DEV ("Publicar novidades"). Cada jogador vê
	a tela de novidades UMA vez por versão publicada (profile.lastUpdateSeen) e pode rever no menu Config →
	Novidades. Nada aqui é decidido pelo cliente: o UpdateLogService lê este módulo e o DataStore de publicação.

	Regras de texto: português, curto, sem nome de plataforma externa (nunca escrever "Discord").
	`Current` = a versão que o botão DEV "Publicar novidades" publica (a mais nova da lista, normalmente).
]]

local UpdateLogConfig = {}

export type Entry = {
	Version: string, -- ex.: "1.1" (comparação é por igualdade de string, não numérica)
	Title: string, -- manchete curta
	Date: string, -- "AAAA-MM-DD"
	Items: { string }, -- bullets em português
}

UpdateLogConfig.Versions = ({
	{
		Version = "1.1",
		Title = "Stands, novo esquema de golpes e bots",
		Date = "2026-09-25",
		Items = {
			"Cada personagem agora tem 4 ataques (1–4), uma passiva na tecla R e a ULT no G.",
			"Ao despertar, os 4 ataques viram o kit desperto até a ult acabar.",
			"Jotaro, Dio e Kira: o Stand aparece de verdade — na cutscene da ult e socando nas rajadas.",
			"Bruno Gollini, Rick e os outros ganharam kits novos, coerentes com o personagem.",
			"Bots de treino no mapa: só revidam quando apanham (peça a um dev para deixar agressivos).",
			"Capítulo final da história: o traidor está à solta e é mais forte que o Big C.H.O.P.",
		},
	},
	{
		Version = "1.0",
		Title = "Lançamento do mapa livre",
		Date = "2026-09-22",
		Items = {
			"Mapa livre: todo mundo luta o tempo todo, sem filas nem rodadas.",
			"Santuário do boss dentro da muralha sul; a flecha transforma quem a achar no Big C.H.O.P. à noite.",
			"Cenário destrutível: construções desabam tijolo a tijolo e árvores tombam.",
			"Taberna com os murais da história e da equipe; vendedor da Lojinha com trocas entre jogadores.",
			"Clãs com patentes, guerra de clã, duelos 1v1 e 2v2 com ranking.",
		},
	},
} :: { Entry })

-- versão que "Publicar novidades" publica
UpdateLogConfig.Current = "1.1"

function UpdateLogConfig.Get(version: string): Entry?
	for _, entry in UpdateLogConfig.Versions do
		if entry.Version == version then
			return entry
		end
	end
	return nil
end

return UpdateLogConfig
