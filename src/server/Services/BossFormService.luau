--!strict
--[[
	BossFormService (servidor)
	O jogador VIRA o boss (Big C.H.O.P.): o personagem R6 é trocado pelo rig por peças (BossRigs),
	com CharacterId = BossConfig.Form.CharacterId (kit próprio em CharacterDefs), muita vida, socos
	fortes (FormDamageMult) e hitbox grande (HitboxScale no Model). Todo mundo do servidor vê a barra do
	boss (NotifyBoss "summoned"/"state") e caça ele. Acaba quando morre (quem bateu divide a recompensa,
	como o boss NPC) ou em Form.Duration s (o boss ganha SurviveCoins). Depois volta ao personagem normal.

	API: BossFormService.Transform(player) -> (ok, motivo)
	     BossFormService.IsActive() / GetActivePlayer() / End(reason)
	     BossFormService.Changed (BindableEvent) — RitualService atualiza o letreiro do altar
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local BossConfig = require(Modules:WaitForChild("BossConfig"))
local BossRigs = require(Modules:WaitForChild("BossRigs"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local AbilityService = require(script.Parent:WaitForChild("AbilityService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))

local BossFormService = {}

BossFormService.Changed = Instance.new("BindableEvent")

type Form = {
	player: Player,
	model: Model,
	humanoid: Humanoid,
	damageBy: { [Player]: number },
	startedAt: number,
	finished: boolean,
}

local active: Form? = nil
local notifyBoss: RemoteEvent
local CosmeticsService: any = nil

local function broadcast(event: string, data: { [string]: any })
	data.event = event
	notifyBoss:FireAllClients(event, data)
end

function BossFormService.IsActive(): boolean
	return active ~= nil
end

function BossFormService.GetActivePlayer(): Player?
	return if active then active.player else nil
end

function BossFormService.GetModel(): Model?
	return if active then active.model else nil
end

--- Onde o boss nasce: BossSpawn do santuário (senão onde o jogador está).
local function spawnCFrame(player: Player): CFrame
	local sahur = Workspace:FindFirstChild("Sahur")
	local spawn = sahur and sahur:FindFirstChild("BossSpawn", true)
	local height = BossRigs.RootHeight(BossConfig.Form.RigId)
	if spawn and spawn:IsA("BasePart") then
		return CFrame.new(spawn.Position + Vector3.new(0, height + 0.5, 0)) * CFrame.Angles(0, math.rad(spawn.Orientation.Y), 0)
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pos = if root then root.Position else Vector3.new(0, 10, 0)
	return CFrame.new(pos + Vector3.new(0, height, 0))
end

local function rewardHunters(f: Form, defeated: boolean)
	local total = 0
	local top: Player? = nil
	local topDamage = 0
	for player, dmg in f.damageBy do
		total += dmg
		if dmg > topDamage then
			top, topDamage = player, dmg
		end
	end
	local rewards = {}
	if defeated then
		for player, dmg in f.damageBy do
			if player.Parent == Players and total > 0 and player ~= f.player then
				local coins = math.max(BossConfig.RewardMin, math.floor(BossConfig.RewardPool * dmg / total))
				if player == top then
					coins += BossConfig.RewardTopBonus
				end
				coins = DataService.RewardCoins(player, coins)
				ProgressionService.OnBossDefeated(player, dmg, dmg / total, player == top)
				local drop: string? = nil
				if player == top and math.random() < BossConfig.TopDropChance and CosmeticsService then
					drop = CosmeticsService.FreeRoll(player, "boss")
				end
				table.insert(rewards, { name = player.Name, coins = coins, damage = math.floor(dmg), drop = drop })
			end
		end
		table.sort(rewards, function(a, b)
			return a.damage > b.damage
		end)
		broadcast("defeated", { rewards = rewards, top = if top then top.Name else nil, name = BossConfig.Name, by = f.player.Name })
	else
		if f.player.Parent == Players then
			DataService.RewardCoins(f.player, BossConfig.Form.SurviveCoins)
		end
		broadcast("despawned", { name = BossConfig.Name, survived = true, by = f.player.Name })
	end
end

--- Acaba a forma: recompensa, volta o personagem normal (respawn) e libera o ritual.
function BossFormService.End(reason: string)
	local f = active
	if not f or f.finished then
		return
	end
	f.finished = true
	active = nil
	local defeated = reason == "died"
	Log.debug(("[BossFormService] forma de %s acabou (%s)"):format(f.player.Name, reason))
	rewardHunters(f, defeated)
	local player = f.player
	player:SetAttribute("BossForm", nil)
	player:SetAttribute("FormDamageMult", nil)
	AbilityService.SetForm(player, nil)
	if player.Parent == Players then
		if defeated then
			-- CharacterService.LoadModel já agenda o respawn normal (Humanoid.Died)
		else
			AntiExploitService.Grace(player, 3)
			task.delay(0.1, function()
				if player.Parent == Players then
					CharacterService.Load(player)
				end
			end)
		end
	end
	BossFormService.Changed:Fire()
end

--- Vira o boss. Quem chama (RitualService) já conferiu flecha + noite.
function BossFormService.Transform(player: Player): (boolean, string)
	if active then
		return false, "já existe um boss solto"
	end
	local character = player.Character
	if not character or not HealthService.IsAlive(character) then
		return false, "morto"
	end
	if RagdollService.IsRagdolled(player) or player:GetAttribute("InMatch") == true then
		return false, "ocupado"
	end
	local cfg = BossConfig.Form
	-- cutscene curta: parado e invencível no altar, depois troca o corpo
	CombatService.Stun(player, cfg.TransformSeconds, "transform")
	RagdollService.GrantIFrames(character, cfg.TransformSeconds + 1)
	AntiExploitService.Grace(player, cfg.TransformSeconds + 3)
	player:SetAttribute("CutsceneUntil", Workspace:GetServerTimeNow() + cfg.TransformSeconds)
	CombatService.RestoreWalkSpeed(player)
	broadcast("transforming", { by = player.Name, name = BossConfig.Name, seconds = cfg.TransformSeconds, character = character })
	task.delay(cfg.TransformSeconds, function()
		if active or player.Parent ~= Players or player.Character ~= character or not HealthService.IsAlive(character) then
			player:SetAttribute("CutsceneUntil", 0)
			BossFormService.Changed:Fire() -- abortou: RitualService devolve a flecha ao mapa
			return
		end
		player:SetAttribute("CutsceneUntil", 0)
		local model = BossRigs.Build(cfg.RigId)
		model:SetAttribute("MaxHealth", cfg.MaxHealth)
		model:SetAttribute("WalkSpeed", cfg.WalkSpeed)
		model:SetAttribute("HitboxScale", cfg.HitboxScale)
		model:SetAttribute("CharacterId", cfg.CharacterId)
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.JumpPower = 0
		humanoid.UseJumpPower = true
		AbilityService.SetForm(player, cfg.CharacterId)
		player:SetAttribute("BossForm", cfg.RigId)
		player:SetAttribute("FormDamageMult", cfg.DamageMultiplier)
		if not CharacterService.LoadModel(player, model, spawnCFrame(player)) then
			model:Destroy()
			AbilityService.SetForm(player, nil)
			player:SetAttribute("BossForm", nil)
			player:SetAttribute("FormDamageMult", nil)
			return
		end
		AntiExploitService.Grace(player, 4)
		RagdollService.GrantIFrames(model, 2)
		local f: Form = { player = player, model = model, humanoid = humanoid, damageBy = {}, startedAt = os.clock(), finished = false }
		local endsAt = Workspace:GetServerTimeNow() + cfg.Duration
		active = f
		humanoid.Died:Once(function()
			if active == f then
				BossFormService.End("died")
			end
		end)
		model.AncestryChanged:Connect(function(_, parent)
			if not parent and active == f then
				BossFormService.End("removed")
			end
		end)
		humanoid.HealthChanged:Connect(function(h)
			if active == f then
				broadcast("state", { health = h, maxHealth = humanoid.MaxHealth, phase = 1 })
			end
		end)
		task.delay(cfg.Duration, function()
			if active == f then
				BossFormService.End("timeout")
			end
		end)
		Log.debug(("[BossFormService] %s virou %s (%d HP, %ds)"):format(player.Name, BossConfig.Name, cfg.MaxHealth, cfg.Duration))
		broadcast("summoned", { by = player.Name, name = BossConfig.Name .. " (" .. player.Name .. ")", model = model, health = humanoid.Health, maxHealth = humanoid.MaxHealth, form = true, endsAt = endsAt })
		BossFormService.Changed:Fire()
	end)
	return true, "transformando"
end

function BossFormService.Init()
	notifyBoss = Remotes.GetEvent(Remotes.Events.NotifyBoss)
end

function BossFormService.Start()
	local okC, cos = pcall(require, script.Parent:WaitForChild("CosmeticsService"))
	if okC then
		CosmeticsService = cos
	end
	HealthService.Damaged.Event:Connect(function(victim: Model, amount: number, attacker: Player?)
		local f = active
		if f and attacker and victim == f.model and attacker ~= f.player then
			f.damageBy[attacker] = (f.damageBy[attacker] or 0) + amount
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		if active and active.player == player then
			BossFormService.End("left")
		end
	end)
	-- quem entra no meio recebe a barra
	Players.PlayerAdded:Connect(function(player)
		task.wait(1)
		local f = active
		if f then
			notifyBoss:FireClient(player, "summoned", { event = "summoned", by = f.player.Name, name = BossConfig.Name .. " (" .. f.player.Name .. ")", model = f.model, health = f.humanoid.Health, maxHealth = f.humanoid.MaxHealth, form = true, endsAt = f.startedAt + BossConfig.Form.Duration - os.clock() + Workspace:GetServerTimeNow() })
		end
	end)
end

return BossFormService
