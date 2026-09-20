--!strict
--[[
	ModRegistry (compartilhado)
	LOADER dos mods de ASSET (Kind character / cosmetic / vfx / sfx / map — ver MODS_KIT.md). O ModService, ao
	ligar um mod desses num servidor privado, clona `ServerStorage.Mods.<Id>` para
	`ReplicatedStorage.ModsActive.<Id>` (o mapa vai para Workspace.ModMaps). Este módulo observa essa pasta
	nos DOIS lados e injeta o conteúdo nos módulos compartilhados, desfazendo tudo quando a pasta some:
	  - CharacterDef  (ModuleScript → CharacterDef)        → CharacterDefs.Characters[Id] + CharacterDefs.Order
	  - Cosmetics     (ModuleScript → { Items?, Emotes? })  → CosmeticsConfig.Items/Emotes (tudo Free: nada salva)
	  - VFX           (ModuleScript → { Meshes?, Textures?, Effects? }) → VFXLibrary (só chaves NOVAS)
	  - Animations / Sounds / VFX (Folders com subpastas <CharacterId|ModId>) → ReplicatedStorage.Assets.<kind>
	    (SÓ no servidor: as cópias replicam sozinhas; o cliente não mexe em instância)
	Validações mínimas (a equipe já conferiu a lista de exigências antes de subir): módulo devolve tabela,
	Id string, sem colisão com o que já existe, números dentro dos tetos do kit (dano ≤ 3×, vida ≤ 4×...).
	`ModRegistry.Changed` (BindableEvent: id, active) para quem desenha listas (seleção de personagem, roda
	de emotes) atualizar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = script.Parent
local Log = require(Modules:WaitForChild("Log"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local CosmeticsConfig = require(Modules:WaitForChild("CosmeticsConfig"))
local VFXLibrary = require(Modules:WaitForChild("VFXLibrary"))

local ModRegistry = {}

ModRegistry.FolderName = "ModsActive"
ModRegistry.AssetsFolderName = "Assets"
ModRegistry.Changed = Instance.new("BindableEvent") -- (id: string, active: boolean)
-- tetos do kit (MODS_KIT.md, exigência 3)
ModRegistry.Limits = { Damage = 3, Health = 4, Speed = 2 }

type Loaded = {
	characters: { string },
	items: { CosmeticsConfig.Item },
	emotes: { CosmeticsConfig.Emote },
	effects: { string },
	meshes: { string },
	textures: { string },
	instances: { Instance },
}

local loaded: { [string]: Loaded } = {}

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

local function safeRequire(id: string, module: Instance?): { [any]: any }?
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok then
		warn(("[ModRegistry] %s.%s não carregou: %s"):format(id, module.Name, tostring(result)))
		return nil
	end
	if typeof(result) ~= "table" then
		warn(("[ModRegistry] %s.%s precisa devolver uma tabela"):format(id, module.Name))
		return nil
	end
	return result
end

local function validId(value: any): boolean
	return typeof(value) == "string" and value:match("^[%w_]+$") ~= nil
end

--- Limita os números de uma habilidade aos tetos do kit (sem quebrar o que a equipe balanceou).
local function clampEffect(effect: any)
	if typeof(effect) ~= "table" then
		return
	end
	local maxDamage = 40 * ModRegistry.Limits.Damage -- maior golpe do jogo (ults ~30–40) × teto
	for _, key in { "Damage", "SlamDamage", "SpinDamage" } do
		if typeof(effect[key]) == "number" then
			effect[key] = math.clamp(effect[key], 0, maxDamage)
		end
	end
	if typeof(effect.Multiplier) == "number" then
		effect.Multiplier = math.clamp(effect.Multiplier, 0, ModRegistry.Limits.Damage)
	end
	if typeof(effect.Amount) == "number" then
		effect.Amount = math.clamp(effect.Amount, 0, 100 * ModRegistry.Limits.Health)
	end
end

-- ---------------------------------------------------------------------------
-- Loaders
-- ---------------------------------------------------------------------------

local function loadCharacter(id: string, folder: Instance, rec: Loaded)
	local def: any = safeRequire(id, folder:FindFirstChild("CharacterDef"))
	if not def then
		return
	end
	if not validId(def.Id) then
		warn(("[ModRegistry] %s: CharacterDef.Id inválido"):format(id))
		return
	end
	if CharacterDefs.Characters[def.Id] then
		warn(("[ModRegistry] %s: personagem '%s' já existe no jogo — ignorado"):format(id, def.Id))
		return
	end
	if typeof(def.Abilities) ~= "table" or #def.Abilities == 0 then
		warn(("[ModRegistry] %s: CharacterDef.Abilities vazio"):format(id))
		return
	end
	local function checkList(list: any, label: string): boolean
		if typeof(list) ~= "table" then
			return true
		end
		for _, ability in list do
			if typeof(ability) ~= "table" or not validId(ability.Id) then
				warn(("[ModRegistry] %s: %s sem Id"):format(id, label))
				return false
			end
			ability.Cooldown = math.max(0, tonumber(ability.Cooldown) or 0)
			ability.CastTime = math.max(0, tonumber(ability.CastTime) or 0)
			clampEffect(ability.Effect)
			clampEffect(ability.Effect and ability.Effect.Then)
			clampEffect(ability.AwakenedEffect)
		end
		return true
	end
	-- kit ANTIGO (EnergyCost = 100 na última = ult): a ult vira o 1º golpe desperto e sai da lista normal
	local normal = {}
	local awakenedFromOld = {}
	for _, ability in def.Abilities do
		if typeof(ability) == "table" and tonumber(ability.EnergyCost) and tonumber(ability.EnergyCost) >= 100 then
			table.insert(awakenedFromOld, ability)
		else
			table.insert(normal, ability)
		end
	end
	def.Abilities = normal
	if typeof(def.AwakenedAbilities) ~= "table" or #def.AwakenedAbilities == 0 then
		def.AwakenedAbilities = if #awakenedFromOld > 0 then awakenedFromOld else {}
	end
	if typeof(def.Ultimate) ~= "table" then
		def.Ultimate = { Duration = 20 }
	end
	def.Ultimate.Duration = math.clamp(tonumber(def.Ultimate.Duration) or 20, 5, 40)
	if typeof(def.Ultimate.DamageMultiplier) == "number" then
		def.Ultimate.DamageMultiplier = math.clamp(def.Ultimate.DamageMultiplier, 1, ModRegistry.Limits.Damage)
	end
	clampEffect(def.Ultimate.Effect)
	if not checkList(def.Abilities, "habilidade") or not checkList(def.AwakenedAbilities, "golpe desperto") then
		return
	end
	if def.Passive then
		if not checkList({ def.Passive }, "passiva (R)") then
			return
		end
	end
	if def.DashOverride then
		clampEffect(def.DashOverride.Effect)
	end
	-- mod = todo mundo da sala pode usar (nada salva); nunca "early"/"admin"/"drop"
	def.Access = nil
	def.UnlockCost = 0
	def.DisplayName = if typeof(def.DisplayName) == "string" then def.DisplayName else def.Id
	def.Tagline = ("%s · mod"):format(tostring(def.Tagline or ""))
	CharacterDefs.Characters[def.Id] = def
	table.insert(CharacterDefs.Order, def.Id)
	table.insert(rec.characters, def.Id)
end

local function loadCosmetics(id: string, folder: Instance, rec: Loaded)
	local data: any = safeRequire(id, folder:FindFirstChild("Cosmetics"))
	if not data then
		return
	end
	for _, item in (if typeof(data.Items) == "table" then data.Items else {}) :: { any } do
		if typeof(item) == "table" and validId(item.Id) and not CosmeticsConfig.GetItem(item.Id) and (item.Category == "cape" or item.Category == "aura") then
			item.Free = true -- sala privada: todo mundo tem; nada salva
			item.Weight = 0
			item.Price = nil
			item.EventPrice = nil
			item.Access = nil
			item.Name = ("%s (mod)"):format(tostring(item.Name or item.Id))
			table.insert(CosmeticsConfig.Items, item)
			table.insert(rec.items, item)
		else
			warn(("[ModRegistry] %s: item de cosmético inválido ou repetido (%s)"):format(id, tostring(typeof(item) == "table" and item.Id or "?")))
		end
	end
	for _, emote in (if typeof(data.Emotes) == "table" then data.Emotes else {}) :: { any } do
		if typeof(emote) == "table" and validId(emote.Id) and not CosmeticsConfig.GetEmote(emote.Id) then
			emote.Free = true
			emote.Weight = 0
			emote.Price = nil
			emote.EventPrice = nil
			emote.Kind = if emote.Kind == "scene" then "scene" else "emote"
			table.insert(CosmeticsConfig.Emotes, emote)
			table.insert(rec.emotes, emote)
		else
			warn(("[ModRegistry] %s: emote inválido ou repetido (%s)"):format(id, tostring(typeof(emote) == "table" and emote.Id or "?")))
		end
	end
end

local function loadVFX(id: string, folder: Instance, rec: Loaded)
	local data: any = safeRequire(id, folder:FindFirstChild("VFX"))
	if not data then
		return
	end
	for key, mesh in (if typeof(data.Meshes) == "table" then data.Meshes else {}) :: { [string]: any } do
		if typeof(key) == "string" and not VFXLibrary.Meshes[key] and typeof(mesh) == "table" and typeof(mesh.id) == "number" and typeof(mesh.size) == "Vector3" then
			VFXLibrary.Meshes[key] = mesh
			table.insert(rec.meshes, key)
		end
	end
	for key, tex in (if typeof(data.Textures) == "table" then data.Textures else {}) :: { [string]: any } do
		if typeof(key) == "string" and not VFXLibrary.Textures[key] and (typeof(tex) == "number" or typeof(tex) == "string") then
			VFXLibrary.Textures[key] = tex
			table.insert(rec.textures, key)
		end
	end
	for key, effect in (if typeof(data.Effects) == "table" then data.Effects else {}) :: { [string]: any } do
		if typeof(key) == "string" and key:find("/") and not VFXLibrary.Effects[key] and typeof(effect) == "table" and typeof(effect.layers) == "table" then
			VFXLibrary.Effects[key] = effect
			table.insert(rec.effects, key)
		else
			warn(("[ModRegistry] %s: efeito '%s' inválido ou já existe"):format(id, tostring(key)))
		end
	end
end

--- Animations/Sounds/VFX: cada subpasta (<CharacterId> ou <ModId>) vai para ReplicatedStorage.Assets.<kind>;
--- pasta que já existe recebe só os filhos que faltam. Só no servidor (replica sozinho).
local function loadAssets(id: string, folder: Instance, rec: Loaded)
	local assets = ReplicatedStorage:FindFirstChild(ModRegistry.AssetsFolderName)
	if not assets then
		return
	end
	for _, kind in { "Animations", "Sounds", "VFX" } do
		local src = folder:FindFirstChild(kind)
		local dst = assets:FindFirstChild(kind)
		if src and src:IsA("Folder") and dst then
			for _, sub in src:GetChildren() do
				local target = dst:FindFirstChild(sub.Name)
				if not target then
					local copy = sub:Clone()
					copy:SetAttribute("ModId", id)
					copy.Parent = dst
					table.insert(rec.instances, copy)
				else
					for _, child in sub:GetChildren() do
						if not target:FindFirstChild(child.Name) then
							local copy = child:Clone()
							copy:SetAttribute("ModId", id)
							copy.Parent = target
							table.insert(rec.instances, copy)
						end
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Ligar / desligar
-- ---------------------------------------------------------------------------

local function load(folder: Instance)
	local id = folder.Name
	if loaded[id] then
		return
	end
	local rec: Loaded = { characters = {}, items = {}, emotes = {}, effects = {}, meshes = {}, textures = {}, instances = {} }
	loaded[id] = rec
	loadCharacter(id, folder, rec)
	loadCosmetics(id, folder, rec)
	loadVFX(id, folder, rec)
	if RunService:IsServer() then
		loadAssets(id, folder, rec)
	end
	Log.debug(("[ModRegistry] mod '%s' carregado: %d personagem(ns), %d item(ns), %d emote(s), %d efeito(s), %d asset(s)"):format(id, #rec.characters, #rec.items, #rec.emotes, #rec.effects, #rec.instances))
	ModRegistry.Changed:Fire(id, true)
end

local function unload(id: string)
	local rec = loaded[id]
	if not rec then
		return
	end
	loaded[id] = nil
	for _, charId in rec.characters do
		CharacterDefs.Characters[charId] = nil
		local idx = table.find(CharacterDefs.Order, charId)
		if idx then
			table.remove(CharacterDefs.Order, idx)
		end
	end
	for _, item in rec.items do
		local idx = table.find(CosmeticsConfig.Items, item)
		if idx then
			table.remove(CosmeticsConfig.Items, idx)
		end
	end
	for _, emote in rec.emotes do
		local idx = table.find(CosmeticsConfig.Emotes, emote)
		if idx then
			table.remove(CosmeticsConfig.Emotes, idx)
		end
	end
	for _, key in rec.effects do
		VFXLibrary.Effects[key] = nil
	end
	for _, key in rec.meshes do
		VFXLibrary.Meshes[key] = nil
	end
	for _, key in rec.textures do
		VFXLibrary.Textures[key] = nil
	end
	for _, inst in rec.instances do
		inst:Destroy()
	end
	Log.debug(("[ModRegistry] mod '%s' descarregado"):format(id))
	ModRegistry.Changed:Fire(id, false)
end

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

--- Ids de personagem que este mod trouxe (vazio se não é mod de personagem / não está ativo).
function ModRegistry.CharactersOf(id: string): { string }
	local rec = loaded[id]
	return if rec then table.clone(rec.characters) else {}
end

--- Mod que trouxe este personagem (nil = personagem do jogo).
function ModRegistry.ModOfCharacter(characterId: string): string?
	for id, rec in loaded do
		if table.find(rec.characters, characterId) then
			return id
		end
	end
	return nil
end

function ModRegistry.IsLoaded(id: string): boolean
	return loaded[id] ~= nil
end

function ModRegistry.ActiveIds(): { string }
	local ids = {}
	for id in loaded do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

--- Começa a observar ReplicatedStorage.ModsActive (idempotente). Chamado pelo ModService (servidor) e
--- pelo ModsController (cliente).
local started = false
function ModRegistry.Start()
	if started then
		return
	end
	started = true
	local function hook(folder: Instance)
		if folder:IsA("Folder") then
			load(folder)
		end
	end
	local function watch(root: Instance)
		for _, child in root:GetChildren() do
			hook(child)
		end
		root.ChildAdded:Connect(hook)
		root.ChildRemoved:Connect(function(child)
			unload(child.Name)
		end)
	end
	local root = ReplicatedStorage:FindFirstChild(ModRegistry.FolderName)
	if root then
		watch(root)
	else
		ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == ModRegistry.FolderName and not root then
				root = child
				watch(child)
			end
		end)
	end
end

return ModRegistry
