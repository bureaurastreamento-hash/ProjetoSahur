-- Executa o serviço real: o cliente comum não pode escapar do pré-lançamento.
local Runtime = require("./runtime")
local count = 0
local function test(name, fn)
	fn()
	count += 1
	print("OK " .. name)
end
local function setup(developer)
	local rt = Runtime.new()
	rt.services.RunService = { Heartbeat = Runtime.Signal() }
	rt.mocks.WorldService = { Refresh = function() end }
	rt.mocks.FactionService = { Refresh = function() end }
	rt.mocks.BotService = { Spawn = function() return nil end }
	rt.mocks.ShopService = {}
	rt.mocks.RemoteEvents.Functions = { FetchLaunch = "FetchLaunch" }
	rt.mocks.RemoteEvents.GetFunction = function() return {} end
	local config = rt:load("src/shared/Modules/LaunchConfig")
	local launch = rt:load("src/server/Services/LaunchService")
	launch.Init()
	launch.Start()
	local p = rt:player(901)
	p.Character = nil -- física/respawn ficam no teste do Studio
	p:SetAttribute("IsDeveloper", developer)
	p:SetAttribute("CharacterId", "Humano")
	rt.services.Players.PlayerAdded:Fire(p)
	local request = rt.mocks.RemoteEvents.GetEvent("RequestLaunch")
	return rt, p, request, config
end

test("jogador comum não consegue sair do pré-lançamento pelo remote", function()
	local _, p, request = setup(false)
	assert(p:GetAttribute("PreLaunchLocked") == true)
	request.OnServerEvent:Fire(p, "view", false)
	assert(p:GetAttribute("PreLaunchLocked") == true and p:GetAttribute("PreLaunchView") == nil)
end)
test("admin alterna lobby/kit/mundo e restaura kit sem salvar o teste", function()
	local rt, p, request = setup(true)
	local originalProfile = rt.profiles[p].characterId
	assert(p:GetAttribute("PreLaunchLocked") == false)
	request.OnServerEvent:Fire(p, "view", true)
	assert(p:GetAttribute("PreLaunchLocked") == true)
	request.OnServerEvent:Fire(p, "kit", "Swift")
	assert(p:GetAttribute("CharacterId") == "Swift" and p:GetAttribute("LobbyTest") == true)
	request.OnServerEvent:Fire(p, "view", false)
	assert(p:GetAttribute("PreLaunchLocked") == false and p:GetAttribute("LobbyTest") == nil)
	assert(p:GetAttribute("CharacterId") == "Humano" and rt.profiles[p].characterId == originalProfile)
end)
test("troca bloqueada por combate e argumento inválido não altera modo", function()
	local rt, p, request = setup(true)
	rt.flags.blocked = true
	request.OnServerEvent:Fire(p, "view", true)
	assert(p:GetAttribute("PreLaunchLocked") == false)
	rt.flags.blocked = false
	request.OnServerEvent:Fire(p, "view", "true")
	assert(p:GetAttribute("PreLaunchView") == nil)
end)
test("modo desativado e excesso de pedidos são recusados", function()
	local _, p, request, config = setup(true)
	config.PreLaunch = false
	request.OnServerEvent:Fire(p, "view", true)
	assert(p:GetAttribute("PreLaunchView") == nil)
	config.PreLaunch = true
	request.OnServerEvent:Fire(p, "view", true)
	request.OnServerEvent:Fire(p, "view", false)
	request.OnServerEvent:Fire(p, "view", true)
	assert(p:GetAttribute("PreLaunchLocked") == false)
end)
print(count .. " testes de acesso ao pré-lançamento passaram")
