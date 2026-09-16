--!strict
--[[
	AnimationCheckService (servidor, SÓ no Studio)
	Diagnóstico das animações de ReplicatedStorage.Assets.Animations: para cada Animation com id,
	baixa o KeyframeSequence e diz no Output se ela é R6 ou R15 e se o jogo tem acesso (jogo de
	grupo só carrega animações publicadas COM O GRUPO como criador).
	Não faz nada fora do Studio.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local BossConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("BossConfig"))

local AnimationCheckService = {}

local R15_PARTS = { LowerTorso = true, UpperTorso = true, RightUpperArm = true, LeftUpperLeg = true }
local R6_PARTS = { Torso = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true }

-- Nomes das partes do modelo 3D do boss (rig custom montado pelo BossRig): as animações do boss
-- animam ESSAS partes, não Torso/Left Arm. nil = modelo não está no place (boss usa o rig R6).
local bossParts: { [string]: boolean }? = nil
local function loadBossParts()
	local template = ServerStorage:FindFirstChild(BossConfig.ModelName, true)
		or ReplicatedStorage:FindFirstChild(BossConfig.ModelName, true)
	if not template then
		return
	end
	bossParts = {}
	for _, d in template:GetDescendants() do
		if d:IsA("BasePart") then
			(bossParts :: { [string]: boolean })[d.Name] = true
		end
	end
end

local function rigOf(ks: KeyframeSequence): string
	local r15, r6, boss, poses = false, false, false, 0
	for _, d in ks:GetDescendants() do
		if d:IsA("Pose") then
			poses += 1
			if R15_PARTS[d.Name] then
				r15 = true
			elseif R6_PARTS[d.Name] then
				r6 = true
			elseif bossParts and bossParts[d.Name] and d.Name ~= "Head" and d.Name ~= "HumanoidRootPart" then
				boss = true
			end
		end
	end
	if boss and not r6 and not r15 then
		return "Boss"
	elseif r15 and not r6 then
		return "R15"
	elseif r6 and not r15 then
		return "R6"
	elseif poses == 0 then
		return "vazia"
	end
	return "misturada/custom"
end

local checked: { [string]: boolean } = {} -- o provider devolve a MESMA instância para o mesmo id

local function check(anim: Animation)
	local id = anim.AnimationId
	local path = anim:GetFullName():gsub("^ReplicatedStorage%.Assets%.Animations%.", "")
	if checked[id] then
		print(("[AnimCheck] %s (%s): mesmo id já verificado acima"):format(path, id))
		return
	end
	checked[id] = true
	local ok, result = pcall(function()
		return KeyframeSequenceProvider:GetKeyframeSequenceAsync(id)
	end)
	if not ok then
		warn(("[AnimCheck] %s (%s): NÃO CARREGOU — %s"):format(path, id, tostring(result)))
		return
	end
	local ks = result :: KeyframeSequence
	local rig = rigOf(ks)
	-- projeto é R6 (CLAUDE.md); a pasta Boss usa o rig custom do BossModel quando ele existe
	local expected = if path:match("^Boss%.") and bossParts then "Boss" else "R6"
	if rig == expected then
		local last = 0
		for _, kf in ks:GetKeyframes() do
			last = math.max(last, (kf :: Keyframe).Time)
		end
		print(("[AnimCheck] %s (%s): OK %s, %.2fs"):format(path, id, rig, last))
	else
		if expected == "Boss" then
			warn(("[AnimCheck] %s (%s): rig %s — o boss usa o rig custom do %s (partes tripo_*), esta animação NÃO vai mexer o boss. Animar em cima do BossModel."):format(path, id, rig, BossConfig.ModelName))
		else
			warn(("[AnimCheck] %s (%s): rig %s — o jogo é %s, esta animação NÃO vai mexer o personagem. Reexportar em rig %s."):format(path, id, rig, expected, expected))
		end
	end
end

function AnimationCheckService.Start()
	if not RunService:IsStudio() then
		return
	end
	task.spawn(function()
		task.wait(3) -- deixa o boot terminar antes de encher o Output
		loadBossParts()
		local root = ReplicatedStorage:FindFirstChild("Assets")
		local folder = root and root:FindFirstChild("Animations")
		if not folder then
			return
		end
		local count = 0
		for _, d in folder:GetDescendants() do
			if d:IsA("Animation") and d.AnimationId ~= "" then
				count += 1
				check(d)
			end
		end
		print(("[AnimCheck] %d animação(ões) da equipe verificadas (só no Studio)"):format(count))
	end)
end

return AnimationCheckService
