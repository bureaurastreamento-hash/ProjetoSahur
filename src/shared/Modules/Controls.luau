--!strict
--[[
	Controls
	FONTE ÚNICA dos controles por dispositivo (teclado/mouse, gamepad, toque). Os controllers perguntam
	`Controls.ActionOf(input)` em vez de comparar KeyCodes soltos; o HUD/ajuda mostram o rótulo certo
	com `Controls.Label(action, device)`.

	Layout do gamepad copiado dos battlegrounds (Jujutsu Shenanigans): B = soco, X = block, Y = dash,
	LB/LT/RT/RB = golpes 1–4, D-pad cima = despertar. Extras nossos: D-pad baixo = emotes, R3 = shift
	lock, Select/Back = placar, D-pad direita = navegar os menus do topo (TopbarPlus).

	Configurações de acessibilidade (salvas no perfil, `profile.settings`): ver Controls.Settings.
]]

local Controls = {}

export type Device = "keyboard" | "gamepad" | "touch"

-- ações do jogo (nomes usados pelos controllers)
Controls.Keyboard = ({
	Attack = Enum.UserInputType.MouseButton1,
	Block = Enum.KeyCode.F,
	Dash = Enum.KeyCode.Q, -- também levanta do ragdoll
	Slot1 = Enum.KeyCode.One,
	Slot2 = Enum.KeyCode.Two,
	Slot3 = Enum.KeyCode.Three,
	Slot4 = Enum.KeyCode.Four,
	Awaken = Enum.KeyCode.G,
	Emotes = Enum.KeyCode.B,
	ShiftLock = Enum.KeyCode.LeftShift,
	Scoreboard = Enum.KeyCode.Tab,
} :: { [string]: any }) :: { [string]: Enum.KeyCode | Enum.UserInputType }

Controls.Gamepad = ({
	Attack = Enum.KeyCode.ButtonB,
	Block = Enum.KeyCode.ButtonX,
	Dash = Enum.KeyCode.ButtonY,
	Slot1 = Enum.KeyCode.ButtonL1,
	Slot2 = Enum.KeyCode.ButtonL2,
	Slot3 = Enum.KeyCode.ButtonR2,
	Slot4 = Enum.KeyCode.ButtonR1,
	Awaken = Enum.KeyCode.DPadUp,
	Emotes = Enum.KeyCode.DPadDown,
	ShiftLock = Enum.KeyCode.ButtonR3,
	Scoreboard = Enum.KeyCode.ButtonSelect,
	Menus = Enum.KeyCode.DPadRight, -- TopbarPlus (Icon.highlightKey)
} :: { [string]: Enum.KeyCode })

-- rótulos curtos para HUD/ajuda
local KEY_LABELS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.ButtonA] = "A",
	[Enum.KeyCode.ButtonB] = "B",
	[Enum.KeyCode.ButtonX] = "X",
	[Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonL1] = "LB",
	[Enum.KeyCode.ButtonR1] = "RB",
	[Enum.KeyCode.ButtonL2] = "LT",
	[Enum.KeyCode.ButtonR2] = "RT",
	[Enum.KeyCode.ButtonL3] = "L3",
	[Enum.KeyCode.ButtonR3] = "R3",
	[Enum.KeyCode.ButtonSelect] = "Back",
	[Enum.KeyCode.ButtonStart] = "Menu",
	[Enum.KeyCode.DPadUp] = "D↑",
	[Enum.KeyCode.DPadDown] = "D↓",
	[Enum.KeyCode.DPadLeft] = "D←",
	[Enum.KeyCode.DPadRight] = "D→",
	[Enum.KeyCode.One] = "1",
	[Enum.KeyCode.Two] = "2",
	[Enum.KeyCode.Three] = "3",
	[Enum.KeyCode.Four] = "4",
	[Enum.KeyCode.LeftShift] = "Shift",
	[Enum.KeyCode.Tab] = "Tab",
}

--- Ação correspondente a um InputObject (teclado/mouse ou gamepad), ou nil.
function Controls.ActionOf(input: InputObject): string?
	if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1 then
		for action, bind in Controls.Keyboard do
			if bind == input.KeyCode or bind == input.UserInputType then
				return action
			end
		end
	elseif input.UserInputType.Name:sub(1, 7) == "Gamepad" then
		for action, bind in Controls.Gamepad do
			if bind == input.KeyCode then
				return action
			end
		end
	end
	return nil
end

function Controls.Label(action: string, device: Device): string
	if device == "gamepad" then
		local key = Controls.Gamepad[action]
		return if key then (KEY_LABELS[key] or key.Name) else ""
	end
	local bind = Controls.Keyboard[action]
	if bind == Enum.UserInputType.MouseButton1 then
		return "M1"
	elseif typeof(bind) == "EnumItem" then
		return KEY_LABELS[bind :: Enum.KeyCode] or (bind :: Enum.KeyCode).Name
	end
	return ""
end

--- Dispositivo atual a partir do último input.
function Controls.DeviceOf(inputType: Enum.UserInputType): Device
	if inputType == Enum.UserInputType.Touch then
		return "touch"
	elseif inputType.Name:sub(1, 7) == "Gamepad" then
		return "gamepad"
	end
	return "keyboard"
end

-- ---------------------------------------------------------------------------
-- Configurações (acessibilidade) — validadas no servidor (SettingsService) e salvas no perfil
-- ---------------------------------------------------------------------------

export type SettingDef = { Default: number | boolean, Options: { number }?, Label: string, Hint: string }
Controls.Settings = ({
	TouchScale = { Default = 1, Options = { 0.8, 1, 1.25 }, Label = "Tamanho dos botões", Hint = "toque" },
	TouchOpacity = { Default = 0.65, Options = { 0.4, 0.65, 0.9 }, Label = "Opacidade dos botões", Hint = "toque" },
	TouchMirror = { Default = false, Label = "Canhoto (botões à esquerda)", Hint = "toque" },
	BlockToggle = { Default = false, Label = "Bloquear: apertar liga/desliga", Hint = "em vez de segurar" },
	AttackHold = { Default = true, Label = "Segurar soco = combo automático", Hint = "" },
	Haptics = { Default = true, Label = "Vibração ao acertar/apanhar", Hint = "controle e celular" },
	ScreenShake = { Default = true, Label = "Tremor de tela", Hint = "" },
} :: { [string]: SettingDef })
Controls.SettingsOrder = { "AttackHold", "BlockToggle", "ScreenShake", "Haptics", "TouchScale", "TouchOpacity", "TouchMirror" }

--- Valor válido para a configuração (nil = inválido).
function Controls.ValidateSetting(key: any, value: any): (number | boolean)?
	local def = if typeof(key) == "string" then Controls.Settings[key] else nil
	if not def then
		return nil
	end
	if typeof(def.Default) == "boolean" then
		return if typeof(value) == "boolean" then value else nil
	end
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	if def.Options and not table.find(def.Options, value) then
		return nil
	end
	return value
end

--- Valor atual (do perfil) ou o padrão.
function Controls.Setting(settings: { [string]: any }?, key: string): number | boolean
	local def = Controls.Settings[key]
	local v = if settings then settings[key] else nil
	if v ~= nil and Controls.ValidateSetting(key, v) ~= nil then
		return v
	end
	return def.Default
end

return Controls
