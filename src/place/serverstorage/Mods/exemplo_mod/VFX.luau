--[[
	VFX — efeitos compostos por código (mesmo formato da VFXLibrary do jogo).
	Effects: chave "Pasta/Nome" — para uma habilidade do seu personagem use "<CharacterId>/<AbilityId>" (toca no cast)
	e "<CharacterId>/<AbilityId>_Hit" (toca em quem levou). Chaves que já existem no jogo são ignoradas.
	Camadas: mesh { mesh, color, material?, size0, size1 (números = studs), t, spin?, tr0?, tr1?, ground?, up?, ease? },
	emit { texture, color, count, size, life, speed, spread? }, light { color, brightness, range, t }, sound { folder, name }.
	Cores: Color3 ou "$primary"/"$secondary" (cor do personagem). Meshes prontos: ShockCurl, ShockOpen, ShockGround, ShockRing...
	Meshes/Textures: ids de assets PÚBLICOS ou do grupo; `size` = tamanho nativo do mesh em studs.
]]
return {
	Meshes = {
		-- ExemploAnel = { id = 6026280813, size = Vector3.new(1, 0.1, 1) },
	},
	Textures = {
		-- ExemploFaisca = 6101261905,
	},
	Effects = {
		["Exemplo/Onda"] = {
			lifetime = 1.2,
			layers = {
				{ kind = "mesh", mesh = "ShockCurl", color = "$primary", material = Enum.Material.Neon, size0 = 4, size1 = 24, t = 0.55, tr0 = 0.15, tr1 = 1, ground = true, up = true, spin = Vector3.new(0, 140, 0), ease = "Quart" },
				{ kind = "mesh", mesh = "ShockGround", color = "$primary", material = Enum.Material.Neon, size0 = 2, size1 = 28, t = 0.5, tr0 = 0.1, tr1 = 1, ground = true, up = true, ease = "Quart" },
				{ kind = "light", color = "$primary", brightness = 4, range = 18, t = 0.4 },
			},
		},
		["Exemplo/Onda_Hit"] = {
			lifetime = 0.6,
			layers = {
				{ kind = "mesh", mesh = "ShockOpen", color = "$primary", material = Enum.Material.Neon, size0 = 2, size1 = 7, t = 0.3, tr0 = 0.3, tr1 = 1 },
			},
		},
	},
}
