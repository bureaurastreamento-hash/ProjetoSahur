--!strict
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Controller={}
local player=Players.LocalPlayer
local portals: { [Model]: string }={}
local function track(item: Instance)
 if item:IsA("Model") and typeof(item:GetAttribute("PortalRoute"))=="string" then portals[item]=item:GetAttribute("PortalRoute") :: string end
end
function Controller.Start()
 for _,item in workspace:GetDescendants() do track(item) end
 workspace.DescendantAdded:Connect(track)
 local elapsed=0
 RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.1 then return end;elapsed=0
  local camera=workspace.CurrentCamera
  for model,route in portals do
   if not model.Parent then portals[model]=nil;continue end
   if not camera or (camera.CFrame.Position-model:GetPivot().Position).Magnitude>240 then continue end
   local ready=player:GetAttribute("PortalReady_"..route)==true
   for _,rune in model:GetChildren() do
    if rune:IsA("BasePart") and rune.Name=="Runa" then
     rune.Color=if ready then Color3.fromRGB(238,193,78) else Color3.fromRGB(91,99,132)
     rune.Transparency=if ready then .12+.12*math.sin(os.clock()*2.5) else .65
    end
   end
  end
 end)
end
return Controller
