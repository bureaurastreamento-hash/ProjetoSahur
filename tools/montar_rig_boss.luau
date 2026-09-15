--[[
	MONTA O RIG DO BOSS NO STUDIO (modo Edit, com o Rojo conectado), em cima de
	ServerStorage.BossModel, para dar para animar no Animation Editor.

	COMO USAR: abra este arquivo, selecione TUDO (Ctrl+A), copie (Ctrl+C), vá no Studio em
	View > Command Bar, cole (Ctrl+V) e aperte Enter. Depois: File > Save to Roblox.
	(Colar só o caminho "tools/montar_rig_boss.luau" não funciona — tem que ser o conteúdo.)

	O que faz (BossRig.Assemble, o mesmo que o servidor usa em runtime):
	  • usa os grupos Tronco / Cabeça / BracoDir / BracoEsq / PernaDir / PernaEsq;
	  • cria os Motor6D tronco -> membros (Neck, Right/Left Shoulder, Right/Left Hip) que faltavam;
	  • solda os micro-detalhes sem junta na parte com junta mais próxima do mesmo grupo;
	  • cria HumanoidRootPart + RootJoint + Humanoid (R15). Mantém os grupos (não achata).
	Pode rodar mais de uma vez: não duplica o que já existe.
]]
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local model = ServerStorage:FindFirstChild("BossModel", true)
if not model or not model:IsA("Model") then
	warn("[BossRig] ServerStorage.BossModel não encontrado")
	return
end
local BossRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("BossRig"))
local report = BossRig.Assemble(model, { Flatten = false })
print(("[BossRig] pronto: %d partes em %d grupos, %d Motor6D, %d soldadas, raiz %s, HipHeight %.1f"):format(
	report.parts, report.groups, report.motors, report.welded, report.root, report.hipHeight))
print("[BossRig] agora: selecione o BossModel e abra o Animation Editor (Avatar > Animation Editor); salve o place.")
