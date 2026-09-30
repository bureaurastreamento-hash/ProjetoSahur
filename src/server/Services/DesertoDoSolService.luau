--!strict
--[[
	Ilha 2 do Capítulo 1 — DESERTO DO SOL (Parte 2; BIBLIA_CAMPANHA_CAP1_v0.1.md, Missões 6–10).
	Mapa = FXPilaresIsland + santuário/ruínas da ArenaExtras (ids "ilha_pilares"/"Pilares" mantidos para saves e Rojo).
	Marcadores (pasta Historia, tools/gerar_ilha_pilares_fx.py): EscavacaoPad*, MestreSpot, DiscipuloPad,
	CamaraMarker, SacerdoteSpawn. "Calor" (Missão 6) = chegar pelo portal (StoryService.ArriveRegion).
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local BotService = require(script.Parent:WaitForChild("BotService"))
local StoryService = require(script.Parent:WaitForChild("StoryService"))
local BuildService = require(script.Parent.BuildService)

local DesertoDoSolService = {}
local MASTER = "Mestre da Respiração"

local function prompt(parent: Instance, action: string, object: string, hold: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText, p.ObjectText = action, object
	p.HoldDuration, p.MaxActivationDistance, p.RequiresLineOfSight = hold, 11, false
	p.Parent = parent
	return p
end

-- NPC parado (sem combate), rig R6 padrão com cores de deserto.
local function spawnMaster(spot: BasePart, parent: Instance)
	local ok, npc = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(176, 128, 86)
		desc.HeadColor, desc.LeftArmColor, desc.RightArmColor, desc.TorsoColor = skin, skin, skin, Color3.fromRGB(196, 170, 120)
		desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(120, 86, 52), Color3.fromRGB(120, 86, 52)
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not npc then return end
	npc.Name = "MestreDaRespiracao"
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then npc:Destroy(); return end
	humanoid.DisplayName = MASTER
	for _, d in npc:GetDescendants() do
		if d:IsA("BasePart") then d.CanCollide = false end
	end
	root.Anchored = true
	root.CFrame = spot.CFrame.Rotation + Vector3.new(spot.Position.X, spot.Position.Y + spot.Size.Y / 2 + 3, spot.Position.Z) -- pela raiz, em pé
	npc.Parent = parent
	prompt(root, "Conversar", MASTER, 0).Triggered:Connect(function(player: Player)
		local character = player.Character
		local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
		local playerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not playerRoot or not playerRoot:IsA("BasePart") or not playerHumanoid or playerHumanoid.Health <= 0
			or (playerRoot.Position - root.Position).Magnitude > 14 then return end
		if StoryService.Wants(player, "fx_mestre") then
			StoryService.Say(player, "Você luta prendendo o ar. Quem prende o ar morre cansado. Respire com o golpe, não contra ele. "
				.. "Meu discípulo vai atacar você: apare duas vezes (F na hora do golpe) e eu vejo se aprendeu.", MASTER)
			StoryService.Progress(player, "fx_mestre", 1)
		elseif StoryService.HasCompleted(player, "respira") and not StoryService.HasFlag(player, "tecnica_m8_aprendeu") then
			BuildService.LearnTechnique(player)
			StoryService.SetFlag(player, "tecnica_m8_aprendeu")
			StoryService.Say(player, "Respire com o golpe, não contra ele. Você aprendeu a Técnica corporal.", MASTER)
		else
			StoryService.Say(player, "O corpo lembra o que a cabeça esquece. Volte quando quiser treinar.", MASTER)
		end
	end)
end

local function populate(island: Model)
	local story = island:FindFirstChild("Historia")
	if not story then
		warn("[DesertoDoSol] pasta Historia não encontrada em FXPilaresIsland")
		return
	end
	for _, pad in story:GetChildren() do
		if pad:IsA("BasePart") and pad.Name:match("^EscavacaoPad") then
			BotService.Spawn({ CharacterId = "Jotaro", Name = "Homem de Pedra", CFrame = pad.CFrame * CFrame.new(0, 3, 0), Behavior = "aggressive", Team = "fx_pedra",
				Attributes = { FXEnemy = true, StoryKillKind = "fx_pedra_enemy", MaxHealth = 170 }, Tuning = { SeekRadius = 34 } })
		end
	end
	local masterSpot = story:FindFirstChild("MestreSpot")
	if masterSpot and masterSpot:IsA("BasePart") then spawnMaster(masterSpot, story) end
	local disciple = story:FindFirstChild("DiscipuloPad")
	if disciple and disciple:IsA("BasePart") then
		BotService.Spawn({ CharacterId = "Swift", Name = "Discípulo da Respiração", CFrame = disciple.CFrame * CFrame.new(0, 3, 0), Behavior = "aggressive", Team = "fx_discipulo",
			Attributes = { FXEnemy = true, MaxHealth = 220, DamageMult = .5 }, Tuning = { SeekRadius = 16 } })
	end
	local chamber = story:FindFirstChild("CamaraMarker")
	if chamber and chamber:IsA("BasePart") then
		prompt(chamber, "Examinar", "Símbolo antigo", 1).Triggered:Connect(function(player: Player)
			if not StoryService.CanInteract(player, chamber, 14) then return end
			if StoryService.Wants(player, "fx_camara") then
				StoryService.Progress(player, "fx_camara", 1)
			else
				StoryService.Say(player, StoryService.DesertState(player))
			end
			StoryService.OfferDesertEco(player)
		end)
		-- Mecanismos provisórios em runtime; os modelos da Câmara permanecem intactos.
		for index = 1, 3 do
			local seal = Instance.new("Part")
			seal.Name, seal.Size = "MecanismoCamara" .. index, Vector3.new(1.5, 1, 1.5)
			seal.Anchored, seal.CanCollide = true, false
			seal.Material, seal.Color = Enum.Material.Metal, Color3.fromRGB(110, 170, 190)
			seal.CFrame = chamber.CFrame * CFrame.new((index - 2) * 4, 0, 4)
			seal.Parent = story
			local numeral = ({ "I", "II", "III" })[index]
			prompt(seal, "Alinhar", "Mecanismo " .. numeral, 0.6).Triggered:Connect(function(player: Player)
				if StoryService.AlignChamberSeal(player, index, seal) and StoryService.HasFlag(player, "camara_transferencia_preparada") then
					StoryService.OfferDesertEco(player)
				end
			end)
		end
	end
	local priest = story:FindFirstChild("SacerdoteSpawn")
	if priest and priest:IsA("BasePart") then
		BotService.Spawn({ CharacterId = "Kira", Name = "Sacerdote do Sol Negro", CFrame = priest.CFrame * CFrame.new(0, 3, 0), Behavior = "aggressive", Team = "fx_solnegro",
			Attributes = { FXEnemy = true, StoryKillKind = "fx_solnegro_boss", MaxHealth = 450, DamageMult = 1.35 },
			Tuning = { SeekRadius = 45, AbilityChancePerTick = .2, BlockChancePerTick = .25 } })
	end
end

function DesertoDoSolService.Start()
	task.defer(function()
		local sahur = Workspace:FindFirstChild("Sahur")
		local island = sahur and sahur:FindFirstChild("FXPilaresIsland")
		if island and island:IsA("Model") then populate(island) end
	end)
end

return DesertoDoSolService
