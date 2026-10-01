local Runtime = require("./runtime")
local Vector3 = require("@lune/roblox").Vector3
local count = 0
local function test(name, fn) fn(); count += 1; print("OK " .. name) end
local position = Vector3.new(2700, 2, 0)
local function setup(act)
	local rt = Runtime.new(); local player, root = rt:player(1, position)
	local profile = rt.profiles[player]; profile.story.act = act or 22
	profile.level = 50 -- teste da sequência; o bloqueio por nível tem teste próprio
	player:SetAttribute("Level", 50)
	local story = rt:loadStory(); story.Init(); story.Start()
	local world = rt:load("src/shared/Modules/WorldConfig")
	world.Regions.cidade_ambar.Available = true
	table.insert(world.Islands, { Id = "ambar", Region = "cidade_ambar", Center = position, RadiusX = 100, RadiusZ = 100 })
	profile.story.flags.cidade_ambar_unlocked = true
	rt.mocks.WorldService = {}; rt.mocks.BotService = {}
	local city = rt:load("src/server/Services/CidadeAmbarService")
	local function use(name) return city.Interact(player, { Name = name, Position = position }) end
	return rt, player, profile, story, city, use, root, world
end

test("rev4 conserva os 22 atos, itens e contadores; limite antigo não salta chegada", function()
	for i = 1, 23 do
		local rt = Runtime.new(); local player = rt:player(1)
		local p = rt.profiles[player]; p.story.act, p.story.rev = i, 4
		p.story.counters.keep = 2; p.story.flags.keep = true; p.inventory.flecha = 3
		local s = rt:loadStory(); s.Init(); s.Start()
		assert(p.story.rev == 7 and p.story.act == math.min(i, 22))
		assert(p.story.flags.keep and p.inventory.flecha == 3)
		assert(i > 22 or p.story.counters.keep == 2)
	end
end)

test("catálogo inicia indisponível e não inventa coordenadas", function()
	local rt = Runtime.new(); local w = rt:load("src/shared/Modules/WorldConfig")
	assert(not w.Regions.cidade_ambar.Available and not w.CFrameOf("cidade_ambar", "chegada"))
end)

test("chegada precede tarefas; moradores e cenas diferentes contam uma vez", function()
	local rt, player, p, story, city, use = setup()
	assert(not use("AmbarMorador1"))
	story.ArriveRegion(player, "cidade_ambar"); assert(p.story.act == 23)
	assert(use("AmbarMorador1") and not use("AmbarMorador1"))
	assert(use("AmbarTarefa") and p.story.act == 23)
	assert(use("AmbarMorador2") and p.story.act == 24)
	assert(use("AmbarDesaparecimento1") and not use("AmbarDesaparecimento1"))
	assert(use("AmbarDesaparecimento2") and p.story.act == 25)
	for _, m in rt.messages do if m.data and m.data.text then assert(not m.data.text:find("Carlos")) end end
end)

test("nome só aparece após fotografia e confronto válido; reconexão conserva fotografia", function()
	local rt, player, p, story, city, use = setup(25)
	assert(not use("AmbarHumanoider") and not p.story.flags.carlos_nome_revelado)
	assert(use("AmbarFotografia") and p.story.act == 25 and not p.story.flags.carlos_nome_revelado)
	local rt2, player2, p2, story2, city2, use2 = setup(25)
	rt2.profiles[player2] = p
	assert(use2("AmbarHumanoider") and p.story.act == 26 and p.story.flags.carlos_nome_revelado)
	local last = rt2.messages[#rt2.messages]
	assert(last.data.text:find("Carlos") and last.data.text:find("Éramos oito") and last.data.text:find("Agora somos sete"))
	assert(not use2("AmbarHumanoider") and p.story.act == 26)
end)

test("interações rejeitam distância, morte, região, rota fechada e área indisponível", function()
	local rt, player, p, story, city, use, root, world = setup(23)
	root.Position = Vector3.zero; assert(not use("AmbarMorador1"))
	assert(not city.Interact(player, { Name = "AmbarMorador1", Position = Vector3.zero }))
	root.Position = position; rt.flags.dead = true; assert(not use("AmbarMorador1"))
	rt.flags.dead = false; p.story.flags.cidade_ambar_unlocked = nil; assert(not use("AmbarMorador1"))
	p.story.flags.cidade_ambar_unlocked = true; world.Regions.cidade_ambar.Available = false
	assert(not use("AmbarMorador1") and not p.story.counters.fx_ambar_morador)
end)

test("investigação exige cenas/depoimento antes do padrão e da escolha", function()
	local rt, player, p, story, city, use = setup(26)
	assert(not use("AmbarPadrao") and not story.Choose(player, "ambar_suspeito", "ligado_cenas"))
	assert(use("AmbarCena1") and not use("AmbarCena1"))
	assert(use("AmbarCena2") and not use("AmbarPadrao"))
	assert(use("AmbarTestemunha") and use("AmbarPadrao"))
	assert(story.Choose(player, "ambar_suspeito", "ligado_cenas") and p.story.act == 27)
end)

test("acusação incorreta exige contrapista, pode repetir e não trava campanha", function()
	local rt, player, p, story, city, use = setup(26)
	for _, name in { "AmbarCena1", "AmbarCena2", "AmbarTestemunha", "AmbarPadrao" } do assert(use(name)) end
	for _ = 1, 2 do
		assert(story.Choose(player, "ambar_suspeito", "sem_vinculo") and p.story.act == 26)
		assert(not story.Choose(player, "ambar_suspeito", "ligado_cenas"))
		assert(use("AmbarContrapista") and not use("AmbarContrapista"))
	end
	assert(story.Choose(player, "ambar_suspeito", "ligado_cenas") and p.story.act == 27)
	assert(use("AmbarCasa") and p.story.act == 28)
end)

test("contribuição ao boss leva ao Eco; três caminhos compartilham informação e rota", function()
	for _, option in { "autoridades", "humanoider", "pessoal" } do
		local rt, player, p, story = setup(28)
		rt.participants = { player }
		rt.mocks.HealthService.FighterDied.Event:Fire({ bot = true, GetAttribute = function() return "fx_ambar_boss" end }, player)
		assert(p.story.act == 29 and not p.story.flags.costa_dourada_unlocked)
		assert(story.Choose(player, "eco_ilha4", option))
		assert(p.story.act == 30 and p.story.flags.costa_dourada_unlocked and p.story.flags.ambar_metodo_linhas)
		assert(p.story.flags["eco_ilha4_" .. option] and not story.Choose(player, "eco_ilha4", option))
	end
end)


test("mapa incompleto, sobreposição e chão ausente não liberam rota; mapa válido é aditivo", function()
	local rt = Runtime.new()
	local w = rt:load("src/shared/Modules/WorldConfig")
	local pv = rt:load("src/shared/Modules/PvpConfig")
	local config = rt:load("src/shared/Modules/CidadeAmbarConfig")
	local floor = { IsDescendantOf = function() return true end }
	local hasFloor = false
	function rt.services.Workspace:Raycast() return if hasFloor then { Instance = floor, Normal = Vector3.yAxis } else nil end
	local spawned, removed = 0, 0
	local bot = { GetAttribute = function() return "fx_ambar_boss" end }
	rt.mocks.WorldService = { SetCheckpoint = function() end }
	rt.mocks.BotService = { Spawn = function(options) assert(options.HomeMap); spawned += 1 end,
		List = function() return { bot } end, Remove = function() removed += 1 end }
	local city = rt:load("src/server/Services/CidadeAmbarService")
	local parts = {}
	local attributes = { FXRadiusX = 100, FXRadiusZ = 100 }
	local connected = true
	local map = { Name = "FXCidadeAmbar", AncestryChanged = Runtime.Signal(),
		IsDescendantOf = function() return connected end,
		GetAttribute = function(_, name) return attributes[name] end,
		FindFirstChild = function(_, name) return parts[name] end }
	assert(not city.BindMap(map))
	local names = { "AmbarSpawn", "AmbarCentro", "AmbarBossSpawn", "AmbarHumanoider", "AmbarCheckpoint", "AmbarToSolPartido" }
	for name in config.Interactions do table.insert(names, name) end
	local CFrame = require("@lune/roblox").CFrame
	for _, name in names do
		parts[name] = { Name = name, Anchored = true, Position = position, Orientation = Vector3.zero,
			CFrame = CFrame.new(position), IsA = function(_, class) return class == "BasePart" end }
	end
	assert(not city.BindMap(map) and not w.Regions.cidade_ambar.Available)
	hasFloor = true; parts.AmbarCentro.Position = Vector3.new(150, 2, -40)
	assert(not city.BindMap(map))
	parts.AmbarCentro.Position = position; attributes.FXRadiusX = 0/0
	assert(not city.BindMap(map))
	attributes.FXRadiusX = 100
	local islandsBefore, zonesBefore = #w.Islands, #pv.SafeZones
	assert(city.BindMap(map) and spawned == 1 and w.Regions.cidade_ambar.Available)
	assert(w.CFrameOf("cidade_ambar", "chegada") and #w.Islands == islandsBefore + 1 and #pv.SafeZones == zonesBefore + 1)
	assert(not city.BindMap(map) and spawned == 1)
	connected = false; map.AncestryChanged:Fire()
	assert(not w.Regions.cidade_ambar.Available and not w.CFrameOf("cidade_ambar", "chegada"))
	assert(#w.Islands == islandsBefore and #pv.SafeZones == zonesBefore and removed == 1)
end)

test("checkpoint salvo em mapa indisponível usa fallback sem apagar escolha", function()
	local rt = Runtime.new(); local player = rt:player(1)
	local p = rt.profiles[player]
	p.world.region, p.world.checkpoint = "cidade_ambar", "chegada"
	rt:load("src/shared/Modules/LaunchConfig").PreLaunch = false -- o lobby de pré-lançamento tem teste próprio
	local world = rt:load("src/server/Services/WorldService"); world.Start()
	local config = rt:load("src/shared/Modules/WorldConfig")
	assert(p.world.region == "cidade_ambar" and p.world.checkpoint == "chegada")
	assert(player:GetAttribute("WorldRegion") == config.DefaultRegion)
	assert(world.SpawnCFrame(player).Position == config.GetCheckpoint(config.DefaultRegion, config.DefaultCheckpoint).Position)
	config.Regions.cidade_ambar.Checkpoints.chegada = { Position = position, Yaw = 0 }
	config.Regions.cidade_ambar.Available = true
	world.Refresh(player)
	assert(world.SpawnCFrame(player).Position == position and player:GetAttribute("WorldRegion") == "cidade_ambar")
	assert(p.world.region == "cidade_ambar" and p.world.checkpoint == "chegada")
end)

print(("%d testes de Cidade Âmbar passaram"):format(count))
