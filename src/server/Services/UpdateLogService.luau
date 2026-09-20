--!strict
--[[
	UpdateLogService
	Log de atualização no jogo (D4, dono 2026-09-23). O dev escreve as novidades em UpdateLogConfig e
	PUBLICA quando quiser (menu DEV → "Publicar novidades"):
	  - a versão publicada fica num DataStore ("UpdateLog_v1", chave "published") para os servidores que
	    nascerem depois; os que já estão de pé recebem por MessagingService e reenviam a quem está online.
	  - ao entrar (perfil carregado), se a versão publicada ≠ profile.lastUpdateSeen, o cliente recebe
	    NotifyUpdateLog e abre a tela sozinho; ao fechar manda RequestUpdateSeen e o servidor grava.
	  - FetchUpdateLog devolve a lista inteira para o botão Config → Novidades (rever a qualquer hora).
	Servidor privado / Studio: o perfil não salva (DataService.sessionOnly), então a tela pode voltar
	na próxima entrada — comportamento esperado. Sem DataStore (Studio sem acesso à API) a publicação
	vale só para este servidor.
]]

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local UpdateLogConfig = require(Modules:WaitForChild("UpdateLogConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local UpdateLogService = {}

local STORE_NAME = "UpdateLog_v1"
local STORE_KEY = "published"
local TOPIC = "SahurUpdateLog"

local published: string? = nil -- versão publicada conhecida por este servidor (nil = nada publicado ainda)
local limiter = RateLimiter.new(5, 5)

local function notify(player: Player)
	local version = published
	if not version then
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile or profile.lastUpdateSeen == version then
		return
	end
	local entry = UpdateLogConfig.Get(version)
	if not entry then
		return -- publicada uma versão que este build não conhece (servidor antigo): não mostra nada
	end
	Remotes.GetEvent(Remotes.Events.NotifyUpdateLog):FireClient(player, entry)
end

local function applyPublished(version: string, resend: boolean)
	if published == version then
		return
	end
	published = version
	Log.debug("[UpdateLogService] versão publicada:", version)
	if resend then
		for _, player in Players:GetPlayers() do
			notify(player)
		end
	end
end

--- Versão publicada que este servidor conhece (nil = nenhuma).
function UpdateLogService.GetPublished(): string?
	return published
end

--- DEV "Publicar novidades": publica UpdateLogConfig.Current para todos os servidores e reenvia a quem está online.
function UpdateLogService.Publish(): (boolean, string)
	local version = UpdateLogConfig.Current
	if not UpdateLogConfig.Get(version) then
		return false, ("UpdateLogConfig.Current = %q não está na lista Versions"):format(version)
	end
	local notes = {}
	local okStore, errStore = pcall(function()
		DataStoreService:GetDataStore(STORE_NAME):SetAsync(STORE_KEY, version)
	end)
	if not okStore then
		table.insert(notes, "DataStore falhou (" .. tostring(errStore) .. "): servidores novos não vão saber")
	end
	local okMsg, errMsg = pcall(function()
		MessagingService:PublishAsync(TOPIC, version)
	end)
	if not okMsg then
		table.insert(notes, "MessagingService falhou (" .. tostring(errMsg) .. "): só este servidor")
	end
	applyPublished(version, true)
	local msg = ("novidades %s publicadas"):format(version)
	if #notes > 0 then
		msg ..= " — " .. table.concat(notes, "; ")
	end
	return true, msg
end

function UpdateLogService.Start()
	-- versão publicada antes deste servidor nascer
	task.spawn(function()
		local ok, value = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME):GetAsync(STORE_KEY)
		end)
		if ok and typeof(value) == "string" and value ~= "" then
			applyPublished(value, true)
		elseif not ok then
			Log.debug("[UpdateLogService] sem DataStore:", value)
		end
	end)
	-- publicações feitas em outro servidor enquanto este está de pé
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			if typeof(message.Data) == "string" and message.Data ~= "" then
				applyPublished(message.Data, true)
			end
		end)
	end)

	DataService.ProfileLoaded.Event:Connect(function(player: Player)
		notify(player)
	end)

	Remotes.GetEvent(Remotes.Events.RequestUpdateSeen).OnServerEvent:Connect(function(player, version)
		if not limiter:Allow(player) or typeof(version) ~= "string" then
			return
		end
		-- só aceita marcar como vista a versão publicada (ou uma da lista, para o botão "Novidades")
		if version ~= published and not UpdateLogConfig.Get(version) then
			return
		end
		local profile = DataService.GetProfile(player)
		if profile and profile.lastUpdateSeen ~= version then
			profile.lastUpdateSeen = version
			DataService.MarkDirty(player)
		end
	end)

	Remotes.GetFunction(Remotes.Functions.FetchUpdateLog).OnServerInvoke = function(player)
		if not limiter:Allow(player) then
			return nil
		end
		return { published = published, versions = UpdateLogConfig.Versions }
	end
end

return UpdateLogService
