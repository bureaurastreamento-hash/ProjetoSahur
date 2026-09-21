--[[
	consertar_meshparts.luau — roda NO STUDIO (via MCP run_code, DataModel de edição).
	Conserta MeshParts "fantasmas": peças recriadas por script (Instance.new("MeshPart") + MeshId, como faz o
	`restaurar_workspace.luau` a partir do backup JSONL) ficam com `MeshSize = 0,0,0` — a colisão fica certa,
	mas o render sai deformado e fora do lugar (parece uma textura gigante atravessando o mapa, e não dá para
	clicar porque o clique usa a colisão). Aconteceu em 25/09 com os 50 móveis do Hall restaurados do backup.
	Para cada MeshId quebrado, cria um MeshPart de verdade com `AssetService:CreateMeshPartAsync` e aplica com
	`ApplyMesh` (mantém CFrame, Size, cor, material, filhos, SurfaceAppearance). Idempotente.
	Opcional: `RAIZ` limita a busca (padrão = Workspace inteiro).
]]
local AssetService = game:GetService("AssetService")
local RAIZ = workspace

local porMesh = {}
for _, d in RAIZ:GetDescendants() do
	if d:IsA("MeshPart") and d.MeshSize == Vector3.zero and d.MeshId ~= "" then
		porMesh[d.MeshId] = porMesh[d.MeshId] or {}
		table.insert(porMesh[d.MeshId], d)
	end
end

local corrigidas, falhas = 0, {}
for meshId, parts in porMesh do
	local ok, novo = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
			CollisionFidelity = parts[1].CollisionFidelity,
			RenderFidelity = parts[1].RenderFidelity,
		})
	end)
	if ok and novo then
		for _, p in parts do
			local size = p.Size
			local ok2, err = pcall(p.ApplyMesh, p, novo)
			if ok2 then
				p.Size = size
				corrigidas += 1
			else
				table.insert(falhas, p:GetFullName() .. ": " .. tostring(err))
			end
		end
		novo:Destroy()
	else
		table.insert(falhas, meshId .. ": " .. tostring(novo))
	end
end
print(("[consertar_meshparts] %d MeshParts corrigidas, %d falhas — SALVAR o place"):format(corrigidas, #falhas))
for _, f in falhas do
	warn("  " .. f)
end
