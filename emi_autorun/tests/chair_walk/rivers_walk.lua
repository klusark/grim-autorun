-- ScummVM #11873: Miss Rivers walks through Yangja's chair (pta.chair2) on the way back from the trash can in the classroom, after
-- she has taken Mungle's tobacco. From the game's jump to Jambalaya (275): the teacher sends Guybrush to the school, the first quiz
-- answer starts the tobacco part. Logs where Miss Rivers walks and the closest distance (x-z) to chair2 and to Yangja on each walk.
ar_log("=== rivers_walk ===")
ar_wait_for_control()
dofile("_jumpscripts.lua")
start_script(jump_script, "275")
ar_wait_for(function() return system.currentSet == cpt end, 30000, "Jambalaya puppet town")
ar_wait_for_control()
sleep_for(2000)
RW_WALK = 0
RW_WAS = nil
rw_d = function(a, b)
	local p = a:getpos()
	local q = b:getpos()
	local dx = p.x - q.x
	local dz = p.z - q.z
	return sqrt(dx * dx + dz * dz)
end
rw_watch = function()
	local f = 0
	local mc = 99
	local my = 99
	while TRUE do
		if system.currentSet == pta and miss_rivers:is_moving() then
			if not RW_WAS then
				RW_WALK = RW_WALK + 1
				mc = 99
				my = 99
				local p = miss_rivers:getpos()
				ar_log("RW walk " .. RW_WALK .. " starts at " .. p.x .. " " .. p.z)
			end
			RW_WAS = TRUE
			local dc = rw_d(miss_rivers, pta.chair2)
			local dy = rw_d(miss_rivers, yangja)
			if dc < mc then mc = dc end
			if dy < my then my = dy end
			f = f + 1
			if mod(f, 4) == 0 then
				local p = miss_rivers:getpos()
				ar_log("RWP " .. RW_WALK .. " " .. p.x .. " " .. p.z)
			end
		elseif RW_WAS then
			RW_WAS = nil
			local p = miss_rivers:getpos()
			ar_log("RW walk " .. RW_WALK .. " ends at " .. p.x .. " " .. p.z .. " closest chair2 " .. mc .. " yangja " .. my)
		end
		break_here()
	end
end
start_script(rw_watch)
ar_put_away()
AR_NO_CHEAT = TRUE
AR_CELL_SET = nil
ar_talk(cpt.teacher_obj)
AR_NO_CHEAT = nil
ar_dlg("tc1")
a2_ready("tc1", 3000)
ar_say("tc1", 70)
a2_ready("tc1", 15000)
ar_say("tc1", 72)
ar_wait_for(function() return ar_set_name() == "pirate transmogrification academy" end, 60000, "the school")
local worst = { 130, 210, 300, 430, 500, 610, 730, 820, 930 }
local guard = 0
local answered = nil
while not answered and guard < 400 do
	sleep_for(1000)
	guard = guard + 1
	local d = getglobal("pt1")
	if d and d.running and d.node and ar_dialog_ready(d, 100) then
		local k = a2_pick_any("pt1", worst)
		if k then
			ar_log("quiz answer " .. k)
			answered = TRUE
		end
	end
end
ar_wait_for(function() return glob.seen_tobacco_taken end, 60000, "the tobacco")
sleep_for(30000)
ar_log("=== rivers_walk done ===")
