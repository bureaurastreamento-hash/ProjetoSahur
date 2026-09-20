--!strict
--[[
	ModService (servidor)
	MODS de servidor privado (dono, 2026-09-22): o DONO do servidor privado (game.PrivateServerOwnerId) liga e
	desliga mods do catálogo aprovado (ModsConfig.Catalog) na sala dele. Regras:
	  - Só existe o que está no catálogo (código/assets do jogo); NADA vem do cliente.
	  - Mods só ATIVAM em servidor privado ou no Studio. Em servidor público devs (IsDeveloper) veem o painel,
	    mas o servidor recusa ligar ("só em servidor privado") — progresso público nunca é afetado.
	  - Em servidor privado NADA salva (DataService.sessionOnly), então "todos os personagens" etc. são só da sala.
	  - Todo mundo da sala recebe NotifyMods (lista ativa + créditos) para o chip "MODS: ..." e o painel.
	Kind "rules" é aplicado aqui (atributos que os outros services já leem: DevDamageMult, DevNoCooldown,
	NoAbilities, ModSpeedMult; Workspace.Gravity; EnvironmentService.SetClockOverride; humanoid MaxHealth/
	JumpPower; BossService.Summon periódico; DestructionService.Enabled). Outros Kinds: estrutura pronta
	(ServerStorage.Mods.<Id>), carregamento em breve (ver MODS_KIT.md).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local ModsConfig = require(Modules:WaitForChild("ModsConfig"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EnvironmentService = require(script.Parent:WaitForChild("EnvironmentService"))
local DestructionService = require(script.Parent:WaitForChild("DestructionService"))
local BossService = require(script.Parent:WaitForChild("BossService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))

local ModService = {}

local DEFAULT_GRAVITY = Workspace.Gravity
local active: { [string]: boolean } = {}
local activeOrder: { string } = {}
local notifyMods: RemoteEvent
local limiter = RateLimiter.new(4, 1)
local bossLoopToken = 0

-- ---------------------------------------------------------------------------
-- Permissões
-- ---------------------------------------------------------------------------

function ModService.IsPrivateServer(): boolean
	return game.PrivateServerId ~= ""
end

--- Pode LIGAR mods nesta sala? Servidor privado ou Studio.
function ModService.CanActivateHere(): boolean
	return ModService.IsPrivateServer() or RunService:IsStudio()
end

--- Pode mexer nos mods: dono do servidor privado, ou dev (AdminConfig → atributo IsDeveloper).
function ModService.CanEdit(player: Player): boolean
	if ModService.IsPrivateServer() and player.UserId == game.PrivateServerOwnerId then
		return true
	end
	return player:GetAttribute("IsDeveloper") == true
end

--- Vê o painel: todo mundo em servidor privado (só o dono edita) e devs em qualquer lugar.
function ModService.CanSee(player: Player): boolean
	return ModService.IsPrivateServer() or player:GetAttribute("IsDeveloper") == true
end

-- ---------------------------------------------------------------------------
-- Regras combinadas
-- ---------------------------------------------------------------------------

local function combinedRules(): { [string]: any }
	local rules: { [string]: any } = {}
	for _, id in activeOrder do
		local mod = ModsConfig.Get(id)
		if mod and mod.Rules then
			for k, v in mod.Rules do
				if typeof(v) == "number" and typeof(rules[k]) == "number" and (k:match("Mult$")) then
					rules[k] = rules[k] * v
				else
					rules[k] = v
				end
			end
		end
	end
	return rules
end

local function applyToCharacter(player: Player, character: Model, rules: { [string]: any })
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if character:GetAttribute("BossRig") or character:GetAttribute("MaxHealth") then
		return -- forma de boss tem a própria vida
	end
	local hm = tonumber(rules.HealthMult) or 1
	local newMax = math.floor(CombatConfig.MaxHealth * hm + 0.5)
	if humanoid.MaxHealth ~= newMax then
		local frac = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		humanoid.MaxHealth = newMax
		humanoid.Health = math.max(1, math.floor(newMax * frac + 0.5))
	end
	local jm = tonumber(rules.JumpMult) or 1
	if humanoid.UseJumpPower then
		humanoid.JumpPower = 50 * jm
	else
		humanoid.JumpHeight = 7.2 * jm
	end
end

local function applyToPlayer(player: Player, rules: { [string]: any })
	player:SetAttribute("DevDamageMult", if rules.DamageMult and rules.DamageMult ~= 1 then rules.DamageMult else nil)
	player:SetAttribute("DevNoCooldown", if rules.NoCooldown == true then true else nil)
	player:SetAttribute("NoAbilities", if rules.NoAbilities == true then true else nil)
	player:SetAttribute("ModSpeedMult", if rules.WalkSpeedMult and rules.WalkSpeedMult ~= 1 then rules.WalkSpeedMult else nil)
	if rules.AllCharacters == true then
		-- só na sessão: em servidor privado nada salva (DataService)
		for _, id in CharacterDefs.Order do
			local def = CharacterDefs.Get(id)
			if def and CharacterDefs.AccessOf(def) ~= "early" then
				DataService.GrantCharacter(player, id)
			end
		end
	end
	CombatService.RestoreWalkSpeed(player)
	local character = player.Character
	if character then
		applyToCharacter(player, character, rules)
	end
end

local function applyAll()
	local rules = combinedRules()
	Workspace.Gravity = tonumber(rules.Gravity) or DEFAULT_GRAVITY
	EnvironmentService.SetClockOverride(tonumber(rules.ClockHour))
	DestructionService.Enabled = rules.DestructionOff ~= true
	for _, player in Players:GetPlayers() do
		applyToPlayer(player, rules)
	end
	-- boss periódico
	bossLoopToken += 1
	local token = bossLoopToken
	local every = tonumber(rules.BossEveryMinutes)
	if every and every > 0 then
		task.spawn(function()
			while bossLoopToken == token do
				task.wait(every * 60)
				if bossLoopToken ~= token then
					return
				end
				local any = Players:GetPlayers()[1]
				if any then
					BossService.Summon(any)
				end
			end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Estado / rede
-- ---------------------------------------------------------------------------

local function payloadFor(player: Player?): { [string]: any }
	local list = {}
	for _, id in activeOrder do
		local mod = ModsConfig.Get(id)
		if mod then
			table.insert(list, { id = mod.Id, name = mod.Name, author = mod.Author })
		end
	end
	local ownerName = nil
	if ModService.IsPrivateServer() then
		local owner = Players:GetPlayerByUserId(game.PrivateServerOwnerId)
		ownerName = if owner then owner.Name else tostring(game.PrivateServerOwnerId)
	end
	return {
		active = list,
		private = ModService.IsPrivateServer(),
		canActivate = ModService.CanActivateHere(),
		canEdit = if player then ModService.CanEdit(player) else false,
		canSee = if player then ModService.CanSee(player) else false,
		owner = ownerName,
	}
end

local function broadcast()
	for _, player in Players:GetPlayers() do
		notifyMods:FireClient(player, payloadFor(player))
	end
end

--- Liga/desliga um mod do catálogo. (ok, mensagem)
function ModService.Set(player: Player?, id: string, enabled: boolean): (boolean, string)
	local mod = ModsConfig.Get(id)
	if not mod then
		return false, "mod desconhecido"
	end
	if player and not ModService.CanEdit(player) then
		return false, "só o dono do servidor privado (ou um dev) mexe nos mods"
	end
	if enabled and not ModService.CanActivateHere() then
		return false, "mods só ligam em servidor PRIVADO (ou no Studio)"
	end
	if enabled then
		if active[id] then
			return true, mod.Name .. " já estava ligado"
		end
		-- exclusivo: desliga o outro do mesmo grupo
		if mod.Exclusive then
			for _, other in ModsConfig.Catalog do
				if other.Id ~= id and other.Exclusive == mod.Exclusive and active[other.Id] then
					active[other.Id] = nil
					local idx = table.find(activeOrder, other.Id)
					if idx then
						table.remove(activeOrder, idx)
					end
				end
			end
		end
		active[id] = true
		table.insert(activeOrder, id)
	else
		if not active[id] then
			return true, mod.Name .. " já estava desligado"
		end
		active[id] = nil
		local idx = table.find(activeOrder, id)
		if idx then
			table.remove(activeOrder, idx)
		end
	end
	applyAll()
	broadcast()
	Log.debug(("[ModService] %s %s '%s' (por %s)"):format(if enabled then "ligou" else "desligou", if player then player.Name else "servidor", mod.Name, mod.Author))
	return true, ("%s %s"):format(mod.Name, if enabled then "ligado" else "desligado")
end

function ModService.ActiveIds(): { string }
	return table.clone(activeOrder)
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function ModService.Init()
	notifyMods = Remotes.GetEvent(Remotes.Events.NotifyMods)
	Remotes.GetEvent(Remotes.Events.RequestModToggle).OnServerEvent:Connect(function(player, id, enabled)
		if not limiter:Allow(player) or typeof(id) ~= "string" then
			return
		end
		local ok, msg = ModService.Set(player, id, enabled == true)
		notifyMods:FireClient(player, payloadFor(player), { ok = ok, message = msg })
	end)
end

function ModService.Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.delay(0.5, function()
				if #activeOrder > 0 and character.Parent then
					applyToCharacter(player, character, combinedRules())
				end
			end)
		end)
		player:GetAttributeChangedSignal("IsDeveloper"):Connect(function()
			notifyMods:FireClient(player, payloadFor(player))
		end)
		task.delay(3, function()
			if player.Parent then
				notifyMods:FireClient(player, payloadFor(player))
				if #activeOrder > 0 then
					applyToPlayer(player, combinedRules())
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	if ModService.IsPrivateServer() then
		Log.debug(("[ModService] servidor PRIVADO (dono %d): %d mods no catálogo; nada salva"):format(game.PrivateServerOwnerId, #ModsConfig.Catalog))
	else
		Log.debug(("[ModService] servidor público: painel só para devs (%d mods no catálogo)"):format(#ModsConfig.Catalog))
	end
end

return ModService
