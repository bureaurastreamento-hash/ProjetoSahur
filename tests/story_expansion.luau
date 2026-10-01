local Runtime = require("./runtime")
local Vector3 = require("@lune/roblox").Vector3
local count = 0
local function test(name, fn) fn(); count += 1; print("OK " .. name) end
local chamberPosition = Vector3.new(884, 1, -1675)
local eclipsePosition = Vector3.new(2026, 4, -1530)
local function setup(act, position)
	local rt = Runtime.new(); local player, root = rt:player(1, position)
	local profile = rt.profiles[player]; profile.story.act = act or 1
	profile.level = 50 -- teste da sequência; o bloqueio por nível tem teste próprio
	player:SetAttribute("Level", 50)
	local story = rt:loadStory(); story.Init(); story.Start()
	return rt, player, profile, story, root
end

test("todos os atos rev3 mantêm identidade e contadores após inserir Eco e Viajante", function()
	local oldActs = { "acorde", "chegada", "porto_da_nevoa", "primeiros_golpes", "fenda_instavel", "eco_sobreviventes", "a_mascara", "rastro_carlos_01", "herdeiro_da_nevoa", "eco_capela", "calor", "homens_de_pedra", "respira", "a_camara", "sol_negro", "rota_do_eclipse", "cacados", "homem_que_nao_existe", "eclipse", "rumo_cidade_ambar" }
	for index, id in oldActs do
		local rt = Runtime.new(); local player = rt:player(1)
		local profile = rt.profiles[player]
		profile.story.rev, profile.story.act = 3, index
		profile.story.counters.saved = 2; profile.story.flags.ilha_sol_partido_unlocked = true
		profile.story.traces.carlos_eclipse01 = true; profile.inventory.flecha = 2
		local story = rt:loadStory(); story.Init(); story.Start()
		local config = rt:load("src/shared/Modules/StoryConfig")
		assert(config.Chapters[1].Acts[profile.story.act].Id == id)
		assert(profile.story.rev == 7 and profile.story.counters.saved == 2)
		assert(profile.story.flags.ilha_sol_partido_unlocked and profile.story.traces.carlos_eclipse01)
		assert(profile.inventory.flecha == 2)
	end
end)

test("perfil novo inicia na Missão 0 e rev2 passa pelas duas migrações", function()
	local rt, player, profile, story = setup()
	assert(profile.story.act == 1 and profile.story.rev == 7)
	profile.story.rev, profile.story.act = 2, 12
	rt.mocks.DataService.ProfileLoaded.Event:Fire(player, profile, false)
	assert(profile.story.act == 20 and profile.story.rev == 7)
end)

test("Sacerdote abre Eco; rota do Eclipse só libera depois da escolha", function()
	for _, option in { "selar", "destruir" } do
		local rt, player, profile, story = setup(15, chamberPosition)
		rt.participants = { player }
		local victim = { bot = true, GetAttribute = function() return "fx_solnegro_boss" end }
		rt.mocks.HealthService.FighterDied.Event:Fire(victim, player)
		assert(profile.story.act == 16 and not profile.story.flags.ilha_sol_partido_unlocked)
		assert(not story.Choose(player, "eco_ilha2", "transferir"))
		assert(story.Choose(player, "eco_ilha2", option))
		assert(profile.story.act == 17 and profile.story.flags.ilha_sol_partido_unlocked)
		assert(profile.story.flags["eco_ilha2_" .. option] and profile.story.completed.eco_deserto)
		assert(not story.Choose(player, "eco_ilha2", option))
		assert(profile.story.act == 17)
	end
end)

test("puzzle é pessoal, exige sequência correta e valida posição/vida", function()
	local rt, player, profile, story, root = setup(16, chamberPosition)
	local other = rt:player(2, chamberPosition)
	local marker = { Position = chamberPosition }
	root.Position = Vector3.new(0, 0, 0)
	assert(not story.AlignChamberSeal(player, 2, marker))
	root.Position = chamberPosition; rt.flags.dead = true
	assert(not story.AlignChamberSeal(player, 2, marker))
	rt.flags.dead = false
	assert(not story.AlignChamberSeal(player, 99, marker))
	assert(story.AlignChamberSeal(player, 2, marker))
	assert(not story.AlignChamberSeal(player, 3, marker))
	assert(not profile.story.flags.camara_puzzle_etapa_1)
	for _, seal in { 2, 1, 3 } do assert(story.AlignChamberSeal(player, seal, marker)) end
	assert(profile.story.flags.camara_transferencia_preparada)
	assert(profile.inventory["mat:selo_solar"] == 1)
	assert(story.AlignChamberSeal(player, 3, marker) and profile.inventory["mat:selo_solar"] == 1)
	assert(not rt.profiles[other].story.flags.camara_transferencia_preparada)
	assert(story.Choose(player, "eco_ilha2", "transferir"))
	assert(profile.story.flags.eco_ilha2_transferiu and story.DesertState(player):find("anomalia"))
end)

test("reconexão preserva puzzle e reoferece escolha habilitada", function()
	local rt, player, profile, story = setup(16, chamberPosition)
	profile.build.route = "tecnica"
	profile.story.flags.camara_puzzle_etapa_1 = true
	profile.story.flags.camara_puzzle_etapa_2 = true
	local snapshot = profile
	local nextRt = Runtime.new(); local nextPlayer = nextRt:player(1, chamberPosition)
	nextRt.profiles[nextPlayer] = snapshot
	local nextStory = nextRt:loadStory(); nextStory.Init(); nextStory.Start()
	assert(nextStory.AlignChamberSeal(nextPlayer, 3, { Position = chamberPosition }))
	nextRt.mocks.RemoteEvents.GetEvent("RequestStoryState").OnServerEvent:Fire(nextPlayer)
	local last = nextRt.messages[#nextRt.messages]
	assert(last.event == "choice" and last.data.id == "eco_ilha2")
	assert(last.data.options[3].enabled)
end)

test("Eco faltante em perfil antigo pode ser escolhido sem voltar o ato", function()
	local rt = Runtime.new(); local player = rt:player(1, chamberPosition)
	local profile = rt.profiles[player]
	profile.story.rev, profile.story.act = 3, 19
	profile.story.flags.ilha_sol_partido_unlocked = true
	profile.story.counters.fx_sol_boss = 0
	local story = rt:loadStory(); story.Init(); story.Start()
	assert(profile.story.act == 21)
	story.OfferDesertEco(player)
	assert(rt.messages[#rt.messages].data.id == "eco_ilha2")
	assert(story.Choose(player, "eco_ilha2", "selar"))
	assert(profile.story.act == 21 and profile.story.completed.eco_deserto)
	assert(not story.Choose(player, "eco_ilha2", "destruir"))
end)

test("Viajante não avança campanha de longe, morto ou antes da Missão 13", function()
	local rt, player, profile, story, root = setup(18, eclipsePosition)
	local marker = { Position = eclipsePosition }
	assert(not story.TalkToTraveler(player, marker) and profile.story.act == 18)
	profile.story.act = 19; root.Position = chamberPosition
	assert(not story.TalkToTraveler(player, marker))
	root.Position = eclipsePosition; rt.flags.dead = true
	assert(not story.TalkToTraveler(player, marker))
	rt.flags.dead = false
	assert(story.TalkToTraveler(player, marker))
	assert(profile.story.act == 20 and profile.story.flags.viajante_conhecido)
	assert(profile.story.completed.o_viajante)
	assert(story.TalkToTraveler(player, marker) and profile.story.act == 20)
	for _, message in rt.messages do
		if message.data and message.data.text then assert(not message.data.text:find("Carlos")) end
	end
end)

test("Rastro já descoberto ainda conclui Missão 14 após conversar com Viajante", function()
	local rt, player, profile, story = setup(19, eclipsePosition)
	profile.story.traces.carlos_eclipse01 = true
	story.TalkToTraveler(player, { Position = eclipsePosition })
	assert(not story.DiscoverTrace(player, "carlos_eclipse01"))
	assert(profile.story.act == 21)
	rt.participants = { player }
	rt.mocks.HealthService.FighterDied.Event:Fire({ bot = true, GetAttribute = function() return "fx_sol_boss" end }, player)
	assert(profile.story.act == 22 and profile.story.flags.cidade_ambar_unlocked)
end)

test("save antigo que alinhou a Câmara recupera selo só uma vez", function()
	local rt, player, profile, story = setup(16, chamberPosition)
	profile.story.flags.camara_transferencia_preparada = true
	assert(story.AlignChamberSeal(player, 2, {Position=chamberPosition}))
	assert(profile.inventory["mat:selo_solar"] == 1 and profile.story.flags.relic_camara_rewarded)
	assert(story.AlignChamberSeal(player, 2, {Position=chamberPosition}) and profile.inventory["mat:selo_solar"] == 1)
end)

print(("%d testes de expansão da campanha passaram"):format(count))
