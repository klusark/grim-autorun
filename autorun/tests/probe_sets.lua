-- Probe: the hand-made sets load, can be entered with noenter, and have the sectors of tools/mk_set.py. TESTSETS=1 sh run_chapter.sh tests/probe_sets.lua 200
ar_wait_for_control()
ar_fx_make_sets()
local i = 1
while AR_FX_SETS[i] do
	local set = getglobal(AR_FX_SETS[i])
	set:switch_to_set("noenter")
	break_here()
	break_here()
	manny:put_in_set(set)
	manny:setpos(0, 0, 0)
	break_here()
	local nav = ar_nav_of(set)
	local id, name = IsPointInSector(0, 0, 0, "")
	PrintDebug("PROBE " .. set.name .. " sectors " .. ar_nav_count(nav) .. " current " .. tostring(system.currentSet.name) .. " at " .. tostring(name) .. "\n")
	i = i + 1
end
PrintDebug("PROBE DONE\n")
ar_finish()
