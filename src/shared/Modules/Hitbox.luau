--!strict
--[[
	Hitbox
	Consultas espaciais para encontrar personagens vivos (Model com Humanoid).
	Usado pelo servidor para detecção autoritativa. R6.
]]

local Workspace = game:GetService("Workspace")

local Hitbox = {}

local function isAlive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function collect(parts: { BasePart }, exclude: Model, maxTargets: number): { Model }
	local found: { Model } = {}
	local seen: { [Model]: boolean } = {}
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model ~= exclude and not seen[model] and isAlive(model) then
			seen[model] = true
			table.insert(found, model)
			if #found >= maxTargets then
				break
			end
		end
	end
	return found
end

local function params(exclude: Model): OverlapParams
	local p = OverlapParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = { exclude }
	return p
end

--- Caixa à frente do HumanoidRootPart do atacante.
function Hitbox.InFront(attacker: Model, range: number, width: number, height: number, maxTargets: number): { Model }
	local root = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return {}
	end
	local cf = root.CFrame * CFrame.new(0, 0, -range / 2)
	local size = Vector3.new(width, height, range)
	return collect(Workspace:GetPartBoundsInBox(cf, size, params(attacker)), attacker, maxTargets)
end

--- Esfera centrada no atacante.
function Hitbox.Around(attacker: Model, radius: number, maxTargets: number): { Model }
	local root = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return {}
	end
	return collect(Workspace:GetPartBoundsInRadius(root.Position, radius, params(attacker)), attacker, maxTargets)
end

return Hitbox
