-- Executa sem Studio: lune run tests/profile_store.luau
local ProfileStore = require("../src/server/Modules/ProfileStore")
local total = 0
local function test(name, run)
	run()
	total += 1
	print("OK " .. name)
end

local function fixture()
	local now = 1000
	local function memoryStore()
		local store = { records = {}, fault = nil }
		function store:UpdateAsync(key, callback)
			if self.fault then self.fault(key, "before", self.records[key]) end
			-- Roblox pode repetir o callback: a primeira avaliação não é o commit.
			callback(ProfileStore.Copy(self.records[key]))
			local value = callback(ProfileStore.Copy(self.records[key]))
			if value == nil then return nil end
			self.records[key] = ProfileStore.Copy(value)
			if self.fault then self.fault(key, "after", value) end
			return ProfileStore.Copy(value)
		end
		return store
	end
	local store, journal = memoryStore(), memoryStore()
	local persistence = ProfileStore.new(store, journal, function() return now end, 180)
	local a = { coins = 10, inventory = { flecha = 1 }, receipts = {} }
	local b = { coins = 20, inventory = {}, receipts = {} }
	persistence:Acquire("a", "session-a", a)
	persistence:Acquire("b", "session-b", b)
	local afterA, afterB = ProfileStore.Copy(a), ProfileStore.Copy(b)
	afterA.inventory.flecha = nil; afterB.inventory.flecha = 1
	afterA.coins += 5; afterB.coins -= 5
	local participants = {
		{ key = "a", owner = "session-a", before = a, after = afterA },
		{ key = "b", owner = "session-b", before = b, after = afterB },
	}
	return persistence, store, journal, participants, function() now += 181 end
end

test("segunda sessão não toma perfil ativo", function()
	local p = fixture()
	assert(not pcall(function() p:Acquire("a", "other", {}) end))
end)

test("sessão expirada não sobrescreve a nova", function()
	local p, s, _, _, expire = fixture()
	expire(); p:Acquire("a", "new", {})
	assert(not pcall(function() p:Save("a", "session-a", { coins = 999 }, false) end))
	assert(s.records.a.coins == 10)
end)

test("snapshot não compartilha tabelas com perfil mutável", function()
	local p, s, _, participants = fixture()
	local copy = ProfileStore.Copy(participants[1].before)
	participants[1].before.inventory.flecha = 900
	p:Save("a", "session-a", copy, false)
	assert(s.records.a.inventory.flecha == 1)
end)

test("troca completa e repetida não duplica item nem moeda", function()
	local p, s, _, participants = fixture()
	assert(p:Trade("trade-1", participants))
	assert(p:Trade("trade-1", participants))
	assert(s.records.a.inventory.flecha == nil and s.records.b.inventory.flecha == 1)
	assert(s.records.a.coins == 15 and s.records.b.coins == 15)
end)

test("falha antes de preparar o segundo participante aborta", function()
	local p, s, j, participants = fixture()
	s.fault = function(key, phase, raw)
		if key == "b" and phase == "before" and raw._pendingTrade == nil then
			s.fault = nil; error("falha simulada")
		end
	end
	assert(not p:Trade("trade-2", participants))
	assert(j.records["trade-2"].state == "aborted")
	assert(s.records.a.inventory.flecha == 1 and s.records.b.inventory.flecha == nil)
end)

test("resposta perdida no prepare não autoriza entrega parcial", function()
	local p, s, j, participants = fixture()
	s.fault = function(key, phase, raw)
		if key == "b" and phase == "after" and raw._pendingTrade then s.fault = nil; error("resposta perdida") end
	end
	assert(not p:Trade("trade-3", participants))
	assert(j.records["trade-3"].state == "aborted")
	assert(s.records.a.inventory.flecha == 1 and s.records.b.inventory.flecha == nil)
end)

test("crash depois da decisão committed recupera ambos ao reconectar", function()
	local p, s, j, participants, expire = fixture()
	j.fault = function(_, phase, raw)
		if phase == "after" and raw.state == "committed" then j.fault = nil; error("crash") end
	end
	assert(not pcall(function() p:Trade("trade-4", participants) end))
	expire()
	local a, b = p:Acquire("a", "new-a", {}), p:Acquire("b", "new-b", {})
	assert(a.coins == 15 and b.coins == 15)
	assert(a.inventory.flecha == nil and b.inventory.flecha == 1)
	assert(s.records.a._pendingTrade == nil and s.records.b._pendingTrade == nil)
end)

test("crash antes da decisão expira e preserva os dois inventários", function()
	local p, s, j, participants, expire = fixture()
	j.fault = function(_, phase, raw)
		if phase == "before" and raw and raw.state == "pending" then j.fault = nil; error("crash") end
	end
	assert(not pcall(function() p:Trade("trade-5", participants) end))
	expire()
	local a, b = p:Acquire("a", "new-a", {}), p:Acquire("b", "new-b", {})
	assert(a.inventory.flecha == 1 and b.inventory.flecha == nil)
	assert(a.coins + b.coins == 30)
end)

test("falha ao finalizar um lado converge sem reaplicar a troca", function()
	local p, s, _, participants = fixture()
	s.fault = function(key, phase, raw)
		if key == "b" and phase == "after" and raw._pendingTrade == nil and raw.coins == 15 then
			s.fault = nil; error("resposta perdida")
		end
	end
	assert(not pcall(function() p:Trade("trade-6", participants) end))
	assert(p:Trade("trade-6", participants))
	assert(s.records.a.coins + s.records.b.coins == 30 and s.records.b.inventory.flecha == 1)
end)

test("recompensa e PurchaseId sobrevivem no mesmo save", function()
	local p, s, _, participants = fixture()
	local profile = participants[1].before
	profile.coins += 100; profile.receipts["receipt-1"] = true
	p:Save("a", "session-a", profile, true)
	local restored = p:Acquire("a", "new-a", {})
	assert(restored.coins == 110 and restored.receipts["receipt-1"])
	assert(s.records.a._session.id == "new-a")
end)
print(("%d testes de persistência passaram"):format(total))
