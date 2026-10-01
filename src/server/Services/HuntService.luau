--!strict
-- Contrato de sessão: alvo avisado, sem coordenadas; paga só após crédito válido da reputação.
local Players = game:GetService("Players")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.HuntConfig)
local Factions = require(Modules.FactionConfig)
local BountyConfig = require(Modules.BountyConfig)
local RateLimiter = require(Modules.RateLimiter)
local Remotes = require(Modules.RemoteEvents)
local DataService = require(script.Parent.DataService)
local BountyService = require(script.Parent.BountyService)
local ProgressionService = require(script.Parent.ProgressionService)
local HealthService = require(script.Parent.HealthService)
local Service = {}
type Contract = { target: Player, expires: number }
local active: { [Player]: Contract } = {}
local limiter = RateLimiter.new(3, 1)
local function notify(player: Player, event: string, data: any)
	if player.Parent == Players then Remotes.GetEvent(Remotes.Events.NotifyHunt):FireClient(player, event, data) end
end
local function close(hunter: Player, reason: string)
	local contract = active[hunter]
	if not contract then return end
	active[hunter] = nil
	notify(hunter, "closed", { text = reason })
	notify(contract.target, "warning", { text = "Uma caçada contra você terminou." })
end
local function targetEligible(hunter: Player, target: Player): boolean
	local p, t = DataService.GetProfile(hunter), DataService.GetProfile(target)
	if hunter == target or target.Parent ~= Players or not p or not t then return false end
	if not Factions.Valid(p.faction) or t.faction ~= Factions.Outlaw or t.bounty.points < Config.MinimumBounty then return false end
	if math.abs(p.level - t.level) > BountyConfig.MaxLevelGap then return false end
	local state = BountyConfig.Normalize(if p.faction == Factions.Government then p.honor else p.bounty, os.time())
	if state.recentVictims[tostring(target.UserId)] then return false end
	return true
end
function Service.State(hunter: Player): any
	local current: Contract? = active[hunter]
	if current and (current.expires <= os.time() or current.target.Parent ~= Players) then close(hunter, "Contrato encerrado."); current = nil end
	local targets = {}
	for _, target in Players:GetPlayers() do
		if targetEligible(hunter, target) then
			local p = DataService.GetProfile(target)
			if p then table.insert(targets, { userId = target.UserId, name = target.DisplayName, bounty = p.bounty.points, level = p.level }) end
		end
	end
	table.sort(targets, function(a, b) return a.bounty > b.bounty end)
	return { targets = targets, active = if current then { name = current.target.DisplayName, expires = current.expires } else nil,
		coins = Config.Coins, xp = Config.XP, duration = Config.Duration }
end
function Service.Accept(hunter: Player, userId: any): boolean
	if typeof(userId) ~= "number" or not (userId > 0 and userId <= 9007199254740991)
		or userId ~= math.floor(userId) or hunter.Parent ~= Players or not hunter.Character
		or not HealthService.IsAlive(hunter.Character) then return false end
	Service.State(hunter) -- expira contrato anterior antes de aceitar
	if active[hunter] then return false end
	for _, attr in { "InMatch", "Tournament", "DuelId", "WarId" } do
		if hunter:GetAttribute(attr) then return false end
	end
	local combatUntil = hunter:GetAttribute("PvpCombatUntil")
	if typeof(combatUntil) == "number" and combatUntil > workspace:GetServerTimeNow() then return false end
	local target = Players:GetPlayerByUserId(userId)
	if not target or not targetEligible(hunter, target) then return false end
	local hunters = 0
	for _, contract in active do if contract.target == target and contract.expires > os.time() then hunters += 1 end end
	if hunters >= Config.MaxHuntersPerTarget then return false end
	active[hunter] = { target = target, expires = os.time() + Config.Duration }
	notify(target, "warning", { text = "Um caçador aceitou um contrato contra você. Não há rastreamento da sua posição." })
	notify(hunter, "state", Service.State(hunter))
	return true
end
function Service.OnReward(hunter: Player, victim: Player): boolean
	local contract = active[hunter]
	if not contract or contract.target ~= victim then return false end
	local p, t = DataService.GetProfile(hunter), DataService.GetProfile(victim)
	if contract.expires <= os.time() or not p or not t or t.faction ~= Factions.Outlaw or t.bounty.points < Config.MinimumBounty then
		close(hunter, "Contrato expirado ou alvo indisponível."); return false
	end
	active[hunter] = nil -- consumir antes de conceder; sinal de bounty já deduplicou crédito/cooldown
	local coins = DataService.RewardCoins(hunter, Config.Coins)
	ProgressionService.AddXP(hunter, Config.XP, "Contrato de caçador")
	notify(hunter, "completed", { text = ("Contrato cumprido · +%d moedas · %d XP base"):format(coins, Config.XP) })
	notify(victim, "warning", { text = "Um contrato contra você foi concluído." })
	return true
end
function Service.Init()
	Remotes.GetEvent(Remotes.Events.RequestHunt).OnServerEvent:Connect(function(player, action, userId)
		if not limiter:Allow(player) then return end
		if action == "refresh" then notify(player, "state", Service.State(player))
		elseif action == "accept" then
			if not Service.Accept(player, userId) then notify(player, "denied", { text = "Contrato indisponível. Atualize a lista e confira se você está fora de combate." }) end
		elseif action == "cancel" then close(player, "Você cancelou o contrato.") end
	end)
end
function Service.Start()
	BountyService.Rewarded.Event:Connect(Service.OnReward)
	Players.PlayerRemoving:Connect(function(player)
		close(player, "Contrato encerrado ao sair.")
		for hunter, contract in active do if contract.target == player then close(hunter, "O alvo saiu do servidor.") end end
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			for hunter, contract in active do if contract.expires <= os.time() then close(hunter, "O contrato expirou.") end end
		end
	end)
end
return Service
