--[[
	juntar_animacoes.luau (Lune): junta TODOS os KeyframeSequences de packs/Import/Animacoes/*/
	num único arquivo packs/Import/AnimPreview.rbxm com um preview embutido:
	  AnimPreview (Folder)
	    Sequencias (Folder)  -> um KeyframeSequence por animação (nome = Pack_Nome)
	    PreviewServer (Script) + PreviewGui (LocalScript, Disabled)
	No Studio (place em branco): Insert from File > AnimPreview.rbxm > Play. Aparece uma lista
	à esquerda; clique toca no boneco. Escolheu? Clique direito no KeyframeSequence em
	Sequencias > Save to Roblox (criador = grupo) e me manda "Nome: id".
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local SRC = "packs/Import/Animacoes"
local OUT = "packs/Import/AnimPreview.rbxm"

local root = roblox.Instance.new("Folder")
root.Name = "AnimPreview"
local seqs = roblox.Instance.new("Folder")
seqs.Name = "Sequencias"
seqs.Parent = root

local count = 0
for _, pack in fs.readDir(SRC) do
	local dir = SRC .. "/" .. pack
	if fs.isDir(dir) then
		for _, file in fs.readDir(dir) do
			if file:match("%.rbxm$") then
				local ok, model = pcall(roblox.deserializeModel, fs.readFile(dir .. "/" .. file))
				if ok then
					for _, inst in model do
						local kfs = if inst.ClassName == "KeyframeSequence" then inst else inst:FindFirstChildOfClass("KeyframeSequence")
						if kfs then
							kfs.Name = pack:sub(1, 6) .. "_" .. file:gsub("%.rbxm$", "")
							kfs.Parent = seqs
							count += 1
						end
					end
				else
					print("falhou " .. file .. ": " .. tostring(model))
				end
			end
		end
	end
end

local server = roblox.Instance.new("Script")
server.Name = "PreviewServer"
server.Source = fs.readFile("tools/preview/PreviewServer.luau")
server.Parent = root
local client = roblox.Instance.new("LocalScript")
client.Name = "PreviewGui"
client.Source = fs.readFile("tools/preview/PreviewGui.luau")
client.Disabled = true
client.Parent = root

fs.writeFile(OUT, roblox.serializeModel({ root }))
print(("%d KeyframeSequence(s) -> %s"):format(count, OUT))
