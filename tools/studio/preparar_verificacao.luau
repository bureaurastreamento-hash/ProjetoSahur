-- Executar pelo MCP em Edit antes do Play; depois remover as três instâncias temporárias.
assert(game.PlaceId == 85844807133499)
local storage=game.ServerStorage.FerramentasStudio
local sandbox=Instance.new("Folder");sandbox.Name="VerificacaoServicosIsolados"
local previous=game.ServerScriptService:FindFirstChild(sandbox.Name);if previous then previous:Destroy() end
local data=Instance.new("ModuleScript",sandbox);data.Name="DataServiceTest"
data.Source=[[local profile={coins=1000,story={flags={ilha_pilares_unlocked=true,ilha_sol_partido_unlocked=true}}};return {GetProfile=function() return profile end,IsSessionOnly=function() return false end,SetCoins=function(_,v) profile.coins=v end}]]
local story=Instance.new("ModuleScript",sandbox);story.Name="StoryServiceTest"
story.Source=[[local real=require(game.ServerScriptService.Server.Services.StoryService);return {CanInteract=real.CanInteract,HasFlag=function() return true end,Say=function() end,ArriveRegion=function() end}]]
local world=Instance.new("ModuleScript",sandbox);world.Name="WorldServiceTest"
world.Source=[[return {Discover=function() end}]]
local source=game.ServerScriptService.Server.Services.VesselService.Source
source=source:gsub('require%(script.Parent.DataService%)','require(script.Parent.DataServiceTest)')
source=source:gsub('require%(script.Parent.StoryService%)','require(script.Parent.StoryServiceTest)')
source=source:gsub('require%(script.Parent.WorldService%)','require(script.Parent.WorldServiceTest)')
source=source:gsub('require%(script.Parent.AntiExploitService%)','require(game.ServerScriptService.Server.Services.AntiExploitService)')
source=source:gsub('require%(script.Parent.Parent.Modules.CaptainAppearance%)','require(game.ServerScriptService.Server.Modules.CaptainAppearance)')
source=source:gsub('"PortosStrength"','"PortosStrengthTeste"')
local testModule=Instance.new("ModuleScript",sandbox);testModule.Name="VesselServiceTest";testModule.Source=source
sandbox.Parent=game.ServerScriptService
for _,row in {{game.ServerScriptService,"VerificacaoStudioTemporaria","Script","verificar_servidor"},{game.StarterPlayer.StarterPlayerScripts,"VerificacaoClienteTemporaria","LocalScript","verificar_cliente"}} do
 local old=row[1]:FindFirstChild(row[2]);if old then old:Destroy() end
 local s=Instance.new(row[3]);s.Name=row[2];s.Source=storage[row[4]].Source;s.Parent=row[1]
end
print("Verificações temporárias preparadas; dados de aluguel simulados.")
