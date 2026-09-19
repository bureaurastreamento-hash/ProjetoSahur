--!strict
--[[
	ReportConfig
	Motivos predefinidos da denúncia (RequestReport) + limites. Usado pelo ReportController
	(cliente, monta os botões) e pelo ReportService (servidor, valida a chave recebida).
]]

export type Reason = { Id: string, Label: string }

local ReportConfig = {
	Reasons = {
		{ Id = "exploit", Label = "Hack / exploit" },
		{ Id = "toxicity", Label = "Comportamento tóxico / assédio" },
		{ Id = "name", Label = "Nome ou perfil impróprio" },
		{ Id = "spam", Label = "Spam" },
		{ Id = "bug_abuse", Label = "Abuso de bug" },
		{ Id = "other", Label = "Outro" },
	} :: { Reason },

	MaxTextLength = 200,
	MaxReportsPerTarget = 30, -- guarda só as últimas N por alvo (DataStore)
	CooldownSeconds = 30, -- entre denúncias do mesmo jogador
	MaxPerWindow = 5, -- RateLimiter: no máximo 5 em 5 min
	WindowSeconds = 300,
}

function ReportConfig.IsValidReason(id: string): boolean
	for _, r in ReportConfig.Reasons do
		if r.Id == id then
			return true
		end
	end
	return false
end

return ReportConfig
