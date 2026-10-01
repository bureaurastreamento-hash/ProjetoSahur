local Runtime = require("./runtime")
local roblox = require("@lune/roblox")
local total = 0
local function test(name, fn) fn(); total += 1; print("OK", name) end
test("respawn distingue chefe sem boss no nome; limita overrides inválidos", function()
	local rt = Runtime.new(); local policy = rt:load("src/shared/Modules/NpcLifecycleConfig")
	assert(policy.IsBoss("fx_capataz") and policy.IsBoss("fx_mare_avatar"))
	assert(policy.Respawn("fx_capataz") == 600 and policy.Respawn("fx_mare_avatar") == 1800)
	assert(policy.Respawn("fx_tutorial_enemy", 999) == 30 and policy.Respawn("fx_cap1_boss", 1) == 600)
	assert(policy.Respawn("fx_tutorial_enemy", 0/0) == 20 and policy.Respawn("fx_tutorial_enemy", math.huge) == 20)
	assert(policy.MobRegen.Delay == 15 and policy.BossRegen.Delay > policy.MobRegen.Delay and policy.BossRegen.Fraction < policy.MobRegen.Fraction)
end)
test("entrada de navio rejeita NaN, infinito, tipo errado e fora da faixa", function()
	local config = Runtime.new():load("src/shared/Modules/VesselConfig")
	assert(config.ValidInput(1, -1) and config.ValidInput(0, 0))
	for _, v in { 0/0, math.huge, -math.huge, 1.01, "1", {} } do assert(not config.ValidInput(v, 0) and not config.ValidInput(0, v)) end
	assert(config.Offers.remo.Price == 0 and config.Offers.strength.Price > config.Offers.lancha.Price)
end)
local function puzzle()
	local rt = Runtime.new(); local a, root = rt:player(1, roblox.Vector3.new(246, 1, 178))
	rt.services.Workspace.Raycast = function() return {Position=roblox.Vector3.new(246, 0, 178)} end
	rt.mocks.StoryService = {
		CanInteract = function(_, marker) return not rt.flags.dead and (root.Position - marker.Position).Magnitude <= 12 end,
		Refresh = function() end, Say = function() end,
	}
	rt.mocks.RateLimiter = {new=function() return {Allow=function() return not rt.flags.throttled end} end}
	local service = rt:load("src/server/Services/RelicPuzzleService");service.Start()
	local markers = {}
	for _, item in rt.instances do if item.Name == "Sol" then markers[1] = item elseif item.Name == "Névoa" then markers[2] = item elseif item.Name == "Lua" then markers[3] = item end end
	return rt, a, root, service, markers
end
test("lentes exigem ordem, validam marcador e pagam uma única vez por perfil", function()
	local rt, a, _, service, markers = puzzle()
	assert(not service.Activate(a,1,markers[1]))
	assert(service.Activate(a,3,markers[3]))
	assert(not service.Activate(a,2,markers[2])) -- erro zera sequência
	assert(service.Activate(a,3,markers[3]) and service.Activate(a,1,markers[1]) and service.Activate(a,2,markers[2]))
	assert(rt.profiles[a].story.flags.relic_lentes_solved and rt.profiles[a].inventory["mat:nucleo_marinho"] == 1)
	assert(not service.Activate(a,3,markers[3]) and rt.profiles[a].inventory["mat:nucleo_marinho"] == 1)
end)
test("lentes rejeitam distância, morte, fallback, throttle e marcador forjado", function()
	local rt,a,root,service,markers = puzzle()
	root.Position=roblox.Vector3.new(1000,0,0);assert(not service.Activate(a,3,markers[3]))
	root.Position=roblox.Vector3.new(246,1,178)
	for _,flag in {'dead','sessionOnly','throttled'} do rt.flags[flag]=true;assert(not service.Activate(a,3,markers[3]));rt.flags[flag]=false end
	assert(not service.Activate(a,3,markers[1]) and not service.Activate(a,999,markers[3]))
	markers[3].Parent=nil;assert(not service.Activate(a,3,markers[3]))
	assert(not rt.profiles[a].inventory['mat:nucleo_marinho'])
end)
test("reconexão conserva relíquia e cada jogador precisa resolver seu enigma", function()
	local rt,a,root,service,markers=puzzle(); local b=rt:player(2,root.Position)
	assert(service.Activate(a,3,markers[3]) and service.Activate(a,1,markers[1]) and service.Activate(a,2,markers[2]))
	assert(not service.Activate(b,2,markers[2]))
	local saved=rt.profiles[a];rt.services.Players.PlayerRemoving:Fire(a)
	local c=rt:player(3,root.Position);rt.profiles[c]=saved
	assert(not service.Activate(c,3,markers[3]) and saved.inventory['mat:nucleo_marinho']==1)
	assert(not rt.profiles[b].story.flags.relic_lentes_solved)
end)
test("navegação guia objetivo pendente, treino por nível e parry sem GPS de segredo",function()
	local rt=Runtime.new();local nav=rt:load('src/server/Modules/StoryNavigation')
	local pos=roblox.Vector3.new(72,1,213)
	local marker={Position=pos,IsA=function() return true end,IsDescendantOf=function() return true end}
	rt.services.Workspace.FindFirstChild=function() return {FindFirstChild=function(_,name) if name=='M0_Destrocos' or name=='MobPad_Clareira0' or name=='VagantePad0' then return marker end end} end
	local state=nav.Next({},{{kind='fx_m0_destrocos',progress=0,goal=1,text='Destroços'}},false)
	assert(state.position==pos and state.label=='Destroços')
	assert(nav.Next({},{{kind='segredo_sem_marcador',progress=0,goal=1}},false)==nil)
	assert(nav.Next({Region='ilha_tutorial'},{},true).label=='Treino da região')
	assert(nav.Next({},{{kind='parries',progress=0,goal=1}},false).label:find('F antes',1,true))
end)
print(total,"testes de NPCs, navegação e relíquias passaram")
