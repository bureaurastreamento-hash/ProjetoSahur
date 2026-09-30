--[[
	Cosmetics — capas/auras e emotes do mod. Só visual (nunca dá buff). Na sala do mod todo mundo tem.
	Item: { Id, Name, Category = "cape"|"aura", Color = Color3, Style? (aura: wisps|flame|smoke|sparkle|electric) }
	Emote: { Id, Name, Kind = "emote"|"scene", Duration? (scene), Color?, Theme? } — animação em Animations/Emotes/<Id>.
	Ids não podem colidir com os do jogo (cape_red, aura_ember, wave, dance...). Prefixe com o Id do mod.
]]
return {
	Items = {
		{ Id = "exemplo_cape", Name = "Capa Esmeralda", Category = "cape", Color = Color3.fromRGB(40, 200, 120) },
		{ Id = "exemplo_aura", Name = "Aura Esmeralda", Category = "aura", Color = Color3.fromRGB(80, 255, 160), Style = "sparkle" },
	},
	Emotes = {
		{ Id = "exemplo_pose", Name = "Pose Esmeralda", Kind = "emote" },
	},
}
