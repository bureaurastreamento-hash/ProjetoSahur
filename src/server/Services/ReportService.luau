--!strict
--[[
	ReportService (servidor)
	Denúncia de jogador: motivo predefinido (ReportConfig.Reasons) + texto livre, gravado no
	DataStore por alvo (chave = UserId do denunciado). O menu DEV (AdminService.GetReports/
	GetReportsByName) lê essa lista; ninguém decide nada aqui além de validar e gravar.

	Guarda só as últimas ReportConfig.MaxReportsPerTarget denúncias por alvo (lista, mais
	recente primeiro). Falha do DataStore não derruba o jogador, só avisa.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local ReportConfig = require(Modules:WaitForChild("ReportConfig"))

local ReportService = {}

local STORE_NAME = "Reports_v1"
local windowLimiter = RateLimiter.new(ReportConfig.MaxPerWindow, ReportConfig.WindowSeconds)
local lastReportAt: { [Player]: number } = {}

local store: DataStore? = nil
local function getStore(): DataStore?
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		store = if ok then result else false :: any
	end
	return if store then store :: DataStore else nil
end

export type ReportEntry = {
	reporter: string,
	reporterId: number,
	reason: string,
	text: string,
	at: number,
	jobId: string,
}

--- Lê as denúncias gravadas contra um UserId. Falha do DataStore devolve lista vazia + a mensagem de erro.
function ReportService.GetReports(userId: number): ({ ReportEntry }, string?)
	local s = getStore()
	if not s then
		return {}, "DataStore indisponível"
	end
	local ok, result = pcall(function()
		return s:GetAsync(tostring(userId))
	end)
	if not ok then
		return {}, tostring(result)
	end
	if typeof(result) ~= "table" then
		return {}, nil
	end
	return result :: { ReportEntry }, nil
end

local function submit(reporter: Player, targetName: any, reasonId: any, text: any)
	if typeof(targetName) ~= "string" or typeof(reasonId) ~= "string" then
		return
	end
	if not ReportConfig.IsValidReason(reasonId) then
		Remotes.GetEvent(Remotes.Events.NotifyReport):FireClient(reporter, false, "motivo inválido")
		return
	end
	local target: Player? = nil
	local lowered = targetName:lower()
	for _, p in Players:GetPlayers() do
		if p.Name:lower() == lowered or p.DisplayName:lower() == lowered then
			target = p
			break
		end
	end
	if not target then
		Remotes.GetEvent(Remotes.Events.NotifyReport):FireClient(reporter, false, "jogador não encontrado no servidor")
		return
	end
	if target == reporter then
		Remotes.GetEvent(Remotes.Events.NotifyReport):FireClient(reporter, false, "não dá pra se denunciar")
		return
	end
	local last = lastReportAt[reporter] or 0
	if os.clock() - last < ReportConfig.CooldownSeconds then
		Remotes.GetEvent(Remotes.Events.NotifyReport):FireClient(reporter, false, "espere um pouco antes de denunciar de novo")
		return
	end
	if not windowLimiter:Allow(reporter) then
		Remotes.GetEvent(Remotes.Events.NotifyReport):FireClient(reporter, false, "muitas denúncias; tente mais tarde")
		return
	end

	local cleanText = if typeof(text) == "string" then text:gsub("^%s+", ""):gsub("%s+$", ""):sub(1, ReportConfig.MaxTextLength) else ""

	local s = getStore()
	if not s then
		Remotes.GetEvent(Remotes.Events.NotifyReport):FireClient(reporter, false, "DataStore indisponível (Studio: ligue 'Enable Studio Access to API Services')")
		return
	end
	lastReportAt[reporter] = os.clock()

	local entry: ReportEntry = {
		reporter = reporter.Name,
		reporterId = reporter.UserId,
		reason = reasonId,
		text = cleanText,
		at = os.time(),
		jobId = game.JobId,
	}
	local ok, err = pcall(function()
		s:UpdateAsync(tostring(target.UserId), function(old)
			local list = if typeof(old) == "table" then old else {}
			table.insert(list, 1, entry)
			while #list > ReportConfig.MaxReportsPerTarget do
				table.remove(list)
			end
			return list
		end)
	end)
	if not ok then
		warn(("[ReportService] falha ao gravar denúncia de %s contra %s: %s"):format(reporter.Name, target.Name, tostring(err)))
		Remotes.GetEvent(Remotes.Events.NotifyReport):FireClient(reporter, false, "não gravou a denúncia: " .. tostring(err))
		return
	end
	Log.debug(("[ReportService] %s denunciou %s (%s)"):format(reporter.Name, target.Name, reasonId))
	Remotes.GetEvent(Remotes.Events.NotifyReport):FireClient(reporter, true, "denúncia enviada, obrigado")
end

function ReportService.Start()
	Remotes.GetEvent(Remotes.Events.RequestReport).OnServerEvent:Connect(function(player, targetName, reasonId, text)
		local ok, err = pcall(function()
			submit(player, targetName, reasonId, text)
		end)
		if not ok then
			warn(("[ReportService] erro em RequestReport(%s): %s"):format(player.Name, tostring(err)))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastReportAt[player] = nil
	end)
end

return ReportService
