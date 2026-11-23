-- Bug 11789 (wood footsteps on Jambalaya's beach): which footstep sector (type SPECIAL) Guybrush is in at a few places of the town
-- (gpt), and the footstep sound StepMan picks there. gpt.setb's footstep_dock (id 821) repeats its first corner.
ar_log("=== gpt footstep sectors ===")
ar_wait_for_control()
dofile("_jumpscripts.lua")
start_script(jump_script, "250")
local t = 0
while (system.currentSet ~= gpt or cutSceneLevel > 0) and t < 600 do
	break_here()
	t = t + 1
end
ar_wait_for_control()
fsg_name = function(tbl)
	local k, v = next(footsteps, nil)
	while k do
		if v == tbl then
			return k
		end
		k, v = next(footsteps, k)
	end
	return "nil"
end
fsg_at = function(label, x, y, z)
	guybrush:setpos(x, y, z)
	break_here()
	break_here()
	local id, name = guybrush:find_sector_type(SPECIAL)
	ar_log("FSG " .. label .. ": sector " .. tostring(name) .. " id " .. tostring(id) .. ", override " .. fsg_name(glob.footstep_override_sound) .. ", default " .. fsg_name(guybrush.footsteps))
end
ar_log("FSG multiple_footstep_sounds " .. tostring(glob.multiple_footstep_sounds))
fsg_at("town (sector137q)", 7.3, 3.0, -30.0)
fsg_at("pier (sector75)", -37.6, 0.5, -7.9)
fsg_at("pier end (sector72)", -44.2, 0.5, -22.6)
fsg_at("beach (sector76)", -30.1, 0.5, 1.1)
fsg_at("beach far (sector86)", -13.1, 0.5, 10.4)
ar_log("FSG done")
