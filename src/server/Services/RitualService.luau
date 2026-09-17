--!strict
--[[
	RitualService (servidor)
	Ritual da FLECHA (dono, 2026-09-16): uma flecha perdida aparece de TEMPOS EM TEMPOS (BossConfig.Ritual
	SpawnDelayMin..Max) num ponto ESCONDIDO sorteado do mapa (raycast do céu; os ArrowSpot* do ArenaExtras
	são só reserva). Nada aponta para ela (sem feixe). Encostar pega a flecha: ela aparece nas costas do
	portador (todo mundo vê quem está com ela — vira alvo). Se o portador morre, a flecha fica no chão por
	DropLifetime s; ninguém pegou = some e entra na fila aleatória de novo. À NOITE
	(EnvironmentService.IsNight), o portador segura E no altar e VIRA o boss (BossFormService.Transform).
	Enquanto o boss está solto não há flecha; ela entra na fila RespawnDelay s depois de a forma acabar.

	Altar (ArenaExtras): BossAltar (ProximityPrompt + letreiro, criados aqui), BossAltarTorch{i} (acendem
	à noite), BossAltarRune/BossCrack* (acendem quando a flecha está com alguém à noite), BossAltarSkullSocket{i}
	(caveiras decorativas fixas).

	Flecha: Model/BasePart chamado BossConfig.Ritual.ArrowModelName em ServerStorage ou
	ReplicatedStorage.Assets (a equipe pode fazer uma); senão flecha dourada por código.
	Tag CollectionService "RitualArrow" no Model no chão (o cliente faz flutuar/girar — BossController).

	Eventos (NotifyBoss): "arrow" { state = "spawned"|"taken"|"dropped", by?, position? }
	Atributos: Player.HasArrow (true no portador); Workspace.ArrowCarrier (nome ou nil).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local BossConfig = require(Modules:WaitForChild("BossConfig"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local EnvironmentService = require(script.Parent:WaitForChild("EnvironmentService"))
local BossFormService = require(script.Parent:WaitForChild("BossFormService"))

local RitualService = {}

local TAG = "RitualArrow"
local ATTR_HAS_ARROW = "HasArrow"

local notifyBoss: RemoteEvent
local spots: { BasePart } = {}
local torches: { BasePart } = {}
local sockets: { BasePart } = {}
local rune: BasePart? = nil
local cracks: { BasePart } = {}
local altar: BasePart? = nil
local prompt: ProximityPrompt? = nil
local statusLabel: TextLabel? = nil
local arrowFolder: Folder
local groundArrow: Model? = nil -- flecha no chão (com Trigger)
local groundTrigger: BasePart? = nil
local carrier: Player? = nil
local carriedVisual: Model? = nil
local respawnToken = 0
local dropToken = 0
local rng = Random.new()

RitualService.Changed = Instance.new("BindableEvent")

-- ---------------------------------------------------------------------------
-- Estado
-- ---------------------------------------------------------------------------

function RitualService.GetCarrier(): Player?
	return carrier
end

--- Quem tem a flecha pode virar o boss agora? (noite + nenhum boss solto)
function RitualService.CanTransform(player: Player): boolean
	local cfg = BossConfig.Ritual
	if not cfg.Enabled then
		return not BossFormService.IsActive()
	end
	if carrier ~= player or BossFormService.IsActive() then
		return false
	end
	if cfg.NightOnly and not EnvironmentService.IsNight() then
		return false
	end
	return true
end

--- Texto do letreiro do altar.
function RitualService.StatusText(): string
	local cfg = BossConfig.Ritual
	local formPlayer = BossFormService.GetActivePlayer()
	if formPlayer then
		return ("%s está solto — derrubem %s!"):format(BossConfig.Name, formPlayer.Name)
	end
	if not carrier then
		if groundArrow then
			return "Uma FLECHA está perdida no mapa…"
		end
		return "A flecha ainda não caiu…"
	end
	if cfg.NightOnly and not EnvironmentService.IsNight() then
		return ("%s tem a flecha — espere a NOITE"):format(carrier.Name)
	end
	return ("%s: segure E para VIRAR o %s"):format(carrier.Name, BossConfig.Name)
end

-- ---------------------------------------------------------------------------
-- Visual do altar
-- ---------------------------------------------------------------------------

local function setFire(part: BasePart, on: boolean)
	for _, d in part:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			(d :: any).Enabled = on
		end
	end
end

local function refreshAltar()
	local night = EnvironmentService.IsNight()
	for _, torch in torches do
		setFire(torch, night)
	end
	local ready = carrier ~= nil and night and not BossFormService.IsActive()
	if rune then
		rune.Material = if ready then Enum.Material.Neon else Enum.Material.Slate
		rune.Color = if ready then Color3.fromRGB(230, 50, 50) else Color3.fromRGB(60, 22, 22)
		for _, d in rune:GetDescendants() do
			if d:IsA("PointLight") then
				d.Enabled = ready
			end
		end
	end
	for _, c in cracks do
		c.Material = if ready then Enum.Material.Neon else Enum.Material.Slate
		c.Color = if ready then Color3.fromRGB(200, 40, 40) else Color3.fromRGB(45, 18, 18)
	end
	if prompt then
		prompt.Enabled = carrier ~= nil and not BossFormService.IsActive()
	end
	if statusLabel then
		statusLabel.Text = RitualService.StatusText()
	end
	Workspace:SetAttribute("ArrowCarrier", if carrier then carrier.Name else nil)
end

-- ---------------------------------------------------------------------------
-- Flecha (modelo)
-- ---------------------------------------------------------------------------

local function findTemplate(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	for _, root in { ServerStorage, assets } do
		local found = root and root:FindFirstChild(name, true)
		if found and (found:IsA("Model") or found:IsA("BasePart")) then
			return found
		end
	end
	return nil
end

local function prepareModel(model: Model)
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	model.PrimaryPart = primary
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.Anchored = d == primary
			if d ~= primary and primary then
				local w = Instance.new("WeldConstraint")
				w.Part0 = primary
				w.Part1 = d
				w.Parent = d
			end
		end
	end
end

--- Flecha (Model com PrimaryPart apontando para cima = +Y). Da equipe se existir, senão por código.
function RitualService.BuildArrow(): Model
	local template = findTemplate(BossConfig.Ritual.ArrowModelName)
	local model: Model
	if template then
		local clone = template:Clone()
		if clone:IsA("Model") then
			model = clone
		else
			model = Instance.new("Model")
			clone.Parent = model
		end
	else
		model = Instance.new("Model")
		local gold = Color3.fromRGB(214, 172, 60)
		local dark = Color3.fromRGB(70, 52, 30)
		local function mk(name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Shape = shape
			p.Size = size
			p.CFrame = cf
			p.Color = color
			p.Material = material or Enum.Material.SmoothPlastic
			p.CastShadow = false
			p.Parent = model
			return p
		end
		-- haste vertical (cilindro no eixo Y), ponta em cima, penas embaixo
		local shaft = mk("Shaft", Enum.PartType.Cylinder, Vector3.new(3.2, 0.22, 0.22), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), dark, Enum.Material.Wood)
		mk("Head", Enum.PartType.Block, Vector3.new(0.7, 1.1, 0.2), CFrame.new(0, 2.0, 0), gold, Enum.Material.Metal)
		mk("HeadTip", Enum.PartType.Block, Vector3.new(0.5, 0.5, 0.2), CFrame.new(0, 2.65, 0) * CFrame.Angles(0, 0, math.rad(45)), gold, Enum.Material.Metal)
		mk("FeatherL", Enum.PartType.Block, Vector3.new(0.5, 0.9, 0.08), CFrame.new(-0.28, -1.3, 0) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(230, 60, 60))
		mk("FeatherR", Enum.PartType.Block, Vector3.new(0.5, 0.9, 0.08), CFrame.new(0.28, -1.3, 0) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(230, 60, 60))
		local glow = mk("Glow", Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 2.0, 0), Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
		glow.Transparency = 0.55
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 110)
		light.Brightness = 1.8
		light.Range = 14
		light.Parent = glow
		model.PrimaryPart = shaft
	end
	prepareModel(model)
	return model
end

local function clearGround()
	if groundArrow then
		groundArrow:Destroy()
	end
	groundArrow = nil
	groundTrigger = nil
end

local function clearCarried()
	if carriedVisual then
		carriedVisual:Destroy()
	end
	carriedVisual = nil
end

--- Põe a flecha no chão em `cf` (em cima de um ArrowSpot ou onde o portador morreu).
local function placeArrow(cf: CFrame, spotName: string?)
	clearGround()
	local model = RitualService.BuildArrow()
	model.Name = "RitualArrow"
	model:PivotTo(cf * CFrame.new(0, 2.6, 0) * CFrame.Angles(math.rad(25), 0, 0))
	local trigger = Instance.new("Part")
	trigger.Name = "Trigger"
	trigger.Size = Vector3.new(6, 6, 6)
	trigger.CFrame = cf * CFrame.new(0, 3, 0)
	trigger.Transparency = 1
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.CastShadow = false
	trigger.Parent = model
	if spotName then
		model:SetAttribute("SpotName", spotName)
	end
	CollectionService:AddTag(model, TAG)
	model.Parent = arrowFolder
	groundArrow = model
	groundTrigger = trigger
	trigger.Touched:Connect(function(hit)
		RitualService.TryTake(trigger, hit)
	end)
	notifyBoss:FireAllClients("arrow", { event = "arrow", state = "spawned" }) -- sem posição: escondida
	refreshAltar()
	RitualService.Changed:Fire()
end

--- Sorteia um ponto escondido do mapa: raycast do céu num (x, z) aleatório; aceita chão plano na altura
--- do mapa, longe do altar e dos jogadores. nil se não achou (cai nos ArrowSpot*).
local function randomHiddenSpot(): CFrame?
	local cfg = BossConfig.Ritual
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { arrowFolder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	for _ = 1, 40 do
		local x = rng:NextNumber(-cfg.SpawnRadius, cfg.SpawnRadius)
		local z = rng:NextNumber(-cfg.SpawnRadius, cfg.SpawnRadius)
		local hit = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -260, 0), params)
		if not hit or hit.Normal.Y < 0.85 or hit.Position.Y < -4 or hit.Position.Y > 14 then
			continue
		end
		if hit.Material == Enum.Material.Water or (hit.Instance :: BasePart).Transparency >= 1 then
			continue
		end
		if altar and (hit.Position - altar.Position).Magnitude < cfg.MinDistanceFromAltar then
			continue
		end
		local tooClose = false
		for _, p in Players:GetPlayers() do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - hit.Position).Magnitude < cfg.MinDistanceFromPlayers then
				tooClose = true
				break
			end
		end
		if not tooClose then
			return CFrame.new(hit.Position)
		end
	end
	return nil
end

local function spawnArrowAtSpot()
	respawnToken += 1 -- cancela qualquer espera pendente
	if BossConfig.Ritual.HiddenSpawn then
		local cf = randomHiddenSpot()
		if cf then
			placeArrow(cf)
			Log.debug(("[RitualService] flecha escondida em %.0f, %.0f, %.0f"):format(cf.X, cf.Y, cf.Z))
			return
		end
	end
	if #spots == 0 then
		warn("[RitualService] sem ArrowSpot* no ArenaExtras; ritual desativado")
		return
	end
	local spot = spots[rng:NextInteger(1, #spots)]
	placeArrow(spot.CFrame, spot.Name)
	Log.debug(("[RitualService] flecha em %s"):format(spot.Name))
end

--- Agenda a próxima flecha para daqui a um tempo aleatório (min..max). Só uma espera por vez.
local function scheduleSpawn(minSeconds: number, maxSeconds: number)
	respawnToken += 1
	local token = respawnToken
	local delaySeconds = rng:NextNumber(minSeconds, maxSeconds)
	Log.debug(("[RitualService] próxima flecha em %.0f s"):format(delaySeconds))
	task.delay(delaySeconds, function()
		if token ~= respawnToken or carrier or groundArrow or BossFormService.IsActive() then
			return
		end
		spawnArrowAtSpot()
	end)
end

--- Flecha no chão sem dono: some depois de DropLifetime s e volta para a fila aleatória.
local function startDropTimer()
	dropToken += 1
	local token = dropToken
	task.delay(BossConfig.Ritual.DropLifetime, function()
		if token ~= dropToken or not groundArrow or carrier then
			return
		end
		clearGround()
		notifyBoss:FireAllClients("arrow", { event = "arrow", state = "vanished" })
		refreshAltar()
		RitualService.Changed:Fire()
		Log.debug("[RitualService] ninguém pegou a flecha: sumiu")
		scheduleSpawn(BossConfig.Ritual.SpawnDelayMin, BossConfig.Ritual.SpawnDelayMax)
	end)
end

--- Flecha nas costas do portador (visível para todos).
local function attachToCarrier(player: Player)
	clearCarried()
	local character = player.Character
	local torso = character and (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")) :: BasePart?
	if not torso then
		return
	end
	local visual = RitualService.BuildArrow()
	visual.Name = "CarriedArrow"
	local primary = visual.PrimaryPart :: BasePart
	primary.Anchored = false
	visual:PivotTo(torso.CFrame * CFrame.new(0.4, 0.3, 0.75) * CFrame.Angles(0, 0, math.rad(-30)))
	local w = Instance.new("WeldConstraint")
	w.Part0 = torso
	w.Part1 = primary
	w.Parent = primary
	visual.Parent = character
	carriedVisual = visual
end

local function setCarrier(player: Player?)
	local old = carrier
	if old and old ~= player then
		old:SetAttribute(ATTR_HAS_ARROW, nil)
	end
	carrier = player
	if player then
		player:SetAttribute(ATTR_HAS_ARROW, true)
		attachToCarrier(player)
	else
		clearCarried()
	end
	refreshAltar()
	RitualService.Changed:Fire()
end

function RitualService.TryTake(trigger: BasePart, hit: BasePart)
	if groundTrigger ~= trigger or carrier or BossFormService.IsActive() then
		return
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or not character or not HealthService.IsAlive(character) then
		return
	end
	if player:GetAttribute("BossForm") ~= nil then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - trigger.Position).Magnitude > BossConfig.Ritual.CollectRadius + 3 then
		return
	end
	clearGround()
	dropToken += 1 -- cancela o sumiço da flecha caída
	setCarrier(player)
	Log.debug(("[RitualService] %s pegou a flecha"):format(player.Name))
	notifyBoss:FireAllClients("arrow", { event = "arrow", state = "taken", by = player.Name, night = EnvironmentService.IsNight() })
end

--- Portador morreu/saiu: a flecha cai onde ele estava (ou volta a um ponto se não der).
local function dropArrow(player: Player, position: Vector3?)
	if carrier ~= player then
		return
	end
	setCarrier(nil)
	if position then
		-- encaixa no chão
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local exclude: { Instance } = { arrowFolder }
		if player.Character then
			table.insert(exclude, player.Character)
		end
		params.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
		local ground = if hit then hit.Position else Vector3.new(position.X, 0, position.Z)
		placeArrow(CFrame.new(ground))
		startDropTimer()
		notifyBoss:FireAllClients("arrow", { event = "arrow", state = "dropped", by = player.Name, position = ground, seconds = BossConfig.Ritual.DropLifetime })
		Log.debug(("[RitualService] a flecha caiu de %s"):format(player.Name))
	else
		-- saiu do jogo: a flecha some e volta na fila aleatória
		scheduleSpawn(BossConfig.Ritual.SpawnDelayMin, BossConfig.Ritual.SpawnDelayMax)
	end
end

--- Altar: só o portador, à noite, vira o boss.
local function onAltarTriggered(player: Player)
	if not RitualService.CanTransform(player) then
		notifyBoss:FireClient(player, "denied", { event = "denied", reason = RitualService.StatusText() })
		return
	end
	local ok, why = BossFormService.Transform(player)
	if not ok then
		notifyBoss:FireClient(player, "denied", { event = "denied", reason = why })
		return
	end
	-- a flecha foi consumida
	setCarrier(nil)
end

--- [Admin] dá a flecha ao jogador (ou põe uma no mapa se nil).
function RitualService.GiveArrow(player: Player?)
	clearGround()
	if player then
		setCarrier(player)
	else
		setCarrier(nil)
		spawnArrowAtSpot()
	end
end

--- Forma acabou: flecha entra na fila aleatória depois de RespawnDelay.
function RitualService.Restart(delaySeconds: number?)
	local cfg = BossConfig.Ritual
	local base = delaySeconds or cfg.RespawnDelay
	scheduleSpawn(base + cfg.SpawnDelayMin, base + cfg.SpawnDelayMax)
end

function RitualService.Init()
	notifyBoss = Remotes.GetEvent(Remotes.Events.NotifyBoss)
end

function RitualService.Start()
	local sahur = Workspace:FindFirstChild("Sahur")
	if not sahur then
		return
	end
	local torchByIndex: { [number]: BasePart } = {}
	local socketByIndex: { [number]: BasePart } = {}
	for _, d in sahur:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local torchIdx = d.Name:match("^BossAltarTorch(%d+)$")
		local socketIdx = d.Name:match("^BossAltarSkullSocket(%d+)$")
		if d.Name:match("^ArrowSpot%d+$") then
			table.insert(spots, d)
		elseif torchIdx then
			torchByIndex[tonumber(torchIdx) :: number] = d
		elseif socketIdx then
			socketByIndex[tonumber(socketIdx) :: number] = d
		elseif d.Name == "BossAltarRune" then
			rune = d
		elseif d.Name == "BossAltar" then
			altar = d
		elseif d.Name:match("^BossCrack%d+$") then
			table.insert(cracks, d)
		end
	end
	for i = 0, 15 do
		if torchByIndex[i] then
			table.insert(torches, torchByIndex[i])
		end
		if socketByIndex[i] then
			table.insert(sockets, socketByIndex[i])
		end
	end
	arrowFolder = Instance.new("Folder")
	arrowFolder.Name = "RitualArrow"
	arrowFolder.Parent = Workspace

	-- caveiras decorativas fixas nos encaixes do altar
	for _, socket in sockets do
		local skull = Instance.new("Part")
		skull.Name = "Skull"
		skull.Shape = Enum.PartType.Ball
		skull.Size = Vector3.new(1.4, 1.4, 1.4)
		skull.Color = Color3.fromRGB(214, 204, 176)
		skull.Material = Enum.Material.SmoothPlastic
		skull.Anchored = true
		skull.CanCollide = false
		skull.CastShadow = false
		skull.CFrame = socket.CFrame * CFrame.new(0, 0.9, 0)
		skull.Parent = socket
	end

	if altar then
		local p = Instance.new("ProximityPrompt")
		p.Name = "RitualPrompt"
		p.ActionText = "Virar " .. BossConfig.Name
		p.ObjectText = "Altar"
		p.HoldDuration = 1.2
		p.MaxActivationDistance = 12
		p.RequiresLineOfSight = false
		p.Parent = altar
		p.Triggered:Connect(onAltarTriggered)
		prompt = p

		local gui = Instance.new("BillboardGui")
		gui.Name = "BossAltarGui"
		gui.Size = UDim2.fromOffset(300, 40)
		gui.StudsOffset = Vector3.new(0, 4, 0)
		gui.MaxDistance = 90
		gui.Parent = altar
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 18
		label.TextColor3 = Color3.fromRGB(255, 220, 200)
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
		statusLabel = label
	else
		warn("[RitualService] Workspace.Sahur sem BossAltar (ArenaExtras); altar desativado")
	end

	if not BossConfig.Ritual.Enabled then
		refreshAltar()
		return
	end
	scheduleSpawn(BossConfig.Ritual.FirstSpawnMin, BossConfig.Ritual.FirstSpawnMax)
	Workspace:GetAttributeChangedSignal("IsNight"):Connect(function()
		refreshAltar()
		RitualService.Changed:Fire()
	end)
	BossFormService.Changed.Event:Connect(function()
		refreshAltar()
		if not BossFormService.IsActive() then
			RitualService.Restart()
		end
	end)
	-- portador morreu = flecha cai ali; saiu = volta a um ponto
	HealthService.Died.Event:Connect(function(victim: Player)
		if victim == carrier then
			local root = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			dropArrow(victim, root and root.Position)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if player == carrier then
			dropArrow(player, nil)
		end
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function()
			if carrier == player and player:GetAttribute("BossForm") == nil then
				task.wait(0.5)
				attachToCarrier(player)
			end
		end)
	end)
	Log.debug(("[RitualService] pronto: %d pontos da flecha, %d tochas"):format(#spots, #torches))
end

return RitualService
