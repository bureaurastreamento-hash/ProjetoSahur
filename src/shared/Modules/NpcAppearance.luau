--!strict
-- Exclusivo dos rigs gerados de inimigos. Anciões continuam com seus modelos/avatares únicos.
local Appearance = {}
local SKIN = { Color3.fromRGB(230, 185, 146), Color3.fromRGB(177, 122, 82), Color3.fromRGB(112, 76, 54) }
local CLOTH = { Color3.fromRGB(92, 108, 79), Color3.fromRGB(108, 68, 57), Color3.fromRGB(63, 83, 108), Color3.fromRGB(123, 105, 71), Color3.fromRGB(77, 66, 96), Color3.fromRGB(58, 81, 79) }
function Appearance.Description(index: number): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[(index - 1) % #SKIN + 1]
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor = CLOTH[(index - 1) % #CLOTH + 1]
	local legs = Color3.fromRGB(44, 43, 48)
	desc.LeftLegColor, desc.RightLegColor = legs, legs
	-- Catálogo oficial Roblox, gratuito e verificado via MarketplaceService (30/09).
	desc.HairAccessory = if index % 2 == 0 then "376548738" else "63690008"
	desc.Shirt = if index % 3 == 0 then 3670737444 else 144076358
	desc.Pants = 398633812
	if index % 4 == 0 then desc.HatAccessory = "48474313" end
	return desc
end
function Appearance.Dress(model: Model)
	local torso = model:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then return end
	local function piece(name: string, size: Vector3, offset: Vector3, color: Color3)
		local part = Instance.new("Part")
		part.Name, part.Size, part.Color = name, size, color
		part.Material = Enum.Material.Fabric
		part:SetAttribute("NpcClothing", true)
		part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, true
		part.CFrame = torso.CFrame * CFrame.new(offset)
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = torso, part, part
	end
	piece("CintoNPC", Vector3.new(2.04, .2, 1.04), Vector3.new(0, -.72, 0), Color3.fromRGB(60, 43, 31))
	piece("BolsaNPC", Vector3.new(.48, .5, .22), Vector3.new(.58, -.43, -.61), Color3.fromRGB(110, 83, 52))
	model:SetAttribute("GenericNpcAppearance", true)
end
return Appearance
