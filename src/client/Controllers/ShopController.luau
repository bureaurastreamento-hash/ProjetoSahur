--!strict
--[[
	ShopController (cliente)
	Preenche ShopGui.Panel com o catálogo de ShopConfig (moedas via Developer Product, passes)
	e pede a compra ao servidor (RequestShop), que abre o prompt oficial da Roblox.
	Só reflete: moedas vêm do atributo Coins; passes possuídos do atributo Pass_<key>.
	O painel é aberto/fechado pelo ícone "Loja" (B) no TopbarController.
	API: ShopController.Panel (Frame) para o topbar ligar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local ShopConfig = require(Modules:WaitForChild("ShopConfig"))
local FX = require(Modules:WaitForChild("FX"))

local ShopController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local panel: Frame
local coinsLabel: TextLabel
local productsList: Frame
local productTemplate: TextButton
local passesList: Frame
local passTemplate: TextButton
local hint: TextLabel
local passRows: { [string]: TextButton } = {}
local requestShop: RemoteEvent

local GREEN = Color3.fromRGB(90, 204, 128)
local MUTED = Color3.fromRGB(158, 158, 173)

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[ShopController] '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function setHint(text: string, seconds: number?)
	local original = "Personagens são comprados com moedas na tela Personagens (V)."
	hint.Text = text
	if seconds then
		task.delay(seconds, function()
			if hint.Text == text then
				hint.Text = original
			end
		end)
	end
end

local function refreshCoins()
	local coins = localPlayer:GetAttribute("Coins")
	coinsLabel.Text = if typeof(coins) == "number" then ("%d moedas"):format(coins) else ""
end

local function refreshPass(key: string)
	local row = passRows[key]
	local def = ShopConfig.GetPass(key)
	if not row or not def then
		return
	end
	local price = row:FindFirstChild("Price") :: TextLabel
	if localPlayer:GetAttribute("Pass_" .. key) == true then
		price.Text = "ADQUIRIDO"
		price.TextColor3 = MUTED
	elseif def.gamepassId <= 0 then
		price.Text = "EM BREVE"
		price.TextColor3 = MUTED
	else
		price.Text = "COMPRAR"
		price.TextColor3 = GREEN
	end
end

local function build()
	for i, product in ShopConfig.Products do
		local card = productTemplate:Clone()
		card.Visible = true
		card.LayoutOrder = i
		;(card:FindFirstChild("Amount") :: TextLabel).Text = ("%d"):format(product.coins)
		;(card:FindFirstChild("Name") :: TextLabel).Text = product.name
		local price = card:FindFirstChild("Price") :: TextLabel
		if product.productId > 0 then
			price.Text = "ROBUX"
		else
			price.Text = "EM BREVE"
			price.TextColor3 = MUTED
		end
		card.Activated:Connect(function()
			requestShop:FireServer("product", product.key)
		end)
		card.Parent = productsList
	end
	for i, pass in ShopConfig.Passes do
		local row = passTemplate:Clone()
		row.Visible = true
		row.LayoutOrder = i
		;(row:FindFirstChild("Name") :: TextLabel).Text = pass.name
		;(row:FindFirstChild("Desc") :: TextLabel).Text = pass.desc
		row.Activated:Connect(function()
			requestShop:FireServer("pass", pass.key)
		end)
		row.Parent = passesList
		passRows[pass.key] = row
		refreshPass(pass.key)
		localPlayer:GetAttributeChangedSignal("Pass_" .. pass.key):Connect(function()
			refreshPass(pass.key)
		end)
	end
end

function ShopController.Init()
	requestShop = Remotes.GetEvent(Remotes.Events.RequestShop)
	panel = get(get(playerGui, "ShopGui"), "Panel") :: Frame
	coinsLabel = get(panel, "Coins") :: TextLabel
	productsList = get(panel, "Products") :: Frame
	productTemplate = get(productsList, "Template") :: TextButton
	passesList = get(panel, "Passes") :: Frame
	passTemplate = get(passesList, "Template") :: TextButton
	hint = get(panel, "Hint") :: TextLabel
	ShopController.Panel = panel
end

function ShopController.Start()
	build()
	refreshCoins()
	localPlayer:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
	Remotes.GetEvent(Remotes.Events.NotifyShop).OnClientEvent:Connect(function(event: string, data: any)
		data = if typeof(data) == "table" then data else {}
		if event == "purchased" then
			local coins = tonumber(data.coins)
			setHint(if coins then ("Compra concluída: +%d moedas"):format(coins) else "Passe adquirido. Obrigado!", 4)
			FX.PlaySoundUI("Match", "Victory")
		elseif event == "denied" then
			setHint("Este item ainda não está disponível.", 3)
		elseif event == "owned" then
			setHint("Você já tem este passe.", 3)
		end
	end)
	Log.debug("[ShopController] pronto")
end

return ShopController
