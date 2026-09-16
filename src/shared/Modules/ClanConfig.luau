--!strict
--[[
	ClanConfig
	Regras dos clãs (ClanService). O clã é a unidade da futura guerra de clã/dominação:
	tag no nome, cofre de pontos (paga as guerras/recompensas) e placar por clã.
]]

local ClanConfig = {}

ClanConfig.CreateCost = 500 -- pontos para fundar
ClanConfig.MaxMembers = 20
ClanConfig.NameMin = 3
ClanConfig.NameMax = 20
ClanConfig.TagMin = 2
ClanConfig.TagMax = 4 -- só letras/números; vira maiúscula; é o id único do clã
ClanConfig.DepositMin = 10 -- pontos por depósito no cofre
ClanConfig.InviteSeconds = 30 -- convite expira
ClanConfig.Roles = { "member", "officer", "leader" } -- ordem crescente de poder
ClanConfig.RoleNames = { member = "Membro", officer = "Oficial", leader = "Líder" }

export type Member = { name: string, role: string, joinedAt: number }
export type Clan = {
	tag: string,
	name: string,
	leader: number, -- userId
	members: { [string]: Member }, -- userId (string) -> membro
	vault: number, -- pontos no cofre
	wins: number, -- guerras vencidas (futuro)
	createdAt: number,
}

function ClanConfig.RoleRank(role: string): number
	return table.find(ClanConfig.Roles, role) or 1
end

function ClanConfig.MemberCount(clan: Clan): number
	local n = 0
	for _ in clan.members do
		n += 1
	end
	return n
end

--- Normaliza/valida a tag digitada. Retorna a tag em maiúsculas ou nil + motivo.
function ClanConfig.NormalizeTag(raw: any): (string?, string?)
	if typeof(raw) ~= "string" then
		return nil, "tag inválida"
	end
	local tag = raw:upper():gsub("%s", "")
	if #tag < ClanConfig.TagMin or #tag > ClanConfig.TagMax then
		return nil, ("a tag precisa ter de %d a %d caracteres"):format(ClanConfig.TagMin, ClanConfig.TagMax)
	end
	if not tag:match("^[A-Z0-9]+$") then
		return nil, "a tag só pode ter letras e números"
	end
	return tag, nil
end

function ClanConfig.NormalizeName(raw: any): (string?, string?)
	if typeof(raw) ~= "string" then
		return nil, "nome inválido"
	end
	local name = raw:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	if #name < ClanConfig.NameMin or #name > ClanConfig.NameMax then
		return nil, ("o nome precisa ter de %d a %d caracteres"):format(ClanConfig.NameMin, ClanConfig.NameMax)
	end
	if not name:match("^[%w%s%-_'.]+$") then
		return nil, "o nome tem caracteres inválidos"
	end
	return name, nil
end

return ClanConfig
