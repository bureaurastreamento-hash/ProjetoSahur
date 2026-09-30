local Runtime = require("./runtime")
local Vector3 = require("@lune/roblox").Vector3
local count = 0
local function test(name, fn) fn(); count += 1; print("OK " .. name) end
local position = Vector3.new(3500, 2, 0)
local function setup(act)
	local rt = Runtime.new(); local player, root = rt:player(1, position)
	local p = rt.profiles[player]; p.story.act = act or 30
	local story = rt:load("src/server/Services/StoryService"); story.Init(); story.Start()
	local config = rt:load("src/shared/Modules/WorldConfig")
	config.Regions.costa_dourada.Available = true
	table.insert(config.Islands, { Id = "costa", Region = "costa_dourada", Center = position, RadiusX = 100, RadiusZ = 100 })
	p.story.flags.costa_dourada_unlocked = true
	rt.mocks.WorldService, rt.mocks.BotService = {}, {}
	local service = rt:load("src/server/Services/CostaDouradaService")
	local function use(name) return service.Interact(player, { Name = name, Position = position }) end
	return rt, player, p, story, service, use, root, config
end

test("migração rev5 preserva os 30 atos e não pula chegada após limite antigo", function()
	for i = 1, 31 do
		local rt = Runtime.new(); local player = rt:player(1)
		local p = rt.profiles[player]; p.story.rev, p.story.act = 5, i
		p.story.counters.keep = 7; p.inventory.flecha = 2; p.story.flags.carlos_nome_revelado = true
		local story = rt:load("src/server/Services/StoryService"); story.Init(); story.Start()
		assert(p.story.act == math.min(i, 30) and p.story.rev == 7)
		assert(i == 31 or p.story.counters.keep == 7)
		assert(p.inventory.flecha == 2 and p.story.flags.carlos_nome_revelado)
	end
end)

test("chegada e lotes distintos antecedem organização e escolha de infiltração", function()
	local rt, player, p, story, service, use = setup()
	assert(not use("CostaLote1")); story.ArriveRegion(player, "costa_dourada")
	assert(p.story.act == 31 and use("CostaLote1") and not use("CostaLote1"))
	assert(use("CostaLote2") and p.story.act == 32)
	assert(use("CostaOrganizacao") and p.story.act == 33)
	assert(not story.Choose(player, "costa_infiltracao", "social"))
end)

test("força exige kills PvE de guardas e acesso principal; PvP não conta", function()
	local rt, player, p, story, service, use = setup(33)
	assert(story.Choose(player, "costa_infiltracao", "forca") and p.story.act == 34)
	assert(not use("CostaAcessoSocial") and not use("CostaAcessoForca"))
	rt.mocks.HealthService.FighterDied.Event:Fire(player, player)
	assert(not p.story.counters.fx_costa_guard)
	for i = 1, 3 do
		rt.mocks.HealthService.FighterDied.Event:Fire({ bot = true, GetAttribute = function() return "fx_costa_guard" end }, player)
		if i < 3 then assert(not use("CostaAcessoForca")) end
	end
	assert(p.story.act == 34 and use("CostaAcessoForca") and p.story.act == 35)
end)

test("furtividade exige passagens em ordem e nunca exige derrotar guardas", function()
	local rt, player, p, story, service, use = setup(33)
	assert(story.Choose(player, "costa_infiltracao", "furtividade"))
	assert(not use("CostaPassagem2") and not use("CostaAcessoFurtivo"))
	assert(use("CostaPassagem1") and not use("CostaPassagem1"))
	assert(use("CostaPassagem2") and use("CostaAcessoFurtivo") and p.story.act == 35)
	assert(not p.story.flags.costa_infiltracao_forca)
end)

test("social exige conhecer contato, recolher entrega e retornar; dados são pessoais", function()
	local rt, player, p, story, service, use = setup(33)
	local other = rt:player(2, position)
	assert(not use("CostaFavor") and not story.Choose(player, "costa_infiltracao", "social"))
	assert(use("CostaContato") and use("CostaFavor") and not use("CostaFavor"))
	assert(not story.Choose(player, "costa_infiltracao", "social"))
	assert(use("CostaContato") and p.story.flags.costa_acesso_social)
	assert(not rt.profiles[other].story.flags.costa_acesso_social)
	assert(story.Choose(player, "costa_infiltracao", "social"))
	assert(not use("CostaAcessoForca") and use("CostaAcessoSocial") and p.story.act == 35)
	local cfg = rt:load("src/shared/Modules/CostaDouradaConfig")
	assert(cfg.Style(p.story.flags):find("ajudando"))
end)

test("reconexão conserva passagens e caminho sem liberar outra solução", function()
	local rt, player, p, story, service, use = setup(33)
	story.Choose(player, "costa_infiltracao", "furtividade"); assert(use("CostaPassagem1"))
	local rt2, player2, p2, story2, service2, use2 = setup(34); rt2.profiles[player2] = p
	assert(not story2.Choose(player2, "costa_infiltracao", "forca") and not use2("CostaPassagem1"))
	assert(use2("CostaPassagem2") and use2("CostaAcessoFurtivo") and p.story.act == 35)
end)

test("registros distintos levam a C-8; reconhecimento exige mostrar identificação", function()
	local rt, player, p, story, service, use = setup(35)
	assert(use("CostaRegistro1") and not use("CostaRegistro1"))
	assert(use("CostaRegistro2") and p.story.act == 36)
	assert(not use("CostaHumanoider") and not p.story.flags.costa_c8_reconhecido)
	assert(use("CostaC8") and use("CostaHumanoider") and p.story.act == 37)
	assert(p.story.flags.costa_c8_reconhecido and rt.messages[#rt.messages].data.text:find("Carlos"))
end)

test("boss por contribuição e todos os Ecos levam à Fortaleza Maré sem mudar final", function()
	for _, option in { "destruir", "faccao", "monitorar" } do
		local rt, player, p, story = setup(37); rt.participants = { player }
		rt.mocks.HealthService.FighterDied.Event:Fire({ bot = true, GetAttribute = function() return "fx_costa_boss" end }, player)
		assert(p.story.act == 38 and not p.story.flags.fortaleza_mare_unlocked)
		assert(story.Choose(player, "eco_ilha5", option) and p.story.act == 39 and p.story.flags.fortaleza_mare_unlocked)
		local cfg = rt:load("src/shared/Modules/CostaDouradaConfig")
		assert(cfg.Market(p.story.flags) ~= "" and not story.Choose(player, "eco_ilha5", option))
	end
end)

test("acesso recusa distância, morte, região, rota fechada e mapa indisponível", function()
	local rt, player, p, story, service, use, root, config = setup(31)
	root.Position = Vector3.zero; assert(not use("CostaLote1"))
	assert(not service.Interact(player, { Name = "CostaLote1", Position = Vector3.zero }))
	root.Position = position; rt.flags.dead = true; assert(not use("CostaLote1"))
	rt.flags.dead = false; p.story.flags.costa_dourada_unlocked = nil; assert(not use("CostaLote1"))
	p.story.flags.costa_dourada_unlocked = true; config.Regions.costa_dourada.Available = false
	assert(not use("CostaLote1") and not p.story.counters.fx_costa_mercado)
end)
test("registro da Costa exige chão nos guardas e não duplica região/prompts/bots", function()
	local rt = Runtime.new()
	local w = rt:load("src/shared/Modules/WorldConfig")
	local c = rt:load("src/shared/Modules/CostaDouradaConfig")
	local floor = { IsDescendantOf = function() return true end }
	local grounded = false
	function rt.services.Workspace:Raycast(origin)
		if origin.X == position.X + 20 and not grounded then return nil end
		return { Instance = floor, Normal = Vector3.yAxis }
	end
	local spawned, removed = 0, 0
	rt.mocks.WorldService = { Refresh = function() end }
	local bots = {}
	rt.mocks.BotService = { Spawn = function(options)
		assert(options.HomeMap); spawned += 1
		table.insert(bots, { GetAttribute = function() return options.Attributes.StoryKillKind end })
	end, List = function() return bots end, Remove = function() removed += 1 end }
	local service = rt:load("src/server/Services/CostaDouradaService")
	local parts, connected = {}, true
	local map = { Name = c.Map, AncestryChanged = Runtime.Signal(), IsDescendantOf = function() return connected end,
		GetAttribute = function() return 100 end, FindFirstChild = function(_, name) return parts[name] end }
	local names = table.clone(c.SpecialMarkers)
	for name in c.Interactions do table.insert(names, name) end
	for _, name in { "CostaCentro", "CostaSpawn", "CostaBossSpawn" } do table.insert(names, name) end
	local CFrame = require("@lune/roblox").CFrame
	for _, name in names do
		local pos = if name == "CostaGuardPad1" then position + Vector3.new(20, 0, 0) else position
		parts[name] = { Name = name, Position = pos, Orientation = Vector3.zero, CFrame = CFrame.new(pos), Anchored = true,
			IsA = function(_, class) return class == "BasePart" end }
	end
	assert(not service.BindMap(map) and not w.Regions.costa_dourada.Available and spawned == 0)
	grounded = true
	assert(service.BindMap(map) and w.Regions.costa_dourada.Available and spawned == 4)
	local instances = #rt.instances
	assert(not service.BindMap(map) and spawned == 4 and #rt.instances == instances)
	connected = false; map.AncestryChanged:Fire()
	assert(not w.Regions.costa_dourada.Available and not w.CFrameOf(c.Region, "chegada") and removed == 4)
end)

print(("%d testes de Costa Dourada passaram"):format(count))
