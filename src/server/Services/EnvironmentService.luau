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
local Workspace = game:GetService("Workspace")

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

-- ---------------------------------------------------------------------------
-- Ciclo dia/noite (servidor manda). O boss só pode ser invocado à NOITE (BossService/RitualService).
-- O dev controla: AdminService.SetTime/SetDay/SetNight congelam a hora; TimeAuto volta ao ciclo.
-- Workspace.IsNight (atributo) replica para os clientes.
-- ---------------------------------------------------------------------------
EnvironmentService.DayNight = {
	Enabled = true,
	DayMinutes = 28, -- duração real do dia (NightEnd → NightStart) — dono (2026-09-17): noite = evento RARO
	NightMinutes = 4, -- duração real da noite (NightStart → NightEnd)
	NightStart = 18.5, -- ClockTime em que começa a noite
	NightEnd = 5.5, -- ClockTime em que amanhece
	StartClock = 9.0, -- hora ao ligar o servidor (manhã: primeira noite só depois de ~20 min)
	-- iluminação extra da noite (interpolada nos ~1,5 h de transição em volta de NightStart/NightEnd)
	Night = {
		Brightness = 0.9,
		Ambient = Color3.fromRGB(28, 30, 44),
		OutdoorAmbient = Color3.fromRGB(44, 48, 72),
		ExposureCompensation = -0.15,
	},
}

local clock = EnvironmentService.DayNight.StartClock
local clockOverride: number? = nil -- dev congelou a hora
local isNight = false

local function nightAmount(hour: number): number
	-- 0 = dia pleno, 1 = noite plena; transição de 1,5 h em volta dos limites
	local dn = EnvironmentService.DayNight
	local function ramp(x: number): number
		return math.clamp(x, 0, 1)
	end
	local fade = 1.5
	if hour >= dn.NightStart or hour < dn.NightEnd then
		local sinceStart = (hour - dn.NightStart) % 24
		local untilEnd = (dn.NightEnd - hour) % 24
		return math.min(ramp(sinceStart / fade + 0.5), ramp(untilEnd / fade + 0.5), 1)
	end
	local toStart = dn.NightStart - hour
	local sinceEnd = hour - dn.NightEnd
	return math.max(ramp(0.5 - toStart / fade), ramp(0.5 - sinceEnd / fade), 0)
end

local function applyClock(hour: number)
	local dn = EnvironmentService.DayNight
	clock = hour % 24
	Lighting.ClockTime = clock
	local a = nightAmount(clock)
	local day = CONFIG.Lighting
	Lighting.Brightness = day.Brightness + (dn.Night.Brightness - day.Brightness) * a
	Lighting.Ambient = day.Ambient:Lerp(dn.Night.Ambient, a)
	Lighting.OutdoorAmbient = day.OutdoorAmbient:Lerp(dn.Night.OutdoorAmbient, a)
	Lighting.ExposureCompensation = day.ExposureCompensation + (dn.Night.ExposureCompensation - day.ExposureCompensation) * a
	local night = clock >= dn.NightStart or clock < dn.NightEnd
	if night ~= isNight then
		isNight = night
		Workspace:SetAttribute("IsNight", night)
		Log.debug(("[EnvironmentService] %s (ClockTime %.1f)"):format(if night then "anoiteceu" else "amanheceu", clock))
	end
end

function EnvironmentService.IsNight(): boolean
	return isNight
end

function EnvironmentService.GetClock(): number
	return clock
end

--- Dev: congela a hora (nil = volta ao ciclo automático).
function EnvironmentService.SetClockOverride(hour: number?)
	clockOverride = hour
	if hour then
		applyClock(hour)
	end
	Workspace:SetAttribute("ClockOverride", hour)
end

local function dayNightLoop()
	local dn = EnvironmentService.DayNight
	applyClock(dn.StartClock)
	Workspace:SetAttribute("IsNight", isNight)
	local step = 1
	while true do
		task.wait(step)
		if clockOverride or not dn.Enabled then
			continue
		end
		local nightHours = (dn.NightEnd - dn.NightStart) % 24
		local dayHours = 24 - nightHours
		local hoursPerSecond = if isNight then nightHours / (dn.NightMinutes * 60) else dayHours / (dn.DayMinutes * 60)
		applyClock(clock + hoursPerSecond * step)
	end
end

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
		-- já existe um efeito da mesma classe (Bloom/Atmosphere do place)? reaproveita em vez de duplicar
		-- (dois BloomEffect somam; duas Atmospheres brigam)
		local inst = Lighting:FindFirstChildOfClass(def.ClassName)
		if not inst then
			inst = Instance.new(def.ClassName)
		end
		inst.Name = def.Name
		applyProperties(inst, def.Properties)
		inst.Parent = Lighting
	end
	Log.debug("[EnvironmentService] iluminação aplicada (Technology precisa ser Future/ShadowMap no Studio)")
	EnvironmentService.OptimizeShadows()
	task.spawn(dayNightLoop)
end

-- Sombras só em parts que fazem diferença visual: decoração miúda (< ShadowMinSize studs no maior eixo),
-- parts invisíveis e não colidíveis (hitboxes, marcadores) não projetam sombra. Roda uma vez no boot sobre
-- Workspace.Sahur (mapa) — ganho de GPU no cliente, sem mexer nos assets no disco.
EnvironmentService.ShadowMinSize = 2.5
function EnvironmentService.OptimizeShadows()
	local root = Workspace:FindFirstChild("Sahur")
	if not root then
		return
	end
	local changed, total = 0, 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.CastShadow then
			total += 1
			local size = d.Size
			local biggest = math.max(size.X, size.Y, size.Z)
			if biggest < EnvironmentService.ShadowMinSize or (d.Transparency >= 1 and not d.CanCollide) then
				d.CastShadow = false
				changed += 1
			end
		end
	end
	Log.debug(("[EnvironmentService] sombras: %d de %d parts do mapa deixaram de projetar"):format(changed, total))
end

return EnvironmentService
