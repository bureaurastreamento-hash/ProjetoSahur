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
	JumpPower; BossService.Summon periódico; DestructionService.Enabled).
	Mods de ASSET (character/cosmetic/vfx/sfx/map): a pasta ServerStorage.Mods.<Id> é clonada para
	ReplicatedStorage.ModsActive.<Id> (Map vai para Workspace.ModMaps.<Id>); o ModRegistry (compartilhado)
	injeta CharacterDef/Cosmetics/VFX nos módulos dos dois lados e copia Animations/Sounds/VFX para os Assets.
	Personagem de mod: todo mundo da sala ganha (nada salva); ao desligar, quem estava com ele volta ao padrão.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local ModsConfig = require(Modules:WaitForChild("ModsConfig"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local ModRegistry = require(Modules:WaitForChild("ModRegistry"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AbilityService = require(script.Parent:WaitForChild("AbilityService"))
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

ModService.SourceFolderName = "Mods" -- ServerStorage.Mods.<Id>
ModService.MapFolderName = "ModMaps" -- Workspace.ModMaps.<Id>

-- ---------------------------------------------------------------------------
-- Mods de asset: clonar/retirar a pasta do mod
-- ---------------------------------------------------------------------------

local function sourceFolder(id: string): Instance?
	local mods = ServerStorage:FindFirstChild(ModService.SourceFolderName)
	return mods and mods:FindFirstChild(id)
end

-- Mods "de teste" (SÓ no Studio): toda pasta ServerStorage.Mods.<Id> com um ModConfig válido entra no painel
-- mesmo sem estar no catálogo — é assim que a equipe testa o que a comunidade mandou antes de aprovar.
local testMods: { [string]: ModsConfig.Mod } = {}
local testOrder: { string } = {}

local function scanTestMods()
	table.clear(testMods)
	table.clear(testOrder)
	if not RunService:IsStudio() then
		return
	end
	local mods = ServerStorage:FindFirstChild(ModService.SourceFolderName)
	if not mods then
		return
	end
	for _, folder in mods:GetChildren() do
		local module = folder:FindFirstChild("ModConfig")
		if not folder:IsA("Folder") or not module or not module:IsA("ModuleScript") then
			continue
		end
		local ok, cfg = pcall(require, module)
		if not ok or typeof(cfg) ~= "table" then
			warn(("[ModService] %s.ModConfig não carregou: %s"):format(folder.Name, tostring(cfg)))
			continue
		end
		if cfg.Id ~= folder.Name then
			warn(("[ModService] %s.ModConfig.Id ('%s') precisa ser igual ao nome da pasta"):format(folder.Name, tostring(cfg.Id)))
			continue
		end
		if ModsConfig.Get(folder.Name) then
			continue -- já aprovado: vale o catálogo
		end
		testMods[folder.Name] = {
			Id = folder.Name,
			Name = tostring(cfg.Name or folder.Name),
			Author = tostring(cfg.Author or "?"),
			AuthorUserId = tonumber(cfg.AuthorUserId),
			Version = tostring(cfg.Version or "0"),
			Desc = tostring(cfg.Desc or ""),
			Kind = tostring(cfg.Kind or "rules"),
			Rules = if typeof(cfg.Rules) == "table" then cfg.Rules else nil,
			Exclusive = if typeof(cfg.Exclusive) == "string" then cfg.Exclusive else nil,
			Approved = "teste (Studio)",
		}
		table.insert(testOrder, folder.Name)
	end
	table.sort(testOrder)
end

--- Entrada do catálogo ou, no Studio, mod de teste da pasta ServerStorage.Mods.
function ModService.Entry(id: string): ModsConfig.Mod?
	return ModsConfig.Get(id) or testMods[id]
end

local function ensureFolder(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

--- Copia ServerStorage.Mods.<Id> para ReplicatedStorage.ModsActive.<Id> (o ModRegistry carrega a partir daí)
--- e o Map (se houver) para Workspace.ModMaps.<Id>. (ok, mensagem)
local function mountAssets(mod: ModsConfig.Mod): (boolean, string)
	local src = sourceFolder(mod.Id)
	if not src then
		return false, ("pasta ServerStorage.%s.%s não existe no place"):format(ModService.SourceFolderName, mod.Id)
	end
	local root = ensureFolder(ReplicatedStorage, ModRegistry.FolderName)
	if root:FindFirstChild(mod.Id) then
		return true, "já montado"
	end
	local copy = Instance.new("Folder")
	copy.Name = mod.Id
	for _, child in src:GetChildren() do
		if child.Name == "Map" then
			if child:IsA("Model") or child:IsA("Folder") then
				local map: Instance = child:Clone()
				map.Name = mod.Id
				map.Parent = ensureFolder(Workspace, ModService.MapFolderName)
			end
		elseif child:IsA("Script") or child:IsA("LocalScript") then
			warn(("[ModService] %s: '%s' é Script — ignorado (kit: só ModuleScripts de dados)"):format(mod.Id, child.Name))
		else
			child:Clone().Parent = copy
		end
	end
	copy.Parent = root -- ModRegistry.load roda aqui (ChildAdded)
	-- personagem de mod: todo mundo da sala ganha (nada salva em servidor privado)
	for _, player in Players:GetPlayers() do
		for _, charId in ModRegistry.CharactersOf(mod.Id) do
			DataService.GrantCharacter(player, charId)
		end
	end
	return true, "montado"
end

local function unmountAssets(mod: ModsConfig.Mod)
	local chars = ModRegistry.CharactersOf(mod.Id)
	local root = ReplicatedStorage:FindFirstChild(ModRegistry.FolderName)
	local folder = root and root:FindFirstChild(mod.Id)
	if folder then
		folder:Destroy() -- ModRegistry.unload roda aqui (ChildRemoved)
	end
	local maps = Workspace:FindFirstChild(ModService.MapFolderName)
	local map = maps and maps:FindFirstChild(mod.Id)
	if map then
		map:Destroy()
	end
	for _, player in Players:GetPlayers() do
		for _, charId in chars do
			if player:GetAttribute("CharacterId") == charId then
				AbilityService.ForceCharacter(player, CharacterDefs.DefaultCharacter)
			end
			DataService.RevokeCharacter(player, charId)
		end
	end
end

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
		local mod = ModService.Entry(id)
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
		local mod = ModService.Entry(id)
		if mod then
			table.insert(list, { id = mod.Id, name = mod.Name, author = mod.Author })
		end
	end
	local extra = {}
	for _, id in testOrder do
		local mod = testMods[id]
		table.insert(extra, { id = mod.Id, name = mod.Name, author = mod.Author, version = mod.Version, desc = mod.Desc, kind = mod.Kind })
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
		extra = extra, -- mods de teste (Studio): o painel acrescenta as linhas
	}
end

local function broadcast()
	for _, player in Players:GetPlayers() do
		notifyMods:FireClient(player, payloadFor(player))
	end
end

--- Liga/desliga um mod do catálogo. (ok, mensagem)
function ModService.Set(player: Player?, id: string, enabled: boolean): (boolean, string)
	local mod = ModService.Entry(id)
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
		if mod.Kind ~= "rules" then
			local okMount, why = mountAssets(mod)
			if not okMount then
				return false, why
			end
		end
		-- exclusivo: desliga o outro do mesmo grupo
		if mod.Exclusive then
			local others = table.clone(ModsConfig.Catalog)
			for _, tid in testOrder do
				table.insert(others, testMods[tid])
			end
			for _, other in others do
				if other.Id ~= id and other.Exclusive == mod.Exclusive and active[other.Id] then
					active[other.Id] = nil
					local idx = table.find(activeOrder, other.Id)
					if idx then
						table.remove(activeOrder, idx)
					end
					if other.Kind ~= "rules" then
						unmountAssets(other)
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
		if mod.Kind ~= "rules" then
			unmountAssets(mod)
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
	ModRegistry.Start()
	scanTestMods()
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
					for _, id in activeOrder do
						for _, charId in ModRegistry.CharactersOf(id) do
							DataService.GrantCharacter(player, charId)
						end
					end
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
		Log.debug(("[ModService] servidor público: painel só para devs (%d mods no catálogo, %d de teste)"):format(#ModsConfig.Catalog, #testOrder))
	end
end

return ModService
