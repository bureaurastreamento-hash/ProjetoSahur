--!strict
--[[
	BossController (cliente)
	HUD do boss (StarterGui.BossGui): barra de vida no topo enquanto o boss está ativo,
	banner de invocação/fase/derrota e a lista de recompensas. Só reflete NotifyBoss.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local FX = require(Modules:WaitForChild("FX"))

local BossController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local bar: Frame
local nameLabel: TextLabel
local fill: Frame
local subLabel: TextLabel
local banner: TextLabel
local bannerToken = 0
local locomotionConn: RBXScriptConnection? -- Idle/Walk do boss ativo

local MOVING_SPEED = 1.5 -- velocidade horizontal do HRP acima disso = andando

--- Idle/Walk do boss (Assets.Animations.Boss.Idle/Walk; id vazio = não toca). O boss é movido pelo
--- servidor, então o cliente decide pela velocidade do HRP em vez do input. Ataques (Action) ficam por cima.
local function stopLocomotion()
	if locomotionConn then
		locomotionConn:Disconnect()
		locomotionConn = nil
	end
end

local function attachLocomotion(model: Model)
	stopLocomotion()
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local idle = FX.PlayAnimation(model, "Boss", "Idle", true, Enum.AnimationPriority.Idle)
	local walk = FX.PlayAnimation(model, "Boss", "Walk", true, Enum.AnimationPriority.Movement)
	if not idle and not walk then
		return
	end
	if walk then
		walk:Stop(0)
	end
	local moving = false
	locomotionConn = RunService.Heartbeat:Connect(function()
		if not model.Parent or not root.Parent then
			stopLocomotion()
			return
		end
		local v = root.AssemblyLinearVelocity
		local now = Vector3.new(v.X, 0, v.Z).Magnitude > MOVING_SPEED
		if now == moving then
			return
		end
		moving = now
		if walk then
			if moving then
				walk:Play(0.15)
			else
				walk:Stop(0.15)
			end
		end
	end)
end

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[BossController] '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function showBanner(text: string, seconds: number)
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.Visible = true
	task.delay(seconds, function()
		if bannerToken == token then
			banner.Visible = false
		end
	end)
end

local function setHealth(health: number, maxHealth: number)
	local frac = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0
	fill.Size = UDim2.fromScale(frac, 1)
	subLabel.Text = ("%d / %d"):format(math.floor(health), math.floor(maxHealth))
end

local function onNotifyBoss(event: string, data: any)
	data = if typeof(data) == "table" then data else {}
	if event == "summoned" then
		nameLabel.Text = tostring(data.name or "Boss")
		setHealth(tonumber(data.health) or 0, tonumber(data.maxHealth) or 1)
		bar.Visible = true
		if typeof(data.model) == "Instance" and data.model:IsA("Model") then
			attachLocomotion(data.model :: Model)
		end
		showBanner(("%s invocou %s!"):format(tostring(data.by), tostring(data.name)), 4)
		FX.PlaySoundUI("Match", "RoundStart")
		FX.Shake(0.6, 0.6)
	elseif event == "state" then
		setHealth(tonumber(data.health) or 0, tonumber(data.maxHealth) or 1)
		if data.phase == 2 then
			local base = nameLabel.Text:gsub(" — FÚRIA$", "")
			nameLabel.Text = base .. " — FÚRIA"
		end
	elseif event == "phase" then
		showBanner("O boss entrou em FÚRIA!", 3)
		FX.Shake(0.8, 0.5)
		if typeof(data.model) == "Instance" and data.model:IsA("Model") then
			local model = data.model :: Model
			FX.PlayAnimation(model, "Boss", "Roar")
			FX.SpawnVFX(model, "Boss", "Roar")
			FX.PlaySoundAt(model, "Boss", "Roar")
		end
	elseif event == "warning" then
		showBanner(("%s chega ao Santuário em %ds!"):format(tostring(data.name), tonumber(data.seconds) or 0), 4)
		FX.PlaySoundUI("Match", "RoundStart")
	elseif event == "enrage" then
		-- combo estendido no boss: contorno vermelho + aviso; some quando acaba
		local model = if typeof(data.model) == "Instance" and data.model:IsA("Model") then data.model :: Model else nil
		if data.active then
			showBanner("O boss ENRAIVECEU — afaste-se!", 2.5)
			FX.Shake(0.8, 0.5)
			if model then
				FX.SetOutline(model, Color3.fromRGB(255, 40, 40))
				FX.Flash(model, Color3.fromRGB(255, 40, 40), 0.4)
			end
		elseif model then
			FX.SetOutline(model, nil)
		end
	elseif event == "attack" then
		-- golpes do boss: animação + VFX/som por nome (Assets Boss/<Nome> e Boss/<Nome>_Hit)
		local model = data.model
		if typeof(model) ~= "Instance" or not model:IsA("Model") then
			return
		end
		local name = tostring(data.name)
		if data.phase == "windup" then
			FX.PlayAnimation(model, "Boss", name)
			FX.SpawnVFX(model, "Boss", name, true)
			FX.PlaySoundAt(model, "Boss", name)
		else
			local at = if typeof(data.position) == "Vector3" then data.position else nil
			FX.SpawnVFX(model, "Boss", name .. "_Hit", true, at)
			FX.PlaySoundAt(model, "Boss", name .. "_Hit")
			local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and at and (root.Position - at).Magnitude < (tonumber(data.radius) or 10) + 20 then
				FX.Shake(if name == "Swipe" then 0.3 else 0.7, 0.35)
			end
		end
	elseif event == "defeated" then
		stopLocomotion()
		bar.Visible = false
		local lines = { "BOSS DERROTADO!" }
		local mine = 0
		if typeof(data.rewards) == "table" then
			for _, r in ipairs(data.rewards) do
				if r.name == localPlayer.Name then
					mine = tonumber(r.coins) or 0
				end
			end
		end
		if mine > 0 then
			table.insert(lines, ("+%d pontos"):format(mine))
			if typeof(data.rewards) == "table" then
				for _, r in data.rewards do
					if r.name == localPlayer.Name and typeof(r.drop) == "string" then
						table.insert(lines, ("DROP RARO: %s!"):format(r.drop))
					end
				end
			end
		end
		if data.top then
			table.insert(lines, ("Maior dano: %s"):format(tostring(data.top)))
		end
		showBanner(table.concat(lines, "\n"), 6)
		FX.PlaySoundUI("Match", "Victory")
	elseif event == "despawned" then
		stopLocomotion()
		bar.Visible = false
		showBanner("O boss foi embora...", 3)
	elseif event == "denied" then
		showBanner(tostring(data.reason), 3)
	end
end

function BossController.Start()
	local gui = get(playerGui, "BossGui")
	bar = get(gui, "BossBar") :: Frame
	nameLabel = get(bar, "Name") :: TextLabel
	fill = get(get(bar, "Track"), "Fill") :: Frame
	subLabel = get(bar, "Sub") :: TextLabel
	banner = get(gui, "BossBanner") :: TextLabel
	Remotes.GetEvent(Remotes.Events.NotifyBoss).OnClientEvent:Connect(onNotifyBoss)
	Log.debug("[BossController] pronto")
end

return BossController
