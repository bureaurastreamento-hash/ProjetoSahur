-- Harness temporário: executar pelo instalador em Edit, depois Play. Não toca perfil/DataStore do dono.
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local results={}
local function check(name,fn)
 local ok,value=pcall(fn)
 table.insert(results,{name=name,ok=ok,detail=tostring(value)})
 warn("[VerificacaoStudio] "..name.." "..tostring(ok).." "..tostring(value))
end
local player=Players.PlayerAdded:Wait()
local character=player.Character or player.CharacterAdded:Wait()
task.wait(10)
character=player.Character
local savedCFrame=character:GetPivot()
local services=game.ServerScriptService.Server.Services
local modules=game.ReplicatedStorage.Shared.Modules
local health=require(services.HealthService)
local botService=require(services.BotService)
local npc
check("retorno caminhando sem teleporte",function()
 npc=botService.Spawn({Name="Verificacao NPC",CFrame=CFrame.new(-430,4,-25),Behavior="idle",Respawn=false,Attributes={FXEnemy=true,StoryKillKind="fx_campos_enemy",MaxHealth=1000}})
 assert(npc,"NPC indisponível")
 local root=npc:FindFirstChild("HumanoidRootPart")
 root.CFrame=CFrame.new(-550,4,-25)
 task.wait(.7)
 assert(npc:GetAttribute("ReturningHome")==true,"não iniciou retorno")
 local previous=root.Position
 task.wait(.3)
 assert((root.Position-previous).Magnitude<25,"deslocamento instantâneo inesperado")
 task.wait(5)
 assert(root.Position.X>-550,"não caminhou de volta")
 return tostring(root.Position)
end)
check("regen só após pausa de 15 s; dano entre NPCs bloqueado",function()
 assert(npc and npc.Parent)
 local h=npc:FindFirstChildOfClass("Humanoid")
 local before=h.Health
 assert(health.ApplyDamage(npc,100,nil)>0)
 assert(health.ApplyDamage(npc,50,npc)==0)
 local damaged=h.Health
 task.wait(2)
 assert(h.Health==damaged,"regeneração cedo")
 npc:SetAttribute("LastDamageReceived",os.clock()-16)
 task.wait(1.2)
 assert(h.Health>damaged and h.Health<before,"cura gradual não ocorreu")
 return tostring(h.Health)
end)

check("chefe regenera mais tarde e menos por segundo",function()
 assert(npc and npc.Parent)
 npc:SetAttribute("StoryKillKind","fx_capataz")
 local h=npc:FindFirstChildOfClass("Humanoid")
 local before=h.Health
 npc:SetAttribute("LastDamageReceived",os.clock()-16)
 task.wait(1.2);assert(h.Health==before,"chefe curou antes de 30 s")
 npc:SetAttribute("LastDamageReceived",os.clock()-31)
 task.wait(1.2);assert(h.Health>before and h.Health-before<=7,"regen de chefe incorreta")
 return tostring(h.Health-before)
end)
check("extensões têm chão físico e marcadores de treino invisíveis",function()
 local root=workspace.Sahur:WaitForChild("FXPortDistricts",10)
 assert(root and #root:GetChildren()==3,"bairro ausente")
 local total=0
 for _,district in root:GetChildren() do
  local tiles=0
  for _,part in district:GetChildren() do if part:IsA("BasePart") and part.Name=="PraiaPortuaria" then tiles+=1 end end
  assert(tiles>0,district.Name.." sem chão")
  total+=tiles
 end
 for _,part in workspace.Sahur:GetDescendants() do if part.Name:match("^VagantePad%d$") then assert(part.Transparency==1 and not part.CanCollide) end end
 assert(not workspace:FindFirstChild("Dummies"),"dummies ainda presentes")
 return tostring(total).." blocos de chão novos"
end)
if npc then botService.Remove(npc) end
local sandbox=game.ServerScriptService:WaitForChild("VerificacaoServicosIsolados")
local data=sandbox.DataServiceTest
local testModule=sandbox.VesselServiceTest
local vesselService=require(testModule)
vesselService.Start()
local marker
for _,m in workspace.PortosStrengthTeste:GetChildren() do
 if m:IsA("Model") and m:FindFirstChild("HumanoidRootPart") then local root=m.HumanoidRootPart;if (root.Position-Vector3.new(40,3,232)).Magnitude<20 then marker=root end end
end
check("aluguel rejeita distância e preço inválido",function()
 assert(marker,"capitão ausente")
 assert(not vesselService.Rent(player,"strength",marker),"aceitou de longe")
 require(services.AntiExploitService).Grace(player,10)
 character:PivotTo(marker.CFrame*CFrame.new(0,0,-5))
 assert(not vesselService.Rent(player,"cruzeiro_gratis",marker))
 assert(require(data).GetProfile(player).coins==1000)
 return "sem cobrança indevida"
end)
check("cruzeiro cobra uma vez e aceita somente piloto no leme",function()
 assert(vesselService.Rent(player,"strength",marker),"aluguel recusado")
 assert(require(data).GetProfile(player).coins==650)
 assert(not vesselService.Rent(player,"strength",marker))
 assert(require(data).GetProfile(player).coins==650)
 task.wait(1)
 local ship
 for _,m in workspace.PortosStrengthTeste:GetChildren() do if m:GetAttribute("Vessel") then ship=m end end
 assert(ship,"modelo ausente")
 local helm=ship.Leme
 assert(helm.Occupant==character:FindFirstChildOfClass("Humanoid"),"embarque falhou")
 local from=ship:GetPivot().Position
 for _=1,30 do task.wait(.1) end
 assert((ship:GetPivot().Position-from).Magnitude>5,"navio não navegou")
 local distance=(ship:GetPivot().Position-from).Magnitude
 ship:SetAttribute("VerificationDockPhase","return")
 local deadline=os.clock()+12
 repeat task.wait(.2) until (ship:GetPivot().Position-marker.Position).Magnitude<180 or os.clock()>deadline
 ship:SetAttribute("VerificationDockPhase","stop")
 local original=ship:GetPivot().Position
 assert(vesselService.Dock(player,ship,helm),"desembarque recusado no porto")
 task.wait(.1)
 assert((character:GetPivot().Position-marker.Position).Magnitude<15,"não desembarcou no cais")
 assert((ship:GetPivot().Position-original).Magnitude<4,"desembarque moveu o navio")
 return tostring(distance).." studs; desembarque sem mover o casco"
end)
-- Manter o navio parado para a captura de referência; não altera moedas/reputação do perfil real.
for _,m in workspace.PortosStrengthTeste:GetChildren() do if m:GetAttribute("Vessel") then m:SetAttribute("VerificationShip",true) end end
require(services.AntiExploitService).Grace(player,3)
local h=character:FindFirstChildOfClass("Humanoid");local seat=h.SeatPart;h.Sit=false
local weld=seat and seat:FindFirstChild("SeatWeld");if weld then weld:Destroy() end
character:PivotTo(savedCFrame)
warn("[VerificacaoStudioResultado] "..Http:JSONEncode(results))
