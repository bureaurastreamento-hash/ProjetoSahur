local Runtime = require("./runtime")
local Vector3 = require("@lune/roblox").Vector3
local count = 0
local function test(name, fn) fn(); count += 1; print("OK " .. name) end
local position = Vector3.new(4400, 2, 0)
local function setup(id)
	local rt = Runtime.new(); local player, root = rt:player(1, position)
	local cfg = rt:load("src/shared/Modules/StoryConfig")
	local function index(key) for i, act in cfg.Chapters[1].Acts do if act.Id == key then return i end end error(key) end
	local p = rt.profiles[player]; p.story.act = index(id or "rumo_fortaleza_mare")
	local story = rt:load("src/server/Services/StoryService"); story.Init(); story.Start()
	local world = rt:load("src/shared/Modules/WorldConfig"); world.Regions.fortaleza_mare.Available = true
	table.insert(world.Islands, { Id = "mare", Region = "fortaleza_mare", Center = position, RadiusX = 100, RadiusZ = 100 })
	p.story.flags.fortaleza_mare_unlocked = true
	local avatar = { bot = true, GetAttribute = function() return "fx_mare_avatar" end }
	rt.mocks.WorldService = {}
	rt.mocks.BotService = { List = function() return { avatar } end }
	rt.mocks.HealthService.IsAlive = function() return not rt.flags.avatarDead end
	local service = rt:load("src/server/Services/FortalezaMareService")
	local function use(name) return service.Interact(player, { Name = name, Position = position }) end
	return rt, player, p, story, service, use, root, world, index, avatar
end

test("migração rev6 preserva 39 atos e limita perfil além do fim à chegada", function()
	for i = 1, 40 do
		local rt = Runtime.new(); local player = rt:player(1)
		local p = rt.profiles[player]; p.story.rev, p.story.act = 6, i
		p.story.counters.keep = 4; p.inventory.flecha = 3; p.story.flags.keep = true
		local story = rt:load("src/server/Services/StoryService"); story.Init(); story.Start()
		assert(p.story.rev == 7 and p.story.act == math.min(i, 39))
		assert(i == 40 or p.story.counters.keep == 4)
		assert(p.inventory.flecha == 3 and p.story.flags.keep)
	end
end)

test("chegada e prisão precedem escolha; ambas as alas podem abrir sem alterar ato depois", function()
	for _, first in { "civil", "risco" } do
		local rt, player, p, story, service, use, root, world, index = setup()
		assert(not use("MarePrisao")); story.ArriveRegion(player, "fortaleza_mare")
		assert(use("MarePrisao") and p.story.act == index("escolha_quem_sai"))
		assert(not use("MareAlaCivil")); assert(story.Choose(player, "eco_m27", first))
		local selected = if first == "civil" then "MareAlaCivil" else "MareAlaRisco"
		local second = if first == "civil" then "MareAlaRisco" else "MareAlaCivil"
		assert(not use(second) and use(selected) and p.story.act == index("destino"))
		assert(use(second) and not use(second) and p.story.act == index("destino"))
		assert(p.story.flags.mare_ala_civil_aberta and p.story.flags.mare_ala_risco_aberta and p.story.flags.mare_informacao_critica)
		assert(p.story.flags["mare_ala_" .. (if first == "civil" then "risco" else "civil") .. "_tardia"])
	end
end)

test("repetições distintas e último Rastro não revelam autor ou causa das falhas", function()
	local rt, player, p, story, service, use, root, world, index = setup("destino")
	assert(use("MareLoop1") and not use("MareLoop1"))
	assert(use("MareLoop2") and p.story.act == index("ultimo_rastro"))
	assert(use("MareRastro") and p.story.traces.carlos_mare01 and p.story.act == index("colapso"))
	local text = rt.messages[#rt.messages].data.text
	assert(text:find("Não confiem no padrão") and text:find("Carlos sabia"))
	assert(not text:find("Adryan") and not text:find("traidor"))
end)

test("colapso exige fragmentos, chefes PvE e pedido de ajuda; Toduro antecede Adryan", function()
	local rt, player, p, story, service, use, root, world, index = setup("colapso")
	assert(use("MareFragmento1") and use("MareFragmento2") and use("MareComunicador"))
	assert(p.story.act == index("colapso") and not use("MareToduro"))
	rt.participants = { player }
	local function kill(index)
		local victim = { bot = true, GetAttribute = function(_, name) return if name == "StoryObjectiveKey" then "mare_colapso_" .. index else "fx_mare_colapso_boss" end }
		rt.mocks.HealthService.FighterDied.Event:Fire(victim, player)
	end
	kill(1); kill(1)
	assert(p.story.act == index("colapso") and p.story.counters.fx_mare_colapso_boss == 1)
	kill(2)
	assert(p.story.act == index("toduro_avalia") and not use("MareAdryan"))
	assert(use("MareToduro") and use("MareAdryan"))
	assert(story.Choose(player, "adryan_resposta", "cautela") and p.story.act == index("fratura_principal"))
	assert(use("MareFratura") and p.story.act == index("avatar_fratura"))
end)

test("âncoras exigem participação com Avatar vivo e não repetem; matar cedo não conclui", function()
	local rt, player, p, story, service, use, root, world, index, avatar = setup("avatar_fratura")
	assert(not use("MareAncora1"))
	rt.participants = { player }
	assert(use("MareAncora1") and not use("MareAncora1"))
	rt.mocks.HealthService.FighterDied.Event:Fire(avatar, player)
	assert(p.story.act == index("avatar_fratura") and not p.story.counters.fx_mare_avatar)
	rt.flags.avatarDead = true; assert(not use("MareAncora2"))
	rt.flags.avatarDead = false
	assert(use("MareAncora2") and use("MareAncora3"))
	rt.mocks.HealthService.FighterDied.Event:Fire(avatar, player)
	assert(p.story.act == index("metodo_final") and not p.story.flags.cap1_completed)
end)

test("dispositivo alternativo exige três Rastros pessoais, não apenas avançar ato", function()
	local rt, player, p, story, service, use = setup("metodo_final")
	assert(not use("MarePrepararDispositivo") and not story.Choose(player, "eco_final_cap1", "alternativo"))
	p.story.traces.carlos_mare01, p.story.traces.carlos_era01 = true, true
	assert(not use("MarePrepararDispositivo")); p.story.traces.carlos_eclipse01 = true
	assert(use("MarePrepararDispositivo") and not use("MarePrepararDispositivo"))
	assert(story.Choose(player, "eco_final_cap1", "alternativo"))
end)

test("três métodos exigem suas próprias ações e estabilizam a mesma passagem", function()
	for _, method in { "humanoider", "toduro", "alternativo" } do
		local rt, player, p, story, service, use, root, world, index = setup("metodo_final")
		if method == "alternativo" then
			p.story.traces.carlos_era01, p.story.traces.carlos_eclipse01, p.story.traces.carlos_mare01 = true, true, true
			assert(use("MarePrepararDispositivo"))
		end
		assert(story.Choose(player, "eco_final_cap1", method) and not use("MareEstabilizar"))
		if method == "humanoider" then
			assert(not use("MareInterno1") and use("MareSeguro1") and not use("MareSeguro1")); assert(not use("MareEstabilizar")); assert(use("MareSeguro2"))
		elseif method == "toduro" then
			assert(not use("MareSeguro1"))
			for i = 1, 3 do assert(use("MareInterno" .. i)) end
		else
			assert(not use("MareSeguro1") and use("MareAtivarDispositivo") and p.story.flags.fx_assinatura_protagonista)
		end
		assert(use("MareEstabilizar") and p.story.flags.cap1_passagem_estabilizada and p.story.act == index("encerramento_cap1"))
		assert(not p.story.flags.cap1_completed and not p.story.flags.cap2_unlocked)
		assert(use("MareEncerramento") and use("MareTerminal"))
		assert(p.story.flags.cap1_completed and p.story.flags.cap2_unlocked and p.story.act == index("cap2_aguarda"))
		assert(not use("MareTerminal") and p.story.chapter == "cap1")
	end
end)

test("reconexão mantém método e ações vistas sem liberar outro método", function()
	local rt, player, p, story, service, use = setup("metodo_final")
	story.Choose(player, "eco_final_cap1", "humanoider"); assert(use("MareSeguro1"))
	local rt2, player2, p2, story2, service2, use2 = setup("estabilizacao_final"); rt2.profiles[player2] = p
	assert(not use2("MareSeguro1") and not use2("MareInterno1"))
	assert(use2("MareSeguro2") and use2("MareEstabilizar") and p.story.flags.cap1_passagem_estabilizada)
end)

test("interações recusam distância, morte, região, rota fechada e mapa indisponível", function()
	local rt, player, p, story, service, use, root, world = setup("prisioneiro")
	root.Position = Vector3.zero; assert(not use("MarePrisao"))
	assert(not service.Interact(player, { Name = "MarePrisao", Position = Vector3.zero }))
	root.Position = position; rt.flags.dead = true; assert(not use("MarePrisao"))
	rt.flags.dead = false; p.story.flags.fortaleza_mare_unlocked = nil; assert(not use("MarePrisao"))
	p.story.flags.fortaleza_mare_unlocked = true; world.Regions.fortaleza_mare.Available = false
	assert(not use("MarePrisao"))
end)
test("mapa incompleto não ativa Fortaleza; mapa válido gera três bots uma vez e limpa ao sair", function()
	local rt = Runtime.new()
	local w = rt:load("src/shared/Modules/WorldConfig")
	local cfg = rt:load("src/shared/Modules/FortalezaMareConfig")
	local floor = { IsDescendantOf = function() return true end }
	function rt.services.Workspace:Raycast() return { Instance = floor, Normal = Vector3.yAxis } end
	local spawned, removed, bots = 0, 0, {}
	rt.mocks.WorldService = { Refresh = function() end }
	rt.mocks.BotService = { Spawn = function(opts)
		assert(opts.HomeMap); spawned += 1
		table.insert(bots, { GetAttribute = function() return opts.Attributes.StoryKillKind end })
	end, List = function() return bots end, Remove = function() removed += 1 end }
	local service = rt:load("src/server/Services/FortalezaMareService")
	local parts, connected = {}, true
	local map = { Name = cfg.Map, AncestryChanged = Runtime.Signal(), IsDescendantOf = function() return connected end,
		GetAttribute = function() return 100 end, FindFirstChild = function(_, name) return parts[name] end }
	assert(not service.BindMap(map) and not w.Regions.fortaleza_mare.Available)
	local names = table.clone(cfg.SpecialMarkers)
	for name in cfg.Interactions do table.insert(names, name) end
	for _, name in { "MareCentro", "MareSpawn", "MareBossSpawn" } do table.insert(names, name) end
	local CFrame = require("@lune/roblox").CFrame
	for _, name in names do
		parts[name] = { Name = name, Position = position, Orientation = Vector3.zero, CFrame = CFrame.new(position), Anchored = true,
			IsA = function(_, class) return class == "BasePart" end }
	end
	assert(service.BindMap(map) and spawned == 3 and w.Regions.fortaleza_mare.Available)
	assert(not service.BindMap(map) and spawned == 3)
	connected = false; map.AncestryChanged:Fire()
	assert(not w.Regions.fortaleza_mare.Available and not w.CFrameOf(cfg.Region, "chegada") and removed == 3)
end)

print(("%d testes de Fortaleza Maré passaram"):format(count))
