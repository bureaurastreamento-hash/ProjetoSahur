local Runtime = require("./runtime")
local Vector3 = require("@lune/roblox").Vector3
local count = 0
local function test(name, fn) fn(); count += 1; print("OK " .. name) end
local function setup()
	local rt = Runtime.new()
	local killer, root = rt:player(1)
	local victim = rt:player(2)
	rt.profiles[killer].faction, rt.profiles[victim].faction = "fora_da_lei", "fora_da_lei"
	local bounty = rt:load("src/server/Services/BountyService")
	local pvp = rt:load("src/server/Services/PvpService")
	bounty.Start()
	return rt, killer, victim, bounty, pvp, root
end

test("vitória autoritativa acumula e replica bounty; duplicação não paga", function()
	local rt, a, b, _, pvp = setup()
	rt.mocks.HealthService.Died.Event:Fire(b, a, pvp.OnDeath(b, a), pvp.OpenWorldKill(b, a))
	assert(rt.profiles[a].bounty.points == 5000 and a:GetAttribute("Bounty") == 5000)
	assert(a:GetAttribute("BountyTitle") == "Sem título")
	rt.mocks.HealthService.Died.Event:Fire(b, a, true, true)
	assert(rt.profiles[a].bounty.points == 5000 and #rt.messages == 1)
end)

test("níveis próximos nos dois sentidos usam perfil e ignoram atributo falsificado", function()
	for _, high in { "killer", "victim" } do
		local rt, a, b, bounty = setup()
		rt.profiles[if high == "killer" then a else b].level = 12
		a:SetAttribute("Level", 1); b:SetAttribute("Level", 1)
		assert(not bounty.OnDeath(b, a, true, true))
		rt.profiles[if high == "killer" then a else b].level = 11
		assert(bounty.OnDeath(b, a, true, true))
	end
end)

test("sem crédito/contexto, suicídio, PvE e perfil ausente não pontuam", function()
	local rt, a, b, bounty = setup()
	assert(not bounty.OnDeath(b, nil, true, true))
	assert(not bounty.OnDeath(a, a, true, true))
	assert(not bounty.OnDeath(b, a, false, true))
	assert(not bounty.OnDeath(b, a, true, false))
	assert(not bounty.OnDeath(b, a, true))
	rt.profiles[b] = nil
	assert(not bounty.OnDeath(b, a, true, true))
	assert(rt.profiles[a].bounty.points == 0)
end)

test("arena/torneio e zona segura capturam contexto antes da limpeza", function()
	local rt, a, b, bounty, pvp, root = setup()
	for _, player in { a, b } do
		for _, attr in { "InMatch", "Tournament", "DuelId", "WarId" } do
			player:SetAttribute(attr, true)
			local before = pvp.OpenWorldKill(b, a)
			player:SetAttribute(attr, nil)
			assert(not before and not bounty.OnDeath(b, a, true, before))
		end
	end
	root.Position = Vector3.new(40, 2, 185)
	assert(not pvp.OpenWorldKill(b, a))
end)

test("cooldown salvo impede recompensa depois de reconectar; expiração libera", function()
	local rt, a, b, bounty = setup()
	assert(bounty.OnDeath(b, a, true, true))
	local saved = rt:load("src/shared/Modules/BountyConfig").Normalize(rt.profiles[a].bounty, os.time())
	local rt2, a2, b2, bounty2 = setup()
	rt2.profiles[a2].bounty = saved
	assert(not bounty2.OnDeath(b2, a2, true, true))
	saved.recentVictims["2"] = os.time() - 301
	assert(bounty2.OnDeath(b2, a2, true, true))
	assert(rt2.profiles[a2].bounty.points == 10000)
end)

test("migração normaliza perfil ausente, NaN, infinito e timestamps inválidos", function()
	local rt = Runtime.new(); local c = rt:load("src/shared/Modules/BountyConfig")
	assert(c.Normalize(nil, 1000).points == 0)
	for _, points in { 0/0, math.huge, -math.huge, -2 } do assert(c.Normalize({ points = points }, 1000).points == 0) end
	local state = c.Normalize({ points = 1e12, recentVictims = { ["2"] = 999, ["3"] = 699, ["4"] = math.huge, x = 999, ["5"] = 999.5 } }, 1000)
	assert(state.points == c.MaxPoints and state.recentVictims["2"] == 999)
	assert(not state.recentVictims["3"] and not state.recentVictims["4"] and not state.recentVictims.x and not state.recentVictims["5"])
end)

test("limites dos cinco títulos seguem os documentos", function()
	local rt = Runtime.new(); local c = rt:load("src/shared/Modules/BountyConfig")
	local previous = "Sem título"
	for _, tier in c.Tiers do
		assert(c.Title(tier.Points - 1) == previous)
		assert(c.Title(tier.Points) == tier.Title)
		previous = tier.Title
	end
end)

test("bônus de alvo procurado é único; bounty do derrotado não sofre perda inventada", function()
	local rt, a, b, bounty = setup()
	rt.profiles[b].bounty.points = 5000000
	assert(bounty.OnDeath(b, a, true, true))
	assert(rt.profiles[a].coins == 20 and rt.profiles[b].bounty.points == 5000000)
	assert(not bounty.OnDeath(b, a, true, true) and rt.profiles[a].coins == 20)
end)

test("atributo falso não dá bônus; teto e lista cheia não abrem brecha", function()
	local rt, a, b, bounty = setup()
	b:SetAttribute("Bounty", 5000000)
	local c = rt:load("src/shared/Modules/BountyConfig")
	rt.profiles[a].bounty.points = c.MaxPoints - 1
	assert(bounty.OnDeath(b, a, true, true))
	assert(rt.profiles[a].bounty.points == c.MaxPoints and rt.profiles[a].coins == 0)
	local rt2, a2, b2, bounty2 = setup()
	for i = 100, 355 do rt2.profiles[a2].bounty.recentVictims[tostring(i)] = os.time() end
	assert(not bounty2.OnDeath(b2, a2, true, true))
	assert(rt2.profiles[a2].bounty.recentVictims["100"])
end)

test("perfil carregado reflete título; perfil desconectado não recebe vitória", function()
	local rt, a, b, bounty = setup()
	rt.profiles[a].bounty.points = 10000000
	rt.mocks.DataService.ProfileLoaded.Event:Fire(a, rt.profiles[a])
	assert(a:GetAttribute("BountyTitle") == "Anomalia")
	a.Parent = nil
	assert(not bounty.OnDeath(b, a, true, true))
end)

print(("%d testes de bounty passaram"):format(count))
