--!strict
--[[
	MobPadService (servidor) — inimigos de farm colocados pelo MAPA: toda BasePart dentro de Workspace.Sahur com o
	atributo `MobKind` vira um inimigo da campanha nascendo ali (um por marcador, renasce no mesmo lugar).
	Atributos do marcador (o mapa decide, o código não precisa mudar para acrescentar acampamentos):
	  MobKind      — StoryKillKind (recompensa/drops em ProgressionConfig.Npcs; conta para missões)
	  MobName      — nome em cima da cabeça
	  MobTier      — nível do inimigo (EnemyConfig.Tiers: 1 = humano passivo … 5 = elite)
	  MobCharacter — kit (opcional; padrão = o do tier)
	  MobBehavior  — passive | reactive | aggressive (opcional; padrão = o do tier)
	  MobTerritory — raio do território do reactive (opcional)
	  MobHealth / MobDamage — vida máxima e multiplicador de dano (opcionais; chefes/minibosses)
	  MobBoss      — true = miniboss (só enfeita o nome; a recompensa de chefe vem do MobKind)
	Hoje: FXCamposNevoa (tools/gerar_expansao_ilha1.py). Mapa removido do Workspace → os bots dele não renascem.
]]

local Workspace = game:GetService("Workspace")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))
local EnemyConfig = require(Modules:WaitForChild("EnemyConfig"))
local BotService = require(script.Parent:WaitForChild("BotService"))

local MobPadService = {}

local spawned: { [BasePart]: boolean } = {}

local function topModel(pad: Instance): Model?
	local sahur = Workspace:FindFirstChild("Sahur")
	local q = pad
	while q.Parent and q.Parent ~= sahur and q.Parent ~= Workspace do
		q = q.Parent
	end
	return if q:IsA("Model") then q else nil
end

local function spawnPad(pad: BasePart)
	if spawned[pad] then
		return
	end
	local kind = pad:GetAttribute("MobKind")
	if typeof(kind) ~= "string" then
		return
	end
	spawned[pad] = true
	local tier = pad:GetAttribute("MobTier")
	local attributes: { [string]: any } = { FXEnemy = true, StoryKillKind = kind }
	local health, damage = pad:GetAttribute("MobHealth"), pad:GetAttribute("MobDamage")
	if typeof(health) == "number" then
		attributes.MaxHealth = health
	end
	if typeof(damage) == "number" then
		attributes.DamageMult = damage
	end
	local tuning: { [string]: number } = {}
	local territory = pad:GetAttribute("MobTerritory")
	if typeof(territory) == "number" then
		tuning.TerritoryRadius = territory
	end
	local name = pad:GetAttribute("MobName")
	local character, behavior = pad:GetAttribute("MobCharacter"), pad:GetAttribute("MobBehavior")
	BotService.Spawn(EnemyConfig.Options(if typeof(tier) == "number" then tier else 1, {
		Name = if typeof(name) == "string" then name else "Inimigo",
		CFrame = pad.CFrame * CFrame.new(0, 3, 0),
		CharacterId = if typeof(character) == "string" then character else nil,
		Behavior = if typeof(behavior) == "string" then behavior else nil,
		Team = "fx_" .. kind,
		HomeMap = topModel(pad),
		Attributes = attributes,
		Tuning = tuning,
	}))
end

local function scan()
	local sahur = Workspace:FindFirstChild("Sahur")
	if not sahur then
		return
	end
	local n = 0
	for _, d in sahur:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("MobKind") ~= nil and not spawned[d] then
			spawnPad(d)
			n += 1
		end
	end
	if n > 0 then
		Log.debug(("[MobPadService] %d inimigos de mapa criados"):format(n))
	end
end

function MobPadService.Start()
	task.defer(function()
		task.wait(2)
		scan()
		-- mapa que chega depois (Rojo sincronizando, ilha que aparece): confere de novo de tempos em tempos
		while true do
			task.wait(30)
			for pad in spawned do
				if not pad:IsDescendantOf(Workspace) then
					spawned[pad] = nil
				end
			end
			scan()
		end
	end)
end

return MobPadService
