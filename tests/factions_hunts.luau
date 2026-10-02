local Runtime = require("./runtime")
local count = 0
local function test(name, fn) fn(); count += 1; print("OK " .. name) end
local function setup()
	local rt = Runtime.new(); local a = rt:player(1); local b = rt:player(2)
	rt:load("src/shared/Modules/LaunchConfig").PreLaunch = false -- o lobby de pré-lançamento tem teste próprio
	rt:load("src/server/Services/ProgressionService").Init()
	local faction = rt:load("src/server/Services/FactionService"); faction.Init(); faction.Start()
	local bounty = rt:load("src/server/Services/BountyService"); bounty.Start()
	local hunt = rt:load("src/server/Services/HuntService"); hunt.Init(); hunt.Start()
	return rt, a, b, faction, bounty, hunt
end
test("escolha validada, inicial protegida e persistente sem resetar itens ou campanha", function()
	local rt, a, _, faction = setup(); local p = rt.profiles[a]
	p.inventory.flecha = 2; p.story.act = 8; p.bounty.points = 123
	assert(a:GetAttribute("FactionPending") and not faction.Choose(a, "inventada"))
	assert(faction.Choose(a, "governo") and not a:GetAttribute("FactionPending"))
	assert(faction.Choose(a, "fora_da_lei") and p.faction == "fora_da_lei")
	assert(p.inventory.flecha == 2 and p.story.act == 8 and p.bounty.points == 123)
end)
test("perfil salvo ainda exige escolha nesta sessão, load incompleto não aceita escolha", function()
	local rt, a, _, faction = setup()
	rt.profiles[a].faction = "fora_da_lei"
	rt.mocks.DataService.ProfileLoaded.Event:Fire(a, rt.profiles[a], false)
	assert(a:GetAttribute("FactionPending") and a:GetAttribute("Faction") == "fora_da_lei")
	assert(faction.Choose(a, "fora_da_lei") and not a:GetAttribute("FactionPending"))
	rt.profiles[a] = nil; assert(not faction.Choose(a, "governo"))
end)
test("Governo ganha honra contra Fora da Lei; bounty antiga fica preservada", function()
	local rt, a, b, faction, bounty = setup()
	faction.Choose(a, "governo"); faction.Choose(b, "fora_da_lei")
	rt.profiles[a].bounty.points = 123
	assert(bounty.OnDeath(b, a, true, true))
	assert(rt.profiles[a].honor.points == 5000 and rt.profiles[a].bounty.points == 123)
	assert(a:GetAttribute("Honor") == 5000 and not bounty.OnDeath(b, a, true, true))
end)
test("sem facção e Governo contra Governo não recebem reputação", function()
	local _, a, b, faction, bounty = setup()
	assert(not bounty.OnDeath(b, a, true, true))
	faction.Choose(a, "governo"); faction.Choose(b, "governo")
	assert(not bounty.OnDeath(b, a, true, true))
end)
test("lista de contratos recusa próprio jogador, baixo bounty, gap e atributos falsos", function()
	local rt, a, b, faction, _, hunt = setup()
	faction.Choose(a, "governo"); faction.Choose(b, "fora_da_lei")
	b:SetAttribute("Bounty", 10000000)
	assert(not hunt.Accept(a, 2) and #hunt.State(a).targets == 0)
	rt.profiles[b].bounty.points = 50000; rt.profiles[b].level = 12
	assert(not hunt.Accept(a, 2))
	rt.profiles[b].level = 1
	for _, invalid in { math.huge, 0/0, -1, 2.5 } do assert(not hunt.Accept(a, invalid)) end
	rt.flags.dead = true; assert(not hunt.Accept(a, 2)); rt.flags.dead = false
	assert(not hunt.Accept(a, 1) and hunt.Accept(a, 2) and not hunt.Accept(a, 2))
	local row = hunt.State(a).targets[1]
	assert(row.userId == 2 and not row.position and not row.region)
	assert(rt.messages[#rt.messages - 1].player == b and rt.messages[#rt.messages - 1].event == "warning")
end)
test("contrato só paga junto de reputação válida; repetição e contexto errado não pagam", function()
	local rt, a, b, faction, bounty, hunt = setup()
	faction.Choose(a, "governo"); faction.Choose(b, "fora_da_lei"); rt.profiles[b].bounty.points = 50000
	assert(hunt.Accept(a, 2))
	assert(not bounty.OnDeath(b, a, true, false) and rt.profiles[a].coins == 0)
	assert(bounty.OnDeath(b, a, true, true))
	assert(rt.profiles[a].coins == 21 and rt.profiles[a].xp == 80 and rt.profiles[a].honor.points == 5000)
	assert(not hunt.State(a).active and not bounty.OnDeath(b, a, true, true) and not hunt.Accept(a, 2))
end)
test("cancelar, sair e reconectar não deixam contrato recompensável", function()
	local rt, a, b, faction, bounty, hunt = setup()
	faction.Choose(a, "fora_da_lei"); faction.Choose(b, "fora_da_lei"); rt.profiles[b].bounty.points = 50000
	assert(hunt.Accept(a, 2))
	rt.mocks.RemoteEvents.GetEvent("RequestHunt").OnServerEvent:Fire(a, "cancel")
	assert(not hunt.State(a).active)
	assert(bounty.OnDeath(b, a, true, true) and rt.profiles[a].coins == 1)
	local rt2, a2, b2, f2, _, h2 = setup()
	f2.Choose(a2, "governo"); f2.Choose(b2, "fora_da_lei"); rt2.profiles[b2].bounty.points = 50000
	assert(h2.Accept(a2, 2)); rt2.services.Players.PlayerRemoving:Fire(b2)
	assert(not h2.State(a2).active and not h2.OnReward(a2, b2))
end)
test("limite de caçadores por alvo e bloqueio de aceitar durante combate/arena", function()
	local rt, a, b, faction, _, hunt = setup()
	faction.Choose(a, "governo"); faction.Choose(b, "fora_da_lei"); rt.profiles[b].bounty.points = 50000
	a:SetAttribute("DuelId", 1); assert(not hunt.Accept(a, 2)); a:SetAttribute("DuelId", nil)
	a:SetAttribute("PvpCombatUntil", 1e12); assert(not hunt.Accept(a, 2)); a:SetAttribute("PvpCombatUntil", nil)
	assert(hunt.Accept(a, 2))
	for id = 3, 4 do local p = rt:player(id); faction.Choose(p, "governo"); assert(hunt.Accept(p, 2)) end
	local p = rt:player(5); faction.Choose(p, "governo"); assert(not hunt.Accept(p, 2))
end)
test("NPCs não causam dano em bots/chefes; jogadores e dano ambiental permanecem", function()
	local rt = Runtime.new(); local a = rt:player(1)
	local rules = rt:load("src/shared/Modules/NpcCombatRules")
	assert(not rules.CanDamage({ bot = true }, { bot = true }))
	assert(not rules.CanDamage({ BossRig = "boss" }, { bot = true }))
	assert(rules.CanDamage(a, { bot = true }) and rules.CanDamage({ bot = true }, a) and rules.CanDamage(nil, { bot = true }))
	local combat = rt:load("src/server/Services/CombatService")
	assert(combat.ResolveNpcHit({ bot = true }, { bot = true }, 100, {}) == 0)
	local health = rt:load("src/server/Services/HealthService")
	local victim = { GetAttribute = function() return nil end }
	assert(health.IsInvulnerable(victim, { bot = true }))
	a:SetAttribute("FactionPending", true); assert(health.IsInvulnerable(victim, a))
end)
test("aparências genéricas não têm assets da equipe e materiais não escolhem marcadores/janelas", function()
	local rt = Runtime.new()
	local appearance = rt:load("src/shared/Modules/NpcAppearance")
	local a, b = appearance.Description(1), appearance.Description(2)
	assert(a.TorsoColor ~= b.TorsoColor and a.Shirt == 144076358 and a.Pants == 398633812 and a.HairAccessory == "63690008" and b.HairAccessory == "376548738")
	local c = rt:load("src/shared/Modules/EnvironmentConfig")
	local enum = require("@lune/roblox").Enum.Material
	assert(c.Kind("Casa01_Corpo", enum.SmoothPlastic) == "Brick")
	assert(c.Kind("Praia0", enum.SmoothPlastic) == "Sand")
	assert(c.Kind("BossSpawn", enum.SmoothPlastic) == nil and c.Kind("Casa01_Janela", enum.Glass) == nil)
	assert(not c.Roots.Taberna and c.Roots.FXVilaNova)
end)
test("contrato expirado não paga nem consome progresso de reputação adicional", function()
	local rt, a, b, faction, bounty, hunt = setup()
	faction.Choose(a, "governo"); faction.Choose(b, "fora_da_lei"); rt.profiles[b].bounty.points = 50000
	rt:load("src/shared/Modules/HuntConfig").Duration = -1
	assert(hunt.Accept(a, 2))
	assert(bounty.OnDeath(b, a, true, true))
	assert(rt.profiles[a].coins == 1 and rt.profiles[a].xp == 0 and not hunt.State(a).active)
end)
test("metas de forja mostram materiais reais e desaparecem quando arma já é possuída", function()
	local rt, a = setup(); local goals = rt:load("src/shared/Modules/GoalsConfig")
	local p = rt.profiles[a]; p.inventory["mat:nevoa"] = 10
	local rows = goals.Rows(p)
	assert(rows[1].title == "Próximo nível")
	local found = false
	for _, row in rows do if row.title == "Forjar Lâmina da Névoa" then assert(row.text:find("10/15", 1, true)); found = true end end
	assert(found)
	p.build.weapon = "lamina_nevoa"; p.inventory["arma:katana_fratura"] = 1
	for _, row in goals.Rows(p) do assert(row.title ~= "Forjar Lâmina da Névoa" and row.title ~= "Forjar Katana da Fratura") end
end)
test("meta de maestria usa desbloqueio real e título do Governo usa honra", function()
	local rt, a = setup(); local p = rt.profiles[a]
	p.power, p.mastery.Swift, p.faction, p.honor.points = "Swift", 0, "governo", 49999
	local rows = rt:load("src/shared/Modules/GoalsConfig").Rows(p)
	assert(rows[2].title == "Próxima habilidade do Stand" and rows[2].text:find("150 XP", 1, true))
	local found = false
	for _, row in rows do
		if row.title == "Próximo título de honra" then assert(row.text:find("Patrulheiro", 1, true)); found = true end
	end
	assert(found)
end)
test("bloqueio de nível mantém objetivo sem avançar e subida emite aviso", function()
	local rt = Runtime.new(); local a = rt:player(1); local p = rt.profiles[a]
	p.story.act = 7
	local story = rt:loadStory(); story.Init(); story.Start()
	rt.mocks.DataService.ProfileLoaded.Event:Fire(a, p, false)
	local config = rt:load("src/shared/Modules/StoryConfig").Chapters[1].Acts[7]
	assert(config.MinLevel == 5)
	local objective = config.Objectives[1].Kind
	assert(not story.Progress(a, objective, 1) and p.story.act == 7)
	p.level = 5; a:SetAttribute("Level", 5)
	local ready = false
	for _, message in rt.messages do if message.data and message.data.title == "Você está pronto" then ready = true end end
	assert(ready and story.Progress(a, objective, 1))
end)
test("escolha enviada antes do load é aplicada uma única vez ao carregar", function()
 local rt,a,_,faction=setup()
 local profile=rt.profiles[a];rt.profiles[a]=nil
 rt.mocks.RemoteEvents.GetEvent("RequestFaction").OnServerEvent:Fire(a,"governo")
 assert(profile.faction==nil or profile.faction=="")
 rt.profiles[a]=profile
 rt.mocks.DataService.ProfileLoaded.Event:Fire(a,profile,false)
 assert(profile.faction=="governo" and a:GetAttribute("FactionReady"))
 rt.mocks.DataService.ProfileLoaded.Event:Fire(a,profile,false)
 assert(profile.faction=="governo")
end)

test("troca livre preserva ambas reputações e exige nova escolha na reconexão", function()
 local rt,a,_,faction=setup();local p=rt.profiles[a]
 p.honor.points=5000;p.bounty.points=8000;p.coins=250;p.inventory.flecha=2;p.story.act=9
 assert(faction.Choose(a,"governo") and faction.Choose(a,"fora_da_lei") and faction.Choose(a,"governo"))
 assert(p.honor.points==5000 and p.bounty.points==8000 and p.coins==250 and p.inventory.flecha==2 and p.story.act==9)
 rt.services.Players.PlayerRemoving:Fire(a)
 rt.services.Players.PlayerAdded:Fire(a)
 assert(a:GetAttribute("FactionPending") and a:GetAttribute("FactionChoiceRequired"))
 assert(faction.Choose(a,"governo") and not a:GetAttribute("FactionPending") and not a:GetAttribute("FactionChoiceRequired"))
end)

test("clique direito e teclado nunca entram na interação de Mouse1", function()
 local rt=Runtime.new()
 local interaction=rt:load("src/client/Controllers/InteractionController")
 local E=require("@lune/roblox").Enum
 assert(not interaction.TryInteract(E.UserInputType.MouseButton2))
 assert(not interaction.TryInteract(E.UserInputType.Keyboard))
end)
print(count .. " testes de facções, contratos, NPCs e interação passaram")
