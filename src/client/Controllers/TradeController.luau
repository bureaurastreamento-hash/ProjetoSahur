--!strict
--[[
	TradeController (cliente)
	Trocas entre jogadores no vendedor (TradeService / TradeConfig). Telas em VendorGui:
	  Invite  — cartão "X quer trocar" (ACEITAR/RECUSAR); aceitar exige estar perto do vendedor.
	  Trade   — mesa: coluna VOCÊ = seu inventário trocável (TradeConfig.Tradeable do perfil) com estado
	            "oferecer"/"OFERECIDO" (clique alterna) + caixas de pontos / pontos de evento; coluna ELE = o
	            que o outro ofereceu. PRONTO nos dois libera CONFIRMAR depois de ConfirmDelay.
	Tudo que aparece vem do servidor (NotifyTrade "state"); o cliente só pede (RequestTrade).
	Propor: VendorController.OnPropose(player) -> RequestTrade("invite", userId).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local TradeConfig = require(Modules:WaitForChild("TradeConfig"))
local FX = require(Modules:WaitForChild("FX"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local VendorController = require(script.Parent:WaitForChild("VendorController"))

local TradeController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local requestTrade: RemoteEvent
local invite: Frame
local inviteText: TextLabel
local trade: Frame
local tradeTitle: TextLabel
local status: TextLabel
local readyBtn: TextButton
local confirmBtn: TextButton
local mineItems: ScrollingFrame
local mineTemplate: TextButton
local minePoints: TextBox
local mineEventPoints: TextBox
local theirsItems: ScrollingFrame
local theirsTemplate: TextButton
local theirsPoints: TextLabel
local theirsEventPoints: TextLabel

local profile: any = nil
local state: any = nil -- último "state" do servidor
local confirmAt = 0

local GREEN = Color3.fromRGB(90, 205, 130)
local MUTED = Color3.fromRGB(150, 150, 160)

local DENY_TEXT: { [string]: string } = {
	busy = "Finalize o combate, a partida ou a troca atual antes de trocar itens.",
	save_failed = "Não foi possível confirmar a troca. Seus itens serão reconciliados antes de continuar.",
	target_busy = "Esse jogador está ocupado.",
	far = "Vá até o vendedor para trocar.",
	not_loaded = "Dados não carregados (ou sem salvar nesta sessão): sem troca.",
	unknown = "Jogador não encontrado.",
	full = ("No máximo %d itens por lado."):format(TradeConfig.MaxItemsPerSide),
	lost_item = "Você não tem mais esse item.",
	not_tradeable = "Esse item não pode ser trocado.",
	other_owns = "O outro jogador já tem esse item.",
	coins = "Pontos insuficientes para essa oferta.",
	not_ready = "Os dois precisam estar prontos (e esperar um instante).",
}
local END_TEXT: { [string]: string } = {
	done = "Troca concluída!",
	cancelled = "Troca cancelada.",
	left = "O outro jogador saiu.",
}

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[TradeController] '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function clearRows(container: Instance, template: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("TextButton") and child ~= template then
			child:Destroy()
		end
	end
end

local function offered(side: any, kind: string, id: string): boolean
	if typeof(side) ~= "table" or typeof(side.items) ~= "table" then
		return false
	end
	for _, it in side.items do
		if it.kind == kind and it.id == id then
			return true
		end
	end
	return false
end

local KIND_LABEL: { [string]: string } = { character = "personagem", cosmetic = "cosmético", emote = "emote", item = "mochila" }

local function render()
	if not state then
		return
	end
	tradeTitle.Text = ("Troca com %s"):format(tostring(state.other))
	-- minha coluna: inventário trocável inteiro, marcando o que está na mesa
	clearRows(mineItems, mineTemplate)
	local mine = state.mine
	for i, it in TradeConfig.Tradeable(profile) do
		local row = mineTemplate:Clone()
		row.Visible = true
		row.LayoutOrder = i
		row.Text = ("%s  ·  %s"):format(it.name, KIND_LABEL[it.kind] or it.kind)
		local isOn = offered(mine, it.kind, it.id)
		local st = row:FindFirstChild("State") :: TextLabel
		st.Text = if isOn then "OFERECIDO" else "oferecer"
		st.TextColor3 = if isOn then GREEN else MUTED
		row.Activated:Connect(function()
			requestTrade:FireServer(if isOn then "remove" else "add", it.kind, it.id)
		end)
		row.Parent = mineItems
	end
	if not minePoints:IsFocused() then
		minePoints.Text = if (tonumber(mine.points) or 0) > 0 then tostring(mine.points) else ""
	end
	if not mineEventPoints:IsFocused() then
		mineEventPoints.Text = if (tonumber(mine.eventPoints) or 0) > 0 then tostring(mine.eventPoints) else ""
	end
	-- coluna do outro
	clearRows(theirsItems, theirsTemplate)
	local theirs = state.theirs
	if typeof(theirs.items) == "table" then
		for i, it in theirs.items do
			local row = theirsTemplate:Clone()
			row.Visible = true
			row.LayoutOrder = i
			row.Text = ("%s  ·  %s"):format(tostring(it.name), KIND_LABEL[tostring(it.kind)] or tostring(it.kind))
			;(row:FindFirstChild("State") :: TextLabel).Text = ""
			row.Parent = theirsItems
		end
	end
	theirsPoints.Text = ("%d pontos"):format(tonumber(theirs.points) or 0)
	theirsEventPoints.Text = ("%d pontos de evento"):format(tonumber(theirs.eventPoints) or 0)
	-- botões
	readyBtn.Text = if state.myReady then "PRONTO ✓ (desfazer)" else "PRONTO"
	local both = state.myReady and state.theirReady
	confirmAt = tonumber(state.confirmAt) or 0
	confirmBtn.Visible = both
	confirmBtn.Text = if state.myConfirmed then "CONFIRMADO ✓" else "CONFIRMAR"
	local lines = {}
	table.insert(lines, if state.theirReady then ("%s está PRONTO."):format(tostring(state.other)) else ("Esperando %s ficar pronto."):format(tostring(state.other)))
	if both then
		table.insert(lines, if state.theirConfirmed then "Ele já confirmou: confirme para concluir." else "Os dois prontos: confirme quando o outro também confirmar.")
	end
	status.Text = table.concat(lines, " ")
end

local function setStatus(text: string)
	status.Text = text
end

local function applyPointsBox(box: TextBox, action: string)
	local n = tonumber(box.Text)
	if box.Text == "" then
		n = 0
	end
	if not n or n < 0 then
		box.Text = ""
		return
	end
	requestTrade:FireServer(action, math.floor(n))
end

function TradeController.Init()
	requestTrade = Remotes.GetEvent(Remotes.Events.RequestTrade)
	local gui = get(playerGui, "VendorGui")
	invite = get(gui, "Invite") :: Frame
	inviteText = get(invite, "Text") :: TextLabel
	trade = get(gui, "Trade") :: Frame
	tradeTitle = get(trade, "Title") :: TextLabel
	status = get(trade, "Status") :: TextLabel
	readyBtn = get(trade, "Ready") :: TextButton
	confirmBtn = get(trade, "Confirm") :: TextButton
	local mine = get(trade, "Mine")
	mineItems = get(mine, "Items") :: ScrollingFrame
	mineTemplate = get(mineItems, "Template") :: TextButton
	minePoints = get(mine, "Points") :: TextBox
	mineEventPoints = get(mine, "EventPoints") :: TextBox
	local theirs = get(trade, "Theirs")
	theirsItems = get(theirs, "Items") :: ScrollingFrame
	theirsTemplate = get(theirsItems, "Template") :: TextButton
	theirsPoints = get(theirs, "Points") :: TextLabel
	theirsEventPoints = get(theirs, "EventPoints") :: TextLabel
end

function TradeController.Start()
	VendorController.OnPropose = function(target: Player)
		requestTrade:FireServer("invite", target.UserId)
	end
	;(get(invite, "Accept") :: TextButton).Activated:Connect(function()
		requestTrade:FireServer("accept")
	end)
	;(get(invite, "Decline") :: TextButton).Activated:Connect(function()
		requestTrade:FireServer("decline")
		invite.Visible = false
	end)
	readyBtn.Activated:Connect(function()
		if state then
			requestTrade:FireServer("ready", not state.myReady)
		end
	end)
	confirmBtn.Activated:Connect(function()
		if workspace:GetServerTimeNow() < confirmAt then
			setStatus(("Espere %.0f s antes de confirmar."):format(confirmAt - workspace:GetServerTimeNow()))
			return
		end
		requestTrade:FireServer("confirm")
	end)
	local function cancel()
		requestTrade:FireServer("cancel")
	end
	;(get(trade, "Cancel") :: TextButton).Activated:Connect(cancel)
	;(get(trade, "Close") :: TextButton).Activated:Connect(cancel)
	minePoints.FocusLost:Connect(function()
		applyPointsBox(minePoints, "points")
	end)
	mineEventPoints.FocusLost:Connect(function()
		applyPointsBox(mineEventPoints, "event_points")
	end)

	Remotes.GetEvent(Remotes.Events.NotifyProfile).OnClientEvent:Connect(function(p: any)
		if typeof(p) == "table" then
			profile = p
			if trade.Visible then
				render()
			end
		end
	end)
	Remotes.GetEvent(Remotes.Events.NotifyTrade).OnClientEvent:Connect(function(event: string, data: any)
		data = if typeof(data) == "table" then data else {}
		if event == "invite" then
			inviteText.Text = ("%s quer TROCAR com você. Vá até o vendedor e aceite."):format(tostring(data.fromName))
			invite.Visible = true
			FX.PlaySoundUI("Shared", "UltReady")
			local expiresAt = tonumber(data.expiresAt) or 0
			task.delay(math.max(0, expiresAt - workspace:GetServerTimeNow()), function()
				if inviteText.Text:find(tostring(data.fromName), 1, true) then
					invite.Visible = false
				end
			end)
		elseif event == "invite_sent" then
			HUDController.ShowBanner(("Convite de troca enviado para %s"):format(tostring(data.targetName)), 3)
		elseif event == "invite_closed" then
			invite.Visible = false
			local why = ({ expired = "expirou", declined = "foi recusado", cancelled = "foi cancelado", unavailable = "não deu" })[tostring(data.reason)] or tostring(data.reason)
			HUDController.ShowBanner(("Convite de troca com %s %s."):format(tostring(data.other), why), 3)
		elseif event == "start" then
			invite.Visible = false
			VendorController.Close()
			state = nil
			trade.Visible = true
			minePoints.Text = ""
			mineEventPoints.Text = ""
			setStatus("Clique nos seus itens para oferecer. Os dois marcam PRONTO e depois CONFIRMAM.")
		elseif event == "state" then
			state = data
			if not trade.Visible then
				trade.Visible = true
			end
			render()
		elseif event == "end" then
			trade.Visible = false
			state = nil
			local text = END_TEXT[tostring(data.reason)] or tostring(data.reason)
			if data.reason == "cancelled" and data.by and data.by ~= localPlayer.Name then
				text = ("%s cancelou a troca."):format(tostring(data.by))
			end
			HUDController.ShowBanner(text, 3)
			if data.reason == "done" then
				FX.PlaySoundUI("Match", "Victory")
			end
		elseif event == "denied" then
			local text = DENY_TEXT[tostring(data.reason)] or tostring(data.reason)
			if trade.Visible then
				setStatus(text)
			else
				HUDController.ShowBanner(text, 3)
			end
		end
	end)
	Log.debug("[TradeController] pronto")
end

return TradeController
