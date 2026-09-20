--!strict
--[[
	SaloonDoorService (servidor)
	PORTAS DE SALOON do hall da Taberna (dono, 2026-09-25): `Workspace.Taberna.Hall.Entrada.PortaSaloon`
	(montada por tools/montar_hall.luau) tem duas asas (`AsaSul`/`AsaNorte`, Models com PrimaryPart
	`Dobradica` no eixo da dobradiça e atributo `Dir` = para que lado a asa cresce em z) e um `Gatilho`
	invisível no vão. Quem entra no gatilho (jogador ou bot) empurra as duas asas para o lado oposto de
	onde veio (vindo de fora = abrem para dentro); ficam abertas enquanto houver alguém no vão e voltam
	balançando quando sai. As asas são ancoradas: o servidor move por PivotTo a cada Heartbeat (só quando
	estão se mexendo), e o cliente recebe a replicação normal.
	Também marca a PORTA DOS FUNDOS (`Workspace["Moveis taverna"].Door_Interior_Frame_A_Static`, a porta
	norte do salão) como TRANCADA: ProximityPrompt sem ação — segredo/missão futura da história (dono).
	Sem o hall no place = não faz nada (avisa no Studio).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))

local SaloonDoorService = {}

local OPEN_ANGLE = 100 -- graus
local OPEN_SPEED = 6 -- 1/s (quanto maior, mais rápido chega)
local CLOSE_SPEED = 3.5
local SWING_BACK = 0.35 -- balanço ao fechar (fração do ângulo que passa do zero e volta)
local HOLD_SECONDS = 0.6 -- segura aberta depois de o vão esvaziar

type Wing = { model: Model, hinge: BasePart, rest: CFrame, dir: number, angle: number, target: number }
local wings: { Wing } = {}
local trigger: BasePart? = nil
local occupants: { [Model]: number } = {} -- personagem -> os.clock() da última vez visto no vão
local openSide = 1 -- +1 = asas empurradas para +x (para dentro do hall), −1 = para fora
local moving = false
local lastEmpty = 0
local heartbeat: RBXScriptConnection? = nil

local function characterOf(part: BasePart): Model?
	local node: Instance? = part.Parent
	for _ = 1, 4 do
		if not node or node == Workspace then
			return nil
		end
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function applyWings()
	for _, w in wings do
		-- asa gira em Y em volta da dobradiça; o sinal depende do lado da dobradiça e do lado para onde abre
		local sign = w.dir * openSide
		w.model:PivotTo(w.rest * CFrame.Angles(0, math.rad(w.angle * sign), 0))
	end
end

local function step(dt: number)
	local now = os.clock()
	-- quem ainda está no vão? (Touched não avisa direito quando o jogador para dentro do gatilho)
	local anyone = false
	for character, seen in occupants do
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not character.Parent then
			occupants[character] = nil
		else
			local t = trigger :: BasePart
			local local_ = t.CFrame:PointToObjectSpace(root.Position)
			local half = t.Size / 2
			if math.abs(local_.X) <= half.X + 1 and math.abs(local_.Y) <= half.Y + 2 and math.abs(local_.Z) <= half.Z then
				occupants[character] = now
				anyone = true
			elseif now - seen > 0.3 then
				occupants[character] = nil
			end
		end
	end
	if anyone then
		lastEmpty = now
	end
	local wantOpen = anyone or now - lastEmpty < HOLD_SECONDS
	local settled = true
	for _, w in wings do
		w.target = if wantOpen then OPEN_ANGLE else 0
		local speed = if wantOpen then OPEN_SPEED else CLOSE_SPEED
		local diff = w.target - w.angle
		if wantOpen then
			w.angle += diff * math.min(1, dt * speed)
		else
			-- fechando: passa um pouco do zero e volta (balanço de porta de saloon)
			w.angle += diff * math.min(1, dt * speed)
			if w.angle < 0.5 and w.angle > -0.01 and not w.model:GetAttribute("Swung") then
				w.model:SetAttribute("Swung", true)
				w.angle = -OPEN_ANGLE * SWING_BACK
			end
		end
		if wantOpen then
			w.model:SetAttribute("Swung", false)
		end
		if math.abs(w.target - w.angle) > 0.2 then
			settled = false
		end
	end
	applyWings()
	if settled and not wantOpen then
		for _, w in wings do
			w.angle = 0
		end
		applyWings()
		moving = false
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end
end

local function startMoving()
	if moving then
		return
	end
	moving = true
	heartbeat = RunService.Heartbeat:Connect(step)
end

local function onTouched(part: BasePart)
	local character = characterOf(part)
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	if next(occupants) == nil then
		-- primeiro a entrar decide o lado: vindo de x menor (fora) empurra para +x (dentro)
		openSide = if root.Position.X < (trigger :: BasePart).Position.X then 1 else -1
	end
	occupants[character] = os.clock()
	lastEmpty = os.clock()
	startMoving()
end

local function setupDoor(): boolean
	local taberna = Workspace:FindFirstChild("Taberna")
	local hall = taberna and taberna:FindFirstChild("Hall")
	local entrada = hall and hall:FindFirstChild("Entrada")
	local porta = entrada and entrada:FindFirstChild("PortaSaloon")
	if not porta then
		return false
	end
	trigger = porta:FindFirstChild("Gatilho") :: BasePart?
	if not trigger then
		return false
	end
	table.clear(wings)
	for _, name in { "AsaSul", "AsaNorte" } do
		local m = porta:FindFirstChild(name)
		local hinge = m and m:IsA("Model") and m.PrimaryPart
		if m and hinge then
			table.insert(wings, { model = m, hinge = hinge, rest = m:GetPivot(), dir = tonumber(m:GetAttribute("Dir")) or 1, angle = 0, target = 0 })
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanQuery = false -- hitboxes de combate não batem nas asas
				end
			end
		end
	end
	if #wings == 0 then
		return false
	end
	trigger.CanTouch = true
	trigger.Touched:Connect(onTouched)
	return true
end

local function setupBackDoor()
	local kit = Workspace:FindFirstChild("Moveis taverna")
	local door = kit and kit:FindFirstChild("Door_Interior_Frame_A_Static")
	local leaf = door and door:FindFirstChild("Interrior_Door", true)
	if not leaf or not leaf:IsA("BasePart") then
		return
	end
	if leaf:FindFirstChild("LockedPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LockedPrompt"
	prompt.ObjectText = "Porta dos fundos"
	prompt.ActionText = "Trancada"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = leaf
	prompt.Triggered:Connect(function()
		-- só chacoalha a maçaneta: nada acontece (segredo/missão futura)
		local sound = door and door:FindFirstChild("DoorClose", true)
		if sound and sound:IsA("Sound") then
			sound:Play()
		end
	end)
end

function SaloonDoorService.Start()
	if not setupDoor() then
		if RunService:IsStudio() then
			Log.debug("[SaloonDoorService] sem Workspace.Taberna.Hall.Entrada.PortaSaloon (rodar tools/montar_hall.luau)")
		end
	else
		Log.debug(("[SaloonDoorService] portas de saloon prontas (%d asas)"):format(#wings))
	end
	setupBackDoor()
end

return SaloonDoorService
