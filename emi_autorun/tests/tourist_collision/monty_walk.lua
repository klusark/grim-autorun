-- ScummVM #11822: Guybrush walks through the tourist (Monty, at Tiny LaFeet's statue in Jambalaya town) when he is sent to talk to
-- him from Monty's right. From the game's own jump to Act 2 in Jambalaya (250), from several places around Monty: talk to him and log
-- the closest distance (x-z, centres) from Guybrush to Monty during the walk.
ar_log("=== monty_walk ===")
ar_wait_for_control()
dofile("_jumpscripts.lua")
start_script(jump_script, "250")
ar_wait_for(function() return system.currentSet == gpt end, 30000, "Jambalaya town")
ar_wait_for_control()
sleep_for(2000)
TM_ON = nil
TM_MIN = 99
tm_watch = function()
	while TRUE do
		if TM_ON and guybrush:is_moving() then
			local p = guybrush:getpos()
			local q = monty:getpos()
			local dx = p.x - q.x
			local dz = p.z - q.z
			local d = sqrt(dx * dx + dz * dz)
			if d < TM_MIN then TM_MIN = d end
		end
		break_here()
	end
end
start_script(tm_watch)
tm_dlg = function()
	return mn1 and mn1.running
end
TM_STARTS = { { 3.65, -27.29 }, { 3.63, -27.11 }, { 3.45, -27.94 }, { 3.43, -26.75 }, { 3.51, -26.76 }, { 3.15, -28.34 }, { 2.36, -28.04 }, { 3.92, -27.89 }, { 2.15, -27.04 }, { 3.7, -26.9 } }
local i = 1
while TM_STARTS[i] do
	local s = TM_STARTS[i]
	ar_walk_to(s[1], 3.05, s[2])
	ar_wait_for_control()
	guybrush:setpos(s[1], 3.05, s[2])
	break_here()
	local gp = guybrush:getpos()
	ar_log("TM trial " .. i .. " from " .. gp.x .. " " .. gp.z)
	TM_MIN = 99
	TM_ON = TRUE
	local task = start_script(gpt.monty_obj.talkTo, gpt.monty_obj)
	local ok = ar_try_wait(tm_dlg, 20000)
	TM_ON = nil
	ar_log("TM trial " .. i .. " closest: monty " .. TM_MIN)
	if ok then
		ar_say_exit("mn1")
		ar_dlg_done("mn1")
	else
		ar_log("TM trial " .. i .. " STUCK")
		stop_script(task)
		guybrush:stop_moving()
	end
	ar_wait_for_control()
	i = i + 1
end
ar_log("=== monty_walk done ===")
