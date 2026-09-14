--[[
	SOMENTE LEITURA. Cole na barra de comando do Studio (View > Command Bar) e
	copie a saída do Output para o chat. Não altera nada no lugar.
	Lista até MAX_DEPTH níveis de ReplicatedStorage, Workspace, StarterGui,
	StarterPlayer, StarterPack, ServerStorage, SoundService e Lighting.
]]
local MAX_DEPTH = 4
local roots = { "ReplicatedStorage", "Workspace", "StarterGui", "StarterPlayer", "StarterPack", "ServerStorage", "SoundService", "Lighting" }
local function dump(inst, depth)
	if depth > MAX_DEPTH then return end
	local extra = ""
	if inst:IsA("Animation") then extra = " id=" .. inst.AnimationId
	elseif inst:IsA("Sound") then extra = " id=" .. inst.SoundId
	elseif inst:IsA("MeshPart") then extra = " mesh=" .. inst.MeshId
	elseif inst:IsA("Model") and inst:FindFirstChildOfClass("Humanoid") then extra = " (Humanoid " .. tostring(inst:FindFirstChildOfClass("Humanoid").RigType) .. ")" end
	print(string.rep("  ", depth) .. inst.Name .. " [" .. inst.ClassName .. "]" .. extra)
	local children = inst:GetChildren()
	if #children > 40 then
		print(string.rep("  ", depth + 1) .. "... " .. #children .. " filhos (mostrando 40)")
	end
	for i, c in ipairs(children) do
		if i > 40 then break end
		dump(c, depth + 1)
	end
end
for _, name in ipairs(roots) do
	local ok, svc = pcall(game.GetService, game, name)
	if ok and svc then dump(svc, 0) end
end
print("== Avatar: verifique em Game Settings > Avatar se está em R6 ==")
