--!strict
local Layout = require(game:GetService("ReplicatedStorage").Shared.Modules.IslandLayout)
local Module = {}
function Module.Apply(world: Workspace)
	if world:GetAttribute("IslandLayoutVersion") == Layout.Version then return end
	local parts: { { part: BasePart, cf: CFrame, offset: Vector3 } } = {}
	local pivots: { { model: Model, cf: CFrame, offset: Vector3 } } = {}
	for _, item in world:GetDescendants() do
		-- Cidade é um conjunto independente que invade a caixa antiga do Eclipse; preservar inteiro.
		if item.Name == "FXCidadeAmbar" or item:FindFirstAncestor("FXCidadeAmbar") then continue end
		if item:IsA("BasePart") then
			local offset = Layout.OffsetAt(item.Position)
			if offset.Magnitude > 0 then table.insert(parts, { part = item, cf = item.CFrame, offset = offset }) end
		elseif item:IsA("Model") and not item.PrimaryPart then
			local cf = item:GetPivot()
			local offset = Layout.OffsetAt(cf.Position)
			if offset.Magnitude > 0 then table.insert(pivots, { model = item, cf = cf, offset = offset }) end
		end
	end
	-- Partes soldadas podem mover as vizinhas: usar o CFrame original evita somar o deslocamento duas vezes.
	for _, item in parts do item.part.CFrame = item.cf + item.offset end
	for _, item in pivots do item.model.WorldPivot = item.cf + item.offset end
	world:SetAttribute("IslandLayoutVersion", Layout.Version)
end
return Module
