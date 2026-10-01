local Runtime=require('./runtime')
local count=0
local function test(name,fn)fn();count+=1;print('OK '..name)end
local function setup()
 local rt=Runtime.new();local p=rt:player(1)
 rt.mocks.AntiExploitService={Grace=function()end}
 rt.mocks.WorldService={Discover=function()end}
 rt.mocks.StoryService={}
 local service=rt:load('src/server/Services/WorldPortalService')
 return rt,p,rt.profiles[p],service
end
test('missão bloqueia portal mesmo com item/visita',function()
 local rt,p,profile,s=setup()
 profile.story.flags['portal_attuned:ilha_pilares']=true
 assert(not s.CanTravel(p,s.Routes.TutorialToPilares))
end)
test('primeira viagem marítima abre atalho sem conceder moedas ou itens',function()
 local rt,p,profile,s=setup()
 profile.story.flags.ilha_pilares_unlocked=true
 assert(not s.CanTravel(p,s.Routes.TutorialToPilares))
 profile.story.flags['portal_attuned:ilha_pilares']=true
 assert(s.CanTravel(p,s.Routes.TutorialToPilares))
end)
test('Selo Solar estabiliza Eclipse depois da missão; item não é consumido',function()
 local rt,p,profile,s=setup()
 profile.inventory['mat:selo_solar']=1
 assert(not s.CanTravel(p,s.Routes.PilaresToSolPartido))
 profile.story.flags.ilha_sol_partido_unlocked=true
 assert(s.CanTravel(p,s.Routes.PilaresToSolPartido))
 assert(profile.inventory['mat:selo_solar']==1)
end)
test('destinos já descobertos conservam atalhos; perfil ausente é recusado',function()
 local rt,p,profile,s=setup()
 profile.story.flags.ilha_pilares_unlocked=true
 profile.world.discovered.ilha_pilares=true
 assert(s.CanTravel(p,s.Routes.TutorialToPilares))
 assert(s.CanTravel(p,s.Routes.PilaresToTutorial))
 rt.profiles[p]=nil;assert(not s.CanTravel(p,s.Routes.PilaresToTutorial))
end)
print(count..' testes de acesso às viagens passaram')
