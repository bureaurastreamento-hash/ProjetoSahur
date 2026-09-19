--!strict
--[[
	ClanConfig
	Regras dos clãs (ClanService). O clã é a unidade da futura guerra de clã/dominação:
	tag no nome, cofre de pontos (paga as guerras/recompensas) e placar por clã.
	PATENTES (dono, 2026-09-20): o clã sobe de patente pelo TOTAL já depositado no cofre (`contributed`,
	nunca desce). Cada patente libera coisas dentro (mais vagas, quem pode SACAR do cofre e quanto por dia)
	e fora do clã (bônus de XP/pontos para os membros, cosmético exclusivo enquanto estiver no clã).
	Membro comum NUNCA saca; quem depositou também não recupera (é doação ao clã).
]]

local ClanConfig = {}

ClanConfig.CreateCost = 500 -- pontos para fundar
ClanConfig.MaxMembers = 25 -- teto absoluto (a patente manda; ver Ranks)
ClanConfig.WithdrawMin = 10
ClanConfig.NameMin = 3
ClanConfig.NameMax = 20
ClanConfig.TagMin = 2
ClanConfig.TagMax = 4 -- só letras/números; vira maiúscula; é o id único do clã
ClanConfig.DepositMin = 10 -- pontos por depósito no cofre
ClanConfig.InviteSeconds = 30 -- convite expira
ClanConfig.Roles = { "member", "officer", "leader" } -- ordem crescente de poder
ClanConfig.RoleNames = { member = "Membro", officer = "Oficial", leader = "Líder" }

export type Rank = {
	Level: number,
	Name: string,
	Points: number, -- total depositado (contributed) para chegar aqui
	MaxMembers: number,
	Withdraw: string?, -- nil = ninguém saca | "leader" | "officer" (oficial e líder)
	WithdrawCap: number, -- máximo sacado por dia (por clã)
	XpBonus: number, -- fração extra de XP para os membros (0.1 = +10%)
	CoinBonus: number, -- fração extra de pontos ganhos jogando
	Cosmetic: string?, -- item de CosmeticsConfig com Access = "clan" liberado a partir desta patente
}

ClanConfig.Ranks = {
	{ Level = 1, Name = "Bando", Points = 0, MaxMembers = 10, Withdraw = nil, WithdrawCap = 0, XpBonus = 0, CoinBonus = 0 },
	{ Level = 2, Name = "Companhia", Points = 1500, MaxMembers = 14, Withdraw = "leader", WithdrawCap = 300, XpBonus = 0.05, CoinBonus = 0 },
	{ Level = 3, Name = "Guilda", Points = 4000, MaxMembers = 18, Withdraw = "officer", WithdrawCap = 600, XpBonus = 0.10, CoinBonus = 0.05 },
	{ Level = 4, Name = "Ordem", Points = 9000, MaxMembers = 22, Withdraw = "officer", WithdrawCap = 1200, XpBonus = 0.15, CoinBonus = 0.10, Cosmetic = "cape_clan" },
	{ Level = 5, Name = "Lenda", Points = 18000, MaxMembers = 25, Withdraw = "officer", WithdrawCap = 2500, XpBonus = 0.20, CoinBonus = 0.15, Cosmetic = "aura_clan" },
} :: { Rank }

export type Member = { name: string, role: string, joinedAt: number }
export type Clan = {
	tag: string,
	name: string,
	leader: number, -- userId
	members: { [string]: Member }, -- userId (string) -> membro
	vault: number, -- pontos no cofre
	contributed: number?, -- total já depositado na vida do clã (patente); perfis antigos = nil
	withdrawDay: number?, -- dia (os.time() // 86400) do último saque
	withdrawnToday: number?, -- quanto já saiu hoje
	wins: number, -- guerras vencidas (futuro)
	createdAt: number,
}

--- Patente atual do clã (pelo total depositado).
function ClanConfig.RankOf(clan: Clan): Rank
	local total = clan.contributed or 0
	local best = ClanConfig.Ranks[1]
	for _, r in ClanConfig.Ranks do
		if total >= r.Points then
			best = r
		end
	end
	return best
end

--- Próxima patente (nil = já é a última).
function ClanConfig.NextRank(clan: Clan): Rank?
	local cur = ClanConfig.RankOf(clan)
	return ClanConfig.Ranks[cur.Level + 1]
end

--- Este cargo pode sacar do cofre nesta patente?
function ClanConfig.CanWithdraw(rank: Rank, role: string): boolean
	if rank.Withdraw == nil or role == "member" then
		return false
	end
	if rank.Withdraw == "leader" then
		return role == "leader"
	end
	return role == "officer" or role == "leader"
end

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
