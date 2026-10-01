local Runtime = require("./runtime")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local count = 0
local function test(name, fn) fn(); count += 1; print("OK " .. name) end
local porto = Vector3.new(150, 2, -40)
local camara = Vector3.new(884, 1, -575)
local function setup()
	local rt = Runtime.new(); local player, root = rt:player(1, porto)
	local profile = rt.profiles[player]
	local story = rt:loadStory(); story.Init(); story.Start()
	local progression = rt:load("src/server/Services/ProgressionService"); progression.Init()
	local service = rt:load("src/server/Services/SidequestService")
	return rt, player, profile, service, root
end

test("investigações trancadas ou id desconhecido não concedem progresso/recompensa", function()
	local rt, player, profile, side = setup()
	assert(not side.Inspect(player, "arquivos_capela", { Position = porto }))
	assert(not side.Inspect(player, "inventada", { Position = porto }))
	assert(side.Deliver(player, { Position = porto }) == 0)
	assert(profile.xp == 0 and profile.coins == 0)
end)

test("arquivos exigem resultado do Eco e só pagam após investigação e entrega", function()
	local rt, player, profile, side = setup()
	profile.story.flags.eco_ilha1_prisioneiros = true
	assert(not side.Inspect(player, "arquivos_capela", { Position = porto }))
	profile.story.flags.eco_ilha1_arquivos = true -- terceira solução também preserva estes dados
	assert(side.Deliver(player, { Position = porto }) == 0)
	assert(side.Inspect(player, "arquivos_capela", { Position = porto }))
	assert(not side.Inspect(player, "arquivos_capela", { Position = porto }))
	assert(side.Deliver(player, { Position = porto }) == 1)
	assert(profile.xp == 25 and profile.coins == 3)
	assert(side.Deliver(player, { Position = porto }) == 0)
	assert(profile.xp == 25 and profile.coins == 3 and profile.story.act == 1)
end)

test("anomalia exige transferência; posição, região e vida são autoritativas", function()
	local rt, player, profile, side, root = setup()
	profile.story.flags.eco_ilha2_selou = true
	root.Position = camara
	assert(not side.Inspect(player, "anomalia_deserto", { Position = camara }))
	profile.story.flags.eco_ilha2_transferiu = true
	root.Position = porto
	assert(not side.Inspect(player, "anomalia_deserto", { Position = porto }))
	assert(not side.Inspect(player, "anomalia_deserto", { Position = camara }))
	root.Position = camara; rt.flags.dead = true
	assert(not side.Inspect(player, "anomalia_deserto", { Position = camara }))
	rt.flags.dead = false
	assert(side.Inspect(player, "anomalia_deserto", { Position = camara }))
	assert(side.Deliver(player, { Position = camara }) == 0)
	root.Position = porto
	assert(side.Deliver(player, { Position = porto }) == 1)
	assert(profile.xp == 35 and profile.coins == 4)
end)

test("estado salvo permite entregar na reconexão sem repetir a recompensa", function()
	local rt, player, profile, side = setup()
	profile.story.flags.eco_ilha1_arquivos = true
	assert(side.Inspect(player, "arquivos_capela", { Position = porto }))
	local nextRt, nextPlayer, nextProfile, nextSide = setup()
	nextRt.profiles[nextPlayer] = profile
	assert(nextSide.Deliver(nextPlayer, { Position = porto }) == 1)
	local thirdRt, thirdPlayer, thirdProfile, thirdSide = setup()
	thirdRt.profiles[thirdPlayer] = profile
	assert(thirdSide.Deliver(thirdPlayer, { Position = porto }) == 0)
	assert(profile.xp == 25 and profile.coins == 3)
end)

test("investigações são pessoais e entrega conjunta paga cada uma exatamente uma vez", function()
	local rt, player, profile, side, root = setup()
	local other = rt:player(2, porto)
	profile.story.flags.eco_ilha1_arquivos = true
	profile.story.flags.eco_ilha2_transferiu = true
	assert(side.Inspect(player, "arquivos_capela", { Position = porto }))
	root.Position = camara
	assert(side.Inspect(player, "anomalia_deserto", { Position = camara }))
	root.Position = porto
	assert(side.Deliver(player, { Position = porto }) == 2)
	assert(profile.xp == 60 and profile.coins == 7)
	assert(rt.profiles[other].xp == 0 and rt.profiles[other].coins == 0)
end)

test("resumo dos Ecos e HUD opcionais não alteram final nem revelam Carlos", function()
	local rt, player, profile, side = setup()
	local config = rt:load("src/shared/Modules/SidequestConfig")
	local summary = config.EchoSummary({ eco_m3_deixou = true, eco_ilha1_prisioneiros = true, eco_ilha1_arquivos = true })
	assert(summary:find("Só quem") and summary:find("parte dos arquivos") and not summary:find("Carlos"))
	assert(#config.State(profile.story.flags) == 0)
	profile.story.flags.eco_ilha1_arquivos = true
	assert(#config.State(profile.story.flags) == 1 and not config.State(profile.story.flags)[1].ready)
	side.Inspect(player, "arquivos_capela", { Position = porto })
	assert(config.State(profile.story.flags)[1].ready)
	side.Deliver(player, { Position = porto })
	assert(#config.State(profile.story.flags) == 0 and profile.story.act == 1)
end)

test("cliente aplica desaparecimento pessoal e prompts sem tocar modelos não marcados", function()
	local rt, player, profile = setup()
	local part = { LocalTransparencyModifier = 0, IsA = function(_, cls) return cls == "BasePart" end }
	local humanoid = {}
	local npc = {
		IsA = function(_, cls) return cls == "Model" end,
		GetAttribute = function() return "ferido" end,
		GetDescendants = function() return { part } end,
		FindFirstChildOfClass = function() return humanoid end,
	}
	local prompt = {
		IsA = function(_, cls) return cls == "ProximityPrompt" end,
		GetAttribute = function() return "arquivos_capela" end,
	}
	local unmarked = { IsA = function(_, cls) return cls == "Model" end, GetAttribute = function() return nil end }
	local sahur = { GetDescendants = function() return { npc, prompt, unmarked } end }
	rt.services.Workspace.FindFirstChild = function() return sahur end
	rt.services.Workspace.DescendantAdded = Runtime.Signal()
	local eco = rt:load("src/client/Controllers/EcoController"); eco.Start()
	local signal = rt.mocks.RemoteEvents.GetEvent("NotifyProfile").OnClientEvent
	signal:Fire(profile)
	assert(part.LocalTransparencyModifier == 0 and not prompt.Enabled)
	profile.story.flags.eco_m3_deixou = true; profile.story.flags.eco_ilha1_arquivos = true
	signal:Fire(profile)
	assert(part.LocalTransparencyModifier == 1 and prompt.Enabled)
	assert(humanoid.DisplayDistanceType == roblox.Enum.HumanoidDisplayDistanceType.None)
	profile.story.flags.side_arquivos_capela_inspected = true
	signal:Fire(profile)
	assert(not prompt.Enabled)
end)

print(("%d testes de sidequests passaram"):format(count))
