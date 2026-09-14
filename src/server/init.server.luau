--!strict
--[[
	Boot do servidor.
	Carrega cada ModuleScript em Services/ isolado em pcall, em duas fases:
	  1) Init()  - preparar estado, criar instâncias, registrar remotes
	  2) Start() - conectar eventos e começar a rodar
	Um erro em um serviço não impede os demais de subir.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("RemoteEvents"))

-- Remotes precisam existir antes de qualquer serviço rodar Init()
Remotes.Init()

local servicesFolder = script:WaitForChild("Services")
local loaded: { [string]: any } = {}

for _, module in servicesFolder:GetChildren() do
	if not module:IsA("ModuleScript") then
		continue
	end
	local ok, result = pcall(require, module)
	if ok then
		loaded[module.Name] = result
	else
		warn(("[Server] FALHA ao carregar service '%s': %s"):format(module.Name, tostring(result)))
	end
end

for name, service in loaded do
	if type(service) == "table" and type(service.Init) == "function" then
		local ok, err = pcall(service.Init, service)
		if not ok then
			warn(("[Server] FALHA em %s.Init(): %s"):format(name, tostring(err)))
		end
	end
end

for name, service in loaded do
	if type(service) == "table" and type(service.Start) == "function" then
		local ok, err = pcall(service.Start, service)
		if not ok then
			warn(("[Server] FALHA em %s.Start(): %s"):format(name, tostring(err)))
		end
	end
end

-- TODO(launch): reduzir log
local count = 0
for _ in loaded do
	count += 1
end
print(("[Server] boot concluído, %d service(s) carregado(s)"):format(count))
