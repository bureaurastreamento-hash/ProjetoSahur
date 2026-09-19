--!strict
--[[
	VendorConfig
	Catálogo do VENDEDOR da Lojinha (E no NPC; VendorService no servidor, VendorController no cliente).
	Dono (2026-09-20, lojas divididas): a Loja do menu (L) só vende Robux; o vendedor vende TUDO que
	custa pontos — cosméticos, emotes, personagens e giros da roleta — por PONTOS (`Price`) ou por
	PONTOS DE EVENTO (`EventPrice`, moeda dos mini eventos do Canion). O vendedor também é o ponto de
	TROCA entre jogadores (TradeConfig).
	Os preços moram nas configs dos itens (CosmeticsConfig Price/EventPrice, CharacterDefs UnlockCost);
	aqui só se monta a lista, na mesma ordem para servidor e cliente.
]]

local CharacterDefs = require(script.Parent:WaitForChild("CharacterDefs"))
local CosmeticsConfig = require(script.Parent:WaitForChild("CosmeticsConfig"))

local VendorConfig = {}

--- Distância (studs) do NPC em que o painel fica aberto; longe disso ele fecha sozinho.
VendorConfig.Range = 16

export type Entry = {
	kind: string, -- "cosmetic" | "emote" | "character" | "roll"
	id: string,
	name: string,
	group: string, -- título da seção no painel
	price: number?, -- pontos
	eventPrice: number?, -- pontos de evento
	color: Color3?,
}

VendorConfig.GroupOrder = { "ROLETA", "PERSONAGENS", "CAPAS", "AURAS", "EMOTES", "EVENTO" }

--- Lista do que o vendedor vende (ordem fixa). Itens de evento vão para a seção EVENTO.
function VendorConfig.Catalog(): { Entry }
	local list: { Entry } = {}
	table.insert(list, { kind = "roll", id = "roll", name = "1 giro da roleta (item aleatório)", group = "ROLETA", price = CosmeticsConfig.RollCost })
	for _, id in CharacterDefs.Order do
		local def = CharacterDefs.Get(id)
		if def and CharacterDefs.AccessOf(def) == "coins" and def.UnlockCost > 0 then
			table.insert(list, { kind = "character", id = id, name = def.DisplayName, group = "PERSONAGENS", price = def.UnlockCost })
		end
	end
	for _, item in CosmeticsConfig.Items do
		if item.Price or item.EventPrice then
			local group = if item.Price then CosmeticsConfig.CategoryNames[item.Category]:upper() else "EVENTO"
			table.insert(list, { kind = "cosmetic", id = item.Id, name = item.Name, group = group, price = item.Price, eventPrice = item.EventPrice, color = item.Color })
		end
	end
	for _, emote in CosmeticsConfig.Emotes do
		if emote.Price or emote.EventPrice then
			table.insert(list, { kind = "emote", id = emote.Id, name = emote.Name, group = if emote.Price then "EMOTES" else "EVENTO", price = emote.Price, eventPrice = emote.EventPrice, color = emote.Color })
		end
	end
	return list
end

function VendorConfig.Get(id: string): Entry?
	for _, e in VendorConfig.Catalog() do
		if e.id == id then
			return e
		end
	end
	return nil
end

return VendorConfig
