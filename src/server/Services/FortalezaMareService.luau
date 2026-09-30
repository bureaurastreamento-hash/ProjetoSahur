--!strict
local Workspace = game:GetService("Workspace")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local EnemyConfig = require(Modules.EnemyConfig)
local Config = require(Modules.FortalezaMareConfig)
local WorldConfig = require(Modules.WorldConfig)
local Registration = require(script.Parent.Parent.Modules.CampaignMapRegistration)
local StoryService = require(script.Parent.StoryService)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)
local HealthService = require(script.Parent.HealthService)
local BotService = require(script.Parent.BotService)
local Service = {}
local active: Model? = nil

local function fightingAvatar(player: Player): boolean
	for _, bot in BotService.List() do
		if bot:GetAttribute("StoryKillKind") == "fx_mare_avatar" and HealthService.IsAlive(bot) then
			for _, participant in HealthService.PveParticipants(bot) do if participant == player then return true end end
		end
	end
	return false
end
function Service.Interact(player: Player, marker: BasePart): boolean
	local p = DataService.GetProfile(player)
	local region = WorldConfig.GetRegion(Config.Region)
	if not p or not region or not region.Available or not p.story.flags.fortaleza_mare_unlocked
		or not StoryService.CanInteract(player, marker, 14) or StoryService.RegionOf(player) ~= Config.Region then return false end
	local flags, counters = p.story.flags, p.story.counters
	if marker.Name == "MareHumanoider" then
		local summary = Config.Wings(flags)
		if summary ~= "" then StoryService.Say(player, summary) else StoryService.TalkToGuide(player) end
		return false
	elseif marker.Name == "MarePrepararDispositivo" then
		if flags.mare_dispositivo_preparado or not p.story.traces.carlos_era01 or not p.story.traces.carlos_eclipse01 or not p.story.traces.carlos_mare01 then return false end
		StoryService.SetFlag(player, "mare_dispositivo_preparado")
		StoryService.Refresh(player)
		StoryService.Say(player, "Os Rastros permitiram preparar o dispositivo de Carlos. Um método alternativo estará disponível na estabilização final.")
		return true
	end
	local wing = ({ MareAlaCivil = "civil", MareAlaRisco = "risco" })[marker.Name]
	if wing then
		if flags["mare_ala_" .. wing .. "_aberta"] then return false end
		local kind = "fx_mare_ala_" .. wing
		local initial = StoryService.Wants(player, kind)
		local other = if wing == "civil" then "risco" else "civil"
		if not initial and not flags["mare_ala_" .. other .. "_aberta"] then return false end
		StoryService.SetFlag(player, "mare_ala_" .. wing .. "_aberta")
		if not initial then StoryService.SetFlag(player, "mare_ala_" .. wing .. "_tardia") end
		if wing == "risco" then StoryService.SetFlag(player, "mare_informacao_critica") end
		if initial then StoryService.ProgressOnce(player, kind, marker.Name, true) end
		StoryService.Refresh(player)
		StoryService.Say(player, "A ala " .. wing .. " foi aberta. " .. Config.Wings(flags))
		return true
	end
	local action = Config.Interactions[marker.Name]
	if not action then return false end
	if action.Kind == "fx_mare_ancora" and not fightingAvatar(player) then return false end
	if action.Kind == "fx_mare_estabilizar" then
		local ready = (flags.final_cap1_humanoider and (counters.fx_mare_seguro or 0) >= 2)
			or (flags.final_cap1_toduro and (counters.fx_mare_interno or 0) >= 3)
			or (flags.final_cap1_alternativo and flags.mare_dispositivo_preparado and (counters.fx_mare_dispositivo or 0) >= 1)
		if not ready then return false end
	end
	if not StoryService.ProgressOnce(player, action.Kind, marker.Name, true) then return false end
	if action.Kind == "fx_mare_rastro" then
		p.story.traces.carlos_mare01 = true
		DataService.MarkDirty(player)
	elseif action.Kind == "fx_mare_dispositivo" then
		StoryService.SetFlag(player, "fx_assinatura_protagonista")
	elseif action.Kind == "fx_mare_terminal" then
		StoryService.SetFlag(player, "cap2_unlocked")
	end
	StoryService.Say(player, action.Text, if marker.Name == "MareToduro" then "ToduroDemais" elseif marker.Name == "MareAdryan" then "Adryan" else nil)
	return true
end
local function prompt(marker: BasePart, callback: (Player) -> ()): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText, p.ObjectText = "Interagir", "Fortaleza Maré"
	p.HoldDuration, p.MaxActivationDistance, p.RequiresLineOfSight = .5, 11, false
	p.Parent = marker; p.Triggered:Connect(callback)
	return p
end
function Service.BindMap(map: Model): boolean
	if active or map.Name ~= Config.Map or not map:IsDescendantOf(Workspace) then return false end
	local prompts: { ProximityPrompt } = {}
	local names = table.clone(Config.SpecialMarkers)
	for name in Config.Interactions do table.insert(names, name) end
	local markers = Registration.Bind(map, { Region = Config.Region, Center = "MareCentro", Spawn = "MareSpawn", Boss = "MareBossSpawn", Markers = names,
		FloorMarkers = { "MareColapsoPad1", "MareColapsoPad2", "MareCheckpoint" } }, function()
		active = nil
		for _, p in prompts do p:Destroy() end
		for _, bot in BotService.List() do
			local kind = bot:GetAttribute("StoryKillKind")
			if kind == "fx_mare_avatar" or kind == "fx_mare_colapso_boss" then BotService.Remove(bot) end
		end
	end)
	if not markers then return false end
	active = map
	for name, marker in markers do
		if Config.Interactions[name] or name == "MareHumanoider" or name == "MareAlaCivil" or name == "MareAlaRisco" or name == "MarePrepararDispositivo" then
			table.insert(prompts, prompt(marker, function(player) Service.Interact(player, marker) end))
		end
	end
	table.insert(prompts, prompt(markers.MareCheckpoint, function(player)
		if active == map and StoryService.CanInteract(player, markers.MareCheckpoint, 14)
			and StoryService.RegionOf(player) == Config.Region and StoryService.HasFlag(player, "fortaleza_mare_unlocked") then WorldService.SetCheckpoint(player, Config.Region, "chegada") end
	end))
	for i, character in { "Jotaro", "Swift" } do
		BotService.Spawn(EnemyConfig.Options(5, { HomeMap = map, CharacterId = character, Name = "Eco alterado da Fratura", CFrame = markers["MareColapsoPad" .. i].CFrame * CFrame.new(0, 3, 0),
			Behavior = "aggressive", Team = "fx_mare", Attributes = { FXEnemy = true, StoryKillKind = "fx_mare_colapso_boss", StoryObjectiveKey = "mare_colapso_" .. i, MaxHealth = 450, DamageMult = 1.3 }, Tuning = { SeekRadius = 40 } }))
	end
	-- Combate provisório; quatro fases/alternância de regiões exigem kit e cena próprios, ainda pendentes.
	BotService.Spawn(EnemyConfig.Options(5, { HomeMap = map, CharacterId = "Jotaro", Name = "Avatar da Fratura", CFrame = markers.MareBossSpawn.CFrame * CFrame.new(0, 3, 0),
		Behavior = "aggressive", Team = "fx_mare", Attributes = { FXEnemy = true, StoryKillKind = "fx_mare_avatar", MaxHealth = 1000, DamageMult = 1.7 }, Tuning = { SeekRadius = 65 } }))
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
		if descendant.Name == Config.Map or descendant.Name:match("^Mare") then task.defer(tryMap) end
	end)
end
return Service
