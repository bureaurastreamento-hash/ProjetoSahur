--!strict
--[[
	TeamConfig — a EQUIPE (grupo FX_Bacons 9835819) para os NPCs de quest e o mural dos desenvolvedores.
	Gerado por tools/atualizar_equipe.py (API pública da Roblox); Function/Spot/Quote são editados à mão aqui
	e preservados por UserId quando o script roda de novo. Ordem = cargo (dono primeiro) e depois nome.
]]

local TeamConfig = {}

TeamConfig.GroupId = 9835819
TeamConfig.GroupName = "FX_Bacons"
TeamConfig.Thanks = "Obrigado a cada um que colocou a mão nesse jogo. Sem vocês o Sahur não existiria."

export type Member = { UserId: number, Username: string, DisplayName: string, Role: string, Rank: number, Function: string, Quote: string }

TeamConfig.Members = {
	{ UserId = 3792294725, Username = "humanoider_20", DisplayName = "Humanoider_20", Role = "Owner", Rank = 255, Function = "desenvolvedor", Quote = "" },
	{ UserId = 435519507, Username = "guilacartinhasgames", DisplayName = "ToduroDemais", Role = "Owner", Rank = 255, Function = "desenvolvedor", Quote = "" },
	{ UserId = 7521923542, Username = "BeasleyJavier5", DisplayName = "adryan_keep", Role = "Admin", Rank = 254, Function = "desenvolvedor", Quote = "" },
	{ UserId = 1955537372, Username = "lrydavizao", DisplayName = "LRY", Role = "Admin", Rank = 254, Function = "desenvolvedor", Quote = "" },
	{ UserId = 3751306055, Username = "Ravi132012", DisplayName = "Ravy", Role = "Admin", Rank = 254, Function = "desenvolvedor", Quote = "" },
	{ UserId = 1712538599, Username = "gaubriel567895", DisplayName = "approx_verde", Role = "Membro", Rank = 1, Function = "desenvolvedor", Quote = "" },
	{ UserId = 3352486957, Username = "fssjnjhgf", DisplayName = "RIP_ACE", Role = "Membro", Rank = 1, Function = "desenvolvedor", Quote = "" },
} :: { Member }

function TeamConfig.ByUserId(userId: number): Member?
	for _, m in TeamConfig.Members do
		if m.UserId == userId then
			return m
		end
	end
	return nil
end

return TeamConfig
