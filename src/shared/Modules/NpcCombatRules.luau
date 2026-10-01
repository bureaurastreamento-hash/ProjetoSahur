--!strict
local Combatant = require(script.Parent.Combatant)
local Rules = {}
-- NPCs aliados serão uma implementação própria futura, sem exceção implícita por TeamId.
function Rules.CanDamage(attacker: Instance?, victim: Instance?): boolean
	if not attacker then return true end -- dano ambiental
	return Combatant.PlayerOf(attacker) ~= nil or Combatant.PlayerOf(victim) ~= nil
end
return Rules
