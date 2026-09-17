--!strict
--[[
	RagdollService (servidor)
	Ragdoll de COMBATE (reversível): a vítima cai por alguns segundos, não pode agir, e leva
	follow-ups. Levanta sozinha ao fim do tempo ou antes com ragdoll cancel (Q; MovementService).
	Quem derruba: CombatService.Knockback com `ragdollSeconds` (4º M1, finisher, habilidades com
	Knockback.Ragdoll). Morte usa o ragdoll permanente do HealthService (mesmo RagdollRig).

	I-frames: atributo "IFramesUntil" (os.clock) no personagem; HealthService.ApplyDamage respeita.
	Replicação: atributo "Ragdolled" (boolean) no Player + NotifyRagdoll(character, active, seconds).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local RagdollRig = require(Modules:WaitForChild("RagdollRig"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))

local RagdollService = {}

local ATTR_RAGDOLLED = "Ragdolled"
local ATTR_IFRAMES = "IFramesUntil"

type State = { until_: number, token: number, character: Model }
local states: { [Player]: State } = {}

local notifyRagdoll: RemoteEvent

function RagdollService.IsRagdolled(player: Player): boolean
	local s = states[player]
	return s ~= nil and player.Character == s.character and os.clock() < s.until_
end

--- Concede invulnerabilidade curta (ragdoll cancel, levantar).
function RagdollService.GrantIFrames(character: Model, seconds: number)
	local current = character:GetAttribute(ATTR_IFRAMES)
	local until_ = os.clock() + seconds
	if typeof(current) == "number" and current > until_ then
		return
	end
	character:SetAttribute(ATTR_IFRAMES, until_)
end

--- Encerra i-frames concedidos antes (ex.: agarrão que não pegou ninguém).
function RagdollService.ClearIFrames(character: Model)
	character:SetAttribute(ATTR_IFRAMES, 0)
end

--- Levanta o jogador agora (se estiver ragdollado). Retorna true se levantou.
function RagdollService.Recover(player: Player, iframes: number?): boolean
	local s = states[player]
	if not s then
		return false
	end
	states[player] = nil
	local character = s.character
	if character.Parent and HealthService.IsAlive(character) then
		RagdollRig.Release(character)
		if iframes and iframes > 0 then
			RagdollService.GrantIFrames(character, iframes)
		end
	end
	player:SetAttribute(ATTR_RAGDOLLED, false)
	notifyRagdoll:FireAllClients(character, false)
	return true
end

--- Derruba o jogador por `seconds` (renova se já estiver caído). Não derruba morto/CanFight=false.
function RagdollService.Ragdoll(player: Player, seconds: number)
	local character = player.Character
	if not character or not HealthService.IsAlive(character) or not HealthService.CanFight(player) then
		return
	end
	if character:GetAttribute("BossRig") ~= nil then
		return -- forma de boss (Big C.H.O.P.): nunca entra em ragdoll (dono, 2026-09-17)
	end
	seconds = math.clamp(seconds, 0.1, CombatConfig.CombatRagdoll.MaxSeconds)
	local now = os.clock()
	local existing = states[player]
	local token = (existing and existing.token or 0) + 1
	local until_ = math.max(now + seconds, existing and existing.until_ or 0)
	states[player] = { until_ = until_, token = token, character = character }
	if not existing or existing.character ~= character then
		RagdollRig.Apply(character)
		player:SetAttribute(ATTR_RAGDOLLED, true)
	end
	notifyRagdoll:FireAllClients(character, true, until_ - now)
	Log.debug(("[RagdollService] %s ragdoll por %.1fs"):format(player.Name, until_ - now))
	task.delay(until_ - now + 0.02, function()
		local s = states[player]
		if s and s.token == token and os.clock() >= s.until_ then
			RagdollService.Recover(player, CombatConfig.CombatRagdoll.GetUpIFrames)
		end
	end)
end

-- Ragdoll de NPC (bonecos de treino): mesmo rig/constraints, estado por Model, levanta sozinho.
local npcStates: { [Model]: { until_: number, token: number } } = {}

function RagdollService.IsModelRagdolled(model: Model): boolean
	local s = npcStates[model]
	return s ~= nil and os.clock() < s.until_
end

function RagdollService.RagdollModel(model: Model, seconds: number)
	if not HealthService.IsAlive(model) or model:GetAttribute("BossRig") ~= nil then
		return
	end
	seconds = math.clamp(seconds, 0.1, CombatConfig.CombatRagdoll.MaxSeconds)
	local now = os.clock()
	local existing = npcStates[model]
	local token = (existing and existing.token or 0) + 1
	local until_ = math.max(now + seconds, existing and existing.until_ or 0)
	npcStates[model] = { until_ = until_, token = token }
	if not existing then
		RagdollRig.Apply(model)
		model:SetAttribute(ATTR_RAGDOLLED, true)
	end
	notifyRagdoll:FireAllClients(model, true, until_ - now)
	task.delay(until_ - now + 0.02, function()
		local s = npcStates[model]
		if s and s.token == token and os.clock() >= s.until_ then
			npcStates[model] = nil
			if model.Parent and HealthService.IsAlive(model) then
				RagdollRig.Release(model)
				RagdollService.GrantIFrames(model, CombatConfig.CombatRagdoll.GetUpIFrames)
			end
			model:SetAttribute(ATTR_RAGDOLLED, false)
			notifyRagdoll:FireAllClients(model, false)
		end
	end)
end

function RagdollService.Init()
	notifyRagdoll = Remotes.GetEvent(Remotes.Events.NotifyRagdoll)
end

function RagdollService.Start()
	local function onPlayer(player: Player)
		player:SetAttribute(ATTR_RAGDOLLED, false)
		player.CharacterAdded:Connect(function()
			states[player] = nil
			player:SetAttribute(ATTR_RAGDOLLED, false)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	-- Morreu ragdollado: o HealthService aplica o ragdoll permanente; só limpa o estado
	HealthService.Died.Event:Connect(function(victim: Player)
		states[victim] = nil
		victim:SetAttribute(ATTR_RAGDOLLED, false)
	end)
end

return RagdollService
