-- ScummVM #11886: Guybrush can get stuck after bumping into the Lua Bar waitress on the bridge to the kitchen (lua.collide: "Ah...
-- oops, sorry", then lua.ensurewalk calls walkto every frame until he is within 0.1 of a point past her). From the game's jump to
-- Act 2 (200) into the Lua Bar, 40 walks across the bridge between the two points ensurewalk uses. Logs each bump, how long its
-- cutscene lasted and, after 20 s, STUCK (the waitress is then put out of the way, a test-only way out, and the walks go on).
ar_log("=== bridge_walk ===")
ar_wait_for_control()
dofile("_jumpscripts.lua")
start_script(jump_script, "200")
ar_dlg("el15")
sleep_for(2000)
ar_exhaust("el15", nil, 20)
ar_dlg_done("el15")
ar_wait_for_control()
switch_to_set("lua")
ar_wait_for(function() return system.currentSet == lua end, 30000, "the Lua bar")
ar_wait_for_control()
sleep_for(2000)
WB_BUMPS = 0
WB_STUCK = 0
wb_collide_game = lua.collide
wb_collide = function(arg1, arg2)
	if arg2 == guybrush then
		WB_BUMPS = WB_BUMPS + 1
		local p = guybrush:getpos()
		local q = arg1:getpos()
		ar_log("WB bump " .. WB_BUMPS .. " guybrush " .. p.x .. " " .. p.z .. " " .. arg1.name .. " " .. q.x .. " " .. q.z)
	end
	wb_collide_game(arg1, arg2)
end
lua.waitress.collision_handler = wb_collide
wb_watch = function()
	local t = 0
	while TRUE do
		if cutSceneLevel > 0 then
			t = t + system.frameTime
			if t > 20000 then
				WB_STUCK = WB_STUCK + 1
				local p = guybrush:getpos()
				ar_log("WB STUCK " .. WB_STUCK .. " guybrush " .. p.x .. " " .. p.z)
				lua.waitress:setpos(6, 0.35, 4.5)
				t = 0
			end
		else
			if t > 3000 then
				ar_log("WB cutscene " .. t .. " ms")
			end
			t = 0
		end
		break_here()
	end
end
start_script(wb_watch)
local i = 1
while i <= 40 do
	if mod(i, 2) == 1 then
		ar_walk_to(1.38, 0.35, 2.25, nil, 20000)
	else
		ar_walk_to(-3.18, 0.01, -0.82, nil, 20000)
	end
	ar_wait_for_control()
	i = i + 1
end
ar_log("WB done: " .. WB_BUMPS .. " bumps, " .. WB_STUCK .. " stuck")
