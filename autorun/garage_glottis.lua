-- Plays Manny from his office, down the elevator to the garage, and through the first
-- conversation with Glottis. It can start from the office, the hallway or the garage.
--
-- scummvm --autorun=garage_glottis.lua --save-slot=N --debugflags=scripts grim-win
--
-- To run it faster add --engine-speed=0 --sim-fps=60, and mute the voices (speech_mute
-- with subtitles), as they keep their normal speed.
--
-- The output goes through PrintDebug, so it needs --debugflags=scripts. Every line starts
-- with AUTORUN, the last one is RESULT PASSED or RESULT FAILED, and then the game exits.
-- Lua 3.1 has no for loops, only while and repeat.

AR_FAILED = FALSE

ar_log = function(msg)
	PrintDebug("AUTORUN " .. msg .. "\n")
end

ar_check = function(cond, msg)
	if cond then
		ar_log("PASS " .. msg)
	else
		ar_log("FAIL " .. msg)
		AR_FAILED = TRUE
	end
end

ar_finish = function()
	if AR_FAILED then
		ar_log("RESULT FAILED")
	else
		ar_log("RESULT PASSED")
	end
	exit()
end

-- Waits until cond() returns something true, for at most timeout milliseconds
ar_wait_for = function(cond, timeout)
	local waited = 0
	while not cond() and waited < timeout do
		sleep_for(100)
		waited = waited + 100
	end
	return cond()
end

-- A player cannot walk during a cutscene, and walking while one is still running keeps it
-- from ending (it waits for Manny to stop), which keeps the camera from following. So wait
-- until the game gives control back, for example after a door brought Manny to a new set.
ar_wait_for_control = function()
	if not ar_wait_for(function() return cutSceneLevel == 0 end, 60000) then
		ar_log("FAIL the game never gave control back")
		AR_FAILED = TRUE
	end
end

AR_CAMERA = nil

-- Logs the camera setup whenever it changes
ar_note_camera = function()
	local setup = tostring(system.currentSet.name) .. " setup " .. tostring(system.currentSet:current_setup())
	if setup ~= AR_CAMERA then
		AR_CAMERA = setup
		ar_log("camera: " .. setup)
	end
end

-- Walks Manny to a point the way a player does, outside of any cutscene, so the camera
-- follows. Sectors on the way can stop the walk, for example the garage moves Manny across
-- its hot sectors, so the walk is started again until he is there or stop_when() is true.
ar_walk_to = function(x, y, z, stop_when)
	local tries = 0
	ar_wait_for_control()
	ar_note_camera()
	while point_proximity(x, y, z) > 0.1 and tries < 10 and not (stop_when and stop_when()) do
		manny:walkto(x, y, z)
		while manny:is_moving() or manny:is_turning() do
			ar_note_camera()
			break_here()
		end
		tries = tries + 1
	end
	ar_note_camera()
	return point_proximity(x, y, z) <= 0.1
end

ar_in_dialog = function()
	return gl1 and system.buttonHandler == gl1
end

ar_in_hallway = function()
	return system.currentSet == ha
end

ar_in_garage = function()
	return system.currentSet == ga
end

ar_left_office = function()
	return system.currentSet ~= mo
end

-- A conversation that hangs would keep the game running for ever
ar_watchdog = function()
	sleep_for(600000)
	ar_log("FAIL timed out")
	AR_FAILED = TRUE
	ar_finish()
end
start_script(ar_watchdog)

ar_log("start in " .. tostring(system.currentSet.name))

-- 1. The office to the hallway. Walking into the door sector takes Manny through, as in the
-- game. If it does not, the door is used.
if system.currentSet == mo then
	ar_log("step: office to hallway")
	ar_walk_to(mo.ha_door.out_pnt_x, mo.ha_door.out_pnt_y, mo.ha_door.out_pnt_z, ar_left_office)
	if not ar_wait_for(ar_in_hallway, 20000) then
		ar_log("the door sector did not take Manny through, using the door")
		mo.ha_door:walkOut()
	end
	ar_check(ar_in_hallway(), "in the hallway")
end

-- 2. The elevator down to the garage. The door opens as Manny comes close and walking on
-- into the door sector takes him down. If it does not, the door is used.
if system.currentSet == ha then
	ar_log("step: hallway to garage")
	ar_walk_to(ha.ga_door.use_pnt_x, ha.ga_door.use_pnt_y, ha.ga_door.use_pnt_z, ar_in_garage)
	ar_check(ar_in_garage() or ha:current_setup() == ha_elvos, "the camera moved to the elevator view")
	if not ar_wait_for(ar_in_garage, 20000) then
		ar_log("the door sector did not take Manny down, using the door")
		ha.ga_door:use()
	end
	ar_check(ar_in_garage(), "in the garage")
end

if system.currentSet ~= ga then
	ar_log("FAIL cannot get to the garage from " .. tostring(system.currentSet.name))
	ar_finish()
end

-- 3. Walking to the fountain. The garage stops the walk now and then, and using the fountain
-- disturbs Glottis, who comes out to talk. The junk that falls on the way (the crash
-- trigger) starts the same conversation, so wait for the conversation either way.
ar_log("step: walk to the fountain")
ar_walk_to(ga.fountain.use_pnt_x, ga.fountain.use_pnt_y, ga.fountain.use_pnt_z, ar_in_dialog)
if not ar_in_dialog() then
	ga.fountain:use()
end
ar_check(ar_wait_for(ar_in_dialog, 180000), "the conversation with Glottis started")
if not ar_in_dialog() then
	local p = manny:getpos()
	ar_log("Manny is at " .. format("(%.2f %.2f)", p.x, p.y) .. ", crash triggered: " .. tostring(ga.crash.triggered))
end

-- 4. Ask Glottis about himself, then say goodbye
if ar_in_dialog() then
	ar_log("step: talk to Glottis")
	gl1:execute_line(gl1[60])
	ar_check(glottis.introduced, "Glottis introduced himself")
	ar_log("step: end the conversation")
	gl1:execute_line(gl1.exit_lines.first_glottis_node)
	ar_check(not ar_in_dialog(), "the conversation ended")
end

ar_check(glottis.met, "Glottis has been met")
ar_check(system.currentSet == ga, "still in the garage")
ar_finish()
