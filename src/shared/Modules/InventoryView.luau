--!strict
-- Filtros de apresentação; inventário e uso de itens continuam autoritativos no servidor.
local View = {}
View.Tabs = {
	{ Id = "all", Label = "Tudo" }, { Id = "arrow", Label = "Flechas" },
	{ Id = "stand", Label = "Discos" }, { Id = "race", Label = "Raças" },
	{ Id = "build", Label = "Build" },
}
function View.Matches(tab: string, query: string, id: string, name: string, kind: string): boolean
	if tab == "build" or (tab ~= "all" and kind ~= tab) then return false end
	local term = query:match("^%s*(.-)%s*$") or ""
	return term == "" or string.find(string.lower(name .. " " .. id), string.lower(term), 1, true) ~= nil
end
return View
