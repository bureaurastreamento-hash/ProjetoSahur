--!strict
-- Aluguel em moeda do jogo. Simulação/obstáculos/posse no servidor; cliente envia só direção normalizada.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.VesselConfig)
local Remotes = require(Modules.RemoteEvents)
local RateLimiter = require(Modules.RateLimiter)
local Data = require(script.Parent.DataService)
local Story = require(script.Parent.StoryService)
local World = require(script.Parent.WorldService)
local AntiExploit = require(script.Parent.AntiExploitService)
local Captain = require(script.Parent.Parent.Modules.CaptainAppearance)
local Service = {}
local limiter = RateLimiter.new(15, 1)
type Vessel = { model: Model, helm: VehicleSeat, seats: { Seat | VehicleSeat }, cf: CFrame, speed: number, throttle: number, steer: number, inputAt: number, vacantAt: number, offer: Config.Offer, bounds: Vector3, owner: Player }
local vessels: { [Player]: Vessel } = {}
local registered: { [BasePart]: Config.Port } = {}
local folder: Folder
local function clear(player: Player)
	local vessel = vessels[player]
	if not vessel then return end
	vessels[player] = nil
	for _, seat in vessel.seats do if seat.Occupant then seat.Occupant.Sit = false end end
	vessel.model:Destroy()
	player:SetAttribute("VesselOwner", nil)
end
function Service.Dock(who: Player, model: Model, anchor: BasePart): boolean
	local vessel: Vessel? = nil
	for _, candidate in vessels do if candidate.model == model then vessel = candidate; break end end
	if not vessel or not model.Parent then return false end
	local registeredSeat = false
	for _, seat in vessel.seats do if seat == anchor then registeredSeat = true end end
	if not registeredSeat or not Story.CanInteract(who, anchor, 16) then return false end
	local closest: Config.Port? = nil
	local distance = 190
	for _, candidate in Config.Ports do
		local delta = (model:GetPivot().Position - candidate.Land).Magnitude
		if delta < distance and (not candidate.RequiredFlag or Story.HasFlag(who, candidate.RequiredFlag)) then closest, distance = candidate, delta end
	end
	local character = who.Character
	if not closest or not character then Story.Say(who, "Aproxime o navio de um porto já liberado para desembarcar.", "Forever"); return false end
	vessel.speed, vessel.throttle, vessel.steer, vessel.inputAt = 0, 0, 0, 0
	local h = character:FindFirstChildOfClass("Humanoid")
	if h then
		local seat = h.SeatPart
		h.Sit = false
		if seat and seat:IsDescendantOf(model) then
			local weld = seat:FindFirstChild("SeatWeld")
			if weld and weld:IsA("Weld") and weld.Part1 and weld.Part1:IsDescendantOf(character) then weld:Destroy() end
		end
	end
	AntiExploit.Grace(who, 3)
	character:PivotTo(CFrame.new(closest.Land + Vector3.new(0, 5, 0)))
	World.Discover(who, closest.Id)
	Story.ArriveRegion(who, closest.Id)
	return true
end
function Service.Rent(player: Player, key: string, marker: BasePart): boolean
	local port, offer = registered[marker], Config.Offers[key]
	local profile = Data.GetProfile(player)
	if not port or not offer or not profile or (offer.Price > 0 and Data.IsSessionOnly(player)) or player:GetAttribute("DataTransaction")
		or not marker:IsDescendantOf(Workspace) or not Story.CanInteract(player, marker, 14) then return false end
	if port.RequiredFlag and not profile.story.flags[port.RequiredFlag] then Story.Say(player, "Abra a rota desta ilha na campanha antes de contratar uma embarcação.", "Forever"); return false end
	local existing = vessels[player]
	if existing then
		if existing.offer.Asset == offer.Asset and existing.model.Parent and (existing.cf.Position - marker.Position).Magnitude <= 190 and not existing.helm.Occupant and player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return false end
			AntiExploit.Grace(player, 3)
			player.Character:PivotTo(existing.helm.CFrame * CFrame.new(0, 2, 0))
			task.defer(function() if existing.helm.Parent and humanoid.Parent then existing.helm:Sit(humanoid) end end)
			Story.Say(player, "Seu navio está ancorado aqui. Pode voltar ao leme, sem pagar novamente.", "Forever")
			return true
		end
		Story.Say(player, "Seu barco ainda está no mar. Aproxime-o deste porto ou libere-o pelo leme antes de alugar outro.", "Forever"); return false
	end
	if profile.coins < offer.Price then Story.Say(player, ("O aluguel custa %d moedas. O barco a remo é gratuito."):format(offer.Price), "Forever"); return false end
	local assets = ReplicatedStorage.Assets:FindFirstChild("EnvironmentModels")
	local template = assets and assets:FindFirstChild(offer.Asset)
	if not template or not template:IsA("Model") then Story.Say(player, "Esta embarcação está indisponível no momento.", "Forever"); return false end
	local model = template:Clone()
	local _, originalSize = model:GetBoundingBox()
	model:ScaleTo(offer.Length / originalSize.Z)
	local box, size = model:GetBoundingBox()
	local spawn = port.Land + port.Outward * (offer.Length / 2 + 100)
	local cf = CFrame.lookAt(Vector3.new(spawn.X, -2, spawn.Z), Vector3.new(spawn.X, -2, spawn.Z) + port.Outward)
	local pivotOffset = model:GetPivot():ToObjectSpace(box)
	model:PivotTo(cf * CFrame.new(0, size.Y / 2, 0) * pivotOffset:Inverse())
	local overlap = OverlapParams.new(); overlap.FilterType = Enum.RaycastFilterType.Exclude; overlap.FilterDescendantsInstances = { model, folder }
	-- Evitar geometria/terreno na faixa navegável; toda a construção acontece antes de cobrar.
	local collision = Workspace:GetPartBoundsInBox(cf * CFrame.new(0, 4, 0), Vector3.new(size.X + 3, 5, size.Z + 4), overlap)
	for _, part in collision do if part.CanCollide then model:Destroy(); Story.Say(player, "O berço está ocupado. Aguarde a saída do navio.", "Forever"); return false end end
	for _, other in vessels do if (other.cf.Position - cf.Position).Magnitude < (other.bounds.Z + size.Z) / 2 then model:Destroy(); Story.Say(player, "Há um navio manobrando aqui. Aguarde um instante.", "Forever"); return false end end
	for _, part in model:GetDescendants() do if part:IsA("BasePart") then part.Anchored = true; part.CanCollide = false; part.CanTouch = false end end
	model.Name = offer.Name .. " · " .. player.Name
	model:SetAttribute("Vessel", true); model:SetAttribute("OwnerUserId", player.UserId)
	local deckHeight = if offer.Cruise then size.Y * .53 else size.Y * .25
	local deck = Instance.new("Part")
	deck.Name, deck.Size, deck.CFrame = "Convés", Vector3.new(size.X * .7, .5, size.Z * .6), cf * CFrame.new(0, deckHeight, 0)
	deck.Anchored, deck.CanCollide, deck.Transparency, deck.Parent = true, true, 1, model
	local helm = Instance.new("VehicleSeat")
	helm.Name, helm.Size, helm.CFrame = "Leme", Vector3.new(2, 1, 2), cf * CFrame.new(0, deckHeight + 1, -size.Z * .16)
	helm.Anchored, helm.CanCollide, helm.HeadsUpDisplay, helm.Parent = true, true, false, model
	helm:SetAttribute("VesselHelm", true)
	local seats: { Seat | VehicleSeat } = { helm }
	if offer.Cruise then
		for index = 1, 6 do
			local seat = Instance.new("Seat"); seat.Name, seat.Size, seat.Anchored = "Passageiro" .. index, Vector3.new(2, 1, 2), true
			seat.CFrame, seat.Parent = cf * CFrame.new(if index % 2 == 0 then 4 else -4, deckHeight + 1, math.ceil(index / 2) * 5), model
			table.insert(seats, seat)
		end
	end
	local board = Instance.new("ProximityPrompt")
	board.ActionText, board.ObjectText, board.MaxActivationDistance, board.RequiresLineOfSight = "Pilotar", offer.Name, 12, false
	board.Parent = helm
	board.Triggered:Connect(function(who) if who == player and Story.CanInteract(who, helm, 14) and who.Character and not helm.Occupant then local h = who.Character:FindFirstChildOfClass("Humanoid"); if h then helm:Sit(h) end end end)
	local disembark = Instance.new("ProximityPrompt")
	disembark.ActionText, disembark.ObjectText, disembark.KeyboardKeyCode, disembark.HoldDuration, disembark.MaxActivationDistance = "Desembarcar no porto", offer.Name, Enum.KeyCode.T, .7, 14
	disembark.Parent = helm
	disembark.Triggered:Connect(function(who) Service.Dock(who, model, helm) end)
	for _, seat in seats do
		if seat == helm then continue end
		local copy = disembark:Clone(); copy.Parent = seat
		copy.Triggered:Connect(function(who) Service.Dock(who, model, seat) end)
	end
	local release = Instance.new("ProximityPrompt")
	release.ActionText, release.ObjectText, release.KeyboardKeyCode, release.HoldDuration, release.MaxActivationDistance = "Liberar navio", offer.Name, Enum.KeyCode.R, 1.5, 12
	release.Parent = helm
	release.Triggered:Connect(function(who) if who == player and Story.CanInteract(who, helm, 14) then clear(player) end end)
	helm:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = helm.Occupant
		if occupant and Players:GetPlayerFromCharacter(occupant.Parent :: Model) ~= player then occupant.Sit = false end
	end)
	-- Pivô agora na linha d'água, para o servidor movimentar o conjunto coerentemente.
	model.WorldPivot = cf
	model.Parent = folder
	vessels[player] = { model = model, helm = helm, seats = seats, cf = cf, speed = 0, throttle = 0, steer = 0, inputAt = 0, vacantAt = os.clock(), offer = offer, bounds = size, owner = player }
	Data.SetCoins(player, profile.coins - offer.Price)
	player:SetAttribute("VesselOwner", true)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid then
		AntiExploit.Grace(player, 3)
		character:PivotTo(helm.CFrame * CFrame.new(0, 2, 0))
		task.defer(function() if helm.Parent and humanoid.Parent then helm:Sit(humanoid) end end)
	end
	Remotes.GetEvent(Remotes.Events.NotifyVessel):FireAllClients(model, offer.Cruise)
	Story.Say(player, if offer.Cruise then "Strength transformou o barco no seu cruzeiro. W/S aceleram, A/D manobram. Salte para sair do leme; R libera o navio. Leve passageiros sentados durante a viagem." else "W/S aceleram, A/D manobram. Salte para sair e use o leme para voltar a pilotar. R libera o barco.", "Forever")
	return true
end
function Service.Input(player: Player, throttle: any, steer: any)
	if not Config.ValidInput(throttle, steer) or not limiter:Allow(player) then return end
	local vessel = vessels[player]
	local character = player.Character
	if not vessel or not character or vessel.helm.Occupant ~= character:FindFirstChildOfClass("Humanoid") then return end
	vessel.throttle, vessel.steer, vessel.inputAt = throttle, steer, os.clock()
end
function Service.Start()
	folder = Instance.new("Folder"); folder.Name, folder.Parent = "PortosStrength", Workspace
	for _, port in Config.Ports do
		local ray = Workspace:Raycast(port.Land + Vector3.new(0, 100, 0), Vector3.new(0, -140, 0))
		if not ray or ray.Material == Enum.Material.Water then warn("[VesselService] porto sem chão: " .. port.Id); continue end
		local land = Vector3.new(port.Land.X, ray.Position.Y, port.Land.Z)
		local pier = Instance.new("Part")
		pier.Name, pier.Size, pier.Anchored, pier.Material = "Cais_" .. port.Id, Vector3.new(14, 1, 56), true, Enum.Material.WoodPlanks
		pier.Color, pier.CFrame, pier.Parent = Color3.fromRGB(143, 105, 66), CFrame.lookAt(land + port.Outward * 20 + Vector3.new(0, 1, 0), land + port.Outward * 21 + Vector3.new(0, 1, 0)), folder
		local captain = Captain.Create(CFrame.lookAt(land + Vector3.new(0, 3, 0), land - port.Outward + Vector3.new(0, 3, 0)))
		if not captain then continue end
		captain.Parent = folder
		local root = captain:FindFirstChild("HumanoidRootPart") :: BasePart
		registered[root] = port
		for key, offer in Config.Offers do
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText, prompt.ObjectText, prompt.HoldDuration, prompt.MaxActivationDistance = offer.Name, ("Forever · %d moedas"):format(offer.Price), .6, 12
			prompt.KeyboardKeyCode = if key == "strength" then Enum.KeyCode.E elseif key == "lancha" then Enum.KeyCode.F else Enum.KeyCode.T
			prompt.Parent = root
			prompt.Triggered:Connect(function(player) Service.Rent(player, key, root) end)
		end
	end
	Remotes.GetEvent(Remotes.Events.RequestVesselInput).OnServerEvent:Connect(Service.Input)
	Players.PlayerRemoving:Connect(clear)
	RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, .1)
		for player, vessel in vessels do
			if not vessel.model.Parent then clear(player); continue end
			local now = os.clock()
			local occupied = false
			for _, seat in vessel.seats do
				local humanoid = seat.Occupant
				local passenger = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent :: Model)
				if passenger then occupied = true; AntiExploit.Grace(passenger, 1) end
			end
			if occupied then vessel.vacantAt = now elseif now - vessel.vacantAt > 180 then clear(player); continue end
			local active = now - vessel.inputAt < .5 and vessel.helm.Occupant ~= nil
			local target = if active then vessel.throttle * vessel.offer.Speed else 0
			vessel.speed += (target - vessel.speed) * math.min(1, dt * 1.3)
			vessel.model:SetAttribute("Speed", math.abs(vessel.speed))
			local steer = if active then vessel.steer else 0
			local proposed = vessel.cf * CFrame.Angles(0, -steer * vessel.offer.Turn * dt * math.min(1, math.abs(vessel.speed) / 8), 0) * CFrame.new(0, 0, -vessel.speed * dt)
			local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { vessel.model }; params.RespectCanCollide = true
			local movement = proposed.Position - vessel.cf.Position
			if movement.Magnitude > .01 then
				local hit = Workspace:Blockcast(vessel.cf * CFrame.new(0, 4, 0), Vector3.new(vessel.bounds.X, 5, vessel.bounds.Z), movement, params)
				local locked = false
				for _, port in Config.Ports do
					if port.RequiredFlag and not Story.HasFlag(player, port.RequiredFlag) and (proposed.Position - port.Land).Magnitude < vessel.offer.Length / 2 + 35 then locked = true end
				end
				if hit or locked or math.abs(proposed.X) > 4000 or math.abs(proposed.Z) > 3000 then vessel.speed = 0 else vessel.cf = proposed; vessel.model:PivotTo(proposed) end
			end
		end
	end)
end
return Service
