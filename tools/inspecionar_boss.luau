--[[
	SOMENTE LEITURA. Cole na barra de comando do Studio (View > Command Bar) e copie a saída do
	Output para o chat. Mostra a estrutura do BossModel: partes (tamanho), Motor6D (Part0 -> Part1),
	Humanoid/HRP, partes sem junta. Não altera nada.
]]
local ServerStorage = game:GetService("ServerStorage")
local model = ServerStorage:FindFirstChild("BossModel", true) or workspace:FindFirstChild("BossModel", true)
if not model then
	print("[Boss] BossModel não encontrado em ServerStorage/Workspace")
	return
end
print(("[Boss] %s (%s) em %s"):format(model.Name, model.ClassName, model:GetFullName()))
local hum = model:FindFirstChildOfClass("Humanoid")
print("[Boss] Humanoid:", hum and hum.RigType.Name or "NENHUM", "| HRP:", model:FindFirstChild("HumanoidRootPart", true) and "sim" or "NÃO")
local cf, size = model:GetBoundingBox()
print(("[Boss] bounding box %.1f x %.1f x %.1f em %s"):format(size.X, size.Y, size.Z, tostring(cf.Position)))
local parts, motors, jointed = 0, 0, {}
for _, d in model:GetDescendants() do
	if d:IsA("Motor6D") then
		motors += 1
		print(("  Motor6D %s: %s -> %s (em %s)"):format(d.Name, d.Part0 and d.Part0.Name or "?", d.Part1 and d.Part1.Name or "?", d.Parent and d.Parent.Name or "?"))
		if d.Part0 then jointed[d.Part0] = true end
		if d.Part1 then jointed[d.Part1] = true end
	end
end
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		local flag = if jointed[d] then "" else "  (SEM junta: vai ser soldada na mais próxima)"
		print(("  %s [%s] %.1fx%.1fx%.1f anch=%s pai=%s%s"):format(d.Name, d.ClassName, d.Size.X, d.Size.Y, d.Size.Z, tostring(d.Anchored), d.Parent.Name, flag))
	end
end
print(("[Boss] %d partes, %d Motor6D"):format(parts, motors))
