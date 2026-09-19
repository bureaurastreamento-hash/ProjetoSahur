--!strict
--[[
	SettingsController (cliente)
	Cache das configurações de controle/acessibilidade (Controls.Settings) vindas do perfil
	(NotifyProfile) e envio de mudanças (RequestSetting). Outros controllers usam
	SettingsController.Get(key) e escutam SettingsController.Changed (key, value).
	Também aplica as globais: FX.ShakeEnabled e vibração (HapticService) em FX.Haptic.
]]

local HapticService = game:GetService("HapticService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Controls = require(Modules:WaitForChild("Controls"))
local FX = require(Modules:WaitForChild("FX"))
local Log = require(Modules:WaitForChild("Log"))

local SettingsController = {}

local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local values: { [string]: any } = {}
local requestSetting: RemoteEvent

SettingsController.Changed = Instance.new("BindableEvent")

function SettingsController.Get(key: string): number | boolean
	return Controls.Setting(values, key)
end

--- Muda localmente na hora (feedback imediato) e manda ao servidor salvar.
function SettingsController.Set(key: string, value: number | boolean)
	if Controls.ValidateSetting(key, value) == nil then
		return
	end
	values[key] = value
	requestSetting:FireServer(key, value)
	SettingsController.Changed:Fire(key, value)
	SettingsController.ApplyGlobals()
end

--- Próximo valor (booleano alterna; lista de opções avança e volta ao início).
function SettingsController.Cycle(key: string)
	local def = Controls.Settings[key]
	local current = SettingsController.Get(key)
	if typeof(def.Default) == "boolean" then
		SettingsController.Set(key, not (current :: boolean))
		return
	end
	local options = def.Options or { def.Default :: number }
	local idx = table.find(options, current :: number) or 0
	SettingsController.Set(key, options[idx % #options + 1])
end

--- Vibração curta (controle: motor; celular: HapticService nem sempre tem motor — falha em silêncio).
local function haptic(strength: number, seconds: number)
	if SettingsController.Get("Haptics") ~= true then
		return
	end
	local gamepad = UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1)
	local inputType = if gamepad then Enum.UserInputType.Gamepad1 else nil
	if not inputType then
		return
	end
	pcall(function()
		if HapticService:IsVibrationSupported(inputType) and HapticService:IsMotorSupported(inputType, Enum.VibrationMotor.Large) then
			HapticService:SetMotor(inputType, Enum.VibrationMotor.Large, strength)
			task.delay(seconds, function()
				HapticService:SetMotor(inputType, Enum.VibrationMotor.Large, 0)
			end)
		end
	end)
end

function SettingsController.ApplyGlobals()
	FX.ShakeEnabled = SettingsController.Get("ScreenShake") == true
	FX.Haptic = haptic
end

function SettingsController.Init()
	requestSetting = Remotes.GetEvent(Remotes.Events.RequestSetting)
	SettingsController.ApplyGlobals()
end

--- Lista de configurações (SettingsGui.Panel.Settings, item "Configurações" do dropdown Config): clique = alterna/avança.
local function valueText(key: string): string
	local v = SettingsController.Get(key)
	if typeof(v) == "boolean" then
		return if v then "LIGADO" else "DESLIGADO"
	end
	local def = Controls.Settings[key]
	if def.Options then
		local labels = { [0.8] = "Pequeno", [1] = "Médio", [1.25] = "Grande", [0.4] = "Baixa", [0.65] = "Média", [0.9] = "Alta" }
		return labels[v :: number] or tostring(v)
	end
	return tostring(v)
end

local function buildSettingsList()
	local settingsGui = playerGui:WaitForChild("SettingsGui", 10)
	local panel = settingsGui and settingsGui:FindFirstChild("Panel")
	local list = panel and panel:FindFirstChild("Settings")
	local template = list and list:FindFirstChild("Template") :: TextButton?
	if not list or not template then
		return
	end
	local rows: { [string]: TextButton } = {}
	for i, key in Controls.SettingsOrder do
		local def = Controls.Settings[key]
		local row = template:Clone()
		row.Name = key
		row.LayoutOrder = i
		row.Text = def.Label .. (if def.Hint ~= "" then ("  (%s)"):format(def.Hint) else "")
		row.Visible = true
		local value = row:FindFirstChild("Value") :: TextLabel
		value.Text = valueText(key)
		row.MouseButton1Click:Connect(function()
			SettingsController.Cycle(key)
		end)
		row.Parent = list
		rows[key] = row
	end
	SettingsController.Changed.Event:Connect(function(key: string)
		local row = rows[key]
		if row then
			(row:FindFirstChild("Value") :: TextLabel).Text = valueText(key)
		end
	end)
end

function SettingsController.Start()
	task.spawn(buildSettingsList)
	Remotes.GetEvent(Remotes.Events.NotifyProfile).OnClientEvent:Connect(function(profile: any)
		if typeof(profile) ~= "table" or typeof(profile.settings) ~= "table" then
			return
		end
		for key, v in profile.settings do
			if typeof(key) == "string" and Controls.ValidateSetting(key, v) ~= nil and values[key] ~= v then
				values[key] = v
				SettingsController.Changed:Fire(key, v)
			end
		end
		SettingsController.ApplyGlobals()
	end)
	Log.debug("[SettingsController] pronto")
end

return SettingsController
