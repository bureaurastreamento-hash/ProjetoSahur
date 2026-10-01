--!strict
-- Enigma opcional físico; cada jogador resolve sua sequência. Recompensa única no perfil.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local DataService = require(script.Parent.DataService)
local StoryService = require(script.Parent.StoryService)
local Remotes = require(Modules.RemoteEvents)
local RateLimiter = require(Modules.RateLimiter)
local Service = {}
local limiter = RateLimiter.new(2, 2)
local sequence = { 3, 1, 2 } -- Lua → Sol → Névoa; pista no diário, sem GPS de segredo
local markers: { [number]: BasePart } = {}
local progress: { [Player]: number } = {}
local function toast(player: Player, title: string, text: string)
	Remotes.GetEvent(Remotes.Events.NotifyQuest):FireClient(player, "toast", { title = title, text = text })
end
function Service.Activate(player: Player, index: number, marker: BasePart): boolean
	local profile = DataService.GetProfile(player)
	if not profile or DataService.IsSessionOnly(player) or markers[index] ~= marker or not marker:IsDescendantOf(Workspace)
		or not StoryService.CanInteract(player, marker, 12) or not limiter:Allow(player) then return false end
	if profile.story.flags.relic_lentes_solved then toast(player, "Lentes alinhadas", "Você já recuperou o núcleo. O projeto está na forja."); return false end
	local step = progress[player] or 1
	if sequence[step] ~= index then
		progress[player] = nil
		toast(player, "A luz se desfez", "As lentes voltaram ao início. Leia o diário do marinheiro.")
		return false
	end
	if step < #sequence then
		progress[player] = step + 1
		toast(player, "Uma lente respondeu", "A luz permanece por um instante. Continue o alinhamento.")
		return true
	end
	-- Sem yield entre flag e item; repetir prompt/reconectar não duplica a recompensa.
	profile.story.flags.relic_lentes_solved = true
	progress[player] = nil
	DataService.AddItem(player, "mat:nucleo_marinho", 1)
	DataService.MarkDirty(player)
	StoryService.Refresh(player)
	toast(player, "Núcleo Marinho recuperado", "Projeto da Lâmina das Marés descoberto. Confira os materiais na forja.")
	return true
end
function Service.Start()
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "EnigmaDasLentes", Workspace
	local origin = Vector3.new(246, 1, 178)
	local ray = Workspace:Raycast(origin + Vector3.new(0, 100, 0), Vector3.new(0, -150, 0))
	if not ray then folder:Destroy(); return end
	origin = ray.Position
	for index, name in { "Sol", "Névoa", "Lua" } do
		local stone = Instance.new("Part")
		stone.Name, stone.Anchored, stone.Material, stone.Size = "Suporte" .. index, true, Enum.Material.Slate, Vector3.new(2, 3, 2)
		stone.Color, stone.Position, stone.Parent = Color3.fromRGB(91, 102, 109), origin + Vector3.new((index-2)*5, 1.5, 0), folder
		local lens = Instance.new("Part")
		lens.Name, lens.Anchored, lens.Shape = name, true, Enum.PartType.Ball
		lens.Size, lens.Position, lens.Material = Vector3.new(1.4, 1.4, 1.4), stone.Position + Vector3.new(0, 2.2, 0), Enum.Material.Glass
		lens.Color, lens.Transparency, lens.Parent = Color3.fromRGB(89, 168 + index * 20, 191), .2, folder
		markers[index] = lens
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText, prompt.HoldDuration, prompt.MaxActivationDistance = "Girar lente", name, .6, 10
		prompt.Parent = lens
		prompt.Triggered:Connect(function(player) Service.Activate(player, index, lens) end)
	end
	local book = Instance.new("Part")
	book.Name, book.Size, book.Anchored, book.Material = "Diário do marinheiro", Vector3.new(2, .4, 1.5), true, Enum.Material.Wood
	book.Position, book.Color, book.Parent = origin + Vector3.new(0, .3, 5), Color3.fromRGB(101, 65, 41), folder
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText, prompt.MaxActivationDistance, prompt.Parent = "Ler diário", book.Name, 10, book
	prompt.Triggered:Connect(function(player)
		if StoryService.CanInteract(player, book, 12) then
			StoryService.Say(player, "Quando a Lua se recolheu, o Sol tocou a água. Só então a Névoa revelou o caminho. Três lentes, três sinais; o diário termina aqui.", "Diário do marinheiro")
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player) progress[player] = nil end)
end
return Service
