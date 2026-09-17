--!strict
--[[
	DummyService (servidor)
	Bonecos de treino no mapa livre. Rig R6 criado em runtime
	(Players:CreateHumanoidModelFromDescription), tag "Combatant" para a Hitbox
	aceitar, vida via HealthService (dano normal, sem crédito de kill/moedas: não é Player).
	Posições: Parts "DummyPad*" em Workspace.Sahur (ArenaExtras); sem pads = nada.
	Comportamento pelo NOME do pad (ordem alfabética): DummyPad0 = parado, DummyPad1 = bloqueando
	sempre (atributo Blocking; testa block/guard break), DummyPad2 = ATACANTE (soca quem chegar perto,
	combo de 4 com o ritmo do M1; testa hitstun/ragdoll/parry). Atributo "Behavior" no Model.
	Respawn RESPAWN_SECONDS depois de morrer.
	Dono (2026-09-17): bonecos "de verdade" — rig com FÍSICA (não ancorado; fica em pé com WalkSpeed 0),
	toma knockback e RAGDOLL como um jogador (CombatService.Knockback/RagdollService.RagdollModel, atributo
	Npc = true), e se sair de LEASH_RADIUS do seu ponto (ou cair do mapa) volta para o spawn sozinho.
	Admin: DummyService.BringTo(cframe) traz o boneco 1 (parado) para o admin e move o ponto dele junto
	(testar na arena de duelo/guerra); Respawn devolve tudo.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local RagdollRig = require(Modules:WaitForChild("RagdollRig"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))

local BEHAVIORS = { "idle", "block", "attack" } -- pelo índice do pad (ordenado por nome)
local ATTACK_RANGE = 7 -- studs: começa a socar quem chegar a isto
local ATTACK_DAMAGE = 3

local DummyService = {}

DummyService.Enabled = true
local RESPAWN_SECONDS = 4
local LEASH_RADIUS = 20 -- studs do ponto de spawn: além disso o boneco volta sozinho
local LEASH_CHECK = 0.4
local spawnPoints: { [Model]: CFrame } = {} -- ponto atual de cada boneco (muda com BringTo)
local PAD_PREFIX = "DummyPad"
local FOLDER_NAME = "Dummies"
local HEALTH = CombatConfig.MaxHealth

local folder: Folder

local function findPads(): { BasePart }
	local pads: { BasePart } = {}
	local arena = Workspace:FindFirstChild("Sahur") -- Arena (importado) + ArenaExtras (spawns/pads/placar)
	if not arena then
		return pads
	end
	for _, d in arena:GetDescendants() do
		if d:IsA("BasePart") and d.Name:sub(1, #PAD_PREFIX) == PAD_PREFIX then
			table.insert(pads, d)
		end
	end
	table.sort(pads, function(a, b)
		return a.Name < b.Name
	end)
	table.sort(pads, function(a, b)
		return a.Name < b.Name
	end)
	return pads
end

local function buildRig(index: number): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("[DummyService] não consegui criar o rig: " .. tostring(model))
		return nil
	end
	model.Name = "Boneco " .. index
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if not humanoid:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = humanoid -- animação de "Hit" do cliente precisa dele
		end
		humanoid.DisplayName = "Boneco de treino"
		humanoid.MaxHealth = HEALTH
		humanoid.Health = HEALTH
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
		humanoid.NameDisplayDistance = 60
		humanoid.BreakJointsOnDeath = false
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false -- física de verdade: leva empurrão, cai em ragdoll, levanta
			d.CanCollide = d.Name ~= "HumanoidRootPart"
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy() -- Animate/Health padrão não interessam
		end
	end
	if humanoid then
		humanoid.AutoRotate = false
		humanoid.PlatformStand = false
	end
	model:SetAttribute("Npc", true)
	local torso = model:FindFirstChild("Torso") :: BasePart?
	if torso then
		torso.Color = Color3.fromRGB(150, 60, 60)
	end
	CollectionService:AddTag(model, "Combatant")
	return model
end

local function spawnAt(pad: BasePart, index: number)
	local model = buildRig(index)
	if not model then
		return
	end
	-- apoia os pés no chão real abaixo do pad (o mapa da equipe pode não estar em y=0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, pad }
	local hit = Workspace:Raycast(pad.Position + Vector3.new(0, 5, 0), Vector3.new(0, -30, 0), params)
	local floorY = if hit then hit.Position.Y else pad.Position.Y + pad.Size.Y / 2
	local rootY = floorY + 3 + 0.05 -- R6: pernas 2 + metade do HRP 1
	local cf = CFrame.new(pad.Position.X, math.max(rootY, pad.Position.Y + pad.Size.Y / 2 + 3), pad.Position.Z) * CFrame.Angles(0, math.rad(180), 0)
	model:PivotTo(cf)
	model.Parent = folder
	spawnPoints[model] = cf
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		pcall(function()
			root:SetNetworkOwner(nil) -- o servidor simula (empurrão/ragdoll consistentes)
		end)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	-- LEASH: saiu longe do ponto (ou caiu do mapa) e não está caído = volta para o spawn
	task.spawn(function()
		while model.Parent and humanoid and humanoid.Health > 0 do
			task.wait(LEASH_CHECK)
			local home = spawnPoints[model]
			local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not home or not r then
				continue
			end
			local far = (r.Position - home.Position).Magnitude > LEASH_RADIUS
			local fell = r.Position.Y < home.Position.Y - 25
			if (far or fell) and not (RagdollService.IsModelRagdolled(model) and not fell) then
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then
						part.AssemblyLinearVelocity = Vector3.zero
						part.AssemblyAngularVelocity = Vector3.zero
					end
				end
				model:PivotTo(home)
				if model:GetAttribute("Behavior") == "block" then
					CombatService.NotifyNpcBlock(model, true)
				end
			end
		end
	end)
	local behavior = BEHAVIORS[index] or "idle"
	model:SetAttribute("Behavior", behavior)
	if humanoid then
		humanoid.DisplayName = if behavior == "block" then "Boneco (bloqueia)" elseif behavior == "attack" then "Boneco (ataca)" else "Boneco de treino"
	end
	if behavior == "block" then
		model:SetAttribute("Blocking", true)
		CombatService.NotifyNpcBlock(model, true)
	elseif behavior == "attack" and humanoid then
		-- soca quem chegar perto: combo de 4 no ritmo do M1, vira para o alvo (fica ancorado no lugar)
		task.spawn(function()
			local combo = 1
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			while model.Parent and humanoid.Health > 0 and root do
				local m1 = CombatConfig.Attacks.M1
				local targets = Hitbox.Around(model, ATTACK_RANGE, 1)
				local target = targets[1]
				local tRoot = target and target:FindFirstChild("HumanoidRootPart") :: BasePart?
				if tRoot and HealthService.IsAlive(target) then
					local pivot = model:GetPivot()
					local to = tRoot.Position - pivot.Position
					to = Vector3.new(to.X, 0, to.Z)
					if to.Magnitude > 0.1 then
						-- gira no lugar em torno do PRÓPRIO pivô (usar root.Position afundava o boneco a cada golpe)
						model:PivotTo(CFrame.lookAt(pivot.Position, pivot.Position + to.Unit))
					end
					local isFinisher = combo >= m1.ComboLength
					CombatService.NpcPunch(model, combo, ATTACK_DAMAGE)
					combo = if isFinisher then 1 else combo + 1
					task.wait(if isFinisher then m1.ComboEndCooldown else m1.Cooldown)
				else
					combo = 1
					task.wait(0.3)
				end
			end
		end)
	end
	if humanoid then
		-- regen própria fora de combate (a do HealthService só cobre Players)
		local lastHit = os.clock()
		humanoid.HealthChanged:Connect(function(health: number)
			if health < HEALTH then
				lastHit = os.clock()
			end
		end)
		task.spawn(function()
			while model.Parent and humanoid.Health > 0 do
				task.wait(1)
				if os.clock() - lastHit >= CombatConfig.Regen.Delay and humanoid.Health < HEALTH then
					humanoid.Health = math.min(HEALTH, humanoid.Health + CombatConfig.Regen.PerSecond * 3)
				end
			end
		end)
		humanoid.Died:Once(function()
			task.delay(RESPAWN_SECONDS, function()
				spawnPoints[model] = nil
				model:Destroy()
				if DummyService.Enabled and pad.Parent then
					spawnAt(pad, index)
				end
			end)
		end)
	end
end

local function ensureFolder(): Folder
	if not folder then
		local f = Workspace:FindFirstChild(FOLDER_NAME) :: Folder? or Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = Workspace
		folder = f
	end
	return folder
end

--- [Admin] Remove todos e recria (se Enabled).
function DummyService.Respawn(): number
	ensureFolder():ClearAllChildren()
	if not DummyService.Enabled then
		return 0
	end
	local pads = findPads()
	for i, pad in pads do
		spawnAt(pad, i)
	end
	return #pads
end

--- [Admin] Traz o boneco parado (ou o primeiro vivo) para `cf` e move o ponto dele junto — testar golpes
--- dentro da arena de duelo/guerra. Devolve o Model ou nil.
function DummyService.BringTo(cf: CFrame): Model?
	local chosen: Model? = nil
	for _, m in ensureFolder():GetChildren() do
		if m:IsA("Model") and HealthService.IsAlive(m) and (chosen == nil or m:GetAttribute("Behavior") == "idle") then
			chosen = m
		end
	end
	if not chosen then
		return nil
	end
	local target = CFrame.new(cf.Position) * CFrame.Angles(0, math.atan2(-cf.LookVector.X, -cf.LookVector.Z) + math.pi, 0)
	spawnPoints[chosen] = target
	if RagdollService.IsModelRagdolled(chosen) then
		RagdollRig.Release(chosen)
	end
	for _, part in chosen:GetDescendants() do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
		end
	end
	chosen:PivotTo(target)
	return chosen
end

--- [Admin] Liga/desliga.
function DummyService.SetEnabled(enabled: boolean): number
	DummyService.Enabled = enabled
	return DummyService.Respawn()
end

function DummyService.Start()
	if not DummyService.Enabled then
		return
	end
	ensureFolder()
	local pads = findPads()
	for i, pad in pads do
		spawnAt(pad, i)
	end
	-- quem entra depois vê o boneco bloqueador com o contorno
	Players.PlayerAdded:Connect(function(player)
		task.wait(2)
		for _, model in folder:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("Blocking") == true then
				CombatService.NotifyNpcBlock(model, true, player)
			end
		end
	end)
	Log.debug(("[DummyService] %d boneco(s) de treino (parado / bloqueia / ataca)"):format(#pads))
end

return DummyService
