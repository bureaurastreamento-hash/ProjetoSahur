-- Apenas leitura e captura local. Oculta a escolha de facção sem escolher/salvar facção.
local player=game.Players.LocalPlayer
local Http=game:GetService("HttpService")
local gui=player:WaitForChild("PlayerGui")
task.spawn(function()
 while true do
  task.wait(.1)
  local character=player.Character
  local h=character and character:FindFirstChildOfClass("Humanoid")
  local seat=h and h.SeatPart
  local tests=workspace:FindFirstChild("PortosStrengthTeste")
  if seat and tests and seat:IsA("VehicleSeat") and seat:IsDescendantOf(tests) then
   local ship=seat.Parent
   local phase=ship:GetAttribute("VerificationDockPhase")
   seat.ThrottleFloat=if phase=="stop" then 0 elseif phase=="return" then -1 else 1;seat.SteerFloat=0
  end
 end
end)
task.wait(12)
local faction=gui:FindFirstChild("FactionGui");if faction then faction.Enabled=false end
local results={}
local hud=gui:FindFirstChild("HUD")
results.hudExists=hud~=nil
if hud then
 for _,name in {"Health","Energy","XP"} do
  local bar=hud.Vitals:FindFirstChild(name)
  results[name]=bar and {size={bar.AbsoluteSize.X,bar.AbsoluteSize.Y},position={bar.AbsolutePosition.X,bar.AbsolutePosition.Y},text=bar:FindFirstChild("Text") and bar.Text.Text}
 end
end
local camera=workspace.CurrentCamera
camera.CameraType=Enum.CameraType.Scriptable
camera.CFrame=CFrame.lookAt(Vector3.new(115,90,265),Vector3.new(15,4,105))
camera.Focus=CFrame.new(15,4,105)
for _,sound in game:GetService("SoundService"):GetChildren() do
 if sound:IsA("Sound") and sound.Name=="FXSoundtrack" then results.music={id=sound.SoundId,loaded=sound.IsLoaded,playing=sound.IsPlaying} end
end
warn("[VerificacaoClienteResultado] "..Http:JSONEncode(results))
-- Repor a escolha em 2 min; a inspeção não concede facção ou progresso.
task.delay(120,function() if faction and player:GetAttribute("Faction")=="" then faction.Enabled=true end end)

task.spawn(function()
 local assets=game.ReplicatedStorage.Assets.Sounds
 local rows={}
 for _,folder in {assets.Music,assets.CC0} do
  for _,sound in folder:GetChildren() do
   local ok=pcall(function() game:GetService("ContentProvider"):PreloadAsync({sound}) end)
   local row={name=folder.Name.."."..sound.Name,loaded=ok and sound.IsLoaded,length=sound.TimeLength}
   table.insert(rows,row)
   warn("[VerificacaoAudioItem] "..Http:JSONEncode(row))
  end
 end
 warn("[VerificacaoAudioResultado] "..Http:JSONEncode(rows))
end)
