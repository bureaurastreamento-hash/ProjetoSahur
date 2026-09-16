--!strict
--[[
	RitualService (servidor)
	"Puzzle" do boss: caveiras espalhadas pelo mapa (em cima dos SkullSpot* do ArenaExtras, lugares fáceis e
	iluminados). Encostar numa caveira coleta (servidor confere a distância). Cada caveira coletada acende
	uma tocha do altar e aparece num BossAltarSkullSocket{i}; com BossConfig.Ritual.SkullsRequired o ritual
	está completo e o altar aceita a invocação — só à NOITE (EnvironmentService.IsNight).
	Progresso é do servidor (todo mundo colabora). BossService chama Consume() ao invocar e Restart() quando
	a luta acaba; as caveiras voltam em pontos sorteados.

	Caveira: Model/BasePart chamado BossConfig.Ritual.SkullModelName em ServerStorage ou
	ReplicatedStorage.Assets (a equipe pode colocar um modelo); senão uma caveira simples por código.
	Tag CollectionService "RitualSkull" para o cliente animar (flutuar/girar) — BossController.

	Eventos (NotifyBoss): "ritual" { collected, required, by, complete, night }
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

local RitualService = {}

local TAG = "RitualSkull"
local ATTR_COLLECTED = "RitualSkulls" -- em Workspace: replica o progresso (HUD/altar)
local ATTR_REQUIRED = "RitualSkullsRequired"

local notifyBoss: RemoteEvent
local spots: { BasePart } = {}
local sockets: { BasePart } = {}
local torches: { BasePart } = {}
local rune: BasePart? = nil
local cracks: { BasePart } = {}
local skullsFolder: Folder
local activeSkulls: { [BasePart]: boolean } = {}
local collected = 0
local restartToken = 0
local rng = Random.new()

--- Progresso completo? (as caveiras já foram todas coletadas)
function RitualService.IsComplete(): boolean
	return not BossConfig.Ritual.Enabled or collected >= BossConfig.Ritual.SkullsRequired
end

function RitualService.GetProgress(): (number, number)
	return collected, BossConfig.Ritual.SkullsRequired
end

--- O altar pode invocar agora? (ritual completo + noite, se NightOnly)
function RitualService.CanSummon(): boolean
	local cfg = BossConfig.Ritual
	if not cfg.Enabled then
		return true
	end
	if cfg.NightOnly and not EnvironmentService.IsNight() then
		return false
	end
	return RitualService.IsComplete()
end

--- Texto para o letreiro do altar quando não dá para invocar ainda.
function RitualService.StatusText(): string
	local cfg = BossConfig.Ritual
	if not RitualService.IsComplete() then
		return ("Ritual: %d/%d caveiras — procure as lanternas"):format(collected, cfg.SkullsRequired)
	end
	if cfg.NightOnly and not EnvironmentService.IsNight() then
		return "Ritual completo — espere a NOITE"
	end
	return "Altar pronto: segure E para invocar"
end

-- ---------------------------------------------------------------------------
-- Visual do altar
-- ---------------------------------------------------------------------------

local function setFire(part: BasePart, on: boolean)
	for _, d in part:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.Enabled = on
		elseif d:IsA("PointLight") then
			d.Enabled = on
		end
	end
end

local function setRune(ready: boolean)
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
end

local function refreshAltar()
	for i, torch in torches do
		setFire(torch, i <= collected)
	end
	for i, socket in sockets do
		local existing = socket:FindFirstChild("Skull")
		if i <= collected and not existing then
			local skull = RitualService.BuildSkull()
			skull.Name = "Skull"
			skull:PivotTo(socket.CFrame * CFrame.new(0, 0.9, 0))
			skull.Parent = socket
		elseif i > collected and existing then
			existing:Destroy()
		end
	end
	setRune(RitualService.CanSummon())
	Workspace:SetAttribute(ATTR_COLLECTED, collected)
	Workspace:SetAttribute(ATTR_REQUIRED, BossConfig.Ritual.SkullsRequired)
end

-- ---------------------------------------------------------------------------
-- Caveira
-- ---------------------------------------------------------------------------

local function findSkullTemplate(): Instance?
	local name = BossConfig.Ritual.SkullModelName
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	for _, root in { ServerStorage, assets } do
		local found = root and root:FindFirstChild(name, true)
		if found and (found:IsA("Model") or found:IsA("BasePart")) then
			return found
		end
	end
	return nil
end

--- Caveira (Model com PrimaryPart). Do template da equipe, se existir; senão por código.
function RitualService.BuildSkull(): Model
	local template = findSkullTemplate()
	local model: Model
	if template then
		local clone = template:Clone()
		if clone:IsA("Model") then
			model = clone
		else
			model = Instance.new("Model")
			clone.Parent = model
			model.PrimaryPart = clone :: BasePart
		end
		if not model.PrimaryPart then
			model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
		end
	else
		model = Instance.new("Model")
		local bone = Color3.fromRGB(222, 212, 184)
		local function mk(name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3?): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Shape = shape
			p.Size = size
			p.CFrame = cf
			p.Color = color or bone
			p.Material = Enum.Material.SmoothPlastic
			p.CastShadow = false
			p.Parent = model
			return p
		end
		local head = mk("Cranium", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 0.4, 0))
		mk("Jaw", Enum.PartType.Block, Vector3.new(1.1, 0.5, 0.9), CFrame.new(0, -0.45, 0.15))
		local dark = Color3.fromRGB(20, 14, 14)
		mk("EyeL", Enum.PartType.Ball, Vector3.new(0.42, 0.42, 0.3), CFrame.new(-0.32, 0.45, -0.72), dark)
		mk("EyeR", Enum.PartType.Ball, Vector3.new(0.42, 0.42, 0.3), CFrame.new(0.32, 0.45, -0.72), dark)
		mk("Nose", Enum.PartType.Block, Vector3.new(0.22, 0.3, 0.2), CFrame.new(0, 0.1, -0.78), dark)
		local glow = mk("Glow", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.4, 0), Color3.fromRGB(255, 60, 60))
		glow.Material = Enum.Material.Neon
		glow.Transparency = 0.35
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 70, 70)
		light.Brightness = 1.6
		light.Range = 12
		light.Parent = head
		model.PrimaryPart = head
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local primary = model.PrimaryPart
	if primary then
		-- as partes ficam soldadas ao PrimaryPart para o cliente animar movendo só ele
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = d
				weld.Parent = d
				d.Anchored = false
			end
		end
	end
	return model
end

local function clearSkulls()
	for skull in activeSkulls do
		skull:Destroy()
	end
	table.clear(activeSkulls)
end

local function spawnSkulls()
	clearSkulls()
	local cfg = BossConfig.Ritual
	if #spots == 0 then
		warn("[RitualService] sem SkullSpot* no ArenaExtras; ritual desativado")
		return
	end
	local pool = table.clone(spots)
	for i = 1, math.min(cfg.SkullsRequired, #pool) do
		local idx = rng:NextInteger(1, #pool)
		local spot = table.remove(pool, idx) :: BasePart
		local skull = RitualService.BuildSkull()
		skull.Name = "RitualSkull"
		skull:PivotTo(spot.CFrame * CFrame.new(0, 2.2, 0))
		-- gatilho de coleta: caixa invisível em volta (a caveira em si não recebe Touch)
		local trigger = Instance.new("Part")
		trigger.Name = "Trigger"
		trigger.Size = Vector3.new(6, 6, 6)
		trigger.CFrame = spot.CFrame * CFrame.new(0, 3, 0)
		trigger.Transparency = 1
		trigger.Anchored = true
		trigger.CanCollide = false
		trigger.CanQuery = false
		trigger.CastShadow = false
		trigger.Parent = skull
		skull:SetAttribute("SpotName", spot.Name)
		CollectionService:AddTag(skull, TAG)
		skull.Parent = skullsFolder
		activeSkulls[trigger] = true
		trigger.Touched:Connect(function(hit)
			RitualService.TryCollect(trigger, hit)
		end)
	end
	Log.debug(("[RitualService] %d caveira(s) no mapa"):format(cfg.SkullsRequired))
end

function RitualService.TryCollect(trigger: BasePart, hit: BasePart)
	if not activeSkulls[trigger] then
		return
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or not character or not HealthService.IsAlive(character) then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - trigger.Position).Magnitude > BossConfig.Ritual.CollectRadius + 3 then
		return
	end
	activeSkulls[trigger] = nil
	local skull = trigger.Parent
	if skull then
		skull:Destroy()
	end
	collected = math.min(collected + 1, BossConfig.Ritual.SkullsRequired)
	refreshAltar()
	local complete = RitualService.IsComplete()
	Log.debug(("[RitualService] %s coletou uma caveira (%d/%d)"):format(player.Name, collected, BossConfig.Ritual.SkullsRequired))
	notifyBoss:FireAllClients("ritual", {
		event = "ritual",
		collected = collected,
		required = BossConfig.Ritual.SkullsRequired,
		by = player.Name,
		complete = complete,
		night = EnvironmentService.IsNight(),
	})
	RitualService.Changed:Fire()
end

--- Disparado quando o progresso/condição muda (BossService atualiza o letreiro/prompt).
RitualService.Changed = Instance.new("BindableEvent")

--- BossService invocou: gasta o ritual (caveiras do altar somem, tochas apagam).
function RitualService.Consume()
	collected = 0
	refreshAltar()
	RitualService.Changed:Fire()
end

--- Luta acabou / cooldown: caveiras voltam ao mapa depois de RespawnDelay.
function RitualService.Restart(delaySeconds: number?)
	restartToken += 1
	local token = restartToken
	task.delay(delaySeconds or BossConfig.Ritual.RespawnDelay, function()
		if token ~= restartToken then
			return
		end
		collected = 0
		refreshAltar()
		spawnSkulls()
		RitualService.Changed:Fire()
	end)
end

--- [Admin] completa o ritual na hora.
function RitualService.ForceComplete()
	clearSkulls()
	collected = BossConfig.Ritual.SkullsRequired
	refreshAltar()
	RitualService.Changed:Fire()
end

function RitualService.Init()
	notifyBoss = Remotes.GetEvent(Remotes.Events.NotifyBoss)
end

function RitualService.Start()
	local sahur = Workspace:FindFirstChild("Sahur")
	if not sahur then
		return
	end
	local byIndex: { [number]: BasePart } = {}
	local socketByIndex: { [number]: BasePart } = {}
	for _, d in sahur:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local spotIdx = d.Name:match("^SkullSpot(%d+)$")
		local torchIdx = d.Name:match("^BossAltarTorch(%d+)$")
		local socketIdx = d.Name:match("^BossAltarSkullSocket(%d+)$")
		if spotIdx then
			table.insert(spots, d)
		elseif torchIdx then
			byIndex[tonumber(torchIdx) :: number] = d
		elseif socketIdx then
			socketByIndex[tonumber(socketIdx) :: number] = d
		elseif d.Name == "BossAltarRune" then
			rune = d
		elseif d.Name:match("^BossCrack%d+$") then
			table.insert(cracks, d)
		end
	end
	for i = 0, 15 do
		if byIndex[i] then
			table.insert(torches, byIndex[i])
		end
		if socketByIndex[i] then
			table.insert(sockets, socketByIndex[i])
		end
	end
	skullsFolder = Instance.new("Folder")
	skullsFolder.Name = "RitualSkulls"
	skullsFolder.Parent = Workspace

	if not BossConfig.Ritual.Enabled then
		for _, torch in torches do
			setFire(torch, true)
		end
		setRune(true)
		return
	end
	refreshAltar()
	spawnSkulls()
	-- anoiteceu/amanheceu: runa e letreiro
	Workspace:GetAttributeChangedSignal("IsNight"):Connect(function()
		setRune(RitualService.CanSummon())
		RitualService.Changed:Fire()
	end)
	Log.debug(("[RitualService] pronto: %d pontos, %d tochas, %d encaixes"):format(#spots, #torches, #sockets))
end

return RitualService
