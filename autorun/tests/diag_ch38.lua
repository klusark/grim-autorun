-- Diagnostic wrappers (DIAG lines in the log): the game's waits and movie calls log when they begin and end, with the caller's actor. Installed by DIAG_install()
-- after a load (a load brings the game's own functions back).
DIAG_install = function()
	if DIAG_ON then
		return
	end
	DIAG_ON = TRUE
	DIAG_wfc = Actor.wait_for_chore
	Actor.wait_for_chore = function(a, b, c)
		PrintDebug("DIAG wait_for_chore begin " .. tostring(a.name) .. " " .. tostring(b) .. " " .. tostring(c) .. "\n")
		DIAG_wfc(a, b, c)
		PrintDebug("DIAG wait_for_chore end " .. tostring(a.name) .. "\n")
	end
	DIAG_wfm = Actor.wait_for_message
	Actor.wait_for_message = function(a)
		PrintDebug("DIAG Actor.wait_for_message begin " .. tostring(a.name) .. "\n")
		DIAG_wfm(a)
		PrintDebug("DIAG Actor.wait_for_message end " .. tostring(a.name) .. "\n")
	end
	DIAG_wm = wait_for_message
	wait_for_message = function()
		PrintDebug("DIAG wait_for_message begin\n")
		DIAG_wm()
		PrintDebug("DIAG wait_for_message end\n")
	end
	DIAG_sl = Actor.say_line
	Actor.say_line = function(a, b, c, d, e)
		PrintDebug("DIAG say_line " .. tostring(a.name) .. " " .. tostring(b) .. "\n")
		return DIAG_sl(a, b, c, d, e)
	end
	DIAG_rfm = RunFullscreenMovie
	RunFullscreenMovie = function(a, b, c)
		PrintDebug("DIAG RunFullscreenMovie begin " .. tostring(a) .. "\n")
		local r = DIAG_rfm(a, b, c)
		PrintDebug("DIAG RunFullscreenMovie end " .. tostring(a) .. "\n")
		return r
	end
	DIAG_pc = Actor.play_chore
	Actor.play_chore = function(a, b, c, d)
		PrintDebug("DIAG play_chore " .. tostring(a.name) .. " " .. tostring(b) .. " " .. tostring(c) .. "\n")
		return DIAG_pc(a, b, c, d)
	end
	DIAG_el = Dialog.execute_line
	Dialog.execute_line = function(a, b, c)
		PrintDebug("DIAG execute_line begin\n")
		DIAG_el(a, b, c)
		PrintDebug("DIAG execute_line end\n")
	end
	DIAG_fin = Dialog.finish
	Dialog.finish = function(a)
		PrintDebug("DIAG Dialog.finish begin\n")
		DIAG_fin(a)
		PrintDebug("DIAG Dialog.finish end\n")
	end
	DIAG_dl = Dialog.display_lines
	Dialog.display_lines = function(a)
		PrintDebug("DIAG display_lines begin node " .. tostring(a.node) .. "\n")
		DIAG_dl(a)
		PrintDebug("DIAG display_lines end\n")
	end
	DIAG_ehc = enable_head_control
	enable_head_control = function(a)
		PrintDebug("DIAG enable_head_control begin\n")
		DIAG_ehc(a)
		PrintDebug("DIAG enable_head_control end\n")
	end
	DIAG_sotp = SetOffscreenTextPos
	SetOffscreenTextPos = function(a, b)
		PrintDebug("DIAG SetOffscreenTextPos\n")
		return DIAG_sotp(a, b)
	end
	start_script(DIAG_watch)
end
DIAG_watch = function()
	local n = 0
	while TRUE do
		sleep_for(5000)
		n = n + 1
		PrintDebug("DIAG watch " .. n .. " execute_line running: " .. tostring(find_script(cp1.execute_line)) .. " finish running: " .. tostring(find_script(Dialog.finish)) .. " buttonHandler cp1: " .. tostring(system.buttonHandler == cp1) .. "\n")
	end
end
-- Chapter 38: the sunken Lola. Walking the ring of the wreck brings Chepito, the lamplighter, who
-- circles Manny. When he passes close, Manny turns to him and stops him with a talk; after the
-- talk he dangles his lantern as bait, Manny grabs it (and Chepito) and hands him to Glottis
-- (left or right key): the Pearl cutscene. Checkpoint in slot 54.

ar_load(37)
DIAG_install()
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- the ring of the wreck: Glottis comments, then Chepito appears
ar_walk_to(0.55, -3.65, 0)
ar_wait_for_control()
ar_walk_to(-0.1, -4.35, 0)

-- turns Manny to an object's actor, step by step as the stick does, and has the game offer it
local face = function(obj)
	local io = obj.interest_actor
	local p = io:getpos()
	local n = 0
	while TurnActorTo(manny.hActor, p.x, p.y, p.z) and n < 100 do
		break_here()
		n = n + 1
	end
	return ar_gaze_at(obj)
end

local done = nil
local w = 0
while not done and w < 6000 do
	local io = su.moving_chepito_obj.interest_actor
	if su.moving_chepito_obj.touchable and io and proximity(io) < 1.45 then
		if face(su.moving_chepito_obj) then
			ar_press("use")
			done = TRUE
		end
	end
	sleep_for(50)
	w = w + 1
end
ar_check(done, "Manny stopped Chepito")
ar_wait_for(function() return cp1 and system.buttonHandler == cp1 end, 60000)
ar_check(cp1 and system.buttonHandler == cp1, "Chepito talks")
ar_pick_exit(cp1)

-- the bait
done = nil
w = 0
while not done and w < 6000 do
	if su.lantern.touchable and face(su.lantern) then
		ar_press("pickUp")
		done = TRUE
	end
	sleep_for(50)
	w = w + 1
end
ar_check(done, "Manny grabbed the lantern")
ar_wait_for(function() return system.buttonHandler == suButtonHandler end, 120000)
ar_check(system.buttonHandler == suButtonHandler, "Manny holds Chepito")
ar_key_down("TURN_RIGHT")
sleep_for(150)
ar_key_up("TURN_RIGHT")
ar_wait_for(function() return system.currentSet == ps end, 600000)
ar_wait_for(function() return ps.octo_here and not find_script(cut_scene.thepearl) end, 900000)
ar_wait_for_control()
local pp = manny:getpos()
ar_log("POS_AFTER " .. pp.x .. " " .. pp.y)
ar_state("end of chapter 38")
ar_checkpoint(38)
