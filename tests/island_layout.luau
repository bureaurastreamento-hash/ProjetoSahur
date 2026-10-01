local Runtime = require('./runtime')
local r = require('@lune/roblox')
local rt = Runtime.new()
local layout = rt:load('src/shared/Modules/IslandLayout')
local world = rt:load('src/shared/Modules/WorldConfig')
local vessel = rt:load('src/shared/Modules/VesselConfig')
local launch = rt:load('src/shared/Modules/LaunchConfig')
local districts = rt:load('src/shared/Modules/PortDistrictConfig')
local pvp = rt:load('src/shared/Modules/PvpConfig')
local count = 0
local function test(name, fn) fn();count+=1;print('OK '..name) end
test('ilhas principais têm mais de 1000 studs entre centros, sem mover tutorial',function()
 assert(world.Islands[1].Center==r.Vector3.new(150,0,-40))
 assert((world.Islands[3].Center-world.Islands[1].Center).Magnitude>1600)
 assert((world.Islands[4].Center-world.Islands[3].Center).Magnitude>1000)
 assert(world.Islands[5].Center==r.Vector3.new(-750,0,1060))
end)
test('spawn do lobby, porto, checkpoint e distrito recebem a mesma translação',function()
 assert(launch.LobbyCenter==r.Vector3.new(901,0,-1439))
 assert(vessel.Ports[2].Land==r.Vector3.new(643,0,-1510))
 assert(world.Regions.ilha_pilares.Checkpoints.praia.Position==r.Vector3.new(690,2,-1520))
 assert(districts.Districts[2].Center==r.Vector3.new(610,-.15,-1594))
 assert(pvp.SafeZones[3].Center==r.Vector3.new(690,2,-1520))
 assert(vessel.Ports[2].Outward==r.Vector3.new(-1,0,0))
end)
test('funções de região reconhecem chão novo e não a posição antiga',function()
 assert(world.IslandAt(r.Vector3.new(910,0,-1600)).Region=='ilha_pilares')
 assert(world.IslandAt(r.Vector3.new(910,0,-500))==nil)
 assert(world.IslandAt(r.Vector3.new(2000,0,-1530)).Region=='ilha_sol_partido')
 assert(layout.Position(r.Vector3.new(350,0,70))==r.Vector3.new(350,0,70))
end)
test('mapa move peças uma vez e preserva Cidade Âmbar e rotação',function()
 rt.services.ReplicatedStorage.Shared={Modules={IslandLayout={Name='IslandLayout',path='src/shared/Modules/IslandLayout'}}}
 local apply=rt:load('src/server/Modules/WorldLayout')
 local function part(name,pos,city)
  local o={Name=name,Position=pos,CFrame=r.CFrame.new(pos)*r.CFrame.Angles(0,.7,0)}
  function o:IsA(c)return c=='BasePart' end
  function o:FindFirstAncestor()return if city then {} else nil end
  return o
 end
 local a=part('Ilha',r.Vector3.new(910,5,-500),false)
 local b=part('Cidade',r.Vector3.new(1700,5,-130),true)
 local c=part('Taberna',r.Vector3.new(350,5,70),false)
 local originalA,originalB,originalC=a.CFrame,b.CFrame,c.CFrame
 local attrs={}
 local scene={}
 function scene:GetAttribute(k)return attrs[k] end
 function scene:SetAttribute(k,v)attrs[k]=v end
 function scene:GetDescendants()return {a,b,c} end
 apply.Apply(scene)
 assert(a.CFrame==originalA+r.Vector3.new(0,0,-1100))
 assert(b.CFrame==originalB and c.CFrame==originalC)
 local once=a.CFrame;apply.Apply(scene);assert(a.CFrame==once)
end)
print(count..' testes de espaçamento passaram')
