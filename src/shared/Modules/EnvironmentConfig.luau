--!strict
local Config = {}
-- Só cenários procedurais conhecidos. Arte da equipe e modelos externos não são percorridos.
Config.Roots = { FXPortDistricts = true, ChaoIlhas = true, FXVilaNova = true, FXCamposNevoa = true, FXTutorialIsland = true, FXPilaresIsland = true, FXSolPartidoIsland = true } :: { [string]: boolean }
-- Preencher com os IDs publicados no grupo após importar os arquivos CC0; vazio usa material nativo.
type Material = { Base: Enum.Material, Asset: string, ColorMap: string, NormalMap: string, RoughnessMap: string, Tile: number }
Config.Materials = {
	Grass = { Base = Enum.Material.Grass, Asset = "Grass001", ColorMap = "rbxassetid://78530402633298", NormalMap = "rbxassetid://102051815664477", RoughnessMap = "rbxassetid://94418273695890", Tile = 16 },
	Ground = { Base = Enum.Material.Ground, Asset = "Ground037", ColorMap = "rbxassetid://124729655648235", NormalMap = "rbxassetid://135513835202855", RoughnessMap = "rbxassetid://95816162640208", Tile = 12 },
	Sand = { Base = Enum.Material.Sand, Asset = "Ground093A", ColorMap = "rbxassetid://86053575375802", NormalMap = "rbxassetid://78011571088066", RoughnessMap = "rbxassetid://107794939267673", Tile = 18 },
	Wood = { Base = Enum.Material.WoodPlanks, Asset = "WoodFloor007", ColorMap = "rbxassetid://109255658926451", NormalMap = "rbxassetid://109538589648835", RoughnessMap = "rbxassetid://83987883373638", Tile = 8 },
	Brick = { Base = Enum.Material.Brick, Asset = "Bricks001", ColorMap = "rbxassetid://122291970445335", NormalMap = "rbxassetid://75487825203627", RoughnessMap = "rbxassetid://71773326671245", Tile = 10 },
	Rock = { Base = Enum.Material.Slate, Asset = "Rock030", ColorMap = "rbxassetid://79182887938259", NormalMap = "rbxassetid://70426301248713", RoughnessMap = "rbxassetid://91961913994001", Tile = 20 },
} :: { [string]: Material }
function Config.Kind(name: string, material: Enum.Material): string?
	local lower = name:lower()
	if lower:find("marker") or lower:find("pad") or lower:find("spawn") or lower:find("waypoint") or lower:find("core") then return nil end
	if lower:find("janela") and not lower:find("moldura") then return nil end
	if lower:find("agua") or lower:find("portal") or lower:find("fratur") or lower:find("lanterna") then return nil end
	if lower:find("molhada") or lower:find("praia") or lower:find("duna") then return "Sand" end
	if lower:find("tronco") or lower:find("palmeira") or lower:find("porta") or lower:find("moldura") or lower:find("barril")
		or lower:find("caixote") or lower:find("banco") or lower:find("balcao") or lower:find("poste") or lower:find("jardineira") then return "Wood" end
	if lower:find("trilha") or lower:find("caminho") or lower:find("rua") then return "Ground" end
	if lower:find("telhado") or lower:find("chamine") or lower:find("corpo") and lower:find("casa") then return "Brick" end
	if lower:find("rocha") or lower:find("pedra") or lower:find("coluna") or lower:find("fundacao") or lower:find("praca") then return "Rock" end
	if lower:match("^topo%d") then return if material == Enum.Material.Sand or material == Enum.Material.Sandstone then "Sand" else "Grass" end
	if material == Enum.Material.Grass then return "Grass" end
	return nil
end
return Config
