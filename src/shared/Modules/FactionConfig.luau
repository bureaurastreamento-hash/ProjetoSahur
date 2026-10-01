--!strict
local Config = {}
Config.Outlaw = "fora_da_lei"
Config.Government = "governo"
Config.List = {
	{ Id = Config.Outlaw, Name = "Fora da Lei", Description = "Abra seu caminho. Vitórias válidas no PvP de mundo aberto aumentam sua bounty.", Color = Color3.fromRGB(231, 155, 79) },
	{ Id = Config.Government, Name = "Governo", Description = "Enfrente os procurados. Vitórias válidas contra jogadores Fora da Lei aumentam sua honra.", Color = Color3.fromRGB(82, 184, 226) },
}
function Config.Valid(id: any): boolean
	return id == Config.Outlaw or id == Config.Government
end
function Config.Name(id: string): string
	for _, entry in Config.List do if entry.Id == id then return entry.Name end end
	return "Escolha uma facção"
end
function Config.HonorTitle(points: number): string
	if points >= 10000000 then return "Guardião da Ordem" end
	if points >= 5000000 then return "Comandante" end
	if points >= 1000000 then return "Capitão" end
	if points >= 250000 then return "Oficial" end
	if points >= 50000 then return "Patrulheiro" end
	return "Recruta"
end
return Config
