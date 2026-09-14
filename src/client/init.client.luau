--!strict
--[[
	Boot do cliente.
	Carrega cada ModuleScript em Controllers/ isolado em pcall, em duas fases:
	  1) Init()  - preparar estado, pegar referências de remotes/UI
	  2) Start() - conectar input, começar loops
	Um erro em um controller não impede os demais de subir.
]]

local controllersFolder = script:WaitForChild("Controllers")
local loaded: { [string]: any } = {}

for _, module in controllersFolder:GetChildren() do
	if not module:IsA("ModuleScript") then
		continue
	end
	local ok, result = pcall(require, module)
	if ok then
		loaded[module.Name] = result
	else
		warn(("[Client] FALHA ao carregar controller '%s': %s"):format(module.Name, tostring(result)))
	end
end

for name, controller in loaded do
	if type(controller) == "table" and type(controller.Init) == "function" then
		local ok, err = pcall(controller.Init, controller)
		if not ok then
			warn(("[Client] FALHA em %s.Init(): %s"):format(name, tostring(err)))
		end
	end
end

for name, controller in loaded do
	if type(controller) == "table" and type(controller.Start) == "function" then
		local ok, err = pcall(controller.Start, controller)
		if not ok then
			warn(("[Client] FALHA em %s.Start(): %s"):format(name, tostring(err)))
		end
	end
end

local count = 0
for _ in loaded do
	count += 1
end
print(("[Client] boot concluído, %d controller(s) carregado(s)"):format(count))
