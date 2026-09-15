--!strict
--[[
	AdminConfig (SÓ SERVIDOR — ServerScriptService nunca replica para o cliente)
	Quem pode abrir o menu de desenvolvedor.

	Regras (AdminService):
	  - Nick (player.Name, sem diferenciar maiúsculas) em `Developers`, OU UserId em
	    `DeveloperIds`, OU dono do jogo (game.CreatorId).
	  - Quem não passa não recebe o atributo IsDeveloper e o ícone "Dev" nem aparece;
	    mesmo que forje o remote, o servidor recusa.
]]

return {
	Developers = {
		"guilacartinhasgames",
		"humanoider_20",
	} :: { string },
	DeveloperIds = {
		-- [123456789] = true,
	} :: { [number]: boolean },
	AllowAnyoneInStudio = false,
}
