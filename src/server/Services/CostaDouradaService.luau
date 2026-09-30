--!strict
local Workspace = game:GetService("Workspace")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.CostaDouradaConfig)
local WorldConfig = require(Modules.WorldConfig)
local MapRegistration = require(script.Parent.Parent.Modules.CampaignMapRegistration)
local StoryService = require(script.Parent.StoryService)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)
local BotService = require(script.Parent.BotService)
local Service = {}
local active: Model? = nil

function Service.Interact(player: Player, marker: BasePart): boolean
	local profile = DataService.GetProfile(player)
	local region = WorldConfig.GetRegion(Config.Region)
	if not profile or not region or not region.Available or not profile.story.flags.costa_dourada_unlocked
		or not StoryService.CanInteract(player, marker, 14) or StoryService.RegionOf(player) ~= Config.Region then return false end
	local flags, counters = profile.story.flags, profile.story.counters
	if marker.Name == "CostaContato" then
		if not flags.costa_contato_conhecido then
			StoryService.SetFlag(player, "costa_contato_conhecido")
			StoryService.Say(player, "Posso conseguir acesso social. Ajude-me primeiro: busque a entrega no ponto indicado e retorne.", "Contato")
		elseif flags.costa_favor_recolhido and not flags.costa_acesso_social then
			StoryService.SetFlag(player, "costa_acesso_social")
			StoryService.Say(player, "Você ajudou. Agora pode escolher o acesso social na infiltração.", "Contato")
		else
			local state = Config.Style(flags)
			StoryService.Say(player, if state ~= "" then state else "Traga a entrega do ponto indicado para obter acesso social.", "Contato")
		end
		StoryService.Refresh(player)
		return true
	elseif marker.Name == "CostaFavor" then
		if not flags.costa_contato_conhecido or flags.costa_favor_recolhido or flags.costa_acesso_social then return false end
		StoryService.SetFlag(player, "costa_favor_recolhido")
		StoryService.Refresh(player)
		StoryService.Say(player, "Entrega recolhida. Volte ao contato da Costa Dourada.", "Favor")
		return true
	elseif marker.Name == "CostaHumanoider" then
		if StoryService.Wants(player, "fx_costa_c8_relato") and (counters.fx_costa_c8 or 0) >= 1 then
			StoryService.SetFlag(player, "costa_c8_reconhecido")
			StoryService.ProgressOnce(player, "fx_costa_c8_relato", marker.Name, true)
			StoryService.Say(player, Config.C8Report)
			return true
		end
		local summary = Config.Market(flags)
		if summary ~= "" then StoryService.Say(player, summary) else StoryService.TalkToGuide(player) end
		return false
	end
	local path = ({ CostaAcessoForca = "forca", CostaAcessoFurtivo = "furtividade", CostaAcessoSocial = "social" })[marker.Name]
	if path then
		if not flags["costa_infiltracao_" .. path] then return false end
		if path == "forca" and (counters.fx_costa_guard or 0) < 3 then return false end
		if path == "furtividade" and (counters.fx_costa_furtivo or 0) < 2 then return false end
		if path == "social" and not flags.costa_acesso_social then return false end
		if not StoryService.ProgressOnce(player, "fx_costa_acesso", marker.Name, true) then return false end
		StoryService.Say(player, "Você obteve acesso. " .. Config.Style(flags))
		return true
	end
	local action = Config.Interactions[marker.Name]
	if not action then return false end
	if marker.Name == "CostaPassagem2" and not counters.seen_CostaPassagem1 then return false end
	if not StoryService.ProgressOnce(player, action.Kind, marker.Name, true) then return false end
	StoryService.Say(player, action.Text, "Investigação")
	return true
end

local function prompt(marker: BasePart, title: string, callback: (Player) -> ()): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText, p.ObjectText = "Interagir", title
	p.HoldDuration, p.MaxActivationDistance, p.RequiresLineOfSight = .5, 11, false
	p.Parent = marker; p.Triggered:Connect(callback)
	return p
end
function Service.BindMap(map: Model): boolean
	if active or map.Name ~= Config.Map or not map:IsDescendantOf(Workspace) then return false end
	local prompts: { ProximityPrompt } = {}
	local names = table.clone(Config.SpecialMarkers)
	for name in Config.Interactions do table.insert(names, name) end
	local markers = MapRegistration.Bind(map, { Region = Config.Region, Center = "CostaCentro", Spawn = "CostaSpawn", Boss = "CostaBossSpawn", Markers = names, FloorMarkers = { "CostaGuardPad1", "CostaGuardPad2", "CostaGuardPad3", "CostaCheckpoint" } }, function()
		active = nil
		for _, p in prompts do p:Destroy() end
		for _, bot in BotService.List() do
			local kind = bot:GetAttribute("StoryKillKind")
			if kind == "fx_costa_guard" or kind == "fx_costa_boss" then BotService.Remove(bot) end
		end
	end)
	if not markers then return false end
	active = map
	for name, marker in markers do
		if Config.Interactions[name] or name == "CostaContato" or name == "CostaFavor" or name == "CostaHumanoider" or name:match("^CostaAcesso") then
			table.insert(prompts, prompt(marker, if name == "CostaHumanoider" then "Humanoider_20" else "Costa Dourada", function(player) Service.Interact(player, marker) end))
		end
	end
	table.insert(prompts, prompt(markers.CostaCheckpoint, "Salvar chegada", function(player)
		if active == map and StoryService.CanInteract(player, markers.CostaCheckpoint, 14)
			and StoryService.RegionOf(player) == Config.Region and StoryService.HasFlag(player, "costa_dourada_unlocked") then WorldService.SetCheckpoint(player, Config.Region, "chegada") end
	end))
	for i = 1, 3 do
		BotService.Spawn({ HomeMap = map, CharacterId = "Swift", Name = "Guarda da organização", CFrame = markers["CostaGuardPad" .. i].CFrame * CFrame.new(0, 3, 0),
			Behavior = "aggressive", Team = "fx_costa", Attributes = { FXEnemy = true, StoryKillKind = "fx_costa_guard", MaxHealth = 180 }, Tuning = { SeekRadius = 35 } })
	end
	-- Kit provisório existente. Artefatos de múltiplos mundos próprios permanecem pendentes.
	BotService.Spawn({ HomeMap = map, CharacterId = "Kira", Name = "Regente Dourado", CFrame = markers.CostaBossSpawn.CFrame * CFrame.new(0, 3, 0),
		Behavior = "aggressive", Team = "fx_costa", Attributes = { FXEnemy = true, StoryKillKind = "fx_costa_boss", MaxHealth = 750, DamageMult = 1.6 }, Tuning = { SeekRadius = 55 } })
	return true
end
function Service.Start()
	local function tryMap()
		if active then return end
		local map = Workspace:FindFirstChild(Config.Map, true)
		if map and map:IsA("Model") then Service.BindMap(map) end
	end
	task.defer(tryMap)
	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant.Name == Config.Map or descendant.Name:match("^Costa") then task.defer(tryMap) end
	end)
end
return Service
