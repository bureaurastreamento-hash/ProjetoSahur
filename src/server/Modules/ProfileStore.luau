--!strict
-- Persistência sem dependências do engine: posse de sessão e journal de trocas recuperáveis.
-- Os campos _session/_pendingTrade são internos ao armazenamento, nunca ao perfil replicado.
local ProfileStore = {}
ProfileStore.__index = ProfileStore
type Store = typeof(setmetatable({} :: { store: any, journal: any, clock: () -> number, leaseSeconds: number }, ProfileStore))

function ProfileStore.Copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in value do result[key] = ProfileStore.Copy(item) end
	return result
end

function ProfileStore.new(store: any, journal: any, clock: () -> number, leaseSeconds: number): Store
	return setmetatable({ store = store, journal = journal, clock = clock, leaseSeconds = leaseSeconds }, ProfileStore)
end

local function owns(raw: any, owner: string): boolean
	return type(raw) == "table" and type(raw._session) == "table" and raw._session.id == owner
end

function ProfileStore.Release(self: Store, key: string, owner: string)
	self.store:UpdateAsync(key, function(raw)
		if not owns(raw, owner) then return nil end
		local result = ProfileStore.Copy(raw)
		result._session = nil
		return result
	end)
end

-- Resolver usa UpdateAsync também para ler a decisão, sem depender de cache de GetAsync.
function ProfileStore.Resolve(self: Store, key: string, owner: string): any
	local record = self.store:UpdateAsync(key, function(raw)
		if not owns(raw, owner) then return nil end
		return raw
	end)
	assert(owns(record, owner), "session_lost")
	local id = record._pendingTrade
	if not id then return record end
	local decision = self.journal:UpdateAsync(id, function(raw)
		assert(type(raw) == "table", "trade_missing")
		local result = ProfileStore.Copy(raw)
		if result.state == "pending" and result.expires <= self.clock() then result.state = "aborted" end
		return result
	end)
	assert(decision.state ~= "pending", "trade_pending")
	assert(decision.state == "committed" or decision.state == "aborted", "trade_invalid")
	local resolved = self.store:UpdateAsync(key, function(raw)
		if not owns(raw, owner) then return nil end
		if raw._pendingTrade == nil then return raw end -- retry depois de resposta perdida
		assert(raw._pendingTrade == id, "trade_changed")
		local result = ProfileStore.Copy(if decision.state == "committed" then decision.after[key] else raw)
		assert(type(result) == "table", "trade_participant_missing")
		result._pendingTrade = nil
		result._session = { id = owner, expires = self.clock() + self.leaseSeconds }
		return result
	end)
	assert(owns(resolved, owner), "session_lost")
	return resolved
end

function ProfileStore.Acquire(self: Store, key: string, owner: string, default: any): any
	local record = self.store:UpdateAsync(key, function(raw)
		local lock: any = type(raw) == "table" and raw._session
		if type(lock) == "table" and lock.id ~= owner and lock.expires > self.clock() then return nil end
		local result = ProfileStore.Copy(if type(raw) == "table" then raw else default)
		result._session = { id = owner, expires = self.clock() + self.leaseSeconds }
		return result
	end)
	assert(owns(record, owner), "session_locked")
	return if record._pendingTrade then self:Resolve(key, owner) else record
end

function ProfileStore.Save(self: Store, key: string, owner: string, profile: any, release: boolean): any
	local saved = false
	local result = self.store:UpdateAsync(key, function(raw)
		saved = false
		if not owns(raw, owner) then return nil end
		assert(raw._pendingTrade == nil, "trade_pending")
		local nextValue = ProfileStore.Copy(profile)
		nextValue._session = if release then nil else { id = owner, expires = self.clock() + self.leaseSeconds }
		saved = true
		return nextValue
	end)
	assert(saved, "session_lost")
	return result
end

-- Chamador congela os dois perfis até finalizar. Só há decisão committed após preparar AMBOS.
-- Se o processo morrer: pending expira e aborta; committed sempre entrega exatamente o after.
function ProfileStore.Trade(self: Store, id: string, participants: { any }): (boolean, { any })
	local after = {}
	for _, p in participants do after[p.key] = ProfileStore.Copy(p.after) end
	local record = self.journal:UpdateAsync(id, function(raw)
		return raw or { state = "pending", expires = self.clock() + self.leaseSeconds, after = after }
	end)
	if record.state == "pending" then
		local prepared = true
		for _, p in participants do
			local ok, value = pcall(function()
				return self.store:UpdateAsync(p.key, function(raw)
					if not owns(raw, p.owner) then return nil end
					assert(raw._pendingTrade == nil or raw._pendingTrade == id, "trade_busy")
					local result = ProfileStore.Copy(p.before)
					result._pendingTrade = id
					result._session = { id = p.owner, expires = self.clock() + self.leaseSeconds }
					return result
				end)
			end)
			if not ok or not owns(value, p.owner) or value._pendingTrade ~= id then prepared = false; break end
		end
		record = self.journal:UpdateAsync(id, function(raw)
			assert(type(raw) == "table", "trade_missing")
			local result = ProfileStore.Copy(raw)
			if result.state == "pending" then
				result.state = if prepared and result.expires > self.clock() then "committed" else "aborted"
			end
			return result
		end)
	end
	local profiles = {}
	for i, p in participants do profiles[i] = self:Resolve(p.key, p.owner) end
	return record.state == "committed", profiles
end

return ProfileStore
