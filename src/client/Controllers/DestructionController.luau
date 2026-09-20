--!strict
--[[
	DestructionController (cliente)
	Feedback do cenário destrutível (DestructionService): poeira/lascas onde um tijolo quebrou e onde uma
	árvore tombou, com som de impacto. Só visual: quem solta/repõe as peças é o servidor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local FX = require(Modules:WaitForChild("FX"))
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local VFXLibrary = require(Modules:WaitForChild("VFXLibrary"))

local DestructionController = {}

DestructionController.MaxFxPerNotify = 6 -- tijolos por golpe com efeito (o resto só voa)

local localPlayer = Players.LocalPlayer

local function onNotify(attacker: Model?, positions: { Vector3 }, kind: string)
	local character = attacker or localPlayer.Character
	if not character or typeof(positions) ~= "table" then
		return
	end
	local effect = VFXLibrary.Get("Shared", if kind == "tree" then "TreeFall" else "BrickBreak")
	local n = 0
	for _, pos in positions do
		if typeof(pos) ~= "Vector3" then
			continue
		end
		n += 1
		if n > DestructionController.MaxFxPerNotify then
			break
		end
		if effect then
			FX.PlayComposed(character, effect, pos)
		end
	end
	if n > 0 then
		FX.PlaySoundAt(character, "Shared", if kind == "tree" then "WallSplat" else "Punch_Hit")
		if kind == "tree" and character == localPlayer.Character then
			FX.Shake(0.4, 0.25)
		end
	end
end

function DestructionController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyDestruction).OnClientEvent:Connect(onNotify)
end

return DestructionController
