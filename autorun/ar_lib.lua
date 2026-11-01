-- Helpers for autorun scripts that play Grim Fandango. Prepended to a chapter script by
-- run_chapter.sh. Lua 3.1 has no for loops, no local functions and no # operator.
--
-- Output goes through PrintDebug (needs --debugflags=scripts). Every line starts with AUTORUN.
-- Verbs go through the game's own Sentence(), the same entry point as a player's click, and
-- the helpers wait the way a player has to: no walking while a cutscene is running.

-- A save made during a run holds the helper tasks of that run: stop those by the task ids kept
-- in globals before the new ones start
-- (chapter 13 set this for its own cutscene, and a global stays set in the saves)
AR_NO_SKIP = nil

-- The settings the two engines are compared with: subtitles only, text speed 7 (the registry of the original here; ScummVM's own configuration differs), so that a
-- line lasts as long as its text says on both
if SetTextSpeed and not AR_REAL then
	SetTextSpeed(7)
end

if AR_SKIP_TASK then
	stop_script(AR_SKIP_TASK)
end
if AR_OV_TASK then
	stop_script(AR_OV_TASK)
end
if AR_OV_CLOCK_TASK then
	stop_script(AR_OV_CLOCK_TASK)
end
if AR_WATCH_TASK then
	stop_script(AR_WATCH_TASK)
end
if AR_LINE_TASK then
	stop_script(AR_LINE_TASK)
	AR_LINE_TASK = nil
end

AR_FAILED = FALSE

-- AR_NOTIMEOUT (set for a run in real time, REALTIME=1): no wait, walk, drive or movie of the run is given up after a time; it goes on until it ends or is killed
if AR_NOTIMEOUT then
	AR_IDLE_MAX = 1000000000000
end

AR_KEEP_GOING = FALSE

-- The last few steps are shown in the top left corner of the screen. Text objects are part of
-- a save, so they are taken off the screen before one is made.
AR_SHOW_LINES = 5
-- (kept when another copy of the library is loaded later: the text objects it drew can only be removed through them)
ar_shown = ar_shown or { }
ar_shown_objs = ar_shown_objs or { }
ar_shown_count = ar_shown_count or 0
-- (a font of its own: the text objects crash the original when the game gets rid of the one it uses, as it does
-- at the change of the year)
AR_FONT = AR_FONT or LockFont("ocr10.laf")
-- (a small font, a line is cut at AR_SHOW_COLS characters so that it does not wrap on the 640 pixels of the screen, and the lines are AR_SHOW_STEP apart)
AR_SHOW_COLS = 88
AR_SHOW_STEP = 14

ar_screen_clear = function()
	local i = 1
	while i <= ar_shown_count do
		if ar_shown_objs[i] then
			KillTextObject(ar_shown_objs[i])
			ar_shown_objs[i] = nil
		end
		i = i + 1
	end
end

ar_screen_draw = function()
	local i = 1
	local color
	while i <= ar_shown_count do
		color = White
		if i == ar_shown_count then
			color = Yellow
		end
		ar_shown_objs[i] = MakeTextObject(ar_shown[i], { x = 8, y = 20 + (i - 1) * AR_SHOW_STEP, font = AR_FONT, fgcolor = color, ljustify = TRUE })
		i = i + 1
	end
end

ar_screen_add = function(msg)
	if strlen(msg) > AR_SHOW_COLS then
		msg = strsub(msg, 1, AR_SHOW_COLS - 3) .. "..."
	end
	local i = 1
	ar_screen_clear()
	if ar_shown_count >= AR_SHOW_LINES then
		while i < ar_shown_count do
			ar_shown[i] = ar_shown[i + 1]
			i = i + 1
		end
	else
		ar_shown_count = ar_shown_count + 1
	end
	ar_shown[ar_shown_count] = msg
	ar_screen_draw()
end

-- The game's log of the dialog appends every line to a file that is read and written whole (and compressed) each time: it is not for a run that no person plays
if dialog_log and not AR_REAL then
	dialog_log.bActive = nil
	dialog_log.on = function(self) end
end

ar_log = function(msg)
	-- (SPEEDLOG: the frame of every line, to see what a stop was waiting for)
	if AR_SPEEDLOG then
		PrintDebug("AUTORUN [" .. tostring(AR_FRAME) .. "] " .. msg .. "\n")
	else
		PrintDebug("AUTORUN " .. msg .. "\n")
	end
	-- (FRAMES=0: a frame at every step that passed, the same point of the script in both engines, whatever their speed)
	if AR_FRAMES and AR_FRAME_CH and strfind(msg, "^PASS ") then
		ar_frame(AR_FRAME_CH .. "_s" .. format("%04d", AR_STEP_N or 0))
		AR_STEP_N = (AR_STEP_N or 0) + 1
	end
	-- the steps worth following, not the camera and walking details
	if not AR_NOSCREEN and not AR_SAVING and not strfind(msg, "^camera") and not strfind(msg, "^running=") and not strfind(msg, "^walk %(") and not strfind(msg, "^Starting wait") and not strfind(msg, "^Waited") then
		ar_screen_add(msg)
	end
end

-- What a run did, for the coverage report (tools/cov100.py): COV lines, in every mode, not shown on the screen
ar_cov = function(msg)
	PrintDebug("AUTORUN COV " .. msg .. "\n")
end

ar_check = function(cond, msg)
	if cond then
		ar_log("PASS " .. msg)
	else
		ar_log("FAIL " .. msg)
		AR_FAILED = TRUE
		if not AR_KEEP_GOING then
			ar_finish()
		end
	end
	return cond
end

ar_finish = function()
	ar_log("verbs given through the keys: " .. AR_KEYS_USED)
	ar_log("frames: " .. tostring(AR_FRAME) .. ", under the autorun control: " .. tostring(AR_FRAME_CTL or 0))
	if AR_FAILED then
		ar_log("RESULT FAILED")
	else
		ar_log("RESULT PASSED")
	end
	if AR_KEEP_GOING or AR_KEEP_ALIVE then
		stop_script(ar_watchdog)
		stop_script(ar_skipper)
		stop_script(ar_override_clock)
	else
		exit()
		-- exit() ends the game at the end of the frame, nothing more may run meanwhile

	end
	while TRUE do
		sleep_for(1000)
	end
end

-- Starts the chapter from a save: loads it and, once the game has loaded, the engine runs this
-- script again on the loaded state with AR_LOADED set (the loaded state replaces the Lua state,
-- so nothing of this run survives). In a run that plays on from the chapter before nothing is
-- loaded.
ar_load = function(slot)
	if AR_LOADED or AR_CONTINUE then
		return
	end
	ar_log("loading the checkpoint grim" .. format("%02d", slot) .. ".gsv")
	Load(format("grim%02d.gsv", slot))
	while TRUE do
		sleep_for(1000)
	end
end

-- Waits until cond() returns something true, for at most timeout milliseconds
-- Turns Manny toward an object. The game turns him toward the object's use point, which is where he stands after
-- the walk: the original cannot turn toward a point at its own position (the yaw is garbage, he spins on and on),
-- so there it is the object's own position.
ar_face = function(obj)
	if obj.obj_x then
		-- what manny:turn_toward_entity does, but it ends: Manny on a ladder never finishes turning
		if manny.is_climbing then
			return ar_fail("Manny is on a ladder, he cannot turn toward " .. tostring(obj.name))
		end
		local t = 0
		while ar_steer(obj.obj_x, obj.obj_y, manny:getpos().z, 3) and t < 8000 do
			break_here()
			t = t + system.frameTime
		end
		if t >= 8000 then
			return ar_fail("the turn toward " .. tostring(obj.name) .. " did not end in 8 seconds")
		end
	elseif obj.interest_actor then
		local q = obj.interest_actor:getpos()
		ar_turn_to_point(q.x, q.y, q.z)
	end
end

-- Manny turned toward a point with the turn key (as a player does), a few seconds at most
ar_turn_to_point = function(x, y, z)
	local t = 0
	while ar_steer(x, y, z, 3) and t < 8000 do
		break_here()
		t = t + system.frameTime
	end
end

-- Steering with the turn key, the way the game does for a player: one step of TurnActor to the left or right (the rate is
-- the actor's own) each frame. Returns true while Manny is still turning, false once his heading is within a few degrees of
-- the way to the point and he can step forward (the last degrees are turned away while walking).
-- A step of the key moves the heading the actor turns toward, and the actor follows a frame later; how far a step takes him
-- depends on the time of a frame, which the engines do not share (ScummVM at 60 frames a second turns him about 1.4 degrees a
-- frame, the original about 5.6). So the size of a step is measured, and the heading is called right within one and a half
-- steps of it, which is as near as a heading that follows a frame late can be steered.
AR_TURN_STEP = 3
ar_steer = function(x, y, z, thr)
	local yaw = manny:getrot().y
	if AR_STEER_TURNED and AR_STEER_TURNED2 and AR_STEER_YAW then
		-- (only while the key was pressed in the frames before: and not the jumps of a wall that turns him along itself)
		local dy = yaw - AR_STEER_YAW
		dy = abs(dy - 360 * floor(dy / 360 + 0.5))
		if dy > 0.05 and dy < 2.5 * AR_TURN_STEP then
			AR_TURN_STEP = 0.9 * AR_TURN_STEP + 0.1 * dy
		end
	end
	AR_STEER_TURNED2 = AR_STEER_TURNED
	AR_STEER_YAW = yaw
	local d = GetActorYawToPoint(manny.hActor, x, y, z) - yaw
	d = d - 360 * floor(d / 360 + 0.5)
	AR_STEER_D = d
	local lim = 1.6 * AR_TURN_STEP
	if lim < 6 then
		lim = 6
	end
	if abs(d) > lim then
		-- The original moves no actor while a movie plays, though the cutscene flag is down (the movie after a puzzle,
		-- with the control already back): the keys do nothing for a player either, who waits for the movie or skips it.
		-- Turns that do not turn, with a movie going: wait for it.
		if AR_TURN_YAW and abs(yaw - AR_TURN_YAW) < 0.05 then
			AR_TURN_STALL = (AR_TURN_STALL or 0) + 1
		else
			AR_TURN_STALL = 0
		end
		AR_TURN_YAW = yaw
		if AR_TURN_STALL > ar_fr(45) and IsMoviePlaying and IsMoviePlaying() then
			AR_TURN_STALL = 0
			ar_log("steer: Manny does not turn while a movie plays, waiting for the movie")
			ar_try_wait(function() return not IsMoviePlaying() end, 180000)
			ar_wait_for_control()
			AR_STEER_TURNED = nil
			return TRUE
		end
		if d > 0 then
			TurnActor(manny.hActor, 1)
		else
			TurnActor(manny.hActor, -1)
		end
		AR_STEER_TURNED = TRUE
		return TRUE
	end
	AR_STEER_TURNED = nil
	return nil
end

-- Turns Manny until he faces the object to within tol degrees (the cone in which the game sees an object can be narrow:
-- the head of the reaper turns less than the one of the suit)
ar_face_precise = function(obj, tol)
	local t = 0
	local last = nil
	while t < 6000 do
		local p = manny:getpos()
		local d = GetActorYawToPoint(manny.hActor, obj.obj_x, obj.obj_y, p.z) - manny:getrot().y
		d = d - 360 * floor(d / 360 + 0.5)
		if abs(d) <= tol then
			return TRUE
		end
		if d > 0 then
			TurnActor(manny.hActor, 1)
		else
			TurnActor(manny.hActor, -1)
		end
		break_here()
		t = t + system.frameTime
	end
	return nil
end

-- Is Manny facing the point to within a few degrees?
ar_yaw_close = function(x, y, z)
	local d = GetActorYawToPoint(manny.hActor, x, y, z) - manny:getrot().y
	d = d - 360 * floor(d / 360 + 0.5)
	return abs(d) < 12
end

-- (a turn on a slope can go on with the heading already right)
ar_yaw_close_tight = function(x, y, z)
	local d = GetActorYawToPoint(manny.hActor, x, y, z) - manny:getrot().y
	d = d - 360 * floor(d / 360 + 0.5)
	return abs(d) < 3
end

-- A few steps to the side of the way to (x, y): where Manny bumps into a wall a player nudges the stick left or right
AR_WIGGLE_SIDE = 1
-- (counts of frames were tuned where a frame is 133 ms of game time: this many frames at any frame time)
ar_fr = function(n)
	local ft = system.frameTime
	if not ft or ft < 1 then
		ft = 1
	end
	local v = floor(n * 133 / ft + 0.5)
	if v < n then
		v = n
	end
	return v
end

-- The keys that walk and turn Manny do nothing while the game has taken them over: hanging on the chain of the conveyor
-- belt (only forward and backward climb it), floating in the anchor room. The walkers do not step then: that would be a
-- move that a player cannot make. (On a ladder the walk goes on: stepping into the foot of it is what starts the climb.)
ar_walk_blocked = function()
	-- (the flags stay set after the sets are left)
	if cy and cy.drifting and system.currentSet == cy then
		return TRUE
	end
	if ac and ac.drifting and system.currentSet == ac then
		return TRUE
	end
	return nil
end

ar_wiggle = function(x, y)
	local p = manny:getpos()
	local yt = GetActorYawToPoint(manny.hActor, x, y, p.z)
	local yw = yt + AR_WIGGLE_SIDE * 70
	AR_WIGGLE_SIDE = -AR_WIGGLE_SIDE
	local yx = GetActorYawToPoint(manny.hActor, p.x + 1, p.y, p.z)
	local yy = GetActorYawToPoint(manny.hActor, p.x, p.y + 1, p.z)
	local dx = cos(yw - yx)
	local dy = cos(yw - yy)
	local f = 0
	local wset = system.currentSet
	while f < ar_fr(25) and system.currentSet == wset do
		if not ar_steer(p.x + dx, p.y + dy, p.z, 8) then
			manny:walk_forward()
		end
		break_here()
		f = f + 1
	end
end

-- Turns on the spot to a heading (the yaw of a use rotation), the way the turn keys do
ar_face_yaw = function(yaw)
	local p = manny:getpos()
	local t = 0
	-- (the heading as a point: the yaws of the game toward the x and the y axis give the direction of any yaw; cos takes degrees)
	local yx = GetActorYawToPoint(manny.hActor, p.x + 1, p.y, p.z)
	local yy = GetActorYawToPoint(manny.hActor, p.x, p.y + 1, p.z)
	local dx = cos(yaw - yx)
	local dy = cos(yaw - yy)
	while ar_steer(p.x + dx, p.y + dy, p.z, 3) and t < 8000 do
		break_here()
		t = t + system.frameTime
	end
	if AR_TRACE then
		ar_log("faced yaw " .. tostring(yaw) .. ": now " .. tostring(manny:getrot().y) .. " after " .. tostring(t) .. " ms at " .. format("%.2f %.2f", p.x, p.y) .. " dir " .. format("%.2f %.2f", dx, dy))
		sleep_for(300)
		ar_log("  300 ms later " .. tostring(manny:getrot().y))
	end
end

ar_wait_turn = function()
	local t = 0
	while manny:is_turning() and t < 8000 do
		sleep_for(100)
		t = t + 100
	end
	if t >= 8000 then
		ar_log("TURN TIMEOUT: Manny is still turning")
	end
end

ar_try_wait = function(cond, timeout)
	local waited = 0
	ar_log("Starting wait for " .. tostring(cond) .. " with timeout " .. tostring(timeout))
	while not cond() and waited < timeout do
		sleep_for(100)
		-- (the movie of a cutscene plays in real time on both engines: with the game's clock fixed and fast its seconds are not the budget of the wait)
		if not (cutSceneLevel > 0 and IsMoviePlaying and IsMoviePlaying()) then
			waited = waited + 100
		end
		AR_WAIT_STATE = "ar_try_wait " .. tostring(cond) .. " waited " .. tostring(waited) .. " of " .. tostring(timeout)
		-- a set the game passes through while the wait goes on (a cutscene takes Manny through the room that the walk
		-- was going to and out again) is a set that was reached
		if AR_TARGET then
			ar_target_reached()
		end
	end
	ar_log("Waited " .. tostring(waited) .. " ms for " .. tostring(cond) .. ", result: " .. tostring(cond()))
	return cond()
end

-- A wait that must end in time: a timeout is an error, on ScummVM as on the original (the places that look at the result and
-- go on with something else use ar_try_wait). what names what was waited for.
ar_wait_for = function(cond, timeout, what)
	local ok
	if AR_NOTIMEOUT then
		timeout = 1000000000000
	end
	-- (nothing is skipped in a real run: the movies and the speech take what they take)
	if AR_REAL and timeout >= 30000 then
		timeout = timeout * 10
	end
	if timeout > 20000 then
		ok = ar_wait_active(cond, timeout)
		if not ok and AR_IDLE_FAILED then
			AR_IDLE_FAILED = nil
			ar_fail("nothing happened for " .. tostring(AR_IDLE_MAX or 25000) .. " ms while waiting for " .. tostring(what or "a condition"))
			return ok
		end
	else
		ok = ar_try_wait(cond, timeout)
	end
	if not ok then
		ar_fail("timed out after " .. tostring(timeout) .. " ms waiting for " .. tostring(what or "a condition"))
	end
	return ok
end

-- A long wait that gives up when nothing is going on: no cutscene, no line spoken, no script of a verb, Manny standing
-- still, for AR_IDLE_MAX (25 seconds) milliseconds. What the game waits for then is not going to happen.
ar_wait_active = function(cond, timeout)
	local waited = 0
	local idle = 0
	local last = manny:getpos()
	ar_log("Starting wait for " .. tostring(cond) .. " with timeout " .. tostring(timeout))
	while not cond() and waited < timeout do
		sleep_for(100)
		if not (cutSceneLevel > 0 and IsMoviePlaying and IsMoviePlaying()) then
			waited = waited + 100
		end
		AR_WAIT_STATE = "ar_wait_active " .. tostring(cond) .. " waited " .. tostring(waited) .. " of " .. tostring(timeout) .. " idle " .. tostring(idle)
		if AR_TARGET then
			ar_target_reached()
		end
		local p = manny:getpos()
		if cutSceneLevel > 0 or manny.is_driving or IsMessageGoing() or find_script(Sentence) or manny:is_moving() or manny:is_turning() or abs(p.x - last.x) + abs(p.y - last.y) > 0.001 then
			idle = 0
		else
			idle = idle + 100
		end
		last = p
		if AR_TRACE and waited - floor(waited / 1000) * 1000 == 0 then
			local mp = meche:getpos()
			ar_log("  wait: manny " .. format("%.2f %.2f rate %s run %s", p.x, p.y, tostring(GetActorWalkRate(manny.hActor)), tostring(manny.is_running)) .. " meche " .. format("%.2f %.2f rate %s", mp.x, mp.y, tostring(GetActorWalkRate(meche.hActor))))
		end
		if idle >= (AR_IDLE_MAX or 25000) then
			AR_IDLE_FAILED = TRUE
			waited = timeout
		end
	end
	ar_log("Waited " .. tostring(waited) .. " ms for " .. tostring(cond) .. ", result: " .. tostring(cond()))
	return cond()
end

-- A player cannot walk or click during a cutscene, and doing it anyway keeps the cutscene
-- from ending, which also keeps the camera from following. So wait for control.
ar_wait_for_control = function()
	if not ar_wait_for(function() return cutSceneLevel == 0 end, AR_CONTROL_TIMEOUT or 90000) then
		ar_log("FAIL the game never gave control back")
		AR_FAILED = TRUE
		if not AR_KEEP_GOING then
			ar_finish()
		end
	end
end

-- Skips the cutscenes the way the player does: the game gives each one an override
-- Seconds of the wall clock (the clock of the game is fixed and fast on a run with a fixed frame time; movies and speech go by the real one)
ar_wall = function()
	return tonumber(date("%H")) * 3600 + tonumber(date("%M")) * 60 + tonumber(date("%S"))
end

ar_skipper = function()
	while TRUE do
		-- a movie that never ends (the original keeps one playing for ever now and then, with the control back): stopped like a player does it,
		-- after a time that no movie of the game takes
		-- (a movie with the control back is an ambient one that loops by design: only a cutscene's movie can be stuck)
		if cutSceneLevel > 0 and IsMoviePlaying and IsMoviePlaying() then
			local now = ar_wall()
			if not AR_MOVIE_START or now < AR_MOVIE_START then
				AR_MOVIE_START = now
			end
			if not AR_NOTIMEOUT and now - AR_MOVIE_START > (AR_REAL and 400 or 200) then
				ar_log("a movie that does not end: stopped after " .. tostring(now - AR_MOVIE_START) .. " s")
				ar_press_key(ar_real_key("OVERRIDE"))
				AR_MOVIE_START = nil
			end
		else
			AR_MOVIE_START = nil
		end
		-- a line that never ends (a voice that does not finish) is skipped like a player does, with the
		-- key that expires the text
		if IsMessageGoing() then
			AR_MSG_TIME = (AR_MSG_TIME or 0) + 100
			if not AR_NOTIMEOUT and AR_MSG_TIME > (AR_REAL and 180000 or 15000) then
				ar_log("skipping a line that does not end")
				ar_press_key(ar_real_key("EXPIRE_TEXT"))
				AR_MSG_TIME = 0
			end
		else
			AR_MSG_TIME = 0
		end
		AR_NOW = (AR_NOW or 0) + 100
		sleep_for(100)
	end
end

-- A step that hangs would keep the game running for ever
-- Ends the run with a failure when it takes too long, and when the script of the run has died: a Lua error ends the script
-- (the error is in the log of the game, and AR_WHERE says where the walk was), and nothing would else ever notice.
ar_watchdog = function()
	local waited = 0
	local limit = AR_TIMEOUT or 1800000
	local lost = 0
	while waited < limit do
		sleep_for(500)
		waited = waited + 500
		if __autorun__ and not find_script(__autorun__) then
			lost = lost + 1
			if lost > 6 then
				ar_log("FAIL the script of the run has died, of an error of Lua: where the walk was, " .. tostring(AR_WHERE))
				AR_FAILED = TRUE
				ar_finish()
			end
		else
			lost = 0
		end
	end
	ar_log("FAIL timed out")
	AR_FAILED = TRUE
	ar_finish()
end

AR_CAMERA = nil
ar_note_camera = function()
	local setup = tostring(system.currentSet.name) .. " setup " .. tostring(system.currentSet:current_setup())
	if setup ~= AR_CAMERA then
		AR_CAMERA = setup
		ar_log("camera: " .. setup)
	end
end

-- The engine calls system.camChangeHandler(prev, next) on every change of the camera's setup (it looks it up in the system table). AR_CAMDBG = TRUE logs each, with
-- where Manny is: the tool for finding what moves the camera.
AR_FRAME = AR_FRAME or 0
if not AR_CAMCHANGE_SET then
	AR_CAMCHANGE_SET = TRUE
	AR_CAMCHANGE_OLD = system.camChangeHandler or function() end
	system.camChangeHandler = function(prev, next)
		if AR_CAMDBG then
			local mp = manny:getpos()
			ar_log("CAMDBG " .. tostring(system.currentSet.name) .. " " .. tostring(prev) .. "->" .. tostring(next) .. format(" manny %.3f %.3f cut %d", mp.x, mp.y, cutSceneLevel))
		end
		return AR_CAMCHANGE_OLD(prev, next)
	end
end

ar_set_name = function()
	if system.currentSet then
		return tostring(system.currentSet.name)
	end
	return "-"
end

-- What Manny carries
ar_inventory = function()
	local s = ""
	local item = next(Inventory.unordered_inventory_table, nil)
	while item do
		if item.owner == manny then
			s = s .. tostring(item.name) .. "; "
		end
		item = next(Inventory.unordered_inventory_table, item)
	end
	return s
end

ar_state = function(tag)
	local p = manny:getpos()
	ar_log("state " .. tag .. ": " .. ar_set_name() .. " " .. format("(%.2f %.2f)", p.x, p.y) .. " carrying [" .. ar_inventory() .. "]")
end

ar_has = function(item)
	return item.owner == manny
end

-- Walks Manny to a point the way a player does, outside of any cutscene. Sectors on the way
-- can stop the walk, so it is started again until he is there or stop_when() is true.
-- Walks the way the stick does: turn toward the point and step forward, frame by frame
ar_walk_stick = function(x, y, z, stop_when, max_ms)
	local waited = 0
	AR_STICK_LOG = 0
	local last = manny:getpos()
	local stuck = 0
	local best = 100
	local maxstep = 0.04
	local bestat = 0
	local passed = nil
	if not AR_WALK then
		manny:set_run(TRUE)
	end
	local startset = system.currentSet
	AR_STICK_PASSED = nil
	while not passed and system.currentSet == startset and ar_far(x, y, z, AR_HOP_TOL or 0.015) and waited < (max_ms or (AR_NOTIMEOUT and 1000000000000) or 8000) and not (stop_when and stop_when()) and stuck < ar_fr(90) and not ar_walk_blocked() do
		if cutSceneLevel > 0 then
			ar_wait_for_control()
		end
		-- (a player turns on the spot until Manny faces the way, then steps forward)
		-- (at his own height: a point above or below would tilt him as well, and the turn would not end)
		-- (the last stretch at a walk, not at a run: the steps are a quarter of the size, so that Manny can stop on the spot)
		if not AR_WALK and not AR_NO_SLOW then
			local dnow = ar_dist2d(x, y)
			if dnow < 0.45 and not AR_NEAR_SLOW then
				AR_NEAR_SLOW = TRUE
				manny:set_run(FALSE)
			elseif dnow >= 0.6 and AR_NEAR_SLOW then
				AR_NEAR_SLOW = nil
				manny:set_run(TRUE)
			end
		end
		local turning = ar_steer(x, y, last.z, 8)
		if not turning then
			manny:walk_forward()
		end
		break_here()
		waited = waited + system.frameTime
		ar_note_camera()
		local p = manny:getpos()
		if AR_TRACE and waited - AR_STICK_LOG > 150 then
			AR_STICK_LOG = waited
			ar_log("  stick at " .. format("%.2f %.2f %.2f", p.x, p.y, p.z) .. " turning=" .. tostring(turning) .. " yaw=" .. tostring(manny:getrot().y) .. " want=" .. tostring(GetActorYawToPoint(manny.hActor, x, y, last.z)) .. " tgt=" .. format("%.2f %.2f", x, y))
		end
		local moved = sqrt((p.x - last.x) * (p.x - last.x) + (p.y - last.y) * (p.y - last.y))
		if moved > 0.003 and moved < 0.15 then
			maxstep = moved
		end
		if turning then
			-- (turning on the spot is not being stuck)
			stuck = 0
			bestat = waited
		elseif abs(p.x - last.x) + abs(p.y - last.y) < 0.0005 then
			stuck = stuck + 1
			if (stuck == ar_fr(8) or stuck == ar_fr(40)) and ar_dist2d(x, y) > 0.12 then
				ar_wiggle(x, y)
			elseif stuck == ar_fr(20) and ar_nav_unstick then
				ar_nav_unstick()
			end
		else
			stuck = 0
		end
		last = p
		-- (a step of the walk is a few centimetres: past the point already when the distance grows again)
		local d = ar_dist2d(x, y)
		if AR_DBG and waited < 160 then
			ar_log("DBG stick p " .. format("%.3f %.3f", p.x, p.y) .. " d " .. format("%.3f", d) .. " best " .. format("%.3f", best) .. " step " .. format("%.3f", maxstep) .. " target " .. format("%.2f %.2f", x, y))
		end
		if d < best - 0.003 then
			best = d
			bestat = waited
		elseif waited - bestat > 700 and ar_nav_unstick and d > 0.12 then
			-- (no nearer for most of a second: bumping along a wall, a player steers away from it)
			bestat = waited
			ar_wiggle(x, y)
		elseif d < best then
			best = d
		elseif best < min(AR_HOP_TOL and 0.04 or 0.15, 1.5 * maxstep) and d > best + 0.002 then
			passed = TRUE
			ar_log("passed: best " .. tostring(best) .. " d " .. tostring(d) .. " at " .. tostring(p.x) .. " " .. tostring(p.y) .. " target " .. tostring(x) .. " " .. tostring(y))
		end
	end
	AR_STICK_PASSED = passed
	AR_NEAR_SLOW = nil
	if ar_far(x, y, z, AR_HOP_TOL or 0.015) then
		ar_log("stick ended: waited " .. tostring(waited) .. " of " .. tostring(max_ms) .. ", stuck " .. tostring(stuck) .. ", passed " .. tostring(passed) .. ", stop " .. tostring(stop_when and stop_when()))
	end
	return waited
end

-- Walks along a list of points ({ x, y, z }, ...): where the original's own path does not get through (see plan_route.py)
AR_ROUTE_SET = nil
ar_route_left_set = function()
	return system.currentSet ~= AR_ROUTE_SET
end
ar_walk_route = function(points)
	AR_ROUTE_SET = system.currentSet
	local i = 1
	-- the points are placed by hand: no planning of ar_nav.lua between them
	if ar_walk_path then
		ar_walk_path(nil, points, 1, ar_route_left_set)
		return
	end
	AR_IN_NAV = TRUE
	while points[i] and not ar_route_left_set() do
		AR_WALK_SPENT = 0
		ar_walk_to(points[i][1], points[i][2], points[i][3], ar_route_left_set)
		i = i + 1
	end
	AR_IN_NAV = nil
end

-- the distance to a point not counting the height
ar_dist2d = function(x, y)
	local p = manny:getpos()
	return sqrt((p.x - x) * (p.x - x) + (p.y - y) * (p.y - y))
end

-- farther than 10 cm from the point, not counting the height: the walk of the game follows the floor, a use point can be
-- at another height
ar_far = function(x, y, z, tol)
	local p = manny:getpos()
	if AR_NAV_GOAL_X and AR_NAV_GOAL_FOR_X == x and AR_NAV_GOAL_FOR_Y == y then
		-- the point lies outside the walk boxes (a use point often does): the walk ends at the edge of them
		if sqrt((p.x - AR_NAV_GOAL_X) * (p.x - AR_NAV_GOAL_X) + (p.y - AR_NAV_GOAL_Y) * (p.y - AR_NAV_GOAL_Y)) <= (tol or 0.12) then
			return nil
		end
	end
	return sqrt((p.x - x) * (p.x - x) + (p.y - y) * (p.y - y)) > (tol or 0.1)
end

-- max_ms: how long the walk may take in all (10 seconds unless AR_WALK_MAX says otherwise); a walk that needs longer
-- gives a larger value, a walk that is not done by then has failed
ar_walk_to = function(x, y, z, stop_when, max_ms)
	local tries = 0
	local budget = max_ms or AR_WALK_MAX
	if AR_NOTIMEOUT then
		budget = 1000000000000
	end
	if not budget then
		-- 10 seconds, and what the way takes at walking speed (the run is about 1.4 units a second)
		local mp0 = manny:getpos()
		budget = 6000 + 800 * sqrt((mp0.x - x) * (mp0.x - x) + (mp0.y - y) * (mp0.y - y))
	end
	if not AR_IN_NAV or not AR_WALK_SPENT then
		AR_WALK_SPENT = 0
	end
	ar_log("walk (running=" .. tostring(manny.is_running) .. ", walk rate " .. tostring(GetActorWalkRate(manny.hActor)) .. ")")
	ar_wait_for_control()
	if ar_walk_blocked() then
		ar_log("walk: the keys that walk are off now (Manny hangs on the chain)")
		return nil
	end
	ar_note_camera()
	-- There is no clicking in the game: Manny is steered with the keys, turning toward the point and stepping forward. The
	-- way through the sectors is planned by ar_nav.lua where the straight line leaves them
	AR_PATH_DONE = nil
	if AR_NAV and not AR_NO_NAV and not AR_IN_NAV and not AR_STICK then
		ar_nav_walk(x, y, z, stop_when)
		-- (the last leg has the time of a walk of its own)
		AR_WALK_SPENT = 0
		if AR_PATH_DONE then
			-- the path has been followed to its end, as near as the walls allow
			ar_note_camera()
			return TRUE
		end
	end
	local tries = 0
	local startset = system.currentSet
	AR_STICK_PASSED = nil
	while system.currentSet == startset and not (AR_STICK_PASSED and (AR_HOP_TOL or ar_dist2d(x, y) < 0.2)) and ar_far(x, y, z, AR_HOP_TOL) and tries < 4 and AR_WALK_SPENT < budget and not (stop_when and stop_when()) do
		AR_WALK_SPENT = AR_WALK_SPENT + ar_walk_stick(x, y, z, stop_when, budget - AR_WALK_SPENT)
		tries = tries + 1
		if ar_far(x, y, z) and not (stop_when and stop_when()) then
			local sp = manny:getpos()
			ar_log("walk stopped at " .. format("%.2f %.2f", sp.x, sp.y) .. " toward " .. format("%.2f %.2f", x, y))
			if AR_NAV and not AR_NO_NAV and not AR_IN_NAV and not AR_STICK then
				ar_nav_walk(x, y, z, stop_when)
				AR_WALK_SPENT = 0
			end
		end
	end
	if ar_far(x, y, z, AR_HOP_TOL) and AR_WALK_SPENT >= budget then
		ar_fail("the walk used its whole time budget of " .. tostring(budget) .. " ms, stopped at " .. format("%.2f %.2f", manny:getpos().x, manny:getpos().y) .. " toward " .. format("%.2f %.2f", x, y))
	end
	ar_note_camera()
	return not ar_far(x, y, z)
end

-- Verbs, the way a player gives them. Nothing here calls the objects' own functions or
-- Sentence: Manny walks up to the object and faces it, the game's own gaze makes it the "hot
-- object", and the key is pressed on the game's own button handler. An inventory item is put
-- in Manny's hand with its hotkey (1-9) first, and then USE acts with it, on the object he is
-- looking at or on its own. An object the game does not offer is a failure.
AR_START_SET = nil
AR_KEYS_USED = 0

ar_set_changed = function()
	return system.currentSet ~= AR_START_SET
end

ar_key_for = function(verb)
	local map = control_map.USE
	if verb == "pickUp" then
		map = control_map.PICK_UP
	elseif verb == "lookAt" then
		map = control_map.LOOK_AT
	elseif verb == "down" then
		map = control_map.MOVE_BACKWARD
	elseif verb == "inventory" then
		map = control_map.INVENTORY
	end
	return next(map, nil)
end

-- Presses a key the way the game gets it, whether the button handler is a function or a
-- table such as a dialog or the computer
ar_press_key = function(key)
	local handler = system.buttonHandler
	if type(handler) == "function" then
		handler(key, TRUE, nil)
	elseif type(handler) == "table" and handler.buttonHandler then
		handler:buttonHandler(key, TRUE, nil)
	end
end

-- Presses the key of a verb: "use", "pickUp", "lookAt", "down" or "inventory"
ar_press = function(verb)
	ar_press_key(ar_key_for(verb))
end

-- Makes the object the one Manny is looking at, as the player's gaze does. Returns nil when
-- the game does not offer the object (not touchable, out of range or not in front of him).
ar_gaze_at = function(obj)
	if not obj.interest_actor or not vlist or not vlist[obj] then
		return nil
	end
	-- (the change-gaze key, as a player cycles through what is in front of him; nothing of the gaze is set from here)
	local tries = 0
	while hot_object ~= obj and tries < 12 do
		ar_press_key(ar_real_key("CHANGE_GAZE"))
		sleep_for(100)
		tries = tries + 1
	end
	return hot_object == obj
end

-- An item used on its own acts on what Manny is looking at when there is something: a player turns until nothing is in front of him (the turn key, as
-- far as a few seconds take him)
ar_look_away = function()
	local t = 0
	while hot_object and t < 4000 do
		TurnActor(manny.hActor, 1)
		break_here()
		t = t + system.frameTime
	end
	if hot_object then
		ar_log("look away: still looking at " .. tostring(hot_object.name))
	end
end

-- A held item makes USE act with it, so a player puts it away first
ar_put_away = function()
	local tries = 0
	while manny.is_holding and tries < 50 do
		if tries == 0 then
			ar_press("pickUp")
		end
		sleep_for(200)
		tries = tries + 1
	end
	ar_wait_for_control()
	return not manny.is_holding
end

-- Puts an inventory item in Manny's hand with its hotkey: the first nine items are keys 1-9
-- in the order of the inventory. In the Land of the Living the inventory key takes out the
-- scythe, the only thing there.
ar_hold = function(item)
	local i = 1
	local slot = nil
	local keys = { KEY1, KEY2, KEY3, KEY4, KEY5, KEY6, KEY7, KEY8, KEY9 }
	if manny.is_holding == item then
		return TRUE
	end
	if system.currentSet == lr and item == mo.scythe then
		ar_press("inventory")
	else
		while Inventory.ordered_inventory_table[i] do
			if Inventory.ordered_inventory_table[i] == item then
				slot = i
			end
			i = i + 1
		end
		if not slot or slot > 18 then
			ar_log("no hotkey for " .. tostring(item.name) .. ", inventory place " .. tostring(slot))
			return nil
		end
		if slot > 9 then
			-- (the places 10 to 18 are the keys 1 to 9 with the shift key down: the game reads the shift key from the keyboard when a key arrives, so the hotkey
			-- function is called itself with it set)
			shiftKeyDown = TRUE
			inventory_hot_key_pressed(keys[slot - 9])
			shiftKeyDown = nil
		else
			ar_press_key(keys[slot])
		end
	end
	AR_HOLD_ITEM = item
	ar_wait_for(function() return manny.is_holding == AR_HOLD_ITEM end, 30000)
	ar_wait_for_control()
	if manny.is_holding ~= item then
		local hid, hn = manny:find_sector_type(HOT)
		ar_log("hold failed: cut=" .. cutSceneLevel .. " inventory_disabled=" .. tostring(inventory_disabled) .. " hot=" .. tostring(hn) .. " handler_ok=" .. tostring(system.buttonHandler == SampleButtonHandler) .. " holding=" .. tostring(manny.is_holding and manny.is_holding.name))
	end
	return manny.is_holding == item
end

ar_offered = function()
	return vlist and AR_OBJ and vlist[AR_OBJ]
end

-- After some scenes (the jump off the conveyor of the Lamancha) the original keeps Manny's costume without its head
-- joints, so that its test of what he can see finds nothing and no object is ever offered. The game sets them with
-- manny:set_head whenever it makes Manny up (manny.default); here, when nothing at all is seen, the same call.
ar_fix_head = function()
	if GetVisibleThings then
		local seen = GetVisibleThings()
		if not seen or not next(seen, nil) then
			ar_log("nothing is seen: Manny's head joints are set again")
			manny:set_head(3, 4, 5, 165, 28, 80)
		end
	end
end

-- The handler of the keys when nothing special is going on: the idle handlers take its place while Manny stands about
ar_handler_normal = function()
	local h = system.buttonHandler
	return h == SampleButtonHandler or h == idle_buttonHandler or h == idle_save_handler
end

-- Why the game does not offer an object: it must be touchable, visible and in range
ar_why_not_offered = function(obj)
	local why = "touchable=" .. tostring(obj.touchable) .. " range=" .. tostring(obj.range)
	if obj.interest_actor then
		why = why .. " proximity=" .. tostring(proximity(obj.interest_actor))
	else
		why = why .. " no interest actor"
	end
	local seen = GetVisibleThings()
	local k, v = next(seen, nil)
	local visible = FALSE
	local seen_names = ""
	while k do
		if parent_object[k] == obj then
			visible = TRUE
		end
		if parent_object[k] then
			seen_names = seen_names .. tostring(parent_object[k].name) .. ";"
		end
		k, v = next(seen, k)
	end
	why = why .. " seen[" .. seen_names .. "] trackmanny=" .. tostring(find_script(TrackManny)) .. " handler=" .. tostring(system.buttonHandler == SampleButtonHandler)
	local mp = manny:getpos()
	why = why .. " manny=" .. format("%.2f %.2f yaw %.0f", mp.x, mp.y, manny:getrot().y)
	if obj.obj_x then
		why = why .. " object=" .. format("%.2f %.2f yaw-to %.0f", obj.obj_x, obj.obj_y, GetActorYawToPoint(manny.hActor, obj.obj_x, obj.obj_y, mp.z))
	end
	return why .. " visible=" .. tostring(visible) .. " in the list=" .. tostring(vlist and vlist[obj])
end

ar_fail = function(msg)
	ar_log("FAIL " .. msg)
	AR_FAILED = TRUE
	if not AR_KEEP_GOING then
		ar_finish()
	end
	return nil
end

-- A player who cannot see the object offered turns on the spot until the game offers it
ar_scan_for = function(obj)
	-- A full turn on the spot never found an object in a speed run (17 looks round, 5,826 frames, none offered anything): what gets the object offered is the walk to its
	-- use point, the push and the creeping step that follow. The look round is for AR_SCAN = TRUE; what it would have been for is logged instead.
	if not AR_SCAN then
		ar_log("SCAN skipped for " .. tostring(obj.name) .. " at " .. ar_set_name() .. ": " .. ar_why_not_offered(obj))
		-- Every one of them was an object that is touchable and in view, a few centimetres outside its range (1 to 29): a turn does not change that, a step toward it by what is
		-- missing does. Off unless AR_RANGE_STEP = TRUE: it saves 1,891 frames in chapter 29, and puts Manny where he and Toto run into each other at the neck of the ship
		-- (the walk to the fridge is then planned seven times and fails); the walks and the creeping of ar_approach get the object offered otherwise
		if AR_RANGE_STEP and obj.touchable and obj.interest_actor and obj.obj_x and obj.range then
			local over = proximity(obj.interest_actor) - obj.range
			local mp = manny:getpos()
			local d = ar_dist2d(obj.obj_x, obj.obj_y)
			if over > 0 and over < 0.6 and d > 0.05 then
				ar_walk_stick(mp.x + (obj.obj_x - mp.x) * (over + 0.05) / d, mp.y + (obj.obj_y - mp.y) * (over + 0.05) / d, mp.z, ar_offered, 3000)
				ar_try_wait(ar_offered, 600)
			end
		end
		return ar_offered()
	end
	local p = manny:getpos()
	local base = manny:getrot().y
	local i = 1
	local found = nil
	local f0 = AR_FRAME
	while i <= 15 and not found and not ar_set_changed() do
		ar_face_yaw(base + i * 24)
		sleep_for(150)
		if ar_offered() then
			found = TRUE
		end
		i = i + 1
	end
	-- (the SCAN lines: what each look round was for, whether it found the object and what it cost; the sum is in tools/scan_report.py)
	ar_log("SCAN " .. tostring(obj.name) .. " found " .. tostring(found) .. " after " .. (i - 1) .. " turns, " .. tostring(AR_FRAME - f0) .. " frames, at " .. ar_set_name())
	return found
end

-- Walks up to an object and faces it, a step closer if the game still does not offer it
-- A player walks toward an object until the game offers it, and gives the verb then: the use point may be out of reach
ar_changed_or_offered = function()
	return ar_set_changed() or ar_offered()
end

-- An object whose actor rides about (Meche, the agent) is not where the object was made: the use point and the place of the
-- object mean nothing then, a player walks up to the actor where it is. True when the actor is away from the object's place.
ar_actor_away = function(obj)
	if not obj.interest_actor or not obj.obj_x then
		return nil
	end
	local p = obj.interest_actor:getpos()
	return sqrt((p.x - obj.obj_x) * (p.x - obj.obj_x) + (p.y - obj.obj_y) * (p.y - obj.obj_y)) > 0.5
end

-- (ends a walk toward an actor that has moved on, or when the object is offered)
ar_actor_moved_on = function()
	local q = AR_ACT_A:getpos()
	-- (where the actor is when the walk is under way, after the planning)
	if not AR_ACT_SEEN then
		AR_ACT_SEEN = TRUE
		AR_ACT_X = q.x
		AR_ACT_Y = q.y
	end
	local moved = sqrt((q.x - AR_ACT_X) * (q.x - AR_ACT_X) + (q.y - AR_ACT_Y) * (q.y - AR_ACT_Y)) > 0.6
	if moved or ar_offered() or ar_set_changed() then
		ar_log("approach: the walk toward the actor ends (actor " .. format("%.2f %.2f, was %.2f %.2f", q.x, q.y, AR_ACT_X, AR_ACT_Y) .. "): moved " .. tostring(moved) .. ", offered " .. tostring(ar_offered()) .. ", set " .. tostring(ar_set_changed()))
		return TRUE
	end
	return nil
end

-- Walks up to the actor of the object, again where it has got to when it has moved on, until it is in range
ar_approach_actor = function(obj)
	local a = obj.interest_actor
	local tries = 0
	local near = nil
	ar_log("approach: the actor of " .. tostring(obj.name) .. " is away from its place, going to it")
	while not near and not ar_offered() and tries < 8 and not ar_set_changed() do
		local ap = a:getpos()
		local mp = manny:getpos()
		local d = sqrt((ap.x - mp.x) * (ap.x - mp.x) + (ap.y - mp.y) * (ap.y - mp.y))
		-- (a point on the line to Manny, well inside the range)
		local want = (obj.range or 0.8) * 0.6
		if d <= want then
			near = TRUE
		else
			local tx = ap.x + (mp.x - ap.x) * want / d
			local ty = ap.y + (mp.y - ap.y) * want / d
			AR_ACT_A = a
			AR_ACT_SEEN = nil
			-- (the actor can stand where Manny cannot: the walk goes as near as the floor does)
			AR_ALLOW_PARTIAL = TRUE
			-- (the height of the floor there, on the level Manny is on if there are several)
			local fz = ar_nav_floor_z(ar_nav_of(system.currentSet), tx, ty, mp.z) or mp.z
			ar_walk_to(tx, ty, fz, ar_actor_moved_on)
			AR_ALLOW_PARTIAL = nil
		end
		tries = tries + 1
	end
end

ar_approach = function(obj)
	local tries = 0
	AR_OBJ = obj
	if AR_TRACE then ar_state("approach start") end
	-- near enough already? a player turns toward it first, and the walk is not needed when
	-- the game then offers the object (its use point may even be out of reach)
	if obj.use_pnt_x and obj.use_rot_y and ar_dist2d(obj.use_pnt_x, obj.use_pnt_y) < 0.3 then
		-- (at its use point already: the way the game itself stands before it)
		ar_face_yaw(obj.use_rot_y)
		sleep_for(100)
		ar_wait_turn()
		ar_try_wait(ar_offered, 1200)
	end
	-- (not offered from there, within 30 cm of the use point: the heading of the use point is for standing on it. A player turns to the object itself)
	-- (and only where the object is near: from three metres off a player does not turn to it and look all round for it, he walks up to it first; the scan in the lobby of
	-- chapter 2 turned him twice round, 12 s, before the walk to the door; AR_SCAN_FAR = TRUE for the old order)
	-- (and only where turning could make the game offer it: it is offered within the range of the object, from farther off a turn and a look round find nothing,
	-- and the lever of chapter 12, range 0.7, 1.1 m off, had Manny turn all the way round, 6 s, before he walked to it. AR_SCAN_ALWAYS = TRUE turns the rule
	-- off for the verbs that need the time the look round takes: Meche in chapter 55 walks to Manny meanwhile)
	if obj.obj_x and not ar_offered() and (AR_SCAN_FAR or not obj.use_pnt_x or (ar_dist2d(obj.use_pnt_x, obj.use_pnt_y) < 1.0 and (AR_SCAN_ALWAYS or not obj.range or not obj.obj_y or ar_dist2d(obj.obj_x, obj.obj_y) < obj.range + 0.2))) then
		ar_face(obj)
		sleep_for(100)
		ar_wait_turn()
		ar_fix_head()
		ar_try_wait(ar_offered, 1200)
		-- (a player looks around if it is not there)
		if not ar_offered() and not ar_set_changed() then
			ar_scan_for(obj)
		end
	end
	if ar_offered() or AR_NO_WALK_APPROACH then
		return
	end
	if ar_actor_away(obj) then
		ar_approach_actor(obj)
		if ar_set_changed() then
			return
		end
		ar_wait_for_control()
		ar_face(obj.interest_actor and { obj_x = obj.interest_actor:getpos().x, obj_y = obj.interest_actor:getpos().y, name = obj.name } or obj)
		sleep_for(100)
		ar_wait_turn()
	elseif obj.use_pnt_x then
		-- (a door's walk out starts from its use point: a player goes all the way to a door, and to where an item is used)
		if obj.walkOut or AR_APPROACH_ITEM then
			ar_walk_to(obj.use_pnt_x, obj.use_pnt_y, obj.use_pnt_z, ar_set_changed)
		else
			ar_walk_to(obj.use_pnt_x, obj.use_pnt_y, obj.use_pnt_z, ar_changed_or_offered)
		end
		if AR_TRACE then ar_state("approach walked") end
		if ar_set_changed() then
			return
		end
		ar_wait_for_control()
		if ar_set_changed() then
			-- a cutscene on the way took Manny through the door
			return
		end
		if obj.use_rot_y then
			ar_face_yaw(obj.use_rot_y)
		else
			ar_face(obj)
		end
		sleep_for(100)
		ar_wait_turn()
		if AR_TRACE then
			sleep_for(500)
			ar_log("approach faced: " .. ar_why_not_offered(obj))
		end
	end
	-- the camera and the list of what is on the screen need a moment to follow Manny
	if obj.obj_x then
		-- the walk ends where the original's walk boxes end, which can be just out of range of the object: a player
		-- pushes the stick toward it, which also goes through a door
		if AR_TRACE then ar_state("approach faced") end
		ar_fix_head()
		ar_try_wait(ar_offered, 1000)
		if AR_TRACE then ar_state("approach not offered") end
		if not ar_offered() and not ar_set_changed() then
			ar_face(obj)
			ar_wait_turn()
			if AR_TRACE then ar_state("approach push") end
			local t = 0
			AR_START_SET = AR_START_SET or system.currentSet
			while not ar_offered() and not ar_set_changed() and t < 2500 do
				manny:walk_forward()
				break_here()
				t = t + system.frameTime
			end
		end
		if AR_TRACE then ar_state("approach pushed") end
		if ar_set_changed() then
			return
		end
	end
	-- (or the game has taken Manny through the door by itself: its sentence for walking out is running)
	if AR_TRACE then ar_state("approach waiting") end
	-- (a wait that may end without it: the creeping toward the object below follows, and the verb fails if it is still not offered)
	ar_try_wait(function() return ar_offered() or ar_set_changed() or find_script(Sentence) or find_script(AR_CODE) or cutSceneLevel > 0 end, 4000)
	if ar_set_changed() then
		return
	end
	while not ar_offered() and tries < 3 and not ar_set_changed() do
		local p = manny:getpos()
		-- a step toward the object
		ar_walk_stick(p.x + (obj.obj_x - p.x) * 0.3, p.y + (obj.obj_y - p.y) * 0.3, p.z, ar_offered, 5000)
		ar_try_wait(ar_offered, 2000)
		tries = tries + 1
	end
	-- still nothing: a player turns on the spot, looking for it
	if not ar_offered() and not ar_set_changed() then
		ar_scan_for(obj)
	end
	-- (and where the verb would fail now: if the game does not let it be touched at the moment, Meche in chapter 55 is not while she seduces Charlie, a wait for
	-- that, up to 20 s, and one more approach from wherever Manny has got to: it costs nothing where the verb works)
	if not ar_offered() and not ar_set_changed() and not AR_REAPPROACH then
		AR_OBJ = obj
		if not obj.touchable then
			ar_try_wait(function() return AR_OBJ.touchable or ar_set_changed() end, 20000)
		end
		if not ar_set_changed() and obj.touchable then
			ar_log("approach again: " .. tostring(obj.name))
			AR_REAPPROACH = TRUE
			ar_approach(obj)
			AR_REAPPROACH = nil
		end
	end
end

-- Does verb on noun1 the way a player does. verb is "use", "pickUp" or "lookAt". noun2 is an
-- inventory item used on noun1; with noun1 an inventory item and no noun2 it is used on its own.
-- Gives the verb to the object that Manny looks at, with the key, and waits until the game has started its code (AR_CODE).
-- The key starts a Sentence. For a plain verb on an object that first walks Manny to the use point by itself and stops there
-- without a word when it does not get him there, and then nothing happens (the log of the game says "Didn't make it to the
-- use/out point"). So a Sentence that is running is waited for, and one that ends without the code having started is an
-- attempt that failed: Manny goes to the use point himself, and the key is pressed again.
-- (it has to live a frame: a script that has ended by the time start_script returns has no number to give)
ar_noop = function()
	break_here()
end

-- the number of a task (start_script gives a value of its own kind, which prints as "task: 5864")
ar_task_number = function(task)
	return tonumber(strsub(tostring(task), 7))
end

ar_send_verb = function(verb, noun1, label)
	local tries = 0
	-- (a door's sentence is the game's walk out: when it is not ready, closed or locked, the game says so and the chapter waits
	-- for it, as a player does: the sentence is enough)
	local door = verb == "use" and noun1.walkOut
	while tries < 3 do
		if door and find_script(Sentence) then
			-- the game's own walk out is already under way (Manny came up to the door and it took him through)
			return TRUE
		end
		if not ar_gaze_at(noun1) then
			if door and (ar_set_changed() or cutSceneLevel > 0 or find_script(Sentence) or not ar_handler_normal()) then
				-- (the game's own walk out has started, by itself: Manny walked into the sector of the door, and what the door
				-- does then is a cutscene or the walk through it; the chapter checks the outcome)
				ar_try_wait(function() return ar_set_changed() or (cutSceneLevel == 0 and ar_handler_normal() and not find_script(Sentence)) end, 90000)
				return TRUE
			end
			return ar_fail(label .. " is not offered to the player: " .. ar_why_not_offered(noun1))
		end
		-- (the code of a verb can run and end within one frame, then no script of it is there to be seen: the scripts that were
		-- started since the key was pressed are counted by the numbers they get, the sentence being one and the code the next)
		local first_id = ar_task_number(start_script(ar_noop))
		ar_press(verb)
		local t = 0
		local seen = nil
		local state = nil
		while not state do
			if find_script(AR_CODE) or cutSceneLevel > 0 or not ar_handler_normal() or ar_set_changed() then
				state = "started"
			elseif find_script(Sentence) then
				seen = TRUE
				if door then
					state = "started"
				elseif t > 60000 then
					state = "never ended"
				end
			elseif seen or t >= 1500 then
				state = "ended without it"
			end
			if not state then
				break_here()
				t = t + system.frameTime
			end
		end
		local started = ar_task_number(start_script(ar_noop)) - first_id - 1
		if state == "started" then
			return TRUE
		end
		if started >= 2 then
			ar_log("the code of " .. label .. " ran and ended at once (" .. tostring(started) .. " scripts started)")
			return TRUE
		end
		local mp = manny:getpos()
		ar_log("the key did nothing for " .. label .. " (the sentence " .. state .. ", after " .. tostring(floor(t)) .. " ms, " .. tostring(started) .. " scripts started; Manny at " .. format("%.2f %.2f", mp.x, mp.y) .. ", its use point " .. tostring(noun1.use_pnt_x) .. " " .. tostring(noun1.use_pnt_y) .. ", range " .. tostring(noun1.range) .. ", " .. ar_why_not_offered(noun1) .. ")")
		tries = tries + 1
		if tries < 3 and noun1.use_pnt_x then
			-- (a player steps up to where the game wants him and tries again)
			ar_walk_to(noun1.use_pnt_x, noun1.use_pnt_y, noun1.use_pnt_z, ar_set_changed)
			ar_wait_for_control()
		end
	end
	return ar_fail("the key did nothing for " .. label .. ", three times")
end

ar_do = function(verb, noun1, noun2)
	local code
	local item = noun2
	local label = verb .. " " .. tostring(noun1.name)
	if noun2 then
		label = label .. " with " .. tostring(noun2.name)
	end
	ar_wait_for_control()
	if ar_walk_blocked() and not AR_KEEP_GOING then
		return ar_fail("the keys of the verbs are off (Manny hangs on the chain, floats): " .. label)
	end
	AR_START_SET = system.currentSet
	ar_log("do: " .. label .. format(" (Manny at %.2f %.2f)", manny:getpos().x, manny:getpos().y))
	ar_cov("do | " .. verb .. " | " .. tostring(noun1.string_name or noun1.name) .. " | " .. (noun2 and tostring(noun2.string_name or noun2.name) or "") .. " | " .. ar_set_name())
	if noun2 then
		code = noun1[verb .. "_" .. trim_header(noun2.string_name)]
		if not code then
			code = noun2["default_response"]
		end
	elseif verb == "use" and noun1.walkOut then
		code = noun1.walkOut
	else
		code = noun1[verb]
	end
	if not code then
		return ar_fail("nothing happens for " .. label)
	end
	AR_CODE = code
	if not noun2 and noun1.owner == manny then
		-- an inventory item on its own
		item = noun1
	end
	-- (an item used on an object is taken after walking up to it: the inventory does not open while
	-- Manny stands in a door's sector)
	if item and (item == noun1 or not AR_NEW) then
		if not ar_hold(item) then
			return ar_fail("could not take " .. tostring(item.name) .. " in hand")
		end
	end
	if item == noun1 then
		-- used on its own, with nothing in front of Manny to use it on
		ar_look_away()
		ar_press("use")
		AR_KEYS_USED = AR_KEYS_USED + 1
	else
		if manny.is_holding and manny.is_holding ~= item and verb ~= "lookAt" and not ar_put_away() then
			return ar_fail("could not put away what Manny holds, for " .. label)
		end
		AR_APPROACH_ITEM = noun2
		ar_approach(noun1)
		AR_APPROACH_ITEM = nil
		if ar_set_changed() then
			-- walking up to a door went through it
			ar_log("walked through " .. tostring(noun1.name))
			ar_wait_for_control()
			return TRUE
		end
		if not ar_offered() and (find_script(Sentence) or find_script(AR_CODE) or cutSceneLevel > 0) then
			-- the game is already taking Manny through it by itself (the door's walk out)
			ar_log("the game is walking out through " .. tostring(noun1.name))
			ar_wait_for(function() return ar_set_changed() or (not find_script(Sentence) and not find_script(AR_CODE) and cutSceneLevel == 0) end, 120000, "the game's walk out through " .. tostring(noun1.name))
			ar_wait_for_control()
			return TRUE
		end
		-- a cutscene on the way (a rail slide, a stair) can put the item away again
		if item and manny.is_holding ~= item then
			if not ar_hold(item) then
				return ar_fail("could not take " .. tostring(item.name) .. " in hand again")
			end
		end
		if not ar_send_verb(verb, noun1, label) then
			return nil
		end
		AR_KEYS_USED = AR_KEYS_USED + 1
	end
	sleep_for(300)
	-- (the game's code for the verb: it can be a script that never ends, a flight that does not arrive; the time of a movie of a cutscene, which plays in
	-- real time, is not counted)
	local ran = 0
	while find_script(code) and ran < ((AR_NOTIMEOUT and 1000000000000) or AR_CODE_TIMEOUT or 300000) do
		sleep_for(100)
		if not (cutSceneLevel > 0 and IsMoviePlaying and IsMoviePlaying()) then
			ran = ran + 100
		end
		AR_WAIT_STATE = "ar_do code " .. tostring(code) .. " ran " .. tostring(ran)
	end
	if find_script(code) then
		ar_log("the code of the game for " .. tostring(verb) .. " " .. tostring(noun1 and noun1.name) .. " has not ended after " .. tostring(ran) .. " ms, cut scene level " .. tostring(cutSceneLevel))
		if print_scripts then
			print_scripts()
		end
		return ar_fail("the code of the game for " .. tostring(verb) .. " " .. tostring(noun1 and noun1.name) .. " does not end")
	end
	ar_wait_for_control()
	wait_for_message()
	return TRUE
end

-- Waits until the dialog is waiting for a choice
ar_dialog_ready = function(dlg, timeout)
	local waited = 0
	local idle = 0
	timeout = timeout or 300000
	if AR_NOTIMEOUT then
		timeout = 1000000000000
	end
	while system.buttonHandler ~= dlg and waited < timeout and idle < 4000 do
		sleep_for(100)
		waited = waited + 100
		-- The conversation can end by itself (the game hands over what it was for and goes on): once the game
		-- has had its normal controls back for a few seconds, nothing is coming
		if ar_handler_normal() and cutSceneLevel == 0 and not IsMessageGoing() then
			idle = idle + 100
		else
			idle = 0
		end
	end
	return system.buttonHandler == dlg
end

-- Waits for the answer to a line that was chosen to end: the dialog offers its lines again, or the game has its normal controls back
-- (the conversation is over). The task of the line is not looked for: a task of Dialog.execute_line that an earlier dialog left behind (the
-- Olivia dialog of the Blue Casket waits for an idle chore that the original never plays) would be taken for this line's, for the rest of the game.
ar_wait_line_done = function(dlg)
	local waited = 0
	local done = nil
	while not done and waited < 300000 do
		if system.buttonHandler == dlg or ar_handler_normal() then
			done = TRUE
		else
			sleep_for(100)
			waited = waited + 100
		end
	end
	sleep_for(100)
end

-- A frame a little after a line of a dialog was chosen, when its text is on the screen (AR_FRAMES): the same moment in both engines
ar_say_mark = function()
	sleep_for(700)
	local p = manny:getpos()
	local r = manny:getrot()
	ar_log(format("saymark %d set %s manny pos %.4f %.4f %.4f rot %.3f %.3f %.3f", AR_SAY_N or 0, tostring(system.currentSet.name), p.x, p.y, p.z, r.x, r.y, r.z))
	ar_frame(format("say_%02d", AR_SAY_N or 0))
end

-- Says one of the lines of a dialog, which is a table entry such as gl1[60], or the exit
-- line of the current node, and waits for the answer to end
ar_pick = function(dlg, line)
	if not ar_dialog_ready(dlg) then
		ar_log("FAIL the dialog is not waiting for a choice")
		AR_FAILED = TRUE
		if not AR_KEEP_GOING then
			ar_finish()
		end
		return nil
	end
	if type(line) == "number" then
		line = dlg[line]
	end
	ar_log("say: " .. tostring(line.text))
	if AR_FRAMES then
		AR_SAY_N = (AR_SAY_N or 0) + 1
		start_script(ar_say_mark)
	end
	ar_choose_line(dlg, line)
	return TRUE
end

-- A line of the dialog chosen with its keys, down to the line and the choose key, as a player does; the line is said by the dialog's own task
ar_choose_line = function(dlg, line)
	-- (the dialog shows a few lines at a time, in the order of the file: a line that is not shown comes when the ones before it have been said, so a player says
	-- those first. The exit line is never one of them.)
	local rounds = 0
	local at = nil
	local stop = nil
	while not at and not stop and rounds < 12 do
		local i = 1
		local first = nil
		while dlg.current_choices and dlg.current_choices[i] do
			local c = dlg.current_choices[i]
			if c == line then
				at = i
			elseif not first and c ~= dlg.exit_lines[dlg.node] then
				first = i
			end
			i = i + 1
		end
		if not at and not first then
			ar_log("choose: the line is not offered and nothing else can be said first (node " .. tostring(dlg.node) .. "): " .. tostring(line.text))
			stop = TRUE
		elseif not at then
			ar_log("choose: " .. tostring(line.text) .. " is not shown yet, saying " .. tostring(dlg.current_choices[first].text) .. " first")
			ar_cov("say | " .. tostring(dlg.current_choices[first].text))
			local presses = 0
			while dlg.selected_line ~= first and presses < 40 do
				ar_press_key(ar_real_key("DIALOG_DOWN"))
				break_here()
				presses = presses + 1
			end
			ar_press_key(ar_real_key("DIALOG_CHOOSE"))
			sleep_for(300)
			ar_wait_line_done(dlg)
			if not ar_dialog_ready(dlg) then
				ar_log("choose: the dialog ended while saying the lines before " .. tostring(line.text))
				stop = TRUE
			end
			rounds = rounds + 1
		end
	end
	if at then
		ar_cov("say | " .. tostring(line.text))
		local presses = 0
		while dlg.selected_line ~= at and presses < 40 do
			ar_press_key(ar_real_key("DIALOG_DOWN"))
			break_here()
			presses = presses + 1
		end
		ar_press_key(ar_real_key("DIALOG_CHOOSE"))
		sleep_for(300)
		ar_wait_line_done(dlg)
	end
end

-- Whether a line is among the ones the dialog shows now
ar_line_shown = function(dlg, line)
	local i = 1
	while dlg.current_choices and dlg.current_choices[i] do
		if dlg.current_choices[i] == line then
			return TRUE
		end
		i = i + 1
	end
	return nil
end

ar_pick_exit = function(dlg)
	if not ar_dialog_ready(dlg) then
		return nil
	end
	ar_log("say the exit line of " .. tostring(dlg.node))
	ar_choose_line(dlg, dlg.exit_lines[dlg.node])
	return TRUE
end

-- Says the line when the dialog offers it at the moment (not used up, not switched off)
ar_pick_if = function(dlg, line)
	if dlg[line] and not dlg[line].off and not dlg[line].said_here then
		dlg[line].said_here = TRUE
		return ar_pick(dlg, line)
	end
	return nil
end

-- The load menu lists a save by the strings that the game gives to SubmitSaveGameData when it saves (the name, the
-- puzzle state and the set, see save_game_callback), a save without them cannot be loaded from the menu. The menu does
-- it for its own saves, so the checkpoints do the same.
ar_save_game_callback = function()
	if saveload_menu.is_active or critical_saveload_menu.is_active then
		return AR_ORIG_SAVE_CALLBACK()
	end
	SubmitSaveGameData(AR_SAVE_TABLE)
end

ar_set_save_info = function(slot)
	if not AR_ORIG_SAVE_CALLBACK then
		AR_ORIG_SAVE_CALLBACK = save_game_callback
	end
	AR_SAVE_TABLE = { }
	AR_SAVE_TABLE[0] = format("Autorun checkpoint %02d", slot)
	AR_SAVE_TABLE[1] = cur_puzzle_state:get_string()
	AR_SAVE_TABLE[2] = system.currentSet.setFile
	system.saveGameCallback = ar_save_game_callback
end

-- Saves the way the save menu does it (saveload_menu.save_game): the strings for the load list, the dialog log, the save
-- itself and the registry value that the menu reads to select the last saved game.
ar_menu_save = function(slot)
	local fname = format("grim%02d.gsv", slot)
	ar_set_save_info(slot)
	if dialog_log then
		dialog_log:copy_to(format("grimlog%02d.htm", slot))
	end
	-- (the planning cache of the navigation, the lists of every set the run has been in, is 14 of the 15 MB of tables in a save and not game
	-- state: it is read from the set files again by ar_nav_of when it is needed)
	AR_NAV = { }
	JustLoaded()
	Save(fname)
	break_here()
	break_here()
	WriteRegistryValue("LastSavedGame", fname)
end

-- Waits for the game to be in its normal state for a save (no cutscene, the normal button handler), at most 60 s. A handler that is not the normal one and has not changed
-- for 5 s with no cutscene is a mode that stays (the Bone Wagon of ch56, the end of ch04 and ch07): waiting for it was the whole 60 s, three times in a run.
-- AR_SETTLE_FULL = TRUE for the old wait.
ar_wait_normal = function()
	local waited = 0
	local same = 0
	local last = system.buttonHandler
	while waited < 60000 do
		if cutSceneLevel == 0 and ar_handler_normal() then
			return TRUE
		end
		sleep_for(100)
		waited = waited + 100
		if cutSceneLevel == 0 and system.buttonHandler == last then
			same = same + 100
		else
			same = 0
			last = system.buttonHandler
		end
		if same >= 5000 and not AR_SETTLE_FULL then
			return nil
		end
	end
	return nil
end

-- Makes a checkpoint and ends the run: the save holds the state for the next chapter. The
-- saver is a task of its own, and the chapter must end after calling this. A save also holds
-- the tasks, so the old saver that wakes up in the next chapter must stay quiet.
ar_save_task = function(slot, chapter)
	while find_script(__autorun__) do
		sleep_for(50)
	end
	-- a save taken while a conversation or cutscene is still on screen restores half drawn
	ar_wait_normal()
	sleep_for(1000)
	stop_script(ar_watchdog)
	stop_script(ar_skipper)
	stop_script(ar_override_clock)
	ar_screen_clear()
	ar_menu_save(slot)
	sleep_for(3000)
	if chapter == AR_CHAPTER then
		ar_log("saved checkpoint grim" .. slot .. ".gsv")
		ar_finish()
	end
end

ar_checkpoint = function(slot)
	if not AR_ONE_SHOT then
		-- a run that goes on to the next chapter: save here and keep playing. A save taken while the game is in its
		-- normal state loads into a game whose actors never move: the menu saves from its render mode, so do the same.
		ar_wait_normal()
		ar_wait_for_control()
		-- (no cutscene movie in the save: the skipper that the save brings back would take it for one that never ended. A movie of the set that loops, a lighthouse or a
	-- chimney, never ends, and waiting for it was the whole timeout of the wait)
		ar_try_wait(function() return not (cutSceneLevel > 0 and IsMoviePlaying and IsMoviePlaying()) end, 120000)
		AR_MOVIE_START = nil
		-- (a run of the whole game does not save unless asked to, SAVE=1 in run_all.sh: the saves are for playing a chapter by itself)
		if AR_NOSAVE then
			-- (the time that the save takes went by all the same, 6.8 s at the end of every chapter, so that the next chapter started in a scene that had settled:
			-- 408 frames of nothing a chapter in a speed run; AR_CHECKPOINT_PAUSE = <ms> brings a pause back)
			if AR_CHECKPOINT_PAUSE then
				sleep_for(AR_CHECKPOINT_PAUSE)
			end
			ar_log("checkpoint " .. slot .. " not saved")
			return
		end
		sleep_for(1000)
		AR_SAVING = TRUE
		ar_screen_clear()
		RenderModeUser(TRUE)
		sleep_for(300)
		ar_menu_save(slot)
		sleep_for(1500)
		RenderModeUser(nil)
		AR_SAVING = nil
		ar_screen_draw()
		ar_log("saved checkpoint grim" .. slot .. ".gsv")
		-- A resume loads this save and injects the chapter when it sees the line above: the autorun that the save holds
		-- waits here meanwhile, so that it does not play on into the next chapter before the new one takes over.
		sleep_for(4000)
		return
	end
	start_script(ar_save_task, slot, AR_CHAPTER)
end

-- Leaves the set through a door the way a player does: walks to the door's out point (or its
-- use point), which puts Manny in the door sector, and if that does not change the set the
-- door's walkOut is called.
AR_TARGET = nil

ar_is_climbing = function()
	return manny.is_climbing
end

-- Waits for the game to bring Manny to a set after a verb, then checks it
ar_expect_set = function(target, label)
	AR_TARGET = target
	AR_SEEN_TARGET = nil
	ar_wait_for(ar_target_reached, 150000)
	ar_wait_for_control()
	return ar_check(system.currentSet == target, label)
end

ar_target_reached = function()
	if system.currentSet == AR_TARGET then
		AR_SEEN_TARGET = TRUE
		return TRUE
	end
	-- a cutscene on arrival can go on to another set at once (AR_SEEN_STICKY, set by the chapter that expects it): the
	-- target was reached. Without it a set that the game passes through on the way (it takes Manny from the coat check
	-- on into the cafe) does not count.
	return AR_SEEN_STICKY and AR_SEEN_TARGET
end

-- Arriving by a door leaves Manny at the door; a player walks a few steps into the room before
-- anything else. The nearest door of the room (an object with walkOut) within a metre is left behind
-- in a straight line away from it.
ar_step_away_from_door = function()
	local p = manny:getpos()
	local best = nil
	local bestd = 1.0
	local k, v = next(system.currentSet, nil)
	while k do
		if type(v) == "table" and v.walkOut and v.obj_x then
			local d = sqrt((p.x - v.obj_x) * (p.x - v.obj_x) + (p.y - v.obj_y) * (p.y - v.obj_y))
			if v.use_pnt_x then
				local d2 = sqrt((p.x - v.use_pnt_x) * (p.x - v.use_pnt_x) + (p.y - v.use_pnt_y) * (p.y - v.use_pnt_y))
				if d2 < d then
					d = d2
				end
			end
			if d < bestd then
				best = v
				bestd = d
			end
		end
		k, v = next(system.currentSet, k)
	end
	if best then
		local dx = p.x - best.obj_x
		local dy = p.y - best.obj_y
		local len = sqrt(dx * dx + dy * dy)
		if len > 0.01 then
			ar_log("stepping away from " .. tostring(best.name) .. " (" .. format("%.2f", bestd) .. " m)")
			AR_STEP_SET = system.currentSet
			ar_walk_stick(p.x + dx / len * 1.0, p.y + dy / len * 1.0, p.z, function() return system.currentSet ~= AR_STEP_SET end)
		end
	end
end

-- Stepping into the sector of a door starts the game's own walk out a frame or two later: wait for it to start
ar_settle_door = function()
	ar_try_wait(function() return ar_target_reached() or find_script(Sentence) or cutSceneLevel > 0 end, 1000)
end

-- After a door the game walks Manny in from the door by itself, in a cutscene that starts a moment after the set changes:
-- wait for it to start and end before the next step
ar_settle_arrival = function()
	if ar_target_reached() then
		if AR_TRACE then ar_state("arrival before wait, cut " .. tostring(cutSceneLevel)) end
		sleep_for(AR_SETTLE_MS or 100)
		ar_wait_for_control()
		if AR_TRACE then ar_state("arrival after wait, cut " .. tostring(cutSceneLevel)) end
	end
end

ar_go = function(door, target, vx, vy, vz)
	local x, y, z
	AR_TARGET = target
	if door.out_pnt_x then
		x, y, z = door.out_pnt_x, door.out_pnt_y, door.out_pnt_z
	else
		x, y, z = door.use_pnt_x, door.use_pnt_y, door.use_pnt_z
	end
	ar_log("go: " .. ar_set_name() .. " -> " .. tostring(target.name) .. " (holding " .. tostring(manny.is_holding and manny.is_holding.name) .. ", boxes shrunk " .. tostring(system.currentSet.boxes_shrunk) .. ")")
	if door.use_pnt_x then
		-- the original searches its walk boxes for a path and takes minutes when the target is outside them
		-- (the out point of a door often is): walk to the use point, as a click on the door does, and use it
		if manny.is_holding and not AR_KEEP_HELD then
			ar_put_away()
		end
		AR_START_SET_GO = system.currentSet
		AR_SEEN_TARGET = nil
		-- A door can shut again while Manny is on the way (an elevator door closes by a timer 8 to 10 s after it was
		-- opened): then the walk to the other side ends short of it. A player sees the shut door and walks up to it
		-- again.
		local attempts = 0
		-- some doors need a step on a trigger first (the elevator door opens when Manny is near)
		if vx then
			ar_walk_to(vx, vy, vz, ar_target_reached)
			sleep_for(1500)
			ar_wait_for_control()
			-- (and on through the door from there: the trigger opens it only for as long as Manny goes on)
			if not ar_target_reached() and ar_nav_enter_door then
				ar_nav_enter_door(door, ar_target_reached)
				ar_settle_door()
				ar_wait_for_control()
			end
		end
		-- A door the game offers is used the way a player does: up to it, face it, press USE, and the game walks Manny through.
		-- (the doors that are only a sector on the floor are walked into below)
		if AR_DOOR_USE and door.touchable and not ar_target_reached() then
			AR_KEEP_GOING = TRUE
			ar_do("use", door)
			AR_KEEP_GOING = nil
			AR_FAILED = nil
			ar_wait_for_control()
			ar_try_wait(ar_target_reached, 1500)
		end
		while not ar_target_reached() and attempts < 3 do
			if attempts > 0 then
				ar_log("go: the way through " .. tostring(door.name) .. " did not hold, trying again")
			end
			-- A door is what Doorman makes of its sector: Manny walks into it and the game takes him through. One that has no sector
			-- (or one that is off, or that does not react) is used the way a player uses it: up to its use point, and USE.
			local entered = ar_nav_enter_door(door, ar_target_reached)
			if entered and AR_PATH_DONE == nil and not ar_target_reached() and cutSceneLevel == 0 and not find_script(Sentence) then
				-- (no way into its sector at all: the use point and the verb)
				entered = nil
			end
			if not entered or not ar_target_reached() then
				-- (a second for the game to start the sentence of the door, when Manny walked into its sector: for a door that has none nothing is on its way, and the second
				-- was a stop of 60 frames before the walk to the use point, the first time outside on the way to the clown)
				if entered then
					ar_settle_door()
				end
				-- (the game's walk out, or what the door does, to its end)
				ar_try_wait(function() return ar_target_reached() or (not find_script(Sentence) and cutSceneLevel == 0) end, 15000)
				ar_wait_for_control()
			end
			-- (a door that has a sector is walked into again when a scene sent Manny back; the use point and the verb are for a door that has
			-- none, or that does not react after two tries)
			if not ar_target_reached() and (not entered or attempts >= 1) then
				ar_walk_to(door.use_pnt_x, door.use_pnt_y, door.use_pnt_z, ar_target_reached)
				ar_wait_for_control()
				if not ar_target_reached() then
					ar_do("use", door)
					AR_FAILED = nil
					ar_wait_for_control()
					ar_try_wait(ar_target_reached, 2000)
				end
			end
			-- (what the game does on arrival, to its end: it can take Manny on again, then the door is walked through again)
			ar_try_wait(ar_target_reached, 1000)
			ar_settle_arrival()
			attempts = attempts + 1
			-- (the game took Manny on to a third set: the door of this one is no use any more, the chapter goes on from there)
			if not ar_target_reached() and system.currentSet ~= AR_START_SET_GO then
				ar_log("go: the game took Manny from " .. tostring(target.name) .. " on to " .. ar_set_name())
				return nil
			end
		end
		ar_wait_for(ar_target_reached, 1000, "the set " .. tostring(target.name))
		return ar_check(ar_target_reached(), "reached " .. tostring(target.name))
	end
	-- an item in the hand turns the door into a use-with sentence, a player puts it away first
	if manny.is_holding and not AR_KEEP_HELD then
		ar_put_away()
	end
	AR_START_SET_GO = system.currentSet
	AR_SEEN_TARGET = nil
	local attempts = 0
	-- arriving by a door leaves Manny inside its sector, which only reacts when it is entered:
	-- a player walks a step on (he faces away from the door) and comes back
	local hid, hname = manny:find_sector_type(HOT)
	-- arriving by a door leaves Manny inside its sector, which only reacts when it is entered: a
	-- player walks a step on (he faces away from the door) and comes back. (AR_NEW, the later
	-- chapters: only when it is the sector of the door he is going to; a step in the wrong direction
	-- could just as well leave through another door, such as the elevator)
	if hname and (not AR_NEW or system.currentSet[hname] == door) then
		local t = 0
		while t < 1200 do
			manny:walk_forward()
			break_here()
			t = t + system.frameTime
		end
	end
	-- some doors need a step on a trigger first (the elevator door opens when Manny is near)
	if vx then
		local p0 = manny:getpos()
		local tries = 0
		ar_walk_to(vx, vy, vz, ar_target_reached)
		sleep_for(1500)
		ar_wait_for_control()
		-- a trigger that does not fire (a cutscene was running when Manny stepped in) leaves him
		-- standing by the point: go back and step in again
		local pn = manny:getpos()
		while AR_VIA_RETRY and tries < 3 and not ar_target_reached() and abs(pn.x - vx) + abs(pn.y - vy) < 1.2 and abs(p0.x - vx) + abs(p0.y - vy) > 2 do
			local dx = vx - p0.x
			local dy = vy - p0.y
			local len = sqrt(dx * dx + dy * dy)
			ar_walk_to(pn.x - dx / len * 2.5, pn.y - dy / len * 2.5, pn.z, ar_target_reached)
			ar_walk_to(vx, vy, vz, ar_target_reached)
			sleep_for(1500)
			ar_wait_for_control()
			pn = manny:getpos()
			tries = tries + 1
		end
	end
	-- something on the way can interrupt the walk (a cutscene, a trigger), a player walks on
	while not ar_target_reached() and attempts < 4 do
		if attempts > 0 then
			local mp = manny:getpos()
			ar_log("walking on toward " .. tostring(target.name) .. " from " .. format("%.2f %.2f %.2f", mp.x, mp.y, mp.z) .. " to " .. format("%.2f %.2f %.2f", x, y, z))
		end
		-- a cutscene on the way can leave Manny standing in the door's sector with the Doorman
		-- done with it: step back out to the use point and walk in again
		if attempts > 0 and door.use_pnt_x then
			ar_walk_to(door.use_pnt_x, door.use_pnt_y, door.use_pnt_z, ar_target_reached)
		end
		local before = manny:getpos()
		ar_walk_to(x, y, z, ar_target_reached)
		ar_wait_for(ar_target_reached, 15000)
		ar_wait_for_control()
		local after = manny:getpos()
		if AR_NEW and not ar_target_reached() and system.currentSet ~= AR_START_SET_GO then
			ar_log("Manny left " .. tostring(AR_START_SET_GO.name) .. " by another door, into " .. ar_set_name() .. ", on the way to " .. tostring(target.name))
			AR_START_SET_GO = system.currentSet
		end
		if AR_NEW and not ar_target_reached() and attempts > 0 and abs(after.x - before.x) + abs(after.y - before.y) < 0.15 then
			ar_check(nil, "Manny is stuck at " .. format("%.2f %.2f %.2f", after.x, after.y, after.z) .. " on the way to " .. tostring(target.name))
		end
		if not ar_target_reached() and (door.out_pnt_x or door.obj_x) then
			-- into the door itself, on past its out point (or its use point)
			local dx = 0
			local dy = 0
			if door.use_pnt_x and door.out_pnt_x then
				dx = x - door.use_pnt_x
				dy = y - door.use_pnt_y
			end
			if abs(dx) + abs(dy) < 0.05 and door.obj_x then
				dx = door.obj_x - x
				dy = door.obj_y - y
			end
			local len = sqrt(dx * dx + dy * dy)
			if len < 0.01 then
				len = 1
			end
			ar_walk_to(x + dx / len * 1.2, y + dy / len * 1.2, z, ar_target_reached)
			ar_wait_for(ar_target_reached, 15000)
			ar_wait_for_control()
		end
		attempts = attempts + 1
	end
	if not ar_target_reached() then
		ar_do("use", door)
		ar_wait_for(ar_target_reached, 15000)
	end
	ar_wait_for_control()
	ar_settle_arrival()
	return ar_check(ar_target_reached(), "reached " .. tostring(target.name))
end

-- The first object of a table of objects (such as fe.balloons) that Manny carries
ar_find_owned = function(tbl)
	local k, v = next(tbl, nil)
	while k do
		if type(v) == "table" and v.owner == manny then
			return v
		end
		k, v = next(tbl, k)
	end
	return nil
end

-- Held keys. Some of the game polls the state of a key (get_generic_control_state), such as
-- the Bone Wagon's gas and steering, so the engine's key state is wrapped to report the keys
-- this script holds. A save keeps the wrapper, it must not be wrapped twice.
AR_HELD = AR_HELD or { }
if not AR_OLD_GCS then
	AR_OLD_GCS = GetControlState
	GetControlState = function(k, a, b)
		if AR_HELD[k] then
			return 1
		end
		return AR_OLD_GCS(k, a, b)
	end
end

-- Presses and holds the first key of a control ("MOVE_FORWARD", "TURN_LEFT", ...), key down
-- event included
-- The first key of a control that is a real key: the stick pseudo keys are read from the axes
ar_real_key = function(name)
	local key = next(control_map[name], nil)
	while key and (key == JOYSTICK_Y_UP or key == JOYSTICK_Y_DOWN or key == JOYSTICK_X_LEFT or key == JOYSTICK_X_RIGHT) do
		key = next(control_map[name], key)
	end
	return key
end

ar_key_down = function(name)
	local key = ar_real_key(name)
	AR_HELD[key] = TRUE
	ar_press_key(key)
end

-- The key goes up, and the game is told so, as it is when a player lets go: the handler of the keys ends what the key began
-- (the backward walk, for one, which keeps its negative walk rate until it is told that the key is up)
ar_release_key = function(key)
	local handler = system.buttonHandler
	if type(handler) == "function" then
		handler(key, nil, nil)
	elseif type(handler) == "table" and handler.buttonHandler then
		handler:buttonHandler(key, nil, nil)
	end
end

ar_key_up = function(name)
	local key = ar_real_key(name)
	if AR_HELD[key] then
		AR_HELD[key] = nil
		ar_release_key(key)
	end
end

ar_keys_up = function()
	local held = AR_HELD
	AR_HELD = { }
	local key = next(held, nil)
	while key do
		ar_release_key(key)
		key = next(held, key)
	end
end

-- Steers the Bone Wagon to a point with the held keys: forward all the time, and the turn
-- keys by the angle to the point. Returns TRUE when it is near the point.
ar_drive_to = function(x, y, z, tolerance, timeout, stop_when, vehicle)
	if AR_NOTIMEOUT then
		timeout = 1000000000000
	end
	vehicle = vehicle or bonewagon
	local waited = 0
	local flip = 1
	local lastdiff = nil
	local checked = 0
	local stuck = 0
	local lastp = vehicle:getpos()
	AR_UNSTUCK = 0
	AR_DRV_KEY = 0
	AR_DRV_FWD = TRUE
	AR_DRV_LOG = nil
	AR_DRV_N = 0
	AR_DRV_YAW0 = vehicle:getrot().y
	ar_key_down("MOVE_FORWARD")
	while proximity(vehicle.hActor, x, y, z) > tolerance and waited < timeout and not (stop_when and stop_when()) do
		if AR_SOFT_DRIVE and AR_UNSTUCK > 3 then
			-- (a point of a route that the wagon cannot get to: after a few tries it is on to the next)
			waited = timeout
		end
		local want = GetActorYawToPoint(vehicle.hActor, x, y, z)
		local cur = vehicle:getrot().y
		local diff = want - cur
		while diff > 180 do
			diff = diff - 360
		end
		while diff < -180 do
			diff = diff + 360
		end
		-- which way is left? learn it from what the heading does over a few frames of one key (one frame can overshoot: the frames
		-- of the engines are not alike, and a turn that goes the right way and goes too far looks like one that goes the wrong way)
		if checked ~= 0 and checked == AR_DRV_KEY then
			AR_DRV_N = AR_DRV_N + 1
			if AR_DRV_N >= 4 then
				local moved = cur - AR_DRV_YAW0
				moved = moved - 360 * floor(moved / 360 + 0.5)
				if abs(moved) > 1 then
					-- (the left key is to turn toward the positive side of the angle where flip is 1)
					if moved * checked * flip < 0 then
						flip = -flip
					end
				end
				AR_DRV_N = 0
				AR_DRV_YAW0 = cur
			end
		else
			AR_DRV_N = 0
			AR_DRV_YAW0 = cur
		end
		AR_DRV_KEY = checked
		-- A vehicle that turns slowly (the wagon: 30 degrees a second, with a circle of a few units to turn on) runs into the edge of the
		-- road if it drives while it points the wrong way. With AR_TURN_FIRST it stands and turns until it points about right, then drives.
		if not AR_TURN_FIRST then
			-- (not asked for: the key of the way forward stays down)
		elseif abs(diff) > 40 and AR_DRV_FWD then
			AR_DRV_FWD = nil
			ar_key_up("MOVE_FORWARD")
		elseif abs(diff) < 20 and not AR_DRV_FWD then
			AR_DRV_FWD = TRUE
			ar_key_down("MOVE_FORWARD")
		end
		if AR_TRACE and waited - (AR_DRV_LOG or -1000) > 300 then
			AR_DRV_LOG = waited
			ar_log("  drive at " .. format("%.2f %.2f", vehicle:getpos().x, vehicle:getpos().y) .. " yaw " .. format("%.0f", cur) .. " want " .. format("%.0f", want) .. " diff " .. format("%.0f", diff) .. " flip " .. tostring(flip) .. " key " .. tostring(checked))
		end
		lastdiff = diff
		checked = 0
		ar_key_up("TURN_LEFT")
		ar_key_up("TURN_RIGHT")
		if diff * flip > 6 then
			ar_key_down("TURN_LEFT")
			checked = 1
		elseif diff * flip < -6 then
			ar_key_down("TURN_RIGHT")
			checked = -1
		end
		break_here()
		waited = waited + system.frameTime
		local p = vehicle:getpos()
		if abs(p.x - lastp.x) + abs(p.y - lastp.y) < 0.002 then
			stuck = stuck + 1
		else
			stuck = 0
		end
		lastp = p
		if stuck > 45 and not (stop_when and stop_when()) then
			-- Against the edge of the road the wagon can stop dead. A driver backs up straight and drives on from there.
			AR_UNSTUCK = (AR_UNSTUCK or 0) + 1
			ar_log("drive: stuck at " .. format("%.2f %.2f", p.x, p.y) .. ", backing up (" .. tostring(AR_UNSTUCK) .. ")")
			ar_keys_up()
			ar_key_down("MOVE_BACKWARD")
			-- straight, then with the wheel one way, then the other: the nose has to come round before driving on
			if AR_UNSTUCK - floor(AR_UNSTUCK / 3) * 3 == 1 then
				ar_key_down("TURN_RIGHT")
			elseif AR_UNSTUCK - floor(AR_UNSTUCK / 3) * 3 == 2 then
				ar_key_down("TURN_LEFT")
			end
			local backed = 0
			while backed < 1500 do
				break_here()
				backed = backed + system.frameTime
			end
			ar_keys_up()
			ar_key_down("MOVE_FORWARD")
			stuck = 0
			lastdiff = nil
			checked = 0
			waited = waited + backed
		end
	end
	ar_keys_up()
	if proximity(vehicle.hActor, x, y, z) > tolerance and waited >= timeout and not (stop_when and stop_when()) and AR_SOFT_DRIVE then
		ar_log("drive: the point " .. format("%.2f %.2f", x, y) .. " of the route is not reached, on to the next (stopped at " .. format("%.2f %.2f", vehicle:getpos().x, vehicle:getpos().y) .. ")")
	elseif proximity(vehicle.hActor, x, y, z) > tolerance and waited >= timeout and not (stop_when and stop_when()) then
		ar_fail("the drive used its whole time budget of " .. tostring(timeout) .. " ms, stopped at " .. format("%.2f %.2f", vehicle:getpos().x, vehicle:getpos().y) .. " toward " .. format("%.2f %.2f", x, y))
	end
	return proximity(vehicle.hActor, x, y, z) <= tolerance
end

-- Turns a vehicle (the forklift) on the spot to a heading with the held turn keys
ar_turn_vehicle = function(vehicle, yaw, tolerance, timeout)
	if AR_NOTIMEOUT then
		timeout = 1000000000000
	end
	local waited = 0
	local flip = 1
	local lastdiff = nil
	local done = nil
	while waited < timeout and not done do
		local cur = vehicle:getrot().y
		local diff = yaw - cur
		while diff > 180 do
			diff = diff - 360
		end
		while diff < -180 do
			diff = diff + 360
		end
		if abs(diff) <= tolerance then
			done = TRUE
		else
			if lastdiff and abs(diff) > abs(lastdiff) + 0.5 then
				flip = -flip
			end
			lastdiff = diff
			ar_key_up("TURN_LEFT")
			ar_key_up("TURN_RIGHT")
			if diff * flip > 0 then
				ar_key_down("TURN_LEFT")
			else
				ar_key_down("TURN_RIGHT")
			end
			break_here()
			waited = waited + system.frameTime
		end
	end
	ar_keys_up()
	if not done then
		ar_fail("the turn of the vehicle used its whole time budget of " .. tostring(timeout) .. " ms")
	end
	return done
end

-- For working out what to do in a set: lists its objects with the verbs they answer to
ar_describe = function()
	local k, v = next(system.currentSet, nil)
	local n = 0
	ar_log("== objects of " .. ar_set_name() .. ", Manny carries [" .. ar_inventory() .. "]")
	while k do
		if type(v) == "table" and v.name and v.interest_actor and v.touchable then
			local verbs = ""
			local vk, vv = next(v, nil)
			while vk do
				if type(vk) == "string" and type(vv) == "function" and (vk == "use" or vk == "pickUp" or vk == "lookAt" or vk == "walkOut" or strfind(vk, "^use_")) then
					verbs = verbs .. vk .. " "
				end
				vk, vv = next(v, vk)
			end
			ar_log(tostring(k) .. " = " .. tostring(v.name) .. " at (" .. format("%.2f %.2f", v.use_pnt_x or 0, v.use_pnt_y or 0) .. ") range " .. tostring(v.range) .. ": " .. verbs)
			n = n + 1
		end
		k, v = next(system.currentSet, k)
	end
	ar_log("== " .. n .. " objects")
end

-- Prints a map of the walkable area of the set, a character for each walk sector found at some
-- height (the sector id), 'M' for Manny; the points of the objects with a use point are listed
ar_map = function(x0, x1, y0, y1, step)
	local mp = manny:getpos()
	local chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local y = y1
	ar_log("map of " .. ar_set_name() .. " x " .. x0 .. ".." .. x1 .. " y " .. y1 .. ".." .. y0 .. " step " .. step)
	while y >= y0 do
		local row = ""
		local x = x0
		while x <= x1 do
			local c = "."
			local z = -4
			while z <= 4 and c == "." do
				local id = GetPointSector(x, y, z)
				if id then
					c = strsub(chars, mod(id, 62) + 1, mod(id, 62) + 1)
				end
				z = z + 0.25
			end
			if abs(x - mp.x) < step / 2 and abs(y - mp.y) < step / 2 then
				c = "M"
			end
			row = row .. c
			x = x + step
		end
		ar_log(format("%6.2f ", y) .. row)
		y = y - step
	end
end

AR_WATCH_TASK = start_script(ar_watchdog)
-- AR_SKIPLINES (modes speed, speed100): every line that is spoken is ended with the key that expires the text, in the frame it starts, as a player holding
-- the skip key does. Every frame, not at the beats of a timer, so that the frame of the press is the same in both engines.
ar_line_skipper = function()
	while TRUE do
		if IsMessageGoing() and not AR_SAYING then
			ar_press_key(ar_real_key("EXPIRE_TEXT"))
		end
		break_here()
	end
end
if AR_SKIPLINES and not AR_REAL and not AR_FRAMES then
	AR_LINE_TASK = start_script(ar_line_skipper)
end
AR_SKIP_TASK = start_script(ar_skipper)
-- A cutscene is skipped 500 ms of game time after its override was set. The timer is started by set_override itself, in the pass of the script that
-- sets the override, so the frame of the skip does not depend on where this library's tasks stand in the list of tasks (they stand differently in
-- the original, where the library is injected into a running game, and in ScummVM)
if not AR_SETOV_OLD then
	AR_SETOV_OLD = set_override
end
AR_OV_SERIAL = AR_OV_SERIAL or 0
ar_skip_timer = function(serial)
	sleep_for(500)
	if serial == AR_OV_SERIAL and system.override and system.override.is_active and not AR_NO_SKIP and not AR_REAL then
		ar_log("skipping a cutscene")
		-- the movie is stopped first, as the overrides do not always stop it and the
		-- next scene must not load with its sound still playing
		ar_press_key(ar_real_key("OVERRIDE"))
		-- (an override that is still active after the key, a cutscene of several parts: the next 500 ms)
		AR_OV_SERIAL = AR_OV_SERIAL + 1
		if system.override.is_active then
			AR_OV_TASK = start_script(ar_skip_timer, AR_OV_SERIAL)
		end
	end
end
set_override = function(func, table)
	AR_SETOV_OLD(func, table)
	AR_OV_SERIAL = AR_OV_SERIAL + 1
	AR_OV_ARMED = TRUE
	AR_OV_TASK = start_script(ar_skip_timer, AR_OV_SERIAL)
end
-- (an override that is active without having been set in this run: it comes with a loaded save)
ar_override_clock = function()
	while TRUE do
		AR_FRAME = AR_FRAME + 1
		-- (the frames in which the autorun has the control: no cutscene, the game does not move Manny by a script; the frames to cut by tuning the run)
		if cutSceneLevel == 0 then
			AR_FRAME_CTL = (AR_FRAME_CTL or 0) + 1
		end
		-- Manny's idle animation (scratching, smoking) runs until the player touches a key
		-- (every frame, not at the beats of a timer: the frame in which this happens would depend on where the timer's beats fall, which is not the same in the original and in ScummVM)
		if manny.is_idling then
			manny.stop_idle = TRUE
		end
		-- Manny runs, as a player holding the run key does. Every walk to an object turns running off again, so it is switched on whenever he is walking.
		if not AR_WALK and not AR_NEAR_SLOW and not manny.is_running and not manny.is_backward and manny:is_moving() then
			manny:set_run(TRUE)
		end
		if system.override and system.override.is_active then
			if not AR_OV_ARMED then
				AR_OV_ARMED = TRUE
				AR_OV_SERIAL = AR_OV_SERIAL + 1
				AR_OV_TASK = start_script(ar_skip_timer, AR_OV_SERIAL)
			end
		else
			AR_OV_ARMED = nil
		end
		break_here()
	end
end
AR_OV_CLOCK_TASK = start_script(ar_override_clock)

-- F10 cancels the run and hands the game to the player: the script of the run and the helper tasks are stopped, the keys it holds are let go,
-- cutscenes are no longer skipped, and the progress text goes. The game keeps running (ar_finish would end it).
ar_cancel = function()
	ar_log("CANCELLED by F10, where the walk was: " .. tostring(AR_WHERE))
	-- (the watchdog first: it would take the end of the script for a death and finish the run)
	stop_script(ar_watchdog)
	if __autorun__ then
		stop_script(__autorun__)
	end
	stop_script(ar_skipper)
	stop_script(ar_override_clock)
	stop_script(ar_skip_timer)
	stop_script(ar_save_task)
	if AR_FRAME_TASK then
		stop_script(AR_FRAME_TASK)
	end
	local key = next(AR_HELD, nil)
	while key do
		AR_HELD[key] = nil
		ar_release_key(key)
		key = next(AR_HELD, nil)
	end
	local name = next(AR_AXE_KEYS, nil)
	while name do
		ar_axe_key(name, nil)
		name = next(AR_AXE_KEYS, nil)
	end
	AR_NO_SKIP = TRUE
	set_override = AR_SETOV_OLD
	ar_screen_clear()
	ar_shown_count = 0
	AR_NOSCREEN = TRUE
end
ar_cancel_watch = function()
	local gcs = AR_OLD_GCS or GetControlState
	while not gcs(F10KEY) do
		break_here()
	end
	ar_cancel()
end
if AR_CANCEL_TASK then
	stop_script(AR_CANCEL_TASK)
end
if F10KEY then
	AR_CANCEL_TASK = start_script(ar_cancel_watch)
end

-- Frames for the comparison of the engines (tools/framediff.py): with AR_FRAMES = <milliseconds> a frame is taken that often, counted from the start of
-- the chapter (ar_frame_chapter): ScummVM writes the file itself (DumpFrame, dump_frames_dir in its config), for the original the log gets a line that
-- tools/framecap.py answers by copying the window.
ar_frame = function(name)
	PrintDebug("FRAMEMARK " .. name .. "\n")
	if DumpFrame then
		DumpFrame(name)
	end
end
ar_frame_chapter = function(name)
	AR_FRAME_CH = name
	AR_FRAME_N = 0
	AR_STEP_N = 0
end
ar_framer = function()
	while TRUE do
		if AR_FRAME_CH then
			ar_frame(AR_FRAME_CH .. "_" .. format("%04d", AR_FRAME_N))
			AR_FRAME_N = AR_FRAME_N + 1
		end
		sleep_for(AR_FRAMES)
	end
end
if AR_FRAMES then
	if AR_FRAME_TASK then
		stop_script(AR_FRAME_TASK)
	end
	ar_frame_chapter(AR_CHAPTER or "start")
	if AR_FRAMES > 0 then
		AR_FRAME_TASK = start_script(ar_framer)
	end
end

-- The axe handler wants real press and release events, since the walk and turn scripts it
-- starts run until the release
AR_AXE_KEYS = { }
ar_axe_key = function(name, on)
	local key = ar_real_key(name)
	if on and not AR_AXE_KEYS[name] then
		AR_AXE_KEYS[name] = TRUE
		system.buttonHandler(key, TRUE, nil)
	elseif not on and AR_AXE_KEYS[name] then
		AR_AXE_KEYS[name] = nil
		system.buttonHandler(key, nil, nil)
	end
end

-- Drags the broadaxe (Manny only walks backwards with it) to a point: the turn keys aim his
-- back at the point, the backward key is held while he is roughly aimed
ar_axe_drive_to = function(x, y, tolerance, timeout, stop_when)
	if AR_NOTIMEOUT then
		timeout = 1000000000000
	end
	local waited = 0
	local flip = 1
	local lastdiff = nil
	while proximity(manny.hActor, x, y, 0) > tolerance and waited < timeout and not (stop_when and stop_when()) do
		local want = GetActorYawToPoint(manny.hActor, x, y, 0) + 180
		local diff = want - manny:getrot().y
		while diff > 180 do
			diff = diff - 360
		end
		while diff < -180 do
			diff = diff + 360
		end
		if lastdiff and abs(diff) > abs(lastdiff) + 4 then
			flip = -flip
		end
		lastdiff = diff
		if diff * flip > 8 then
			ar_axe_key("TURN_RIGHT", nil)
			ar_axe_key("TURN_LEFT", TRUE)
		elseif diff * flip < -8 then
			ar_axe_key("TURN_LEFT", nil)
			ar_axe_key("TURN_RIGHT", TRUE)
		else
			ar_axe_key("TURN_LEFT", nil)
			ar_axe_key("TURN_RIGHT", nil)
		end
		ar_axe_key("MOVE_BACKWARD", abs(diff) < 35)
		break_here()
		waited = waited + system.frameTime
	end
	ar_axe_key("TURN_LEFT", nil)
	ar_axe_key("TURN_RIGHT", nil)
	ar_axe_key("MOVE_BACKWARD", nil)
	sleep_for(300)
	if proximity(manny.hActor, x, y, 0) > tolerance and waited >= timeout and not (stop_when and stop_when()) then
		ar_fail("the drag of the axe used its whole time budget of " .. tostring(timeout) .. " ms, stopped at " .. format("%.2f %.2f", manny:getpos().x, manny:getpos().y) .. " toward " .. format("%.2f %.2f", x, y))
	end
	return proximity(manny.hActor, x, y, 0) <= tolerance
end

-- Turns Manny (with the axe) on the spot to a heading with the turn keys
ar_axe_face = function(yaw, tol, timeout)
	if AR_NOTIMEOUT then
		timeout = 1000000000000
	end
	local waited = 0
	local flip = 1
	local lastdiff = nil
	local done = nil
	while waited < timeout and not done do
		local diff = yaw - manny:getrot().y
		while diff > 180 do diff = diff - 360 end
		while diff < -180 do diff = diff + 360 end
		if abs(diff) <= tol then
			done = TRUE
		else
			if lastdiff and abs(diff) > abs(lastdiff) + 4 then flip = -flip end
			lastdiff = diff
			if diff * flip > 0 then
				ar_axe_key("TURN_RIGHT", nil)
				ar_axe_key("TURN_LEFT", TRUE)
			else
				ar_axe_key("TURN_LEFT", nil)
				ar_axe_key("TURN_RIGHT", TRUE)
			end
			break_here()
			waited = waited + system.frameTime
		end
	end
	ar_axe_key("TURN_LEFT", nil)
	ar_axe_key("TURN_RIGHT", nil)
	if not done then
		ar_fail("the turn with the axe used its whole time budget of " .. tostring(timeout) .. " ms")
	end
	return done
end

-- Climbs a ladder the way a player does, holding "up" (or "down"), which runs climb_up over and over,
-- until stop_when() or the timeout
ar_climb = function(up, stop_when, timeout)
	local waited = 0
	timeout = timeout or 60000
	if AR_NOTIMEOUT then
		timeout = 1000000000000
	end
	while manny.is_climbing and not (stop_when and stop_when()) and waited < timeout do
		if up then
			if not find_script(manny.climb_up) then
				start_script(manny.climb_up, manny)
			end
		elseif not find_script(manny.climb_down) then
			start_script(manny.climb_down, manny)
		end
		sleep_for(100)
		waited = waited + 100
	end
	if manny.is_climbing and waited >= timeout and not (stop_when and stop_when()) then
		ar_fail("the climb used its whole time budget of " .. tostring(timeout) .. " ms")
	end
end

-- Where something that moves about is now: the object keeps the place it was created at, its actor rides about
ar_where = function(obj)
	if obj.interest_actor then
		return obj.interest_actor:getpos()
	end
	return { x = obj.obj_x, y = obj.obj_y, z = obj.obj_z or 0 }
end

AR_RETRY_OBJ = nil
ar_retry_in_reach = function()
	return proximity(manny.hActor, AR_RETRY_OBJ.interest_actor.hActor) < AR_RETRY_OBJ.range - 0.02
end

-- Gives a verb to something that moves about (the unicycle man, who rides between two spots that are only partly
-- within reach of the floor): a player goes to where it can be reached, waits there until it is in reach, and
-- gives the verb straight away
ar_do_retry = function(verb, obj, item, tries, stand_x, stand_y, stand_z)
	local old_keep = AR_KEEP_GOING
	local old_failed = AR_FAILED
	local n = 0
	local done = nil
	tries = tries or 6
	AR_KEEP_GOING = TRUE
	while not done and n < tries do
		AR_FAILED = nil
		ar_wait_for_control()
		if stand_x then
			-- (the use point can lie outside the floor: a walk to it ends up somewhere else)
			ar_walk_to(stand_x, stand_y, stand_z)
		elseif obj.use_pnt_x then
			ar_walk_to(obj.use_pnt_x, obj.use_pnt_y, obj.use_pnt_z)
		else
			local where = ar_where(obj)
			ar_walk_to(where.x, where.y, where.z)
		end
		-- until it rides within reach (as the game measures it: from its actor)
		if obj.interest_actor and obj.range then
			AR_RETRY_OBJ = obj
			ar_try_wait(ar_retry_in_reach, 30000)
		end
		local where = ar_where(obj)
		ar_turn_to_point(where.x, where.y, where.z)
		ar_wait_turn()
		ar_do(verb, obj, item)
		if not AR_FAILED then
			done = TRUE
		else
			n = n + 1
		end
	end
	AR_KEEP_GOING = old_keep
	AR_FAILED = old_failed
	if not done then
		return ar_fail("could not " .. verb .. " " .. tostring(obj.name) .. " after " .. tostring(tries) .. " tries")
	end
	return TRUE
end
