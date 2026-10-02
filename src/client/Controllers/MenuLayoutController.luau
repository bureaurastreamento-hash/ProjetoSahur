--!strict
-- Espaços únicos: menus centrais, status no canto esquerdo, missões acima deles e avisos à direita.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Theme = require(game.ReplicatedStorage.Shared.Modules.HudLayout)
local Controller = {}
local player = Players.LocalPlayer
local panels: { [GuiObject]: number } = {}
local busy = false
local names: { [string]: boolean } = { EmoteGui=true,SideMenu=true,QuestGui=true,ModsGui=true,WorldShopGui=true,GoalsGui=true,HuntGui=true, CharacterSelect=true, ShopGui=true, VendorGui=true, ProfileGui=true, ClanGui=true, CosmeticsGui=true, SettingsGui=true, HelpGui=true, AchievementsGui=true, ReportGui=true, DuelGui=true, DevGui=true, UpdateLogGui=true, VfxPreviewGui=true, InventoryGui=true, FXChoiceGui=true, InteractionGui=true }
local function skin(panel: GuiObject)
 panel.BackgroundColor3, panel.BackgroundTransparency, panel.BorderSizePixel = Theme.Ink, .04, 0
 local stroke = panel:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
 stroke.Color, stroke.Thickness, stroke.ApplyStrokeMode, stroke.Parent = Theme.Gold, 2, Enum.ApplyStrokeMode.Border, panel
 for _, item in panel:GetDescendants() do
  if item:IsA("UICorner") then item.CornerRadius = UDim.new(0,3)
  elseif item:IsA("TextLabel") then
   item.Font = if item.Name=="Title" or item.Name=="Header" then Enum.Font.GothamBlack else Enum.Font.GothamMedium
   if item.Name=="Title" or item.Name=="Header" then item.TextColor3=Theme.Gold end
  elseif item:IsA("GuiObject") and item.BackgroundTransparency<1 then
   local c=item.BackgroundColor3
   if math.max(c.R,c.G,c.B)<.35 then item.BackgroundColor3=Theme.Ink end
  end
 end
end
local function layout(panel: GuiObject, width: number)
 local camera = workspace.CurrentCamera
 if not camera then return end
 local view=camera.ViewportSize
 local mobile=UIS.TouchEnabled and not UIS.KeyboardEnabled
 local hudScale=math.clamp(view.X/1440,.78,1.1)
 local available=if mobile or view.X<900 then view.X-32 else view.X-2*(36+320*hudScale)
 local scale=math.min(1,math.max(280,available)/width)
 local fit=panel:FindFirstChild("MenuScale") :: UIScale?
 if not fit then local created=Instance.new("UIScale");created.Name="MenuScale";created.Parent=panel;fit=created end
 (fit :: UIScale).Scale=scale
 panel.AnchorPoint, panel.Position = Vector2.new(.5,.5), UDim2.new(.5,0,.5,-16)
 if panel.Parent and (panel.Parent.Name=="InteractionGui" or panel.Parent.Name=="QuestGui" or panel.Parent.Name=="EmoteGui") then return end
 local height=math.min(560,(view.Y-160)/scale)
 panel.Size=UDim2.fromOffset(width,math.max(220,height))
 local bounds=panel:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint?
 if bounds then bounds.MinSize=Vector2.zero;bounds.MaxSize=Vector2.new(width,math.max(220,height)) end
end
local function dockHud()
 local pg=player.PlayerGui
 local touch=UIS.TouchEnabled and not UIS.KeyboardEnabled
 local story=pg:FindFirstChild("FXStoryGui")
 local tracker=story and story:FindFirstChild("MissionTracker") :: GuiObject?
 if tracker then
  tracker.AnchorPoint=if touch then Vector2.new(1,0) else Vector2.zero
  tracker.Position=if touch then UDim2.new(1,-14,0,82) else UDim2.fromOffset(18,82)
  tracker.Size=if touch then UDim2.fromOffset(200,108) else UDim2.fromOffset(300,210)
  local bounds=tracker:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint?
  if bounds then bounds.MaxSize=if touch then Vector2.new(200,108) else Vector2.new(300,210) end
 end
 local hud=pg:FindFirstChild("HUD")
 if hud then
  local feed=hud:FindFirstChild("KillFeed") :: GuiObject?
  local toasts=hud:FindFirstChild("Toasts") :: GuiObject?
  if feed then feed.Position=UDim2.new(1,-18,0,if touch then 202 else 58);feed.Size=UDim2.fromOffset(if touch then 220 else 300,if touch then 72 else 128) end
  if toasts then toasts.Position=UDim2.new(1,-18,0,if touch then 310 else 218);toasts.Size=UDim2.fromOffset(if touch then 220 else 300,180) end
 end
 local mods=pg:FindFirstChild("ModsGui")
 local chip=mods and mods:FindFirstChild("ModsChip") :: GuiObject?
 if chip then chip.Position=UDim2.new(1,-18,0,if touch then 280 else 188);chip.Size=UDim2.fromOffset(if touch then 220 else 300,22) end
end
local function refresh()
 dockHud()
 local opened=player:GetAttribute("FactionMenuOpen") == true
 for panel in panels do if panel.Parent and panel.Visible and (panel:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui).Enabled then opened=true end end
 player:SetAttribute("MenuOpen",opened)
 if opened then UIS.MouseBehavior=Enum.MouseBehavior.Default end
 local pg=player.PlayerGui
 local story=pg:FindFirstChild("FXStoryGui") :: ScreenGui?
 if story then story.Enabled=not opened and player:GetAttribute("LaunchTitleVisible")~=true and player:GetAttribute("PreLaunchLocked")~=true and player:GetAttribute("InteractionTargetPresent")~=true end
 local hud=pg:FindFirstChild("HUD")
 local vitals=hud and hud:FindFirstChild("Vitals") :: GuiObject?
 if vitals then vitals.Visible=not (opened and workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X<900) end
end
local function register(panel: GuiObject)
 if panels[panel] then return end
 local width=panel.Size.X.Offset
 local bounds=panel:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint?
 if width<280 then width=if bounds and bounds.MaxSize.X<1000 then bounds.MaxSize.X else 640 end
 width=math.clamp(width,340,740)
 panels[panel]=width
 skin(panel);layout(panel,width)
 panel:GetPropertyChangedSignal("Visible"):Connect(function()
  if busy then return end
  busy=true
  if panel.Visible then
   skin(panel)
   for other in panels do if other~=panel and other.Parent then other.Visible=false end end
  end
  busy=false;refresh()
 end)
 panel.Destroying:Connect(function() panels[panel]=nil;task.defer(refresh) end)
end
local function scan(gui: Instance)
 if not gui:IsA("ScreenGui") or not names[gui.Name] then return end
 gui.DisplayOrder=50
 gui.IgnoreGuiInset=true
 gui.ScreenInsets=Enum.ScreenInsets.None
 for _, item in gui:GetChildren() do
  if item:IsA("GuiObject") and (item.Name=="Panel" or item.Name=="Dialog" or item.Name=="Trade" or item.Name=="Wheel" or (gui.Name=="InventoryGui" and item:IsA("Frame"))) then register(item) end
 end
 if gui.Name=="SideMenu" then
  local container=gui:FindFirstChild("Menu");local more=container and container:FindFirstChild("More")
  if more and more:IsA("GuiObject") then more.Parent=gui;register(more) end
 end
 if gui.Name=="FXChoiceGui" then
  for _,item in gui:GetDescendants() do if item:IsA("ScrollingFrame") and item.Parent and item.Parent:IsA("Frame") then register(item) end end
 end
 gui:GetPropertyChangedSignal("Enabled"):Connect(refresh)
end
function Controller.Start()
 local pg=player:WaitForChild("PlayerGui") :: PlayerGui
 for _,gui in pg:GetChildren() do scan(gui) end
 pg.ChildAdded:Connect(function(gui) task.defer(function()scan(gui)end) end)
 pg.DescendantAdded:Connect(function(item: Instance)
  if item:IsA("GuiObject") and item.Name=="Panel" then local gui=item:FindFirstAncestorOfClass("ScreenGui");if gui and names[gui.Name] then task.defer(function() if item.Parent then register(item :: GuiObject) end end) end end
 end)
 local camera=workspace.CurrentCamera
 if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()for panel,width in panels do if panel.Parent then layout(panel,width) end end;refresh()end) end
 player:GetAttributeChangedSignal("FactionMenuOpen"):Connect(refresh)
 player:GetAttributeChangedSignal("InteractionTargetPresent"):Connect(refresh)
 player:GetAttributeChangedSignal("LaunchTitleVisible"):Connect(refresh)
 player:GetAttributeChangedSignal("PreLaunchLocked"):Connect(refresh)
 refresh()
end
return Controller
