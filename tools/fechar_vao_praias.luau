--[[
	fechar_vao_praias.luau — roda NO STUDIO (MCP run_code), modo edição. Ctrl+Z desfaz.
	O chão das ilhas (Workspace.Sahur.ChaoIlhas) descia só até y -8 e as rampas da beira até -6.5, mas a areia
	do fundo do mar (Terrain) fica em y -12: sobrava um vão de água embaixo da ilha inteira (dava para nadar por
	baixo). Aqui: toda Part com fundo em -8 desce até FUNDO (1 stud enterrada na areia) e cada rampa (WedgePart)
	ganha um "pé" (Part "Pe<nome>") de FUNDO até a base dela. Idempotente (não duplica os pés).
]]
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local FUNDO = -13
local chao = workspace.Sahur.ChaoIlhas
local rec = ChangeHistoryService:TryBeginRecording("Fechar vão das praias")
local esticadas, pes = 0, 0
for _, d in chao:GetDescendants() do
	if d:IsA("Part") and not d.Name:match("^Pe") then
		local base = d.Position.Y - d.Size.Y / 2
		if math.abs(base - -8) < 0.05 then
			local topo = d.Position.Y + d.Size.Y / 2
			d.Size = Vector3.new(d.Size.X, topo - FUNDO, d.Size.Z)
			d.CFrame = d.CFrame + Vector3.new(0, (topo + FUNDO) / 2 - d.Position.Y, 0)
			esticadas += 1
		end
	elseif d:IsA("WedgePart") and not d.Parent:FindFirstChild("Pe" .. d.Name) then
		local base = d.Position.Y - d.Size.Y / 2
		if base > FUNDO + 0.5 then
			local h = base - FUNDO
			local pe = Instance.new("Part")
			pe.Name = "Pe" .. d.Name
			pe.Anchored = true
			pe.Material = d.Material
			pe.Color = d.Color
			pe.TopSurface = Enum.SurfaceType.Smooth
			pe.BottomSurface = Enum.SurfaceType.Smooth
			pe.Size = Vector3.new(d.Size.X, h, d.Size.Z)
			pe.CFrame = d.CFrame * CFrame.new(0, -d.Size.Y / 2 - h / 2, 0)
			pe.Parent = d.Parent
			pes += 1
		end
	end
end
if rec then
	ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
print(("[praias] %d peças desceram até %d, %d pés de rampa criados"):format(esticadas, FUNDO, pes))
