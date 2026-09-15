--!strict
--[[
	MovementController (cliente)
	  - Correr: segurar Shift esquerdo (gamepad: L3) -> RequestSprint(true/false)
	  - Dash: Ctrl esquerdo (gamepad: B... usa ButtonL2) -> RequestDash; o servidor responde com
	    NotifyDash e só então o impulso é aplicado (na direção do movimento; parado = para frente).
	  - Animações de movimento da equipe: troca os ids do script "Animate" padrão do Roblox
	    (idle/walk/run) pelos de Assets.Animations.Shared.{Idle,Walk,Run}; correndo usa Run.
	API: MovementController.Dash(), MovementController.SetSprint(active) (mobile).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local FX = require(Modules:WaitForChild("FX"))
local Assets = require(Modules:WaitForChild("Assets"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))

local MovementController = {}

local localPlayer = Players.LocalPlayer
local SPRINT_KEY = Enum.KeyCode.LeftShift
local SPRINT_GAMEPAD = Enum.KeyCode.ButtonL3
local DASH_KEY = Enum.KeyCode.LeftControl
local DASH_GAMEPAD = Enum.KeyCode.ButtonL2
local SHARED = "Shared"
local TRAIL_COLOR = Color3.fromRGB(220, 235, 255)

local requestSprint: RemoteEvent
local requestDash: RemoteEvent
local sprintHeld = false
local lastDashAt = -math.huge

-- ---------------------------------------------------------------------------
-- Animações de movimento (script Animate padrão)
-- ---------------------------------------------------------------------------

local function animId(name: string): string?
	local anim = Assets.GetAnimation(SHARED, name)
	return if anim then anim.AnimationId else nil
end

local function setAnimateId(animate: Instance, group: string, child: string, id: string?)
	if not id then
		return
	end
	local g = animate:FindFirstChild(group)
	local a = g and g:FindFirstChild(child)
	if a and a:IsA("Animation") and a.AnimationId ~= id then
		a.AnimationId = id
	end
end

--- Aplica idle/walk/run da equipe no Animate do personagem. `running` troca walk pelo Run.
local function applyMovementAnims(character: Model, running: boolean)
	local animate = character:FindFirstChild("Animate")
	if not animate then
		return
	end
	local idle, walk, run = animId("Idle"), animId("Walk"), animId("Run")
	setAnimateId(animate, "idle", "Animation1", idle)
	setAnimateId(animate, "idle", "Animation2", idle)
	-- R6 usa "walk" para todo movimento; R15 usa "run". Trocamos os dois.
	local moving = if running then run or walk else walk
	setAnimateId(animate, "walk", "WalkAnim", moving)
	setAnimateId(animate, "run", "RunAnim", moving)
end

local function refreshAnims()
	local character = localPlayer.Character
	if character then
		applyMovementAnims(character, localPlayer:GetAttribute("Sprinting") == true)
	end
end

-- ---------------------------------------------------------------------------
-- Correr / dash
-- ---------------------------------------------------------------------------

function MovementController.SetSprint(active: boolean)
	if sprintHeld == active then
		return
	end
	sprintHeld = active
	requestSprint:FireServer(active)
end

function MovementController.Dash()
	if os.clock() - lastDashAt < 0.2 then
		return
	end
	lastDashAt = os.clock()
	requestDash:FireServer()
end

local function onNotifyDash(character: Model, speed: number, duration: number)
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end
	FX.PlayAnimation(character, SHARED, "Dash")
	FX.Trail(character, TRAIL_COLOR, duration + 0.1)
	if character == localPlayer.Character then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			local dir = humanoid.MoveDirection
			if dir.Magnitude < 0.1 then
				dir = root.CFrame.LookVector
			end
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			FX.Push(character, dir * speed, duration)
		end
	end
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == SPRINT_KEY or input.KeyCode == SPRINT_GAMEPAD then
		MovementController.SetSprint(true)
	elseif input.KeyCode == DASH_KEY or input.KeyCode == DASH_GAMEPAD then
		MovementController.Dash()
	end
end

local function onInputEnded(input: InputObject)
	if input.KeyCode == SPRINT_KEY or input.KeyCode == SPRINT_GAMEPAD then
		MovementController.SetSprint(false)
	end
end

function MovementController.Start()
	requestSprint = Remotes.GetEvent(Remotes.Events.RequestSprint)
	requestDash = Remotes.GetEvent(Remotes.Events.RequestDash)
	Remotes.GetEvent(Remotes.Events.NotifyDash).OnClientEvent:Connect(onNotifyDash)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)

	localPlayer:GetAttributeChangedSignal("Sprinting"):Connect(refreshAnims)
	localPlayer.CharacterAdded:Connect(function(character)
		sprintHeld = false
		-- o Animate chega junto com o personagem; espera ele e aplica os ids
		local animate = character:WaitForChild("Animate", 10)
		if animate then
			task.wait() -- deixa o Animate configurar os filhos antes de trocar
			applyMovementAnims(character, false)
		end
		-- Shift já segurado ao renascer: volta a correr
		if UserInputService:IsKeyDown(SPRINT_KEY) then
			MovementController.SetSprint(true)
		end
	end)
	if localPlayer.Character then
		task.defer(refreshAnims)
	end
	Log.debug(("[MovementController] pronto (Shift corre a %d, Ctrl dash %.1fs)"):format(CombatConfig.Sprint.Speed, CombatConfig.Dash.Cooldown))
end

return MovementController
