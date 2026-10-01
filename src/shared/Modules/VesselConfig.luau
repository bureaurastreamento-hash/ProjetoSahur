--!strict
local Config = {}
export type Offer = { Name: string, Asset: string, Price: number, Length: number, Speed: number, Turn: number, Cruise: boolean }
Config.Offers = {
	remo = { Name = "Barco a remo", Asset = "boat-row-small", Price = 0, Length = 16, Speed = 23, Turn = 1.2, Cruise = false },
	lancha = { Name = "Lancha", Asset = "boat-speed-a", Price = 60, Length = 22, Speed = 58, Turn = .8, Cruise = false },
	strength = { Name = "Strength · Cruzeiro", Asset = "ship-ocean-liner", Price = 350, Length = 120, Speed = 42, Turn = .34, Cruise = true },
} :: { [string]: Offer }
export type Port = { Id: string, Name: string, Land: Vector3, Outward: Vector3, RequiredFlag: string? }
Config.Ports = {
	{ Id = "ilha_tutorial", Name = "Porto da Névoa", Land = Vector3.new(40, 0, 232), Outward = Vector3.new(0, 0, 1) },
	{ Id = "ilha_pilares", Name = "Deserto do Sol", Land = Vector3.new(643, 0, -410), Outward = Vector3.new(-1, 0, 0), RequiredFlag = "ilha_pilares_unlocked" },
	{ Id = "ilha_sol_partido", Name = "Rota do Eclipse", Land = Vector3.new(1750, 0, 140), Outward = Vector3.new(0, 0, 1), RequiredFlag = "ilha_sol_partido_unlocked" },
} :: { Port }
function Config.ValidInput(throttle: any, steer: any): boolean
	return typeof(throttle) == "number" and throttle == throttle and math.abs(throttle) <= 1
		and typeof(steer) == "number" and steer == steer and math.abs(steer) <= 1
end
return Config
