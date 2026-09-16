--!strict
--[[
	EnvironmentService (servidor)
	Ajusta a iluminação/atmosfera do mapa livre em runtime (Lighting replica para
	todos os clientes). Aditivo: só cria efeitos que ainda não existem em Lighting
	(por nome) e só mexe nas propriedades listadas em CONFIG.

	Lighting.Technology (Future/ShadowMap) NÃO é ajustável por script: configurar
	manualmente em Lighting > Technology no Studio.

	Desligar tudo: Enabled = false.
]]

local Lighting = game:GetService("Lighting")

local Log = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Log"))

local EnvironmentService = {}

EnvironmentService.Enabled = true

type EffectDef = { Name: string, ClassName: string, Properties: { [string]: any } }

-- Fim de tarde quente: sombras longas dão volume nas Parts lisas do mapa.
local CONFIG: { Lighting: { [string]: any }, Effects: { EffectDef } } = {
	Lighting = {
		ClockTime = 15.6,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(70, 74, 82),
		OutdoorAmbient = Color3.fromRGB(118, 122, 128),
		ColorShift_Top = Color3.fromRGB(255, 232, 205),
		ColorShift_Bottom = Color3.fromRGB(180, 190, 210),
		EnvironmentDiffuseScale = 0.55,
		EnvironmentSpecularScale = 0.6,
		ShadowSoftness = 0.15,
		GlobalShadows = true,
		ExposureCompensation = 0.1,
		-- fog clássico desligado (a Atmosphere faz a névoa); um plugin de iluminação já deixou 10–120 preto no place
		FogStart = 0,
		FogEnd = 100000,
		FogColor = Color3.fromRGB(192, 192, 192),
	},
	-- Instâncias filhas de Lighting (criadas só se não existirem com este nome)
	Effects = {
		{
			Name = "SahurAtmosphere",
			ClassName = "Atmosphere",
			Properties = {
				Density = 0.32,
				Offset = 0.15,
				Color = Color3.fromRGB(205, 200, 190),
				Decay = Color3.fromRGB(110, 120, 140),
				Glare = 0.35,
				Haze = 1.6,
			},
		},
		{
			Name = "SahurBloom",
			ClassName = "BloomEffect",
			Properties = { Intensity = 0.25, Size = 16, Threshold = 1.8 },
		},
		{
			Name = "SahurColor",
			ClassName = "ColorCorrectionEffect",
			Properties = {
				Saturation = 0.12,
				Contrast = 0.08,
				Brightness = 0.02,
				TintColor = Color3.fromRGB(255, 250, 240),
			},
		},
	},
}

local function applyProperties(target: Instance, props: { [string]: any })
	for key, value in props do
		local ok, err = pcall(function()
			(target :: any)[key] = value
		end)
		if not ok then
			warn(("[EnvironmentService] %s.%s: %s"):format(target.Name, key, tostring(err)))
		end
	end
end

function EnvironmentService.Start()
	if not EnvironmentService.Enabled then
		return
	end
	applyProperties(Lighting, CONFIG.Lighting)
	for _, def in CONFIG.Effects do
		if Lighting:FindFirstChild(def.Name) then
			continue
		end
		local inst = Instance.new(def.ClassName)
		inst.Name = def.Name
		applyProperties(inst, def.Properties)
		inst.Parent = Lighting
	end
	Log.debug("[EnvironmentService] iluminação aplicada (Technology precisa ser Future/ShadowMap no Studio)")
end

return EnvironmentService
