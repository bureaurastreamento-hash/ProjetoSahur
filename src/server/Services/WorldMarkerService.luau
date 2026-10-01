--!strict
-- Oculta somente pontos técnicos dos cenários gerados; conserva nomes/posição para os serviços.
local Workspace = game:GetService("Workspace")
local Service = {}
local function hide(item: Instance)
	if not item:IsA("BasePart") then return end
	local name = item.Name
	if name:match("^VagantePad%d+$") or name:match("^EnemyPad%d+$") or name:match("^EscavacaoPad%d+$")
		or name:match("^DummyPad%d+$") or name:match("^MobPad_") or name == "DiscipuloPad"
		or name == "GuardiaoSpawn" or name == "SolarBossSpawn" or name == "TempleMarker" or name == "CamaraMarker" then
		item.Transparency, item.CanCollide, item.CanTouch, item.CanQuery = 1, false, false, false
	end
end
function Service.Start()
	local sahur = Workspace:WaitForChild("Sahur", 15)
	if not sahur then return end
	for _, item in sahur:GetDescendants() do hide(item) end
	sahur.DescendantAdded:Connect(hide)
end
return Service
