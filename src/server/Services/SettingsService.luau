--!strict
--[[
	SettingsService (servidor)
	Configurações de controle/acessibilidade do jogador (Controls.Settings): valida RequestSetting e
	salva em profile.settings. O cliente lê pelo NotifyProfile (SettingsController).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Controls = require(Modules:WaitForChild("Controls"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local SettingsService = {}

local limiter = RateLimiter.new(10, 2)

function SettingsService.Start()
	Remotes.GetEvent(Remotes.Events.RequestSetting).OnServerEvent:Connect(function(player, key, value)
		if not limiter:Allow(player) then
			return
		end
		local valid = Controls.ValidateSetting(key, value)
		if valid == nil then
			return
		end
		local profile = DataService.GetProfile(player)
		if not profile then
			return
		end
		if profile.settings[key :: string] ~= valid then
			profile.settings[key :: string] = valid
			DataService.MarkDirty(player)
			if key == "CharacterModel" then
				-- troca de skin/modelo = respawn (como trocar de personagem); em combate espera o próximo
				local ok, CharacterService = pcall(require, script.Parent:WaitForChild("CharacterService"))
				if ok and player:GetAttribute("InMatch") ~= true then
					task.defer(function()
						(CharacterService :: any).Load(player)
					end)
				end
			end
		end
	end)
end

return SettingsService
