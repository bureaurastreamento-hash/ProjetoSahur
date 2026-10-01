--!strict
--[[
	WorldEventsService (servidor) — eventos que dependem do SERVIDOR ficar de pé por horas (WorldEventsConfig):
	Mercador Errante, Esferas Estreladas → Ilhota do Mestre (Kame, ilha fantasma), Obeliscos do Sol → Cânion
	Fantasma, Ferreiro (forja de armas com materiais) e o Mural de Rumores na vila. Tudo que ele cria em runtime
	fica em Workspace.EventosMundo (nada disso vai para o mapa/Rojo). A Kame começa ESCONDIDA (ServerStorage)
	e só volta na aparição; o Cânion é clonado de ServerStorage.EventMaps.canion (o mesmo do EventService).
	Relógio: Workspace.ServerStartTime (servidor abriu) + Workspace.WorldEventsSkew (DEV pula horas).
	DEV (AdminService): WorldSkipHour, WorldMerchant, WorldOrbs, WorldKame, WorldCanyon.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local Config = require(Modules:WaitForChild("WorldEventsConfig"))
local MaterialConfig = require(Modules:WaitForChild("MaterialConfig"))
local BuildConfig = require(Modules:WaitForChild("BuildConfig"))
local StandConfig = require(Modules:WaitForChild("StandConfig"))
local EnemyConfig = require(Modules:WaitForChild("EnemyConfig"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))

local WorldEventsService = {}

local notifyShop: RemoteEvent
local announceRemote: RemoteEvent
local limiter = RateLimiter.new(6, 1)
local rng = Random.new()
local folder: Folder
local startTime = 0

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

function WorldEventsService.Uptime(): number
	local skew = Workspace:GetAttribute("WorldEventsSkew")
	return Workspace:GetServerTimeNow() - startTime + (if typeof(skew) == "number" then skew else 0)
end
local uptime = WorldEventsService.Uptime

local function announce(text: string)
	announceRemote:FireAllClients(text, "server", "Rumor")
end

local function toast(player: Player, title: string, text: string)
	Remotes.GetEvent(Remotes.Events.NotifyQuest):FireClient(player, "toast", { title = title, text = text })
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function isDev(player: Player): boolean
	return player:GetAttribute("IsDeveloper") == true
end

--- Chão livre perto de `xz` (raycast de cima; só chão baixo e plano, caixa `size` sem nada em cima).
local function findGround(xz: Vector2, radius: number, size: Vector3): Vector3?
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	rp.FilterDescendantsInstances = ignore
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	local sahur = Workspace:FindFirstChild("Sahur")
	local chao = sahur and sahur:FindFirstChild("ChaoIlhas")
	op.FilterDescendantsInstances = if chao then { chao, folder, Workspace.Terrain } else { folder, Workspace.Terrain }
	for i = 0, 30 do
		local off = if i == 0 then Vector2.zero else Vector2.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * radius
		local x, z = xz.X + off.X, xz.Y + off.Y
		local hit = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), rp)
		if hit and hit.Instance ~= Workspace.Terrain and hit.Normal.Y > 0.85 and hit.Position.Y > -1.5 and hit.Position.Y < 6 then
			local box = CFrame.new(hit.Position + Vector3.new(0, size.Y / 2 + 0.3, 0))
			if #Workspace:GetPartBoundsInBox(box, size, op) == 0 then
				return hit.Position
			end
		end
	end
	return nil
end

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function prompt(parent: Instance, action: string, object: string, hold: number, distance: number): ProximityPrompt
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText, pr.ObjectText = action, object
	pr.HoldDuration, pr.MaxActivationDistance, pr.RequiresLineOfSight = hold, distance, false
	pr.Parent = parent
	return pr
end

--- NPC parado R6 (em pé sobre `ground`, posicionado pela RAIZ).
local function staticNpc(name: string, ground: Vector3, facing: Vector3, parent: Instance): (Model?, BasePart?)
	local ok, npc = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if not ok or not npc then
		return nil, nil
	end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		npc:Destroy()
		return nil, nil
	end
	npc.Name = name
	humanoid.DisplayName = name
	for _, d in npc:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	root.Anchored = true
	local pos = ground + Vector3.new(0, 3, 0)
	root.CFrame = CFrame.lookAt(pos, Vector3.new(facing.X, pos.Y, facing.Z))
	npc.Parent = parent
	return npc, root
end

local function giveItem(player: Player, item: string, amount: number): boolean
	return DataService.AddItem(player, item, amount)
end

local function itemName(item: string): string
	local info = StandConfig.ItemInfo(item)
	return if info then info.Name else item
end

local function teleport(player: Player, pos: Vector3)
	local root = rootOf(player)
	if not root then
		return
	end
	AntiExploitService.Grace(player, 3)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
end

local function homeSpawn(): Vector3
	local sahur = Workspace:FindFirstChild("Sahur")
	local spot = sahur and sahur:FindFirstChild("TutorialSpawn", true)
	return if spot and spot:IsA("BasePart") then spot.Position else Vector3.new(40, 2, 185)
end

--- Efeito de "ilha fantasma": realce pálido e as peças surgindo/sumindo aos poucos.
local function ghost(roots: { Instance }, appear: boolean, seconds: number)
	for _, r in roots do
		local hl = r:FindFirstChild("Fantasma")
		if appear and not hl then
			local h = Instance.new("Highlight")
			h.Name = "Fantasma"
			h.FillColor, h.OutlineColor = Color3.fromRGB(190, 225, 255), Color3.fromRGB(230, 245, 255)
			h.FillTransparency, h.OutlineTransparency = 0.8, 0.35
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = r
		end
		for _, d in (if r:IsA("BasePart") then { r } else r:GetDescendants()) :: { Instance } do
			if d:IsA("BasePart") then
				local original = d:GetAttribute("FantasmaT")
				if typeof(original) ~= "number" then
					original = d.Transparency
					d:SetAttribute("FantasmaT", original)
				end
				if appear then
					d.Transparency = 1
					TweenService:Create(d, TweenInfo.new(seconds), { Transparency = original :: number }):Play()
				else
					TweenService:Create(d, TweenInfo.new(seconds), { Transparency = 1 }):Play()
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Painel (mercador / forja)
-- ---------------------------------------------------------------------------

type Merchant = { root: BasePart, model: Model, spot: string, leaveAt: number, stock: { any }, bought: { [Player]: { [string]: number } } }
local merchant: Merchant? = nil
local nextMerchantAt = Config.Merchant.FirstAt
local forgeRoot: BasePart? = nil

local function merchantEntries(player: Player): { any }
	local m = merchant
	if not m then
		return {}
	end
	local profile = DataService.GetProfile(player)
	local bought = m.bought[player] or {}
	local list = {}
	for _, s in m.stock do
		local left = s.Limit - (bought[s.Id] or 0)
		local info = StandConfig.ItemInfo(s.Item)
		table.insert(list, { id = s.Id, name = ("%s ×%d"):format(itemName(s.Item), s.Amount), price = s.Price,
			desc = (if info then info.Desc else "") .. ("  (pode comprar mais %d)"):format(left),
			color = if info then info.Color else Color3.new(1, 1, 1),
			can = left > 0 and profile ~= nil and profile.coins >= s.Price, action = "Comprar" })
	end
	return list
end

local function forgeEntries(player: Player): { any }
	local profile = DataService.GetProfile(player)
	local list = {}
	for _, r in MaterialConfig.Recipes do
		local weapon = BuildConfig.Weapon(r.Weapon)
		local parts, ok = {}, profile ~= nil and profile.level >= r.MinLevel and profile.coins >= r.Coins
		if r.RequiresFlag and (not profile or not profile.story.flags[r.RequiresFlag]) then
			ok = false
			table.insert(parts, r.SecretHint or "Descubra o projeto secreto.")
		end
		for item, need in r.Needs do
			local have = if profile then profile.inventory[item] or 0 else 0
			if have < need then
				ok = false
			end
			table.insert(parts, ("%s %d/%d"):format(itemName(item), have, need))
		end
		table.sort(parts)
		table.insert(list, { id = r.Id, name = r.Name .. (if weapon then (" (%s, dano ×%.2f)"):format(weapon.Rarity, weapon.Damage) else ""),
			price = r.Coins, desc = ("Nível %d · %s"):format(r.MinLevel, table.concat(parts, " · ")),
			color = if weapon then weapon.Color else Color3.new(1, 1, 1), can = ok, action = "Forjar" })
	end
	return list
end

local function openShop(player: Player, kind: string)
	if kind == "merchant" then
		local m = merchant
		if not m then
			return
		end
		notifyShop:FireClient(player, "open", { kind = kind, title = Config.Merchant.Name,
			subtitle = ("No %s por mais %s. Estoque desta visita."):format(m.spot, Config.FormatDuration(m.leaveAt - uptime())),
			entries = merchantEntries(player) })
	elseif kind == "forge" then
		notifyShop:FireClient(player, "open", { kind = kind, title = Config.Forge.Name,
			subtitle = "Materiais + moedas viram arma. A arma forjada vai para a mochila (M): Usar = equipar.",
			entries = forgeEntries(player) })
	end
end

local function near(player: Player, target: BasePart?, range: number): boolean
	if isDev(player) then
		return true
	end
	local root = rootOf(player)
	return target ~= nil and root ~= nil and (root.Position - target.Position).Magnitude <= range + 6
end

local function buyFromMerchant(player: Player, id: string)
	local m = merchant
	if not m or not near(player, m.root, Config.Merchant.Range) then
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile or DataService.IsSessionOnly(player) then
		return toast(player, "Mercador", "Seus dados não carregaram; tente de novo.")
	end
	for _, s in m.stock do
		if s.Id == id then
			local bought = m.bought[player] or {}
			m.bought[player] = bought
			if (bought[id] or 0) >= s.Limit then
				return toast(player, "Mercador", "Já comprei o que dava para vender a você nesta visita.")
			end
			if profile.coins < s.Price then
				return toast(player, "Mercador", ("Faltam %d moedas."):format(s.Price - profile.coins))
			end
			DataService.AddCoins(player, -s.Price)
			if not giveItem(player, s.Item, s.Amount) then
				DataService.AddCoins(player, s.Price)
				return
			end
			bought[id] = (bought[id] or 0) + 1
			notifyShop:FireClient(player, "result", { title = "Comprado", text = ("%s ×%d por %d moedas"):format(itemName(s.Item), s.Amount, s.Price) })
			if s.Id == "aco_estelar" then
				announce(("%s comprou Aço Estelar do Mercador Errante!"):format(player.DisplayName))
			end
			openShop(player, "merchant")
			return
		end
	end
end

local function forge(player: Player, id: string)
	local recipe = MaterialConfig.Recipe(id)
	local weapon = recipe and BuildConfig.Weapon(recipe.Weapon)
	if not recipe or not weapon or not near(player, forgeRoot, Config.Forge.Range) then
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile or DataService.IsSessionOnly(player) then
		return
	end
	if profile.level < recipe.MinLevel then
		return toast(player, "Ferreiro", ("Volte no nível %d. Essa lâmina não perdoa quem não aguenta."):format(recipe.MinLevel))
	end
	if recipe.RequiresFlag and not profile.story.flags[recipe.RequiresFlag] then
		return toast(player, "Projeto incompleto", recipe.SecretHint or "Resolva o enigma antes de forjar.")
	end
	if profile.coins < recipe.Coins then
		return toast(player, "Ferreiro", ("Faltam %d moedas."):format(recipe.Coins - profile.coins))
	end
	for item, need in recipe.Needs do
		if (profile.inventory[item] or 0) < need then
			return toast(player, "Ferreiro", ("Falta %s (%d/%d)."):format(itemName(item), profile.inventory[item] or 0, need))
		end
	end
	for item, need in recipe.Needs do
		DataService.TakeItem(player, item, need)
	end
	DataService.AddCoins(player, -recipe.Coins)
	giveItem(player, "arma:" .. recipe.Weapon, 1)
	notifyShop:FireClient(player, "result", { title = "Forjado", text = weapon.Name .. " está na sua mochila (M)." })
	if weapon.Rarity == "Lendário" then
		announce(("%s forjou a %s!"):format(player.DisplayName, weapon.Name))
	end
	openShop(player, "forge")
end

-- ---------------------------------------------------------------------------
-- Mercador Errante
-- ---------------------------------------------------------------------------

local function despawnMerchant(silent: boolean?)
	local m = merchant
	if not m then
		return
	end
	merchant = nil
	m.model:Destroy()
	for _, p in Players:GetPlayers() do
		notifyShop:FireClient(p, "close", { kind = "merchant" })
	end
	if not silent then
		announce("O Mercador Errante fechou a banca e foi embora.")
	end
end

local function spawnMerchant(): boolean
	if merchant then
		return false
	end
	local cfg = Config.Merchant
	local order = table.clone(cfg.Spots)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for _, spot in order do
		local ground = findGround(spot.XZ, 25, Vector3.new(12, 9, 12))
		if ground then
			local stall = Instance.new("Model")
			stall.Name = "MercadorErrante"
			stall.Parent = folder
			part({ Name = "Balcao", Size = Vector3.new(8, 3, 3), Color = Color3.fromRGB(120, 84, 56), Material = Enum.Material.Wood,
				CFrame = CFrame.new(ground + Vector3.new(0, 1.5, 3)) }, stall)
			part({ Name = "Toldo", Size = Vector3.new(10, 0.4, 7), Color = Color3.fromRGB(150, 60, 70), Material = Enum.Material.Fabric,
				CFrame = CFrame.new(ground + Vector3.new(0, 8, 1.5)) * CFrame.Angles(math.rad(8), 0, 0) }, stall)
			for _, x in { -4.5, 4.5 } do
				part({ Name = "Poste", Size = Vector3.new(0.4, 8, 0.4), Color = Color3.fromRGB(90, 64, 44), Material = Enum.Material.Wood,
					CFrame = CFrame.new(ground + Vector3.new(x, 4, 4.5)) }, stall)
			end
			local _npc, root = staticNpc(cfg.Name, ground, ground + Vector3.new(0, 0, 10), stall)
			if not root then
				stall:Destroy()
				continue
			end
			local stock = {}
			for _, s in cfg.Stock do
				if rng:NextNumber() < s.Chance then
					table.insert(stock, s)
				end
			end
			if #stock == 0 then
				table.insert(stock, cfg.Stock[#cfg.Stock])
			end
			merchant = { root = root, model = stall, spot = spot.Name, leaveAt = uptime() + cfg.Stay, stock = stock, bought = {} }
			prompt(root, "Negociar", cfg.Name, 0, cfg.Range).Triggered:Connect(function(player)
				openShop(player, "merchant")
			end)
			local rare = false
			for _, s in stock do
				rare = rare or s.Id == "aco_estelar"
			end
			announce(("Um Mercador Errante montou banca no %s! Fica %s.%s"):format(spot.Name, Config.FormatDuration(cfg.Stay),
				if rare then " Dizem que ele trouxe algo raro." else ""))
			return true
		end
	end
	warn("[WorldEvents] Mercador: nenhum ponto de chão livre")
	return false
end

-- ---------------------------------------------------------------------------
-- Esferas Estreladas → Ilhota do Mestre (Kame)
-- ---------------------------------------------------------------------------

local kameStore: Folder
local kameRoots: { { inst: Instance, parent: Instance } } = {}
local orbState = "waiting" -- waiting | orbs | island | cooldown
local orbNextAt = Config.Orbs.UnlockAt
local orbsFound = 0
local orbFolder: Folder? = nil
local kameLeaveAt = 0
local kameClaimed: { [Player]: boolean } = {}
local kameChest: Instance? = nil

local function inKame(pos: Vector3): boolean
	local k = Config.Kame
	local dx, dz = (pos.X - k.Center.X) / k.RadiusX, (pos.Z - k.Center.Y) / k.RadiusZ
	return dx * dx + dz * dz <= 1
end

local function hideKame()
	-- tudo solto no Workspace dentro da elipse + o chão da ilhota (Sahur.ChaoIlhas.IlhotaKame)
	local sahur = Workspace:FindFirstChild("Sahur")
	local chao = sahur and sahur:FindFirstChild("ChaoIlhas")
	local ground = chao and chao:FindFirstChild("IlhotaKame")
	local list: { Instance } = {}
	if ground then
		table.insert(list, ground)
	end
	for _, child in Workspace:GetChildren() do
		if child == Workspace.Terrain or child == sahur or child == folder or child:IsA("Camera") or Players:GetPlayerFromCharacter(child) then
			continue
		end
		local pos: Vector3? = nil
		if child:IsA("Model") then
			pos = child:GetBoundingBox().Position
		elseif child:IsA("BasePart") then
			pos = child.Position
		elseif child:IsA("Folder") then
			local any = child:FindFirstChildWhichIsA("BasePart", true)
			pos = if any then any.Position else nil
		end
		if pos and inKame(pos) and child:GetAttribute("Bot") ~= true then
			table.insert(list, child)
		end
	end
	table.clear(kameRoots)
	for _, inst in list do
		table.insert(kameRoots, { inst = inst, parent = inst.Parent :: Instance })
		inst.Parent = kameStore
	end
	Log.debug(("[WorldEvents] Ilhota do Mestre escondida (%d partes do mapa)"):format(#list))
end

local function revealKame()
	if orbState == "island" then
		return
	end
	orbState = "island"
	kameLeaveAt = uptime() + Config.Orbs.IslandStay
	table.clear(kameClaimed)
	if orbFolder then
		orbFolder:Destroy()
		orbFolder = nil
	end
	local roots = {}
	for _, r in kameRoots do
		r.inst.Parent = r.parent
		table.insert(roots, r.inst)
	end
	ghost(roots, true, 6)
	local ground = findGround(Config.Kame.Center, 80, Vector3.new(6, 5, 6))
	if ground then
		local chest = part({ Name = "BauDoMestre", Size = Vector3.new(4, 2.6, 2.6), Color = Color3.fromRGB(140, 90, 50),
			Material = Enum.Material.Wood, CFrame = CFrame.new(ground + Vector3.new(0, 1.3, 0)) }, folder)
		part({ Name = "Faixa", Size = Vector3.new(4.1, 0.5, 2.7), Color = Color3.fromRGB(230, 190, 80), Material = Enum.Material.Metal,
			CFrame = chest.CFrame * CFrame.new(0, 0.6, 0) }, chest)
		kameChest = chest
		prompt(chest, "Abrir", "Baú do Mestre", 1, 10).Triggered:Connect(function(player)
			if kameClaimed[player] or not near(player, chest, 10) then
				return
			end
			kameClaimed[player] = true
			local reward = Config.Orbs.Reward
			DataService.RewardCoins(player, reward.Coins)
			for item, n in (reward.Items :: { [string]: number }) do
				giveItem(player, item, n)
			end
			toast(player, "Baú do Mestre", ("+%d moedas · +1 Flecha. Volte na próxima aparição."):format(reward.Coins))
		end)
	end
	announce(("As 7 Esferas brilharam: uma ilha fantasma surgiu a noroeste do Porto da Névoa! Some em %s."):format(Config.FormatDuration(Config.Orbs.IslandStay)))
end

local function hideKameAgain()
	orbState = "cooldown"
	orbNextAt = uptime() + Config.Orbs.Cooldown
	local roots = {}
	for _, r in kameRoots do
		table.insert(roots, r.inst)
	end
	ghost(roots, false, 4)
	if kameChest then
		kameChest:Destroy()
		kameChest = nil
	end
	announce("A ilha fantasma está sumindo na névoa...")
	task.delay(4.5, function()
		if orbState == "island" then
			return -- reabriu (DEV/esferas) enquanto sumia: não esconder a aparição nova
		end
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root and inKame(root.Position) then
				teleport(player, homeSpawn())
				toast(player, "A ilha sumiu", "Você acordou de volta no Porto da Névoa.")
			end
		end
		for _, r in kameRoots do
			r.inst.Parent = kameStore
			local hl = r.inst:FindFirstChild("Fantasma")
			if hl then
				hl:Destroy()
			end
			for _, d in r.inst:GetDescendants() do
				if d:IsA("BasePart") then
					local original = d:GetAttribute("FantasmaT")
					if typeof(original) == "number" then
						d.Transparency = original
					end
				end
			end
		end
	end)
end

local function spawnOrbs()
	orbState = "orbs"
	orbsFound = 0
	if orbFolder then
		orbFolder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "EsferasEstreladas"
	f.Parent = folder
	orbFolder = f
	local islands = {}
	for _, island in WorldConfig.Islands do
		if island.Region then
			table.insert(islands, island)
		end
	end
	local placed = 0
	for i = 1, Config.Orbs.Count * 3 do
		if placed >= Config.Orbs.Count or #islands == 0 then
			break
		end
		local island = islands[((i - 1) % #islands) + 1]
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.25, 0.85)
		local xz = Vector2.new(island.Center.X + math.cos(a) * island.RadiusX * d, island.Center.Z + math.sin(a) * island.RadiusZ * d)
		local ground = findGround(xz, 20, Vector3.new(3, 4, 3))
		if ground then
			placed += 1
			local orb = part({ Name = "Esfera" .. placed, Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Color = Color3.fromRGB(255, 160, 50),
				Material = Enum.Material.Neon, CanCollide = false, CFrame = CFrame.new(ground + Vector3.new(0, 1.3, 0)) }, f)
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness = orb.Color, 9, 1.2
			light.Parent = orb
			prompt(orb, "Pegar", "Esfera Estrelada", 0.8, 8).Triggered:Connect(function(player)
				if orb.Parent == nil or not near(player, orb, 8) then
					return
				end
				orb:Destroy()
				orbsFound += 1
				giveItem(player, "mat:esfera", 1)
				announce(("%s achou uma Esfera Estrelada (%d/%d)."):format(player.DisplayName, orbsFound, Config.Orbs.Count))
				if orbsFound >= Config.Orbs.Count then
					revealKame()
				end
			end)
		end
	end
	announce(("Pescadores juram ter visto %d esferas com estrelas caindo pelas ilhas..."):format(placed))
end

-- ---------------------------------------------------------------------------
-- Obeliscos do Sol → Cânion Fantasma
-- ---------------------------------------------------------------------------

type Obelisk = { crystal: BasePart, prompt: ProximityPrompt, litUntil: number }
local obelisks: { Obelisk } = {}
local canyon: Model? = nil
local canyonPortal: BasePart? = nil
local canyonLeaveAt = 0
local canyonNextAt = Config.Obelisks.UnlockAt
local canyonClaimed: { [Player]: boolean } = {}
local canyonBots: { Model } = {}

local function isNight(): boolean
	return Workspace:GetAttribute("IsNight") == true
end

local function buildObelisks()
	local desert: any = nil
	for _, island in WorldConfig.Islands do
		if island.Region == "ilha_pilares" then
			desert = island
		end
	end
	if not desert then
		return
	end
	for i = 1, Config.Obelisks.Count do
		local base = math.rad(45 + (i - 1) * 90)
		local ground: Vector3? = nil
		for try = 0, 8 do
			local a = base + math.rad((try % 3 - 1) * 12)
			local d = 0.55 + (try // 3) * 0.08
			ground = findGround(Vector2.new(desert.Center.X + math.cos(a) * desert.RadiusX * d, desert.Center.Z + math.sin(a) * desert.RadiusZ * d),
				10, Vector3.new(5, 16, 5))
			if ground then
				break
			end
		end
		if not ground then
			continue
		end
		local g: Vector3 = ground
		local model = Instance.new("Model")
		model.Name = "ObeliscoDoSol" .. i
		model.Parent = folder
		part({ Name = "Base", Size = Vector3.new(5, 1.5, 5), Color = Color3.fromRGB(120, 80, 55), Material = Enum.Material.Sandstone,
			CFrame = CFrame.new(g + Vector3.new(0, 0.75, 0)) }, model)
		local column = part({ Name = "Coluna", Size = Vector3.new(2.6, 12, 2.6), Color = Color3.fromRGB(150, 100, 70),
			Material = Enum.Material.Sandstone, CFrame = CFrame.new(g + Vector3.new(0, 7.5, 0)) }, model)
		local crystal = part({ Name = "Cristal", Size = Vector3.new(1.6, 2.4, 1.6), Color = Color3.fromRGB(80, 60, 50),
			Material = Enum.Material.Glass, CanCollide = false, CFrame = column.CFrame * CFrame.new(0, 7.4, 0) * CFrame.Angles(0, math.rad(45), 0) }, model)
		local pr = prompt(column, "Acender", "Obelisco do Sol", 2, 10)
		local ob: Obelisk = { crystal = crystal, prompt = pr, litUntil = 0 }
		table.insert(obelisks, ob)
		pr.Triggered:Connect(function(player)
			if not near(player, column, 10) then
				return
			end
			if uptime() < Config.Obelisks.UnlockAt then
				return toast(player, "Obelisco do Sol", "A pedra está fria. Ainda não é hora.")
			end
			if not isNight() then
				return toast(player, "Obelisco do Sol", "Só a noite acende essas pedras.")
			end
			if canyon or uptime() < canyonNextAt then
				return toast(player, "Obelisco do Sol", "A pedra ainda está cansada da última vez.")
			end
			ob.litUntil = uptime() + Config.Obelisks.LitSeconds
			local lit = 0
			for _, o in obelisks do
				if o.litUntil > uptime() then
					lit += 1
				end
			end
			toast(player, "Obelisco aceso", ("%d/%d acesos. Os outros precisam brilhar antes deste apagar (%d s)."):format(lit, #obelisks, Config.Obelisks.LitSeconds))
			if lit >= #obelisks then
				WorldEventsService.OpenCanyon()
			end
		end)
	end
end

local function canyonSpawns(): { CFrame }
	local out = {}
	if canyon then
		for _, d in canyon:GetDescendants() do
			if d:IsA("BasePart") and d.Name:sub(1, 10) == "EventSpawn" then
				table.insert(out, d.CFrame + Vector3.new(0, 3, 0))
			end
		end
		if #out == 0 then
			local cf = canyon:GetBoundingBox()
			table.insert(out, cf)
		end
	end
	return out
end

local function inCanyon(pos: Vector3): boolean
	local c = canyon
	if not c then
		return false
	end
	local cf, size = c:GetBoundingBox()
	local rel = cf:PointToObjectSpace(pos)
	return math.abs(rel.X) <= size.X / 2 and math.abs(rel.Y) <= size.Y / 2 + 20 and math.abs(rel.Z) <= size.Z / 2
end

function WorldEventsService.OpenCanyon(): boolean
	if canyon then
		return false
	end
	if Workspace:GetAttribute("EventActive") == true then
		announce("Os obeliscos brilharam, mas o Cânion já está ocupado por um evento.")
		return false
	end
	local store = ServerStorage:FindFirstChild("EventMaps")
	local template = store and store:FindFirstChild("canion")
	if not template or not template:IsA("Model") then
		warn("[WorldEvents] ServerStorage.EventMaps.canion não existe")
		return false
	end
	local clone = template:Clone()
	clone.Name = "CanionFantasma"
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") and d.Name:sub(1, 10) == "EventSpawn" then
			d.Transparency = 1
			d.CanCollide = false
		end
	end
	clone.Parent = folder
	canyon = clone
	canyonLeaveAt = uptime() + Config.Obelisks.CanyonStay
	table.clear(canyonClaimed)
	ghost({ clone }, true, 6)
	local spawns = canyonSpawns()
	-- portal de ida (Deserto) e de volta (primeiro spawn)
	local ground = findGround(Config.Obelisks.PortalXZ, 40, Vector3.new(8, 12, 8))
	if ground then
		local portal = part({ Name = "PortalCanion", Size = Vector3.new(1, 11, 7), Color = Color3.fromRGB(180, 120, 255),
			Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, CFrame = CFrame.new(ground + Vector3.new(0, 5.5, 0)) }, folder)
		canyonPortal = portal
		prompt(portal, "Entrar", "Cânion Fantasma", 0.5, 10).Triggered:Connect(function(player)
			if canyon and #spawns > 0 and near(player, portal, 10) then
				teleport(player, spawns[rng:NextInteger(1, #spawns)].Position)
			end
		end)
	end
	if #spawns > 0 then
		local back = part({ Name = "PortalVolta", Size = Vector3.new(1, 9, 6), Color = Color3.fromRGB(180, 120, 255),
			Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, CFrame = spawns[1] * CFrame.new(8, 1.5, 0) }, clone)
		prompt(back, "Voltar", "Deserto do Sol", 0.5, 10).Triggered:Connect(function(player)
			if canyonPortal and near(player, back, 10) then
				teleport(player, canyonPortal.Position + Vector3.new(6, -4, 0))
			end
		end)
		local chest = part({ Name = "BauDoCanion", Size = Vector3.new(4, 2.6, 2.6), Color = Color3.fromRGB(90, 60, 110),
			Material = Enum.Material.Wood, CFrame = spawns[#spawns] * CFrame.new(-10, -1.7, 0) }, clone)
		prompt(chest, "Abrir", "Baú do Cânion", 1, 10).Triggered:Connect(function(player)
			if canyonClaimed[player] or not near(player, chest, 10) then
				return
			end
			canyonClaimed[player] = true
			local reward = Config.Obelisks.Reward
			DataService.RewardCoins(player, reward.Coins)
			for item, n in (reward.Items :: { [string]: number }) do
				giveItem(player, item, n)
			end
			local rare = rng:NextNumber() < reward.Rare.Chance and giveItem(player, reward.Rare.Item, 1)
			toast(player, "Baú do Cânion", ("+%d moedas · +5 Areia Negra%s"):format(reward.Coins, if rare then " · +1 AÇO ESTELAR" else ""))
			if rare then
				announce(("%s achou Aço Estelar no Cânion Fantasma!"):format(player.DisplayName))
			end
		end)
		canyonBots = {}
		for i = 1, Config.Obelisks.Enemies do
			local at = spawns[((i - 1) % #spawns) + 1] * CFrame.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14))
			local bot = BotService.Spawn(EnemyConfig.Options(4, { Name = "Espectro do Cânion", CFrame = at, Team = "fx_canion", HomeMap = clone,
				Attributes = { FXEnemy = true, StoryKillKind = "fx_canion_espectro" } }))
			if bot then
				table.insert(canyonBots, bot)
			end
		end
	end
	announce(("Os quatro obeliscos brilharam juntos: o Cânion Fantasma abriu no céu! Portal no Deserto do Sol. Fecha em %s."):format(Config.FormatDuration(Config.Obelisks.CanyonStay)))
	return true
end

local function closeCanyon()
	local c = canyon
	if not c then
		return
	end
	canyonNextAt = uptime() + Config.Obelisks.Cooldown
	for _, o in obelisks do
		o.litUntil = 0
	end
	announce("O Cânion Fantasma está se desfazendo...")
	ghost({ c }, false, 4)
	local oldBots = canyonBots
	canyonBots = {}
	task.delay(4.5, function()
		local back = if canyonPortal then canyonPortal.Position + Vector3.new(6, -4, 0) else homeSpawn()
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root and inCanyon(root.Position) then
				teleport(player, back)
				toast(player, "O Cânion sumiu", "Você caiu de volta no Deserto do Sol.")
			end
		end
		for _, bot in oldBots do
			BotService.Remove(bot)
		end
		if canyon == c then
			canyon = nil
			if canyonPortal then
				canyonPortal:Destroy()
				canyonPortal = nil
			end
		end
		c:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- Ferreiro e Mural
-- ---------------------------------------------------------------------------

local muralText: TextLabel? = nil

local function buildForge()
	local ground = findGround(Config.Forge.XZ, 20, Vector3.new(8, 8, 8))
	if not ground then
		warn("[WorldEvents] Ferreiro: sem chão livre")
		return
	end
	local g: Vector3 = ground
	local model = Instance.new("Model")
	model.Name = "Ferreiro"
	model.Parent = folder
	local anvil = part({ Name = "Bigorna", Size = Vector3.new(3, 1.6, 1.6), Color = Color3.fromRGB(60, 60, 66), Material = Enum.Material.Metal,
		CFrame = CFrame.new(g + Vector3.new(0, 1.8, 3)) }, model)
	part({ Name = "BaseBigorna", Size = Vector3.new(1.6, 1.2, 1.2), Color = Color3.fromRGB(90, 64, 44), Material = Enum.Material.Wood,
		CFrame = CFrame.new(g + Vector3.new(0, 0.6, 3)) }, model)
	local fire = part({ Name = "Fornalha", Size = Vector3.new(3, 3, 3), Color = Color3.fromRGB(80, 70, 66), Material = Enum.Material.Slate,
		CFrame = CFrame.new(g + Vector3.new(4.5, 1.5, 2)) }, model)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 140, 60), 12, 1.5
	light.Parent = fire
	local _npc, root = staticNpc(Config.Forge.Name, g, g + Vector3.new(0, 0, 10), model)
	forgeRoot = root or anvil
	prompt(anvil, "Forjar", Config.Forge.Name, 0, Config.Forge.Range).Triggered:Connect(function(player)
		openShop(player, "forge")
	end)
end

local function buildMural()
	local ground = findGround(Config.Mural.XZ, 20, Vector3.new(10, 9, 3))
	if not ground then
		warn("[WorldEvents] Mural: sem chão livre")
		return
	end
	local g: Vector3 = ground
	local model = Instance.new("Model")
	model.Name = "MuralDeRumores"
	model.Parent = folder
	local face = CFrame.lookAt(g + Vector3.new(0, 5, 0), Vector3.new(40, g.Y + 5, 110)) -- vira para a praça
	local board = part({ Name = "Quadro", Size = Vector3.new(10, 6.5, 0.4), Color = Color3.fromRGB(110, 80, 56), Material = Enum.Material.Wood, CFrame = face }, model)
	for _, x in { -4.6, 4.6 } do
		part({ Name = "Pe", Size = Vector3.new(0.5, 8.5, 0.5), Color = Color3.fromRGB(80, 58, 40), Material = Enum.Material.Wood,
			CFrame = face * CFrame.new(x, -0.75, 0.3) }, model)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.3
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -40, 0, 60)
	title.Position = UDim2.fromOffset(20, 10)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(245, 230, 200)
	title.Text = "MURAL DE RUMORES"
	title.Parent = gui
	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -40, 1, -90)
	body.Position = UDim2.fromOffset(20, 80)
	body.Font = Enum.Font.Gotham
	body.TextSize = 22
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(235, 225, 205)
	body.Parent = gui
	muralText = body
end

local function muralLines(): string
	local now = uptime()
	local F = Config.FormatDuration
	local lines = { ("• Este servidor está de pé há %s."):format(F(now)) }
	local m = merchant
	if m then
		table.insert(lines, ("• O Mercador Errante está no %s! Vai embora em %s."):format(m.spot, F(m.leaveAt - now)))
	elseif now < Config.Merchant.FirstAt then
		table.insert(lines, ("• Um mercador de muito longe aparece quando o servidor completa 6 horas (faltam %s). Às vezes ele traz Aço Estelar."):format(F(Config.Merchant.FirstAt - now)))
	else
		table.insert(lines, ("• O Mercador Errante passa de 3 em 3 horas. Próxima visita em %s."):format(F(nextMerchantAt - now)))
	end
	if orbState == "island" then
		table.insert(lines, ("• A ILHA FANTASMA está a noroeste do Porto! Some em %s. Tem um baú lá."):format(F(kameLeaveAt - now)))
	elseif orbState == "orbs" then
		table.insert(lines, ("• Esferas Estreladas escondidas pelas 3 ilhas: %d/%d achadas. Juntando todas, algo aparece a noroeste."):format(orbsFound, Config.Orbs.Count))
	elseif now < orbNextAt then
		table.insert(lines, ("• Pescadores falam de esferas com estrelas que caem do céu. Faltam %s."):format(F(orbNextAt - now)))
	end
	if canyon then
		table.insert(lines, ("• O CÂNION FANTASMA está aberto no céu (portal no Deserto do Sol). Fecha em %s."):format(F(canyonLeaveAt - now)))
	elseif now < Config.Obelisks.UnlockAt then
		table.insert(lines, ("• No Deserto do Sol, quatro pedras antigas dormem. Dizem que acordam depois de 4 horas (faltam %s)."):format(F(Config.Obelisks.UnlockAt - now)))
	elseif now < canyonNextAt then
		table.insert(lines, ("• Os obeliscos do Deserto descansam. Voltam a responder em %s."):format(F(canyonNextAt - now)))
	else
		local lit = 0
		for _, o in obelisks do
			if o.litUntil > now then
				lit += 1
			end
		end
		table.insert(lines, ("• Os 4 obeliscos do Deserto só acendem à noite, e precisam brilhar JUNTOS (acesos agora: %d/4)."):format(lit))
	end
	table.insert(lines, "• O Ferreiro da vila forja armas com materiais dos inimigos.")
	return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------------------
-- Ciclo
-- ---------------------------------------------------------------------------

local function tick()
	local now = uptime()
	-- mercador
	local m = merchant
	if m and now >= m.leaveAt then
		despawnMerchant()
	elseif not m and now >= nextMerchantAt then
		nextMerchantAt = math.max(nextMerchantAt, now) + Config.Merchant.Every
		spawnMerchant()
	end
	-- esferas / ilha
	if orbState == "island" and now >= kameLeaveAt then
		hideKameAgain()
	elseif (orbState == "waiting" or orbState == "cooldown") and now >= orbNextAt then
		spawnOrbs()
	end
	-- obeliscos / cânion
	if canyon and now >= canyonLeaveAt then
		closeCanyon()
	end
	for _, o in obelisks do
		local lit = o.litUntil > now
		o.crystal.Material = if lit then Enum.Material.Neon else Enum.Material.Glass
		o.crystal.Color = if lit then Color3.fromRGB(255, 200, 90)
			elseif now >= Config.Obelisks.UnlockAt and isNight() and not canyon then Color3.fromRGB(150, 110, 70) else Color3.fromRGB(80, 60, 50)
	end
	if muralText then
		muralText.Text = muralLines()
	end
end

-- DEV ------------------------------------------------------------------------

function WorldEventsService.Skip(seconds: number)
	local skew = Workspace:GetAttribute("WorldEventsSkew")
	Workspace:SetAttribute("WorldEventsSkew", (if typeof(skew) == "number" then skew else 0) + seconds)
	tick()
end

function WorldEventsService.ForceMerchant(): (boolean, string)
	if merchant then
		despawnMerchant(true)
	end
	local ok = spawnMerchant()
	return ok, if ok then "mercador montou banca" else "sem chão livre para o mercador"
end

function WorldEventsService.ForceOrbs(): (boolean, string)
	if orbState == "island" then
		return false, "a ilhota já está visível"
	end
	spawnOrbs()
	return true, "esferas espalhadas"
end

function WorldEventsService.ForceKame(): (boolean, string)
	if orbState == "island" then
		kameLeaveAt = uptime()
		return true, "ilhota vai sumir"
	end
	revealKame()
	return true, "ilhota apareceu"
end

function WorldEventsService.ForceCanyon(): (boolean, string)
	if canyon then
		canyonLeaveAt = uptime()
		return true, "cânion vai fechar"
	end
	local ok = WorldEventsService.OpenCanyon()
	return ok, if ok then "cânion aberto" else "cânion não abriu (veja o Output)"
end

-- ---------------------------------------------------------------------------

function WorldEventsService.Init()
	notifyShop = Remotes.GetEvent(Remotes.Events.NotifyWorldShop)
	announceRemote = Remotes.GetEvent(Remotes.Events.NotifyAnnouncement)
end

function WorldEventsService.Start()
	startTime = Workspace:GetServerTimeNow()
	Workspace:SetAttribute("ServerStartTime", startTime)
	folder = Instance.new("Folder")
	folder.Name = "EventosMundo"
	folder.Parent = Workspace
	kameStore = Instance.new("Folder")
	kameStore.Name = "IlhaSecreta_Kame"
	kameStore.Parent = ServerStorage
	hideKame()
	Remotes.GetEvent(Remotes.Events.RequestWorldShop).OnServerEvent:Connect(function(player: Player, kind: any, id: any)
		if not limiter:Allow(player) or typeof(kind) ~= "string" or typeof(id) ~= "string" then
			return
		end
		if kind == "merchant" then
			buyFromMerchant(player, id)
		elseif kind == "forge" then
			forge(player, id)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		kameClaimed[player] = nil
		canyonClaimed[player] = nil
		if merchant then
			merchant.bought[player] = nil
		end
	end)
	task.defer(function()
		task.wait(3) -- deixa os mapas/ilhas registrarem antes de procurar chão
		buildMural()
		buildForge()
		buildObelisks()
		while true do
			local ok, err = pcall(function()
				tick()
			end)
			if not ok then
				warn("[WorldEvents] " .. tostring(err))
			end
			task.wait(1)
		end
	end)
	Log.debug("[WorldEvents] pronto (mercador 6h, esferas 2h → Kame, obeliscos 4h → Cânion, ferreiro, mural)")
end

return WorldEventsService
