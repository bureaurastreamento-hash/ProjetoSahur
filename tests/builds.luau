local Runtime = require("./runtime")
local count = 0
local function test(name, fn) fn(); count += 1; print("OK " .. name) end
local function campaign(act)
	local rt = Runtime.new()
	local player = rt:player(1)
	rt.profiles[player].story.act = act or 3
	local story = rt:load("src/server/Services/StoryService")
	story.Init(); story.Start()
	return rt, player, rt.profiles[player], story
end

test("rota exige visita à Taberna; opção inválida e repetida não concedem itens", function()
	local rt, player, profile, story = campaign()
	assert(not story.Choose(player, "rota_inicial", "manifestacao"))
	assert(story.Progress(player, "reach_taberna", 1))
	assert(profile.story.act == 3)
	assert(not story.Choose(player, "rota_inicial", "inventada"))
	assert(story.Choose(player, "rota_inicial", "manifestacao"))
	assert(profile.story.act == 4 and profile.inventory.flecha == 1)
	assert(not story.Choose(player, "rota_inicial", "manifestacao"))
	assert(profile.inventory.flecha == 1 and profile.build.route == "manifestacao")
end)

test("as três rotas respeitam a distribuição da Flecha e build ao final da Ilha 1", function()
	for _, route in { "tecnica", "arma", "manifestacao" } do
		local rt, player, profile, story = campaign()
		story.Progress(player, "reach_taberna", 1)
		assert(story.Choose(player, "rota_inicial", route))
		assert((profile.inventory.flecha or 0) == (if route == "manifestacao" then 1 else 0))
		profile.story.act = 10
		assert(story.Choose(player, "eco_ilha1", "prisioneiros"))
		assert(profile.inventory.flecha == 1)
		assert(profile.build.weapon ~= "" or profile.build.style ~= "")
		assert(profile.story.flags.ilha_pilares_unlocked)
	end
end)

test("perfil antigo escolhe sem voltar missão ou ganhar segunda Flecha", function()
	local rt, player, profile, story = campaign(15)
	profile.story.completed.eco_capela = true
	profile.inventory.flecha = 1
	assert(story.Choose(player, "rota_inicial", "manifestacao"))
	assert(profile.story.act == 15 and profile.inventory.flecha == 1)
	assert(profile.build.style == "tecnica_corporal")
	assert(not story.Choose(player, "rota_inicial", "arma"))
end)

test("Missão 8 exige mestre e parries; aprendizado evolui somente a rota Técnica", function()
	for _, route in { "tecnica", "arma", "manifestacao" } do
		local rt, player, profile, story = campaign(13)
		local build = rt:load("src/server/Services/BuildService")
		assert(build.SelectRoute(player, route))
		assert(not story.Choose(player, "tecnica_m8", "aprender"))
		story.Progress(player, "fx_mestre", 1)
		story.Progress(player, "parries", 2)
		assert(profile.story.act == 13)
		assert(story.Choose(player, "tecnica_m8", "aprender"))
		assert(profile.story.act == 14)
		assert(profile.build.techniqueTier == (if route == "tecnica" then 2 else 1))
		assert(profile.story.flags.tecnica_m8_aprendeu)
	end
end)

test("recusar Técnica continua campanha; aprender depois preserva a maestria", function()
	local rt, player, profile, story = campaign(13)
	story.Progress(player, "fx_mestre", 1); story.Progress(player, "parries", 2)
	assert(story.Choose(player, "tecnica_m8", "recusar"))
	assert(profile.story.act == 14 and profile.build.techniqueTier == 0)
	profile.mastery["style:tecnica_corporal"] = 50
	local build = rt:load("src/server/Services/BuildService")
	build.LearnTechnique(player)
	assert(profile.build.techniqueTier == 1 and profile.mastery["style:tecnica_corporal"] == 50)
end)

test("atributos do cliente não ativam bônus; maestrias de estilo e Stand ficam separadas", function()
	local rt, player, profile = campaign()
	local build = rt:load("src/server/Services/BuildService")
	player:SetAttribute("EquippedWeapon", "espada_inicial")
	player:SetAttribute("TechniqueTier", 2)
	assert(build.M1Multiplier(player) == 1 and build.IncomingMultiplier(player) == 1)
	build.SelectRoute(player, "tecnica")
	assert(build.M1Multiplier(player) == 1.1 and build.IncomingMultiplier(player) == 0.95)
	profile.mastery.Swift = 45
	build.OnM1Hit(player)
	assert(profile.mastery["style:tecnica_corporal"] == 1 and profile.mastery.Swift == 45)
	build.LearnTechnique(player)
	assert(build.M1Multiplier(player) == 1.2 and build.IncomingMultiplier(player) == 0.9)
end)

test("Tool real do serviço concede bônus só equipado; equipar em combate é recusado", function()
	local rt, player, profile = campaign()
	player.backpack = {}
	local build = rt:load("src/server/Services/BuildService")
	assert(build.SelectRoute(player, "arma"))
	local tool = rt.instances[1]
	assert(tool.ClassName == "Tool" and tool.Parent == player.backpack and not tool.CanBeDropped)
	assert(build.M1Multiplier(player) == 1)
	tool.Parent = player.Character; rt.flags.blocked = true; tool.Equipped:Fire()
	assert(tool.Parent == player.backpack and build.M1Multiplier(player) == 1)
	rt.flags.blocked = false; tool.Parent = player.Character; tool.Equipped:Fire()
	assert(build.M1Multiplier(player) == 1.15)
	build.OnM1Hit(player)
	assert(profile.mastery["weapon:espada_inicial"] == 1 and not profile.mastery["style:tecnica_corporal"])
	tool.Parent = player.backpack; tool.Unequipped:Fire()
	assert(build.M1Multiplier(player) == 1 and not player:GetAttribute("EquippedWeapon"))
end)

test("arma retorna após respawn sem duplicar concessão ou perder maestria", function()
	local rt, player, profile = campaign()
	player.backpack = {}
	local build = rt:load("src/server/Services/BuildService")
	build.SelectRoute(player, "arma"); build.Start()
	assert(#rt.instances == 2)
	profile.mastery["weapon:espada_inicial"] = 30
	rt.instances[1].Parent = nil
	player.CharacterAdded:Fire()
	assert(#rt.instances == 4 and rt.instances[3].Parent == player.backpack)
	assert(profile.mastery["weapon:espada_inicial"] == 30)
end)

print(("%d testes de builds passaram"):format(count))
