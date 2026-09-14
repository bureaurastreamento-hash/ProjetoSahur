--!strict
--[[
	Log
	Log com nível. Em Studio o padrão é verboso; em servidor publicado só warn/erro.
	  Log.debug("[X] ...")  -> só quando Log.Verbose
	  Log.info(...)         -> sempre (use com moderação: boot, round, save)
	  warn(...)             -> continue usando warn para problemas
]]

local RunService = game:GetService("RunService")

local Log = {}

Log.Verbose = RunService:IsStudio()

function Log.debug(...: any)
	if Log.Verbose then
		print(...)
	end
end

function Log.info(...: any)
	print(...)
end

return Log
