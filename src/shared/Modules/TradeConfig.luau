--!strict
--[[
	TradeConfig
	Trocas entre jogadores no VENDEDOR (dono, 2026-09-20): quem propõe abre a aba TROCAR no painel do
	vendedor; o outro recebe o convite e precisa estar perto do vendedor para aceitar. Cada lado oferece
	itens (cosméticos, emotes, personagens), pontos e pontos de evento; os dois marcam PRONTO, esperam
	ConfirmDelay e CONFIRMAM. Qualquer mudança na oferta desfaz o pronto dos dois (anti-golpe).
	O servidor (TradeService) valida tudo e só executa se os dois lados ainda tiverem o que ofereceram.
	`Tradeable(profile)` é a regra ÚNICA do que pode ser trocado (servidor e cliente usam a mesma).
]]

local CharacterDefs = require(script.Parent:WaitForChild("CharacterDefs"))
local CosmeticsConfig = require(script.Parent:WaitForChild("CosmeticsConfig"))

local TradeConfig = {}

TradeConfig.InviteTimeout = 30 -- s até o convite expirar
TradeConfig.VendorRange = 20 -- studs do vendedor para propor/aceitar
TradeConfig.MaxItemsPerSide = 8
TradeConfig.ConfirmDelay = 2 -- s entre os dois "pronto" e o botão CONFIRMAR liberar
TradeConfig.AllowLimited = true -- itens de passe (Limited) podem circular por troca (dono decide)
TradeConfig.MaxPoints = 100000

export type Item = { kind: string, id: string, name: string, color: Color3? } -- kind: cosmetic | emote | character

--- O que este perfil pode oferecer numa troca (itens; pontos são à parte).
--- Personagem: só os comprados com pontos (nunca o inicial, VIP, forma de boss ou acesso antecipado).
function TradeConfig.Tradeable(profile: any): { Item }
	local list: { Item } = {}
	if typeof(profile) ~= "table" then
		return list
	end
	for _, id in (profile.unlockedCharacters or {}) :: { string } do
		local def = CharacterDefs.Get(id)
		if def and CharacterDefs.AccessOf(def) == "coins" and def.UnlockCost > 0 then
			table.insert(list, { kind = "character", id = id, name = def.DisplayName })
		end
	end
	local cosmetics = if typeof(profile.cosmetics) == "table" then profile.cosmetics.owned or {} else {}
	for _, id in cosmetics :: { string } do
		local item = CosmeticsConfig.GetItem(id)
		if item and CosmeticsConfig.IsTradeable(item) and (TradeConfig.AllowLimited or item.Limited ~= true) then
			table.insert(list, { kind = "cosmetic", id = id, name = item.Name, color = item.Color })
		end
	end
	for _, id in (profile.emotes or {}) :: { string } do
		local emote = CosmeticsConfig.GetEmote(id)
		if emote and CosmeticsConfig.IsTradeable(emote) and (TradeConfig.AllowLimited or emote.Limited ~= true) then
			table.insert(list, { kind = "emote", id = id, name = emote.Name, color = emote.Color })
		end
	end
	return list
end

function TradeConfig.NameOf(kind: string, id: string): string
	if kind == "character" then
		local def = CharacterDefs.Get(id)
		return if def then def.DisplayName else id
	end
	local item = CosmeticsConfig.GetItem(id)
	if item then
		return item.Name
	end
	local emote = CosmeticsConfig.GetEmote(id)
	return if emote then emote.Name else id
end

return TradeConfig
