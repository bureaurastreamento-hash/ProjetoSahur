--!strict
-- Mobiliário portuário sobre terra existente; não fabrica ilhas/grama sobre o mar.
local Workspace = game:GetService("Workspace")
local Modules = game.ReplicatedStorage.Shared.Modules
local Config = require(Modules.VesselConfig)
local Assets = require(Modules.Assets)
local Service = {}
local function prop(parent: Instance, name: string, at: CFrame, scale: number)
 local template=Assets.GetEnvironmentModel(name)
 if not template then return end
 local clone=template:Clone();clone:ScaleTo(scale)
 local box,size=clone:GetBoundingBox()
 clone:PivotTo(at*CFrame.new(0,size.Y/2,0)*clone:GetPivot():ToObjectSpace(box):Inverse())
 for _,p in clone:GetDescendants() do if p:IsA("BasePart") then p.Anchored=true;p.CanCollide=false;p.CanTouch=false end end
 clone.Parent=parent
end
function Service.Start()
 local root=Instance.new("Folder");root.Name="FXPortDistricts";root.Parent=Workspace
 for _,port in Config.Ports do
  local right=Vector3.yAxis:Cross(port.Outward)
  for i,side in {-1,1} do
   local pos=port.Land-port.Outward*16+right*(side*9)
   local params=RaycastParams.new();params.RespectCanCollide=true
   local hit=Workspace:Raycast(pos+Vector3.new(0,80,0),Vector3.new(0,-100,0),params)
   if not hit or hit.Material==Enum.Material.Water or hit.Position.Y< -3 then continue end
   prop(root,if i==1 then "barrel" else "crate",CFrame.new(hit.Position),.8)
  end
 end
end
return Service
