--!strict
--[[ Portais entre as ilhas do Capítulo 1 (ligados pelo NOME da peça; gerados em tools/gerar_ilha_*_fx.py). ]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldService = require(script.Parent:WaitForChild("WorldService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))
local StoryService = require(script.Parent:WaitForChild("StoryService"))
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))

local WorldPortalService = {}
local Data = require(script.Parent.DataService)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
-- Ordem da bíblia: Porto da Névoa → (Herdeiro da Névoa) → Deserto do Sol → (Sacerdote do Sol Negro) → Rota do Eclipse.
-- Voltar é sempre livre. As flags são gravadas pelo `UnlockFlag` do ato em StoryConfig.
type Route = { Region: string, Checkpoint: string, FirstVisitByBoat: boolean?, AttunementItem: string?, RequiredFlag: string?, Locked: string? }
local PORTALS: { [string]: Route } = {
	CostaToMare = { Region = "fortaleza_mare", Checkpoint = "chegada", RequiredFlag = "fortaleza_mare_unlocked", Locked = "Resolva o Eco da Costa Dourada para abrir esta rota." },
	MareToCosta = { Region = "costa_dourada", Checkpoint = "chegada" },
	AmbarToCosta = { Region = "costa_dourada", Checkpoint = "chegada", RequiredFlag = "costa_dourada_unlocked", Locked = "Resolva o Eco da Cidade Âmbar para abrir esta rota." },
	CostaToAmbar = { Region = "cidade_ambar", Checkpoint = "chegada" },
	SolPartidoToAmbar = { Region = "cidade_ambar", Checkpoint = "chegada", RequiredFlag = "cidade_ambar_unlocked",
		Locked = "Derrote O Observador na Rota do Eclipse para abrir esta rota." },
	AmbarToSolPartido = { Region = "ilha_sol_partido", Checkpoint = "oasis" },
	TutorialToPilares = { FirstVisitByBoat = true, Region = "ilha_pilares", Checkpoint = "praia", RequiredFlag = "ilha_pilares_unlocked",
		Locked = "A ruptura para o Deserto do Sol está instável. Derrote o Herdeiro da Névoa nas ruínas ao norte." },
	PilaresToTutorial = { Region = "ilha_tutorial", Checkpoint = "porto" },
	PilaresToSolPartido = { FirstVisitByBoat = true, AttunementItem = "mat:selo_solar", Region = "ilha_sol_partido", Checkpoint = "oasis", RequiredFlag = "ilha_sol_partido_unlocked",
		Locked = "A Rota do Eclipse ainda está fechada. Derrote o Sacerdote do Sol Negro na Câmara (santuário atrás da cachoeira)." },
	SolPartidoToPilares = { Region = "ilha_pilares", Checkpoint = "praia" },
}

function WorldPortalService.CanTravel(player: Player, destination: Route): (boolean,string?)
 local profile=Data.GetProfile(player)
 if not profile then return false,"Seu perfil está carregando." end
 if destination.RequiredFlag and not profile.story.flags[destination.RequiredFlag] then return false,destination.Locked or "Conclua a missão desta rota." end
 if destination.FirstVisitByBoat and not profile.story.flags["portal_attuned:"..destination.Region] and not (profile.world and profile.world.discovered[destination.Region]) and not (destination.AttunementItem and (profile.inventory[destination.AttunementItem] or 0)>0) then
  return false,"A rota marítima está aberta. Faça a primeira viagem de barco e desembarque no porto para liberar este atalho." .. (if destination.AttunementItem then " O Selo Solar também estabiliza esta ruptura." else "")
 end
 return true,nil
end
WorldPortalService.Routes=PORTALS
local function appearance(part: BasePart)
 local model=Instance.new("Model");model.Name="Ruptura_"..part.Name;model:SetAttribute("PortalRoute",part.Name);model.Parent=part.Parent
 part.Transparency=1;part.CanCollide=false
 local core=part.Parent and part.Parent:FindFirstChild(part.Name.."Core")
 if core and core:IsA("BasePart") then core.Transparency=1;core.CanQuery=false end
 for i=0,11 do
  local angle=i*math.pi/6
  local edge=Instance.new("Part");edge.Name="Arco";edge.Size=Vector3.new(.8,2.5,.65);edge.Anchored=true;edge.CanCollide=false;edge.CanTouch=false;edge.CanQuery=false
  edge.CFrame=part.CFrame*CFrame.new(math.sin(angle)*3.8,math.cos(angle)*5.5,0)*CFrame.Angles(0,0,math.pi/2-angle)
  edge.Material=Enum.Material.Slate;edge.Color=Color3.fromRGB(42,47,60);edge.Parent=model
  local rune=Instance.new("Part");rune.Name="Runa";rune.Size=Vector3.new(.86,.5,.22);rune.CFrame=edge.CFrame; rune.Anchored=true;rune.CanCollide=false;rune.CanTouch=false;rune.CanQuery=false
  rune.Material=Enum.Material.Neon;rune.Color=Color3.fromRGB(238,193,78);rune.Parent=model
 end
end

local function bind(part: BasePart, destination: Route)
	if part:GetAttribute("PortalBound") then return end
	part:SetAttribute("PortalBound",true)
	appearance(part)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Atravessar"
	local region = WorldConfig.GetRegion(destination.Region)
	prompt.ObjectText = if region then region.Name else destination.Region
	prompt.HoldDuration = .5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player: Player)
		if not StoryService.CanInteract(player, part, 15) then return end
		local target = WorldConfig.GetRegion(destination.Region)
		if not target or not target.Available then
			StoryService.Say(player, "A área de destino ainda não está disponível para travessia.")
			return
		end
  local allowed,why=WorldPortalService.CanTravel(player,destination)
  if not allowed then Remotes.GetEvent(Remotes.Events.NotifyStory):FireClient(player,"locked",{text=why});return end

		-- viajar NÃO salva o spawn: quem salva é o Pescador da ilha (FisherService, dono 29/09)
		local cf = WorldConfig.CFrameOf(destination.Region, destination.Checkpoint)
		if not cf or not player.Character then return end
		WorldService.Discover(player, destination.Region)
		AntiExploitService.Grace(player, 2)
		player.Character:PivotTo(cf * CFrame.new(0, 3, 0))
		StoryService.ArriveRegion(player, destination.Region)
	end)
end

local function scan(root: Instance)
	for _, descendant in root:GetDescendants() do
		local destination = PORTALS[descendant.Name]
		if destination and descendant:IsA("BasePart") then bind(descendant, destination) end
	end
end

function WorldPortalService.Start()
 local elapsed=0
 RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<1 then return end;elapsed=0
  for _,player in Players:GetPlayers() do
   for name,destination in PORTALS do local ready=WorldPortalService.CanTravel(player,destination);player:SetAttribute("PortalReady_"..name,ready) end
  end
 end)
 scan(Workspace)
	Workspace.DescendantAdded:Connect(function(descendant: Instance)
		local destination = PORTALS[descendant.Name]
		if destination and descendant:IsA("BasePart") then bind(descendant, destination) end
	end)
end

return WorldPortalService
