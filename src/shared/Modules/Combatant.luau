--!strict
--[[
	Combatant — quem LUTA (dono, 2026-09-23: bots com habilidades REAIS para o trailer/testes).
	Um "Fighter" é um `Player` (jogador) OU o `Model` de um bot do servidor (atributo `Bot = true`,
	criado pelo BotService). Os services do núcleo (Health/Ragdoll/Combat/Movement/Ability) recebem
	Fighter no lugar de Player; atributos de estado (CharacterId, Energy, DashingUntil, Ragdolled...) ficam
	no próprio Fighter (`:GetAttribute/:SetAttribute` funcionam igual em Player e Model), e o que é só de
	cliente (FireClient, HUD, DataStore, crédito de kill/pontos) acontece apenas quando há Player.
	Bots têm `Npc = true` também: os ramos "NPC" que já existiam (knockback/ragdoll simulados pelo
	servidor, hitbox estrita do servidor) valem para eles.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Combatant = {}

export type Fighter = Instance -- Player | Model (bot)

Combatant.BotTag = "Bot"
Combatant.ATTR_BOT = "Bot"
Combatant.ATTR_BOT_USERID = "BotUserId" -- negativo, único por bot (crédito/trava de agarrão usam UserId)

--- É o Model de um bot?
function Combatant.IsBot(inst: Instance?): boolean
	return inst ~= nil and inst:IsA("Model") and inst:GetAttribute(Combatant.ATTR_BOT) == true
end

function Combatant.IsPlayer(inst: Instance?): boolean
	return inst ~= nil and inst:IsA("Player")
end

--- Quem controla este personagem: o Player, ou o próprio Model se for bot. nil = NPC sem lutador
--- (boneco de treino, boss NPC, traidor).
function Combatant.Of(character: Model?): Fighter?
	if not character then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		return player
	end
	if Combatant.IsBot(character) then
		return character
	end
	return nil
end

--- Personagem (Model) do lutador: Player.Character ou o próprio bot.
function Combatant.CharacterOf(fighter: Fighter?): Model?
	if not fighter then
		return nil
	end
	if fighter:IsA("Player") then
		return fighter.Character
	end
	if fighter:IsA("Model") then
		return fighter
	end
	return nil
end

function Combatant.PlayerOf(fighter: Fighter?): Player?
	return if fighter and fighter:IsA("Player") then fighter else nil
end

--- Ainda está no jogo (Player em Players / bot ainda no Workspace)?
function Combatant.IsPresent(fighter: Fighter?): boolean
	if not fighter then
		return false
	end
	if fighter:IsA("Player") then
		return fighter.Parent == Players
	end
	return fighter.Parent ~= nil
end

function Combatant.Name(fighter: Fighter?): string
	return if fighter then fighter.Name else "?"
end

--- UserId do jogador, ou o id NEGATIVO do bot (0 se não for lutador).
function Combatant.UserId(fighter: Fighter?): number
	if not fighter then
		return 0
	end
	if fighter:IsA("Player") then
		return fighter.UserId
	end
	local id = fighter:GetAttribute(Combatant.ATTR_BOT_USERID)
	return if typeof(id) == "number" then id else 0
end

--- Lutador por UserId (positivo = Player; negativo = bot).
function Combatant.ByUserId(userId: number): Fighter?
	if userId > 0 then
		return Players:GetPlayerByUserId(userId)
	end
	for _, model in CollectionService:GetTagged(Combatant.BotTag) do
		if model:GetAttribute(Combatant.ATTR_BOT_USERID) == userId then
			return model
		end
	end
	return nil
end

--- FireClient só quando há cliente (bot não recebe nada).
function Combatant.Notify(fighter: Fighter?, remote: RemoteEvent, ...: any)
	local player = Combatant.PlayerOf(fighter)
	if player then
		remote:FireClient(player, ...)
	end
end

--- Todos os lutadores presentes: jogadores + bots.
function Combatant.All(): { Fighter }
	local list: { Fighter } = {}
	for _, p in Players:GetPlayers() do
		table.insert(list, p)
	end
	for _, m in CollectionService:GetTagged(Combatant.BotTag) do
		if m.Parent then
			table.insert(list, m)
		end
	end
	return list
end

return Combatant
