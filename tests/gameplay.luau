local Runtime = require("./runtime")
local Vector3 = require("@lune/roblox").Vector3
local count = 0
local function test(name, fn) fn(); count += 1; print("OK " .. name) end

test("perfil novo permanece na Missão 0 após Start real do StoryService", function()
	local rt = Runtime.new()
	local player = rt:player(1)
	local story = rt:loadStory()
	story.Init(); story.Start()
	assert(rt.profiles[player].story.act == 1)
	assert(rt.profiles[player].story.rev == rt:load("src/shared/Modules/StoryConfig").Revision)
end)

test("migração rev2 preserva posição relativa de perfil antigo", function()
	local rt = Runtime.new(); local player = rt:player(1)
	rt.profiles[player].story.rev = 2; rt.profiles[player].story.act = 4
	local story = rt:loadStory(); story.Init(); story.Start()
	assert(rt.profiles[player].story.act == 9)
end)

test("kill PvP não substitui Vagantes; três eventos PvE e parry avançam", function()
	local rt = Runtime.new(); local player = rt:player(1)
	local state = rt.profiles[player].story
	state.act = 4; state.counters.kills = 3
	local story = rt:loadStory(); story.Init(); story.Start()
	rt.achievementProgress(player, "kills", 100)
	rt.achievementProgress(player, "parries", 1)
	assert(state.act == 4)
	local victim = { bot = true, GetAttribute = function() return "fx_tutorial_enemy" end }
	for _ = 1, 3 do rt.mocks.HealthService.FighterDied.Event:Fire(victim, player) end
	assert(state.act == 5)
end)

test("Eco bloqueado é recusado, desbloqueado entrega Flecha uma vez", function()
	local rt = Runtime.new(); local player = rt:player(1)
	local profile = rt.profiles[player]; profile.story.act = 10
	local story = rt:loadStory(); story.Init(); story.Start()
	assert(not story.Choose(player, "eco_ilha1", "passagem"))
	story.SetFlag(player, "passagem_capela")
	assert(story.Choose(player, "eco_ilha1", "passagem"))
	assert(not story.Choose(player, "eco_ilha1", "passagem"))
	assert(profile.inventory.flecha == 1 and profile.story.flags.ilha_pilares_unlocked)
end)

test("mochila não consome disco, Flecha ou essência durante bloqueio", function()
	local rt = Runtime.new(); local player = rt:player(1)
	local profile = rt.profiles[player]
	profile.inventory = { flecha = 1, ["stand:Dio"] = 1, ["raca:Vampiro"] = 1 }
	rt.flags.blocked = true
	local stand = rt:load("src/server/Services/StandService"); stand.Init()
	for _, id in { "flecha", "stand:Dio", "raca:Vampiro" } do stand.UseItem(player, id); assert(profile.inventory[id] == 1) end
	assert(profile.power == "" and profile.race == "Humano")
	rt.flags.blocked = false; stand.UseItem(player, "stand:Dio")
	assert(profile.power == "Dio" and profile.inventory["stand:Dio"] == 0)
end)

test("regra real da troca recusa duelo, torneio, combate, morte e agarrão", function()
	local rt = Runtime.new(); local player = rt:player(1)
	local ability = rt:load("src/server/Services/AbilityService")
	assert(ability.CanChangeCharacter(player))
	for _, attribute in { "InMatch", "Tournament", "ChangingPower" } do
		player:SetAttribute(attribute, true); assert(not ability.CanChangeCharacter(player)); player:SetAttribute(attribute, nil)
	end
	for _, flag in { "combat", "dead", "stunned", "grabbed", "ragdolled" } do
		rt.flags[flag] = true; assert(not ability.CanChangeCharacter(player)); rt.flags[flag] = nil
	end
end)

test("zona segura protege os dois sentidos sem desligar PvP fora dela", function()
	local rt = Runtime.new(); local a, root = rt:player(1, Vector3.new(40, 2, 185)); local b = rt:player(2)
	local pvp = rt:load("src/server/Services/PvpService")
	assert(not pvp.CanDamage(a, b) and not pvp.CanDamage(b, a))
	root.Position = Vector3.new(150, 2, -40)
	assert(pvp.CanDamage(a, b))
	assert(pvp.OnDeath(b, a)); assert(not pvp.OnDeath(b, a))
	assert(not pvp.CanDamage(a, b))
end)

test("PvP contra iniciante não dá recompensa; duelo mantém suas regras", function()
	local rt = Runtime.new(); local a = rt:player(1); local b = rt:player(2)
	local pvp = rt:load("src/server/Services/PvpService")
	a:SetAttribute("Level", 50)
	assert(not pvp.OnDeath(b, a))
	a:SetAttribute("DuelId", 1); b:SetAttribute("DuelId", 1)
	assert(pvp.CanDamage(a, b))
end)

test("penalidade de abandono só ocorre com combate marcado e respeita teto", function()
	local rt = Runtime.new(); local a = rt:player(1); local b = rt:player(2)
	local pvp = rt:load("src/server/Services/PvpService"); pvp.Init()
	local profile = rt.profiles[a]; profile.coins = 1000
	rt.mocks.DataService.BeforeLeave(a, profile); assert(profile.coins == 1000)
	pvp.RecordHit(a, b); rt.mocks.DataService.BeforeLeave(a, profile); assert(profile.coins == 950)
	rt.mocks.DataService.BeforeLeave(a, profile); assert(profile.coins == 950)
end)
test("mobs pagam XP e moedas; chefe paga participantes, não espectador", function()
	local rt = Runtime.new(); local a = rt:player(1); local b = rt:player(2); local spectator = rt:player(3)
	local progression = rt:load("src/server/Services/ProgressionService"); progression.Init(); progression.Start()
	local config = rt:load("src/shared/Modules/ProgressionConfig")
	local function victim(kind)
		return { bot = true, Name = "Inimigo", GetAttribute = function(_, key) return if key == "FXEnemy" then true else kind end }
	end
	local coins = rt.profiles[a].coins
	rt.mocks.HealthService.FighterDied.Event:Fire(victim("fx_tutorial_enemy"), a)
	assert(rt.profiles[a].xp == config.Npcs.fx_tutorial_enemy.XP)
	assert(rt.profiles[a].coins == coins + config.Npcs.fx_tutorial_enemy.Coins)
	rt.participants = { a, b }
	rt.mocks.HealthService.FighterDied.Event:Fire(victim("fx_mascara_boss"), a)
	assert(rt.profiles[b].xp == config.Npcs.fx_mascara_boss.XP)
	assert(rt.profiles[spectator].xp == 0)
	assert(not rt.profiles[b].inventory.flecha) -- RNG 0.5 não é drop garantido
end)

test("probabilidades exibidas correspondem a todos os intervalos do sorteio", function()
	local rt = Runtime.new(); local config = rt:load("src/shared/Modules/StandConfig")
	local chances, counts = config.RollChances(), {}
	for i = 0, 9999 do
		local id = config.Roll({ NextNumber = function() return (i + 0.5) / 10000 end, NextInteger = function(_, low) return low end })
		counts[id] = (counts[id] or 0) + 1
	end
	for id, chance in chances do assert(math.abs(counts[id] / 100 - chance) < 0.001) end
	assert(counts.Swift == 5500 and counts.Jotaro == 2600 and counts.Kira == 1700 and counts.Dio == 200)
	assert(config.Blessed.Race == 0)
end)
test("HealthService credita dano real e exclui espectador, dano mínimo e distância", function()
	local rt = Runtime.new(); local a = rt:player(1); local b = rt:player(2); local far = rt:player(3, Vector3.new(1000, 0, 0))
	local health = rt:load("src/server/Services/HealthService")
	local humanoid = { Health = 100, MaxHealth = 100 }
	local attributes = { FXEnemy = true }
	local root = { Position = Vector3.new(150, 2, -40), IsA = function() return true end }
	local model = {
		FindFirstChildOfClass = function() return humanoid end,
		FindFirstChild = function() return root end,
		GetAttribute = function(_, key) return attributes[key] end,
		SetAttribute = function(_, key, value) attributes[key] = value end,
	}
	health.ApplyDamage(model, 10, a); health.ApplyDamage(model, 1, b); health.ApplyDamage(model, 10, far)
	local credited = health.PveParticipants(model)
	assert(#credited == 1 and credited[1] == a)
	health.ClearPveCredit(model); assert(#health.PveParticipants(model) == 0)
end)

test("ProcessReceipt real não repete concessão após save falho", function()
	local rt = Runtime.new(); local player = rt:player(1)
	local shopConfig = rt:load("src/shared/Modules/ShopConfig")
	shopConfig.Products[1].productId = 123
	local shop = rt:load("src/server/Services/ShopService"); shop.Init()
	local delivered = 0
	shop.CosmeticHook = function() delivered += 1; return true end
	local receipt = { PlayerId = 1, ProductId = 123, PurchaseId = "test-receipt" }
	local decisions = require("@lune/roblox").Enum.ProductPurchaseDecision
	rt.flags.saveFailed = true
	assert(rt.services.MarketplaceService.ProcessReceipt(receipt) == decisions.NotProcessedYet)
	assert(rt.services.MarketplaceService.ProcessReceipt(receipt) == decisions.NotProcessedYet)
	rt.flags.saveFailed = false
	assert(rt.services.MarketplaceService.ProcessReceipt(receipt) == decisions.PurchaseGranted)
	assert(delivered == 1 and rt.profiles[player].receipts[receipt.PurchaseId])
end)
print(("%d testes de gameplay passaram"):format(count))
