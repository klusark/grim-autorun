-- Tier A: the plan of every case (after offline.lua). AR_NT_FROM / AR_NT_TO: only those cases (the game's Lua kills a script that runs
-- for long without a break_here: tools/lua31/run.sh runs batches)
AR_NT_I = AR_NT_FROM or 1
while NAVTESTS[AR_NT_I] and (not AR_NT_TO or AR_NT_I <= AR_NT_TO) do
	local case = NAVTESTS[AR_NT_I]
	if (not AR_NT_ONLY or AR_NT_ONLY == case.id) and not case.ingame then
		ar_nt_unit(case)
	end
	AR_NT_I = AR_NT_I + 1
end
PrintDebug("NAVTEST SUMMARY unit " .. AR_NT_PASS.unit .. "/" .. AR_NT_RUN.unit .. "\n")
if not NAVTESTS[AR_NT_I] then
	PrintDebug("NAVTEST LAST\n")
end
