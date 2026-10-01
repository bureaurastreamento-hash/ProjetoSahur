--!strict
local Workspace = game:GetService("Workspace")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local StoryConfig = require(Modules.StoryConfig)
local Config = {}
local MARKERS = {
	fx_m0_destrocos = "M0_Destrocos", fx_m0_pertence = "M0_Pertence", fx_m0_estrutura = "M0_Estrutura",
	fx_tutorial_enemy = "VagantePad0", fx_campos_enemy = "MobPad_Clareira0", fx_mascara_boss = "MascaraSpawn",
	fx_cap1_boss = "GuardiaoSpawn", fx_pedra_enemy = "EscavacaoPad0", fx_solnegro_boss = "SacerdoteSpawn",
	fx_sol_enemy = "EnemyPad0", fx_sol_boss = "SolarBossSpawn", fx_ambar_boss = "AmbarBossSpawn",
	fx_costa_boss = "CostaBossSpawn", fx_mare_avatar = "MareBossSpawn", trace_carlos_era01 = "RastroCarlos01",
} :: { [string]: string }
local cache: { [string]: BasePart } = {}
local function marker(name: string): BasePart?
	local existing = cache[name]
	if existing and existing:IsDescendantOf(Workspace) then return existing end
	local sahur = Workspace:FindFirstChild("Sahur")
	local found = sahur and sahur:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then cache[name] = found; return found end
	return nil
end
function Config.Target(kind: string): Vector3?
	local place = StoryConfig.Places[kind:gsub("^reach_", "")]
	if kind:sub(1, 6) == "reach_" and place then return place.Position end
	local name = MARKERS[kind]
	local found = name and marker(name)
	return if found then found.Position else nil
end
function Config.Next(act: StoryConfig.Act?, objectives: { any }, locked: boolean): { [string]: any }?
	if not act then return nil end
	if locked then
		local region = act.Region or "ilha_tutorial"
		local kind = if region == "ilha_tutorial" then "fx_campos_enemy" elseif region == "ilha_pilares" then "fx_pedra_enemy" else "fx_sol_enemy"
		return { position = Config.Target(kind), label = "Treino da região" }
	end
	for _, row in objectives do
		if row.progress >= row.goal then continue end
		local position = Config.Target(row.kind)
		if position then return { position = position, label = row.text, kind = row.kind } end
		if row.kind == "parries" then return { position = Config.Target("fx_tutorial_enemy"), label = "Provoque um Vagante com M1; aperte F antes do golpe para aparar." } end
	end
	if #objectives == 0 and not act.Choice and not act.Arrive then
		local spot = marker("HumanoiderSpot")
		return { position = if spot then spot.Position else nil, label = "Humanoider na vila — aproxime-se e converse [E]" }
	end
	return nil
end
return Config
