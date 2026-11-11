-- EMI layer over ar_lib.lua (loaded after it, nothing in the library is changed). A function is redefined here only where
-- EMI differs; where the change is small it keeps the name and signature of the Grim one so the two can be merged later.

-- EMI has no vlist: the objects the player is offered are in `hotlist` (object -> angle), made by Build_Hotlist.
ar_offer_list = function()
	return vlist or hotlist
end

-- The object the verb is for has to be the one the game highlights (its hot_object: of what Guybrush sees, the one nearest to the way he
-- faces; the player moves the choice along the list with the CHANGE_HOT keys, which is done here until it is the object, and turns to it
-- when that does not get there). Nothing is set in the game.
ar_cycle_to = function(obj)
	ar_try_wait(function() return hot_object == %obj end, 400)
	local n = 0
	while hot_object ~= obj and n < 12 do
		local key = ar_real_key("CHANGE_HOT_UP")
		ar_press_key(key)
		sleep_for(100)
		ar_release_key(key)
		sleep_for(200)
		n = n + 1
	end
	return hot_object == obj
end

ar_gaze_at = function(obj)
	local list = ar_offer_list()
	if not obj.interest_actor or not list or not list[obj] then
		return nil
	end
	if not ar_cycle_to(obj) then
		ar_face(obj)
		ar_try_wait(function() return hot_object == %obj end, 1200)
	end
	return hot_object == obj
end

ar_offered = function()
	local list = ar_offer_list()
	return list and AR_OBJ and list[AR_OBJ]
end

ar_why_not_offered = function(obj)
	local list = ar_offer_list()
	local p = manny:getpos()
	local o = obj.interest_actor and obj.interest_actor:getpos()
	-- how the game decides (the hotlist of _system): the thing must be among what Guybrush sees (GetVisibleThings: within half the field
	-- of view of his facing) and within the range of him (point2_prox_lite, squared, against the range squared)
	local why = ""
	if obj.interest_actor and obj.interest_actor.hActor then
		local vt = GetVisibleThings()
		local seen = nil
		local k, v = next(vt, nil)
		while k do
			if k == obj.interest_actor.hActor then
				seen = TRUE
			end
			k, v = next(vt, k)
		end
		local wx, wy, wz = GetActorWorldPos(obj.interest_actor.hActor)
		local mx, my, mz = GetActorWorldPos(manny.hActor)
		why = format(" seen=%s dist2=%.2f world=%.2f %.2f %.2f", tostring(seen), sqrt((wx - mx) * (wx - mx) + (wz - mz) * (wz - mz)), wx, wy, wz)
	end
	return format("touchable=%s range=%s in the list=%s manny=%.2f %.2f %.2f object=%s", tostring(obj.touchable), tostring(obj.range),
		tostring(list and list[obj]), p.x, p.y, p.z, o and format("%.2f %.2f %.2f", o.x, o.y, o.z) or "?") .. why
end

-- EMI: an object in the hotlist is already close enough; Grim's walk (sectors, use points) is only tried when it is not.
-- Not yet written for EMI: a walk to an object that is not offered fails with the reason.
ar_obj_offered = function()
	local l = ar_offer_list()
	return l and AR_OBJ and l[AR_OBJ]
end


ar_approach = function(obj)
	AR_OBJ = obj
	-- (the list is rebuilt every few frames, and not at all in a cutscene)
	ar_try_wait(ar_obj_offered, 600)
	if ar_obj_offered() then
		return TRUE
	end
	-- (on a map, Guybrush is a marker that walks over it like anywhere else; a place is offered when he is within its range)
	-- not offered: walk toward it (its use point, or itself): the way planned on the sectors ends at the nearest floor, and a
	-- trigger on the way (a step up, a door) does its part. Then points of the floor inside its range, the nearest first.
	local tx, ty, tz
	local o = ar_obj_pos(obj)
	local o0x, o0z = o.x, o.z
	-- (the use point of some objects is an offset from the actor and not a place of the set, far from the object: then the object's own place)
	if obj.use_pnt_x and abs(obj.use_pnt_x - o.x) < 30 and abs(obj.use_pnt_z - o.z) < 30 then
		tx, ty, tz = obj.use_pnt_x, obj.use_pnt_y, obj.use_pnt_z
	else
		tx, ty, tz = o.x, o.y, o.z
	end
	local aset = system.currentSet
	ar_walk_to(tx, ty, tz, ar_obj_offered)
	-- (the walk went through a door on the way, or into the door that is the object: the caller sees the new set)
	if system.currentSet ~= aset then
		return TRUE
	end
	ar_try_wait(ar_obj_offered, 800)
	local pts, np = ar_stand_points(obj)
	local k = 1
	while k <= np and k <= 6 and not ar_obj_offered() do
		ar_walk_to(pts[k][1], pts[k][2], pts[k][3], ar_obj_offered)
		ar_try_wait(ar_obj_offered, 800)
		k = k + 1
		-- (the next point only when this one was not reached, not when the object just needs facing)
		if ar_floor_dist(pts[k - 1][1], pts[k - 1][3]) < 0.8 then
			k = 99
		end
	end
	if system.currentSet ~= aset then
		return TRUE
	end
	-- (not in front of Guybrush: the game only sees what he faces)
	ar_face(obj)
	ar_try_wait(ar_obj_offered, 3000)
	if ar_obj_offered() then
		return TRUE
	end
	-- (someone who walks about (Planet Threepwood's Jolly pirate) has gone elsewhere meanwhile: after him, as a player goes)
	local o1 = ar_obj_pos(obj)
	if o0x and o1.x and abs(o1.x - o0x) + abs(o1.z - o0z) > 1 and (AR_APPROACH_AGAIN or 0) < 2 then
		AR_APPROACH_AGAIN = (AR_APPROACH_AGAIN or 0) + 1
		ar_log(format("%s has moved from %.2f %.2f to %.2f %.2f: walking up to it again", tostring(obj.name), o0x, o0z, o1.x, o1.z))
		local r = ar_approach(obj)
		AR_APPROACH_AGAIN = nil
		return r
	end
	AR_APPROACH_AGAIN = nil
	return ar_fail(tostring(obj.name) .. " is not offered after walking up to it: " .. ar_why_not_offered(obj))
end

-- The control is back when the cutscene level is down; after a door (ar_settled, AR_DLG_CONTROL) also when a conversation waits for a
-- choice: a skipped arrival cutscene can start one itself (the plank diving's starts Marco's), and its cutscene level stays up while it
-- runs; the wait timed out after 120 s and stopped the whole run (every run of Nov 10 after the idle fixes). The chapter follows the
-- conversation. (Everywhere: the poker and the act 3 chapters went on in the middle of conversations.)
ar_dialog_waiting = function()
	local h = system.buttonHandler
	return type(h) == "table" and h.running and h.node and h.current_choices
end
ar_wait_for_control = function()
	if not ar_wait_for(function() return cutSceneLevel == 0 or (AR_DLG_CONTROL and ar_dialog_waiting()) end, AR_CONTROL_TIMEOUT or 90000) then
		ar_log("FAIL the game never gave control back")
		AR_FAILED = TRUE
		if not AR_KEEP_GOING then
			ar_finish()
		end
	elseif cutSceneLevel > 0 then
		ar_log("control: a conversation is waiting for a choice (cutscene level " .. tostring(cutSceneLevel) .. ")")
	end
end

-- A movie is skipped where the game asks for the key: RunFullscreenMovie's loop reads get_generic_control_state("OVERRIDE") on every
-- turn, which reads GetControlState of the Escape keys (wrapped by ar_lib for the held keys). While a movie plays, Escape reads as
-- held there, as a player holds it. This works inside the movie's own loop, so also for a movie that a set's enter plays during
-- switch_to_set, which pauses every other script (the skipper too: Melee dock's movie played its whole length on the original).
-- AR_NO_SKIP or AR_REAL: the movies play.
if not AR_GCS_MOVIE then
	AR_GCS_MOVIE = GetControlState
	GetControlState = function(k, a, b)
		if not AR_NO_SKIP and not AR_REAL and control_map and control_map.OVERRIDE and control_map.OVERRIDE[k] and IsMoviePlaying() then
			return 1
		end
		return AR_GCS_MOVIE(k, a, b)
	end
end

-- Copy of the Grim ar_skipper, skipping a cutscene after one 100 ms look instead of six (AR_SKIP_AFTER)
if AR_SKIP_TASK then
	stop_script(AR_SKIP_TASK)
end
-- The overrides of a door's walk and of a walk up to a door only clean up after themselves and stop the script that goes on to switch
-- the set: skipping those leaves Guybrush standing in the old room. They are left to run (a few seconds).
ar_override_is_door = function()
	-- (a door's verb is being done: its walk to the door is left to run whatever the override says; Escape would stop the walk short of the door)
	-- (only in the room the door is in: a cutscene in the room beyond it is skipped as ever)
	if AR_IN_DOOR and system.currentSet == AR_DOOR_SET then
		return TRUE
	end
	local f = system.override.override_func
	return f == Object.skip_door or f == Object.skip_door_approach or f == Actor.stop_moving
end

AR_ESC_TRIES = 0
ar_skipper = function()
	local seen = 0
	while TRUE do
		-- a movie: the game's own loop (RunFullscreenMovie) ends it when the OVERRIDE control reads as held, so Escape is held down the
		-- way a player holds it, and let go when the movie is over. A movie that does not end is tried again as a player does: the key
		-- let go and pressed again.
		if IsMoviePlaying() and not AR_NO_SKIP and not AR_REAL then
			AR_MOVIE_LOOKS = (AR_MOVIE_LOOKS or 0) + 1
			if AR_MOVIE_LOOKS == 1 then
				ar_log("skipping a movie")
				ar_key_down("OVERRIDE")
			elseif mod(AR_MOVIE_LOOKS, 4) == 0 then
				ar_key_up("OVERRIDE")
				ar_key_down("OVERRIDE")
			end
		else
			if AR_MOVIE_LOOKS and AR_MOVIE_LOOKS > 0 then
				ar_key_up("OVERRIDE")
			end
			AR_MOVIE_LOOKS = 0
		end
		if system.override and system.override.is_active and not AR_NO_SKIP and not AR_REAL and not ar_override_is_door() then
			seen = seen + 1
			if seen > (AR_SKIP_AFTER or 1) then
				ar_log("skipping a cutscene (Escape try " .. tostring(AR_ESC_TRIES or 0) .. ")")
				-- the player's way: the Escape key (control OVERRIDE) through the button handler, with its key up; an override that is
				-- still active is pressed again at the next look
				AR_ESC_TRIES = AR_ESC_TRIES + 1
				-- (held down for a few frames, as a player's key press lasts: the game can start a movie inside the key's own
				-- handler (ch01's intro_a after the opening cutscene), where its loop cannot yield and only ends when it reads
				-- Escape as held; with a press and release in one instant it spun there: the original froze, ScummVM went on)
				ar_key_down("OVERRIDE")
				sleep_for(100)
				ar_key_up("OVERRIDE")
				seen = 0
			end
		else
			seen = 0
			AR_ESC_TRIES = 0
		end
		-- "press any key" (the termite circus, some credits): a player presses one
		if system.press_any_key and system.buttonHandler == system.anykeyButtonHandler then
			ar_log("pressing a key for press_any_key")
			ar_press_key(ar_real_key("USE"))
		end
		-- TrackGuybrush (the hotlist, the doors' Doorman) is the loop of the game; if it is not running the player's game has no hotlist
		-- either: that is logged, not repaired
		if cutSceneLevel == 0 and not find_script(TrackGuybrush) and system.currentSet and ar_set_name() ~= "cdt" and ar_set_name() ~= "Monkey Island Act cards" then
			AR_TG_DEAD = (AR_TG_DEAD or 0) + 1
			if AR_TG_DEAD == 4 then
				ar_log("TrackGuybrush is not running in " .. ar_set_name())
			end
		else
			AR_TG_DEAD = 0
		end
		-- a line that never ends (a voice that does not finish) is skipped like a player does, with the
		-- key that expires the text
		-- Every other line is skipped too once it has been up for AR_LINE_MS (1.5 s), as a player who has read it presses the key: with the
		-- speech muted each line stays up for its whole text time, and Guybrush stood through minutes of conversation (the SCUMM Bar's
		-- arm wrestling 230 s, Carla and Otis 316 s). AR_REAL or AR_KEEP_LINES: the lines run their course.
		if IsMessageGoing() then
			AR_MSG_TIME = (AR_MSG_TIME or 0) + 100
			if not AR_REAL and not AR_KEEP_LINES and AR_MSG_TIME > (AR_LINE_MS or 1500) then
				-- (pressed again every AR_LINE_MS while lines are up, the next line of the conversation included)
				ar_press_key(ar_real_key("EXPIRE_TEXT"))
				AR_MSG_TIME = 0
			elseif AR_MSG_TIME > (AR_REAL and 180000 or 15000) then
				ar_log("skipping a line that does not end")
				ar_press_key(ar_real_key("EXPIRE_TEXT"))
				AR_MSG_TIME = 0
			end
		else
			AR_MSG_TIME = 0
		end
		-- Manny's idle animation (scratching, smoking) runs until the player touches a key
		if manny.is_idling and AR_DIRECT_WALK then
			manny.stop_idle = TRUE
		end
		-- Manny runs, as a player holding the run key does. Every walk to an object turns
		-- running off again, so it is switched on whenever he is walking.
		if AR_DIRECT_WALK and not AR_WALK and not AR_NEAR_SLOW and not manny.is_running and not manny.is_backward and manny:is_moving() then
			manny:set_run(TRUE)
		end
		AR_NOW = (AR_NOW or 0) + 100
		sleep_for(100)
	end
end
AR_SKIP_TASK = start_script(ar_skipper)

-- Copy of the Grim ar_do: the only change is how the code of "use X with Y" is named (EMI: system_name)
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
	if noun2 then
		code = noun1[gsub(verb .. "_" .. trim_header(noun2.system_name or noun2.string_name), " ", "_")]  -- EMI: system_name, spaces to _
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
	-- EMI: a door's walk out runs inside the Sentence script, not as a script of its own
	while find_script(code) or find_script(Sentence) do
		sleep_for(100)
	end
	ar_wait_for_control()
	wait_for_message()
	return TRUE
end

-- Note: the game starts in TombRaider control (MarioControl is nil), the same turn-and-walk keys as Grim, so the library's ar_steer
-- and ar_face work unchanged (the direction-key control of MarioStyleControl is only used when the player turns it on).

AR_TURN_SIGN = -1
-- The heading toward a floor point in the frame of getrot().y: yaw 0 walks +z, yaw 90 walks +x (measured: yaw 270 walked -x).
-- Monkey4.exe's GetActorYawToPoint gives the TURN from the actor's heading to the point (-180..180), not the heading (measured on the
-- original, Nov 11: at yaw 110, +x gives -20, +z -110); ScummVM gave the heading until its fix of that day. The heading is the yaw plus
-- the turn. (Lua 3.1 here has no atan2)
ar_yaw_turn = function(actor, x, y, z)
	return GetActorYawToPoint(actor.hActor, x, y, z)
end
ar_want_yaw = function(x, z)
	local mn = AR_WALKER or manny
	local p = mn:getpos()
	return mn:getrot().y + ar_yaw_turn(mn, x, p.y, z)
end
-- Walking with the keys, through the game's button handler, as a player does: the forward key held starts the game's own move_actor
-- (it walks while get_generic_control_state("MOVE_FORWARD") is on), the turn keys turn, the run key runs. The keys go to whatever has the
-- keys (SampleButtonHandler on foot, the boat's or the raft's handler), never to a conversation (a table handler: its arrow keys pick
-- lines). AR_DIRECT_WALK: the old way (walk_forward and TurnActor called from the script).
ar_drive_on = function(mn)
	return not AR_DIRECT_WALK and mn == system.currentActor and type(system.buttonHandler) == "function"
end
AR_DRIVE = AR_DRIVE or { }
ar_drive_key = function(name, on)
	if on and not AR_DRIVE[name] then
		AR_DRIVE[name] = TRUE
		ar_key_down(name)
	elseif not on and AR_DRIVE[name] then
		AR_DRIVE[name] = nil
		ar_key_up(name)
	end
end
-- turn: "TURN_LEFT", "TURN_RIGHT" or nil
ar_drive_turn = function(turn)
	ar_drive_key("TURN_LEFT", turn == "TURN_LEFT")
	ar_drive_key("TURN_RIGHT", turn == "TURN_RIGHT")
end
-- a step forward: the forward key held (and the run key, unless a slow walk is wanted)
ar_step = function(mn)
	mn = mn or AR_WALKER or manny
	if ar_drive_on(mn) then
		ar_drive_key("RUN", not AR_WALK and not AR_NEAR_SLOW and not guybrush.no_running)
		ar_drive_key("MOVE_FORWARD", TRUE)
	elseif type(system.buttonHandler) ~= "table" or AR_ALLOW_STEP_UNDER_DIALOG then
		if not AR_DIRECT_WALK and mn == manny then
			AR_DRIVE_SKIPPED = (AR_DRIVE_SKIPPED or 0) + 1
			if AR_DRIVE_SKIPPED == 1 or mod(AR_DRIVE_SKIPPED, 300) == 0 then
				ar_log("walk: the keys do not reach Guybrush here (handler " .. tostring(system.buttonHandler) .. "), stepped by the script")
			end
		end
		mn:walk_forward()
	end
end
-- every key of the walk let go (the end of a walk, a turn on the spot)
ar_drive_stop = function()
	local k = next(AR_DRIVE, nil)
	while k do
		ar_key_up(k)
		k = next(AR_DRIVE, k)
	end
	AR_DRIVE = { }
end

-- Copy of the Grim ar_steer, the sign of the turn made a variable
ar_steer = function(x, y, z, thr)
	local mn = AR_WALKER or manny
	local yaw = mn:getrot().y
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
	local d = ar_want_yaw(x, z) - yaw  -- EMI: see ar_want_yaw
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
		if ar_drive_on(mn) then
			-- (the turn key: TURN_LEFT lowers the yaw. Forward stays held through a small turn, as a player steers while walking)
			if d > 0 then
				ar_drive_turn("TURN_RIGHT")
			else
				ar_drive_turn("TURN_LEFT")
			end
			-- (near the point, any turn is made standing: walking on while turning circles round it, as on the original, 22 s
			-- round a way point of Lucre town and out by the Hall o' Justice door)
			local pp = mn:getpos()
			if abs(d) > 30 or (pp.x - x) * (pp.x - x) + (pp.z - z) * (pp.z - z) < 2.5 * 2.5 then
				ar_drive_key("MOVE_FORWARD", nil)
			end
		-- EMI: TurnActor(+1) lowers the yaw (AR_TURN_SIGN = -1); in Grim it raises it (nil / 1)
		elseif (d > 0) == ((AR_TURN_SIGN or 1) > 0) then
			TurnActor(mn.hActor, 1)
		else
			TurnActor(mn.hActor, -1)
		end
		AR_STEER_TURNED = TRUE
		return TRUE
	end
	ar_drive_turn(nil)
	AR_STEER_TURNED = nil
	return nil
end

-- Same as the Grim ar_face, but the object's point is its real 3D position: in EMI y is up and the floor is x/z (Grim's obj_x/obj_y
-- are the floor plane)
ar_face = function(obj)
	local o = ar_obj_pos(obj)
	if not o.x then
		return ar_fail("no position for " .. tostring(obj.name))
	end
	local t = 0
	ar_drive_key("MOVE_FORWARD", nil)
	while ar_steer(o.x, o.y, o.z, 3) and t < 8000 do
		break_here()
		t = t + system.frameTime
	end
	ar_drive_stop()
	if t >= 8000 then
		return ar_fail("the turn toward " .. tostring(obj.name) .. " did not end in 8 seconds")
	end
end

-- Survey of the current set for planning a route: every object of the set with its place, range, whether it can be touched,
-- the verbs it has of its own and the doors (walkOut). EMI-only tool.
ar_survey = function()
	local s = system.currentSet
	local p = manny:getpos()
	ar_log(format("SURVEY set %s guybrush (%.2f %.2f %.2f) yaw %.0f setup %s", ar_set_name(), p.x, p.y, p.z, manny:getrot().y, tostring(s:current_setup())))
	local k, v = next(s, nil)
	while k do
		if type(v) == "table" and v.interest_actor and v.name then
			local o = v.interest_actor:getpos()
			local verbs = ""
			if v.walkOut then verbs = verbs .. " DOOR" end
			if v.use ~= Object.use and v.use then verbs = verbs .. " use" end
			if v.pickUp ~= Object.pickUp and v.pickUp then verbs = verbs .. " pickUp" end
			if v.talkTo then verbs = verbs .. " talkTo" end
			-- (Lua 3.1's format drops the last character of a %s argument: the strings are joined instead)
			ar_log("SURVEY obj " .. tostring(k) .. " = " .. tostring(v.name) .. format(" (%.2f %.2f %.2f) range ", o.x, o.y, o.z) .. tostring(v.range) .. " touch " .. tostring(v.touchable) .. verbs)
		end
		k, v = next(s, k)
	end
	local inv = ar_inventory()
	ar_log("SURVEY inventory: " .. inv)
end

-- EMI walking: the floor is x/z (y is up). Same name and meaning as Grim's ar_walk_to(x, y, z, stop_when, max_ms) with the point in
-- EMI's own axes. The steering is the game's turn key and walk_forward, as for Grim; the planner of ar_nav.lua is for Grim's
-- sectors and is not used.
ar_floor_dist = function(x, z)
	local mn = AR_WALKER or manny
	local p = mn:getpos()
	return sqrt((p.x - x) * (p.x - x) + (p.z - z) * (p.z - z))
end

-- whether a hot box (a door, a cheat box) lies at (x, z) or half way to it from (px, pz)
ar_hot_near = function(px, py, pz, x, z)
	local i1, n1 = GetPointSector(x, py, z, HOT)
	local i2, n2 = GetPointSector((px + x) / 2, py, (pz + z) / 2, HOT)
	return n1 or n2
end

ar_walk_direct = function(x, y, z, stop_when, max_ms)
	local mn = AR_WALKER or manny
	local budget = max_ms or AR_WALK_MAX or (8000 + 1000 * ar_floor_dist(x, z))
	local waited = 0
	local stuck = 0
	local chk = 0
	local avoid_n = 0
	local avoid_x = 0
	local avoid_z = 0
	local side = 1
	local chk_d = ar_floor_dist(x, z)
	local last = mn:getpos()
	local startset = system.currentSet
	if not (stop_when and stop_when()) then
		ar_wait_for_control()
	end
	if not ar_drive_on(mn) then
		mn:set_run(TRUE)
	end
	-- (the keys walk under the handler the walk began with: when the game puts in another one (the rock field of Knuttin town, whose
	-- arrow keys hop from rock to rock), the walk is over, and the keys are let go)
	local h0 = system.buttonHandler
	while system.currentSet == startset and (system.buttonHandler == h0 or not ar_drive_on(mn)) and ar_floor_dist(x, z) > (AR_WALK_TOL or 0.3) and waited < budget and not (stop_when and stop_when()) and stuck < 120 do
		if cutSceneLevel > 0 and not (stop_when and stop_when()) then
			ar_wait_for_control()
		end
		-- Something in the way that does not give (another actor stands there: he does not move out of the way, and Guybrush
		-- does not get past): no nearer to the point for a second and a half, he steps to the side first, as a player does
		chk = chk + 1
		if chk >= 90 and avoid_n == 0 then
			chk = 0
			local dnow = ar_floor_dist(x, z)
			local px = mn:getpos()
			-- (no nearer to the point in the last second and a half, though he walks)
			if chk_d - dnow < 0.25 and dnow > 1.5 then
				local ddx = (x - px.x) / (dnow + 0.001)
				local ddz = (z - px.z) / (dnow + 0.001)
				side = -side
				avoid_x = px.x - ddz * side * 2.5
				avoid_z = px.z + ddx * side * 2.5
				-- (not into a hot box, a door or a cheat box, at the side point or half way: the other side, or no step at all)
				if ar_hot_near(px.x, px.y, px.z, avoid_x, avoid_z) then
					side = -side
					avoid_x = px.x - ddz * side * 2.5
					avoid_z = px.z + ddx * side * 2.5
					if ar_hot_near(px.x, px.y, px.z, avoid_x, avoid_z) then
						avoid_x = nil
					end
				end
				-- (Jambalaya town: the tourist stands about in the square and does not move aside. Not on the island maps: there the walk is no walk, Guybrush is a marker that goes where the verb sends it)
				-- (everywhere but the maps: Lucre town's walkers pinned him on the original, Nov 11)
				if avoid_x and not AR_NO_AVOID and not strfind(strlower(ar_set_name()), "map", 1, TRUE) then
					avoid_n = 75
					ar_log(format("walk: blocked at %.2f %.2f, stepping aside to %.2f %.2f", px.x, px.z, avoid_x, avoid_z))
				end
			end
			chk_d = dnow
		end
		local aim_x = x
		local aim_z = z
		if avoid_n > 0 then
			avoid_n = avoid_n - 1
			aim_x = avoid_x
			aim_z = avoid_z
			if ar_floor_dist(avoid_x, avoid_z) < 0.4 then
				avoid_n = 0
			end
		end
		local turning = ar_steer(aim_x, last.y, aim_z, 8)
		if not turning then
			ar_step(mn)
		end
		if AR_WALK_TRACE and mod(chk, 10) == 0 then
			local tp = mn:getpos()
			local hk = ""
			local hkk = next(AR_DRIVE, nil)
			while hkk do
				hk = hk .. hkk .. " "
				hkk = next(AR_DRIVE, hkk)
			end
			ar_log(format("WT %.2f %.2f yaw %.1f d %.1f turning %s keys ", tp.x, tp.z, mn:getrot().y, AR_STEER_D or 0, tostring(turning)) .. hk .. format("aim %.2f %.2f", aim_x, aim_z) .. " h " .. tostring(system.buttonHandler) .. " loc " .. tostring(kab and kab.current_loc and kab.current_loc.x) .. " cs " .. cutSceneLevel)
		end
		break_here()
		waited = waited + system.frameTime
		-- (the set can change in the frame: the actor of the old one is gone then)
		if system.currentSet == startset then
			local p = mn:getpos()
			if abs(p.x - last.x) + abs(p.z - last.z) < 0.0005 and not turning then
				stuck = stuck + 1
			else
				stuck = 0
			end
			last = p
		end
	end
	AR_STEER_TURNED = nil
	ar_drive_stop()
	if system.buttonHandler ~= h0 and type(system.buttonHandler) == "function" and not AR_DIRECT_WALK then
		ar_log("walk: the game took the keys over (another button handler), the walk ends here")
		return TRUE
	end
	if system.currentSet == startset and ar_floor_dist(x, z) > (AR_WALK_TOL or 0.3) and not (stop_when and stop_when()) then
		local p = mn:getpos()
		ar_log(format("walk stopped at %.2f %.2f after %d ms (stuck %d) toward %.2f %.2f", p.x, p.z, waited, stuck, x, z))
		return nil
	end
	return TRUE
end

-- EMI map of the walkable floor (x across, z down the page, 'M' Guybrush, '.' not walkable): for planning routes by eye
ar_map = function(x0, x1, z0, z1, step)
	local p = manny:getpos()
	local z = z1
	ar_log(format("MAP set %s y=%.2f x %.0f..%.0f step %.1f", ar_set_name(), p.y, x0, x1, step))
	while z >= z0 do
		local row = ""
		local x = x0
		while x <= x1 do
			local c = "."
			local id = GetPointSector(x, p.y, z)
			if id then
				c = strsub("abcdefghijklmnopqrstuvwxyz0123456789", mod(id, 36) + 1, mod(id, 36) + 1)
			end
			if abs(x - p.x) < step / 2 and abs(z - p.z) < step / 2 then
				c = "M"
			end
			row = row .. c
			x = x + step
		end
		ar_log(format("MAP %6.1f ", z) .. row)
		z = z - step
	end
end

-- EMI route planning on the walk sectors: a grid breadth-first search where a cell is walkable when GetPointSector finds a
-- sector there (tried at a few heights: ramps and steps lie above y=0), then the corners cut by straight lines that stay on walkable
-- cells. Returns a list of { x, z } or nil. (Grim's ar_nav.lua reads the set files; this asks the engine.)
AR_GRID = 0.5
AR_YOFF = { 0, 0.2, -0.2, 0.4, -0.4, 0.1, -0.1, 0.6, -0.6, 1, -1 }
-- (slopes and stairs of Act 2: a sloped sector is found only within a hand's breadth of its plane, and a diagonal strip of it between the
-- cells of the grid; the finer heights find it. Off in Act 1, where the coarse ones have been enough)
AR_YOFF_FINE = { 0.05, -0.05, 0.15, -0.15, 0.25, -0.25, 0.3, -0.3, 0.35, -0.35, 0.5, -0.5 }
AR_FINE_Y = nil
-- the height at which a cell is floor, found near y (the floor of a stair or a slope is at another height than its neighbour's), or nil
ar_cell_y = function(x, z, y)
	-- memoized per set and quarter-unit cell and height band (a walk asks about the same cells again and again)
	local set = ar_set_name() .. tostring(AR_CELL_RES or 4)
	if AR_CELL_SET ~= set then
		AR_CELL_SET = set
		AR_CELLC = { }
	end
	local res = AR_CELL_RES or 4
	local key = (floor(x * res + 0.5) + 2000) * 100000 + (floor(z * res + 0.5) + 2000) * 40 + floor(y * 2 + 0.5) + 20
	local c = AR_CELLC[key]
	if c then
		if c == -999 then
			return nil
		end
		if c >= 1000 then
			return c - 2000, TRUE
		end
		return c
	end
	-- The floors under the place, whatever their height (an engine function of the port: GetPointSector answers only for a point on the
	-- plane of a sector, so a step, a ramp or a ribbon of floor is found by chance only): the one a step from where Guybrush is
	if GetFloorHeights then
		-- (a place a hand inside the sector: a line along an edge of the floor is not a way, the walk comes off it)
		local fh = GetFloorHeights(x, z, AR_FLOOR_MARGIN or 0.12)
		local fi = 1
		local fb = nil
		local fd = 0.7
		while fh[fi] do
			local d = abs(fh[fi] - y)
			if d <= fd then
				fd = d
				fb = fh[fi]
			end
			fi = fi + 1
		end
		if fb then
			AR_CELLC[key] = fb
			return fb
		end
	end
	local i = 1
	while AR_YOFF[i] do
		if GetPointSector(x, y + AR_YOFF[i], z) then
			AR_CELLC[key] = y + AR_YOFF[i]
			return y + AR_YOFF[i]
		end
		i = i + 1
	end
	if AR_FINE_Y then
		i = 1
		while AR_YOFF_FINE[i] do
			if GetPointSector(x, y + AR_YOFF_FINE[i], z) then
				AR_CELLC[key] = y + AR_YOFF_FINE[i]
				return y + AR_YOFF_FINE[i]
			end
			i = i + 1
		end
	end
	-- the cheat boxes of a set (HOT sectors named ...cheatbox, the way up a stair or onto a ledge) are walked into on purpose: the game
	-- moves Guybrush to the other level; the walk is planned again from there
	local id, name = GetPointSector(x, y, z, HOT)
	if id and name and strfind(name, "cheat", 1, TRUE) and not AR_NO_CHEAT then
		AR_CELLC[key] = y + 2000
		return y, TRUE
	end
	AR_CELLC[key] = -999
	return nil
end

-- The strips of the doors (HOT sectors named ...door: the entries of the places on a map) are not floor to cross while AR_AVOID_HOT is set
-- (a boat on a map that touches the strip of a place goes there); AR_HOT_OK names the one strip that is the goal. Other triggers (the
-- cannons of Casaba's ship) are crossed.
AR_CELL_BASE = ar_cell_y
ar_cell_y = function(x, z, y)
	local r, c = AR_CELL_BASE(x, z, y)
	if r and not c and AR_AVOID_HOT then
		local id, name = GetPointSector(x, r, z, HOT)
		if id and name and name ~= AR_HOT_OK and name ~= AR_HOT_START and strfind(name, "door", 1, TRUE) then
			return nil
		end
	end
	return r, c
end

ar_line_ok = function(x1, z1, x2, z2, y1, y2)
	local d = sqrt((x2 - x1) * (x2 - x1) + (z2 - z1) * (z2 - z1))
	local n = floor(d / 0.05) + 1  -- (every 5 cm: a gap of the floor 8 cm wide in front of Lucre town's west stair, Nov 11)
	local i = 1
	local y = y1
	while i <= n do
		local cheat = nil
		y, cheat = ar_cell_y(x1 + (x2 - x1) * i / n, z1 + (z2 - z1) * i / n, y)
		-- (a cheat box moves Guybrush to the other level on contact: a line through one is not a way, only a way's end is)
		if not y or (cheat and i < n) then
			return nil
		end
		i = i + 1
	end
	return TRUE
end

ar_cellkey = function(cx, cz)
	return (cx + 500) * 1000 + (cz + 500)
end

-- (the original kills a script that runs for long without break_here ("Killing Lua script that ran without a break_here() for a
-- really long time"): a search of the planners lets a frame pass every 200 steps, on both engines alike)
ar_plan_yield = function()
	AR_PLAN_N = (AR_PLAN_N or 0) + 1
	if mod(AR_PLAN_N, 200) == 0 then
		break_here()
	end
end

ar_grid_path = function(tx, tz)
	local mn = AR_WALKER or manny
	AR_PATH_CHEAT = nil
	local p = mn:getpos()
	local g = AR_GRID
	local sx = floor(p.x / g + 0.5)
	local sz = floor(p.z / g + 0.5)
	local gx = floor(tx / g + 0.5)
	local gz = floor(tz / g + 0.5)
	local S = { prev = { }, px = { }, pz = { }, py = { }, queue = { } }
	local head = 1
	local tail = 1
	local skey = ar_cellkey(sx, sz)
	S.queue[1] = { sx, sz }
	S.prev[skey] = skey
	S.px[skey] = sx
	S.pz[skey] = sz
	S.py[skey] = p.y
	local found = nil
	local bestd = nil
	local bestkey = nil
	local termd = nil
	local termkey = nil
	local nodes = 0
	-- (the goal may lie just outside the sectors, a door's point: a cell within 1.5 cells of it ends the search)
	while head <= tail and not found and nodes < 40000 do
		ar_plan_yield()
		local c = S.queue[head]
		head = head + 1
		nodes = nodes + 1
		local cx = c[1]
		local cz = c[2]
		local ck = ar_cellkey(cx, cz)
		local dgoal = (cx - gx) * (cx - gx) + (cz - gz) * (cz - gz)
		if not bestd or dgoal < bestd then
			bestd = dgoal
			bestkey = ck
		end
		if abs(cx - gx) <= 1.5 and abs(cz - gz) <= 1.5 then
			found = ck
		else
			local dx = -1
			while dx <= 1 do
				local dz = -1
				while dz <= 1 do
					local nx = cx + dx
					local nz = cz + dz
					local nk = ar_cellkey(nx, nz)
					if (dx ~= 0 or dz ~= 0) and not S.prev[nk] then
						local ny, cheat = ar_cell_y(nx * g, nz * g, S.py[ck])
						if ny then
							-- (a diagonal step must not cut a corner of a wall)
							if dx == 0 or dz == 0 or (ar_cell_y((cx + dx) * g, cz * g, S.py[ck]) and ar_cell_y(cx * g, (cz + dz) * g, S.py[ck])) then
								S.prev[nk] = ck
								S.px[nk] = nx
								S.pz[nk] = nz
								S.py[nk] = ny
								if cheat then
									-- (a cheat box moves Guybrush on contact: stepped into, not walked through, and a way's end if it leads nearer)
									local dterm = (nx - gx) * (nx - gx) + (nz - gz) * (nz - gz)
									if not termd or dterm < termd then
										termd = dterm
										termkey = nk
									end
								else
									tail = tail + 1
									S.queue[tail] = { nx, nz }
								end
							end
						end
					end
					dz = dz + 1
				end
				dx = dx + 1
			end
		end
	end
	-- (the goal on the other level: through a cheat box, the one nearest to it, whatever else is nearer on this level)
	AR_OTHER_LEVEL = AR_GRID_TY and abs(AR_GRID_TY - p.y) > 2
	if not found and termkey and (AR_OTHER_LEVEL or not bestd or termd < bestd) and head > tail then
		found = termkey
		AR_PATH_CHEAT = TRUE
		ar_log("grid path: through a cheat box toward " .. format("%.1f %.1f", tx, tz))
	end
	if not found and bestkey and head > tail then
		found = bestkey
		ar_log(format("grid path: goal %.1f %.1f is off the reachable floor, going to the nearest cell (%.1f cells away)", tx, tz, sqrt(bestd) * g))
		AR_GRID_OFF = sqrt(bestd) * g
	end
	if not found then
		ar_log(format("grid path: no way from %.1f %.1f to %.1f %.1f (%d cells)", p.x, p.z, tx, tz, nodes))
		return nil
	end
	local rev = { }
	local n = 0
	local k = found
	while k ~= skey do
		n = n + 1
		rev[n] = k
		k = S.prev[k]
	end
	local pts = { }
	local m = 0
	local i = n
	while i >= 1 do
		m = m + 1
		pts[m] = { S.px[rev[i]] * g, S.pz[rev[i]] * g, S.py[rev[i]] }
		i = i - 1
	end
	return ar_smooth_path(pts, m, p)
end

-- The cells of a way shortened to the legs that the floor allows in a straight line (up to 25 cells ahead of each leg's start)
ar_smooth_path = function(pts, m, p)
	local out = { }
	local o = 0
	local ax = p.x
	local az = p.z
	local ay = p.y
	local j = 1
	while j <= m do
		local far = j
		local t = j
		while t <= m and t <= j + 25 do
			if ar_line_ok(ax, az, pts[t][1], pts[t][2], ay, pts[t][3]) then
				far = t
			end
			t = t + 1
		end
		o = o + 1
		out[o] = pts[far]
		ax = pts[far][1]
		az = pts[far][2]
		ay = pts[far][3]
		j = far + 1
	end
	return out, o
end

-- Sets too large for the breadth-first search of ar_grid_path (Ozzie's tower is hundreds of units wide): A* on a coarse grid
-- (AR_BIG_SET = TRUE; cells of AR_GRID_BIG, 1.5 units by default), looking at the floor only where the search goes
ar_heap_push = function(H, f, key)
	local n = H.n + 1
	H.n = n
	H.f[n] = f
	H.k[n] = key
	while n > 1 do
		local par = floor(n / 2)
		if H.f[par] <= H.f[n] then
			n = 1
		else
			local tf = H.f[par]
			local tk = H.k[par]
			H.f[par] = H.f[n]
			H.k[par] = H.k[n]
			H.f[n] = tf
			H.k[n] = tk
			n = par
		end
	end
end

ar_heap_pop = function(H)
	local key = H.k[1]
	local n = H.n
	H.f[1] = H.f[n]
	H.k[1] = H.k[n]
	H.n = n - 1
	n = H.n
	local i = 1
	while i * 2 <= n do
		local c = i * 2
		if c < n and H.f[c + 1] < H.f[c] then
			c = c + 1
		end
		if H.f[i] <= H.f[c] then
			i = n + 1
		else
			local tf = H.f[c]
			local tk = H.k[c]
			H.f[c] = H.f[i]
			H.k[c] = H.k[i]
			H.f[i] = tf
			H.k[i] = tk
			i = c
		end
	end
	return key
end

ar_grid_path_big = function(tx, tz)
	local mn = AR_WALKER or manny
	AR_PATH_CHEAT = nil
	AR_BIG_OFF = nil
	local p = mn:getpos()
	local g = AR_GRID_BIG or 1.5
	local sx = floor(p.x / g + 0.5)
	local sz = floor(p.z / g + 0.5)
	local gx = floor(tx / g + 0.5)
	local gz = floor(tz / g + 0.5)
	local S = { prev = { }, px = { }, pz = { }, py = { }, gc = { }, closed = { } }
	local H = { n = 0, f = { }, k = { } }
	-- (standing a hair off the floor, as a walk that jumped a gap leaves him: the search starts from the nearest cell of floor)
	local sy = p.y
	if not ar_cell_y(sx * g, sz * g, p.y) then
		local ring = 1
		local fx, fz, fyv = nil, nil, nil
		while ring <= 5 and not fx do
			local ix = -ring
			while ix <= ring and not fx do
				local iz = -ring
				while iz <= ring and not fx do
					if abs(ix) == ring or abs(iz) == ring then
						local yy = ar_cell_y((sx + ix) * g, (sz + iz) * g, p.y)
						if yy then
							fx = sx + ix
							fz = sz + iz
							fyv = yy
						end
					end
					iz = iz + 1
				end
				ix = ix + 1
			end
			ring = ring + 1
		end
		if fx then
			sx = fx
			sz = fz
			sy = fyv
		end
	end
	local skey = ar_cellkey(sx, sz)
	S.prev[skey] = skey
	S.px[skey] = sx
	S.pz[skey] = sz
	S.py[skey] = sy
	S.gc[skey] = 0
	ar_heap_push(H, sqrt((sx - gx) * (sx - gx) + (sz - gz) * (sz - gz)), skey)
	local found = nil
	local bestd = nil
	local bestkey = nil
	local nodes = 0
	while H.n > 0 and not found and nodes < 60000 do
		ar_plan_yield()
		local ck = ar_heap_pop(H)
		if not S.closed[ck] then
			S.closed[ck] = TRUE
			nodes = nodes + 1
			local cx = S.px[ck]
			local cz = S.pz[ck]
			local dgoal = (cx - gx) * (cx - gx) + (cz - gz) * (cz - gz)
			if not bestd or dgoal < bestd then
				bestd = dgoal
				bestkey = ck
			end
			if abs(cx - gx) <= 1.5 and abs(cz - gz) <= 1.5 then
				found = ck
			else
				local dx = -1
				while dx <= 1 do
					local dz = -1
					while dz <= 1 do
						local nx = cx + dx
						local nz = cz + dz
						local nk = ar_cellkey(nx, nz)
						if (dx ~= 0 or dz ~= 0) and not S.closed[nk] then
							local step = 1
							if dx ~= 0 and dz ~= 0 then
								step = 1.4142
							end
							local ngc = S.gc[ck] + step
							if not S.gc[nk] or ngc < S.gc[nk] then
								local ny = ar_cell_y(nx * g, nz * g, S.py[ck])
								-- (a diagonal step must not cut a corner of a wall)
								if ny and (dx == 0 or dz == 0 or (ar_cell_y((cx + dx) * g, cz * g, S.py[ck]) and ar_cell_y(cx * g, (cz + dz) * g, S.py[ck]))) then
									S.prev[nk] = ck
									S.px[nk] = nx
									S.pz[nk] = nz
									S.py[nk] = ny
									S.gc[nk] = ngc
									ar_heap_push(H, ngc + sqrt((nx - gx) * (nx - gx) + (nz - gz) * (nz - gz)), nk)
								end
							end
						end
						dz = dz + 1
					end
					dx = dx + 1
				end
			end
		end
	end
	if not found and bestkey and H.n == 0 then
		found = bestkey
		AR_BIG_OFF = sqrt(bestd) * g
		ar_log(format("grid path: goal %.1f %.1f is off the reachable floor, going to the nearest cell (%.1f units away)", tx, tz, sqrt(bestd) * g))
	end
	if not found then
		ar_log(format("grid path: no way from %.1f %.1f to %.1f %.1f (%d cells)", p.x, p.z, tx, tz, nodes))
		return nil
	end
	local rev = { }
	local n = 0
	local k = found
	while k ~= skey do
		n = n + 1
		rev[n] = k
		k = S.prev[k]
	end
	local pts = { }
	local m = 0
	local i = n
	while i >= 1 do
		m = m + 1
		pts[m] = { S.px[rev[i]] * g, S.pz[rev[i]] * g, S.py[rev[i]] }
		i = i - 1
	end
	return ar_smooth_path(pts, m, p)
end

-- (AR_WALKER names another actor to walk and steer than manny: the rowboat on a map)
-- The walk of the EMI layer: the planned way (ar_grid_path) when the straight line leaves the sectors, then the last leg direct.
-- whether a floor point is inside one of the set's cheat boxes (hot boxes that move the walker across: system.currentSet.cheat_boxes)
ar_in_cheatbox = function(x, y, z)
	local cb = system.currentSet and system.currentSet.cheat_boxes
	if not cb then
		return nil
	end
	local id, name = GetPointSector(x, y, z, HOT)
	return name and cb[name]
end

ar_walk_planned = function(x, y, z, stop_when, max_ms)
	local mn = AR_WALKER or manny
	-- A map: the roads Guybrush's marker walks on are strips half a unit wide, which the grid of a room would step over
	if strfind(strlower(ar_set_name()), "map", 1, TRUE) and not AR_ON_MAP then
		AR_ON_MAP = TRUE
		-- (the strips of the other places are not walked over: the walk would go to that place; the goal's own strip is the way's end)
		local hid, hname = GetPointSector(x, y, z, HOT)
		AR_HOT_OK = hname
		-- (and the strip Guybrush stands in, where he came out of its door: the walk leaves it)
		local mp = mn:getpos()
		local sid, sname = GetPointSector(mp.x, mp.y, mp.z, HOT)
		-- (he can stand a hand's breadth outside the strip he came out of: the strip nearby is his start's)
		local so = 0.15
		while not sname and so <= 0.45 do
			local sxs = { so, -so, 0, 0, so, so, -so, -so }
			local szs = { 0, 0, so, -so, so, -so, so, -so }
			local si = 1
			while si <= 8 and not sname do
				local s2, n2 = GetPointSector(mp.x + sxs[si], mp.y, mp.z + szs[si], HOT)
				if s2 and n2 then sname = n2 end
				si = si + 1
			end
			so = so + 0.15
		end
		AR_HOT_START = sname
		AR_AVOID_HOT = TRUE
		AR_CELLC = { }
		AR_BIG_SET = TRUE
		-- (a far goal is planned on a coarser grid: the search would be hundreds of thousands of cells)
		if ar_floor_dist(x, z) > 25 then
			AR_GRID_BIG = 0.5
			AR_CELL_RES = 4
			AR_FLOOR_MARGIN = 0.12
		else
			AR_GRID_BIG = 0.2
			AR_CELL_RES = 10
			AR_FLOOR_MARGIN = 0.03
		end
		local r = ar_walk_planned(x, y, z, stop_when, max_ms)
		AR_AVOID_HOT = nil
		AR_HOT_OK = nil
		AR_HOT_START = nil
		AR_CELLC = { }
		AR_ON_MAP = nil
		AR_BIG_SET = nil
		AR_GRID_BIG = nil
		AR_CELL_RES = nil
		AR_FLOOR_MARGIN = nil
		return r
	end
	local ok = TRUE
	AR_WALK_SET = system.currentSet
	local round = 1
	local again = TRUE
	-- (replanned after a hop: the cheat boxes of a set move Guybrush to another level, which the plan cannot see past)
	while again and round <= 6 and system.currentSet == AR_WALK_SET and not (stop_when and stop_when()) do
		again = nil
		local p = mn:getpos()
		if not AR_NO_GRID and not ar_line_ok(p.x, p.z, x, z, p.y, p.y) then
			AR_GRID_TY = y
			local pts, n
			AR_GRID_OFF = nil
			if AR_BIG_SET then
				pts, n = ar_grid_path_big(x, z)
				-- (a coarse grid does not get through the narrow strips of a map (half a unit wide, the margin leaves no cell): the same
				-- search on the fine grid, when the coarse one stays far from the goal)
				if AR_BIG_OFF and AR_BIG_OFF > 3 and AR_GRID_BIG and AR_GRID_BIG > 0.2 and not AR_FINE_RETRY then
					local coff = AR_BIG_OFF
					local ocell, ores, omargin, ogrid = AR_CELL_RES, AR_CELL_RES, AR_FLOOR_MARGIN, AR_GRID_BIG
					AR_FINE_RETRY = TRUE
					AR_GRID_BIG = 0.2
					AR_CELL_RES = 10
					AR_FLOOR_MARGIN = 0.03
					local sp = mn:getpos()
					ar_log("grid path: again on a fine grid (the coarse one stayed " .. format("%.1f", coff) .. " away) from " .. format("%.2f %.2f %.2f", sp.x, sp.y, sp.z))
					local fpts, fn = ar_grid_path_big(x, z)
					-- (where Guybrush came out of a door he can stand on the very edge of the strip: no cell has a margin around it)
					if fpts and AR_BIG_OFF and AR_BIG_OFF > 3 then
						AR_FLOOR_MARGIN = 0
						AR_CELLC = { }
						ar_log("grid path: and again without a margin")
						fpts, fn = ar_grid_path_big(x, z)
					end
					if fpts and (not AR_BIG_OFF or AR_BIG_OFF < coff) then
						pts = fpts
						n = fn
					else
						AR_BIG_OFF = coff
					end
					AR_FINE_RETRY = nil
					AR_CELLC = { }
					AR_CELL_RES = ores
					AR_FLOOR_MARGIN = omargin
					AR_GRID_BIG = ogrid
				end
			else
				pts, n = ar_grid_path(x, z)
				-- (a goal far from the floor the coarse grid reaches: floors of narrow strips, ramps and steps a grid of half a unit steps over:
				-- the same search on a fine grid)
				if AR_GRID_OFF and AR_GRID_OFF > 3 and not AR_FINE_RETRY then
					AR_FINE_RETRY = TRUE
					AR_BIG_SET = TRUE
					AR_GRID_BIG = 0.2
					AR_CELL_RES = 10
					AR_FLOOR_MARGIN = 0.03
					ar_log("grid path: again on a fine grid")
					local fpts, fn = ar_grid_path_big(x, z)
					AR_BIG_SET = nil
					AR_GRID_BIG = nil
					AR_CELL_RES = nil
					AR_FLOOR_MARGIN = nil
					AR_FINE_RETRY = nil
					if fpts then
						pts = fpts
						n = fn
					end
				end
			end
			if pts then
				local i = 1
				ar_log("walk: planned way of " .. tostring(n) .. " legs (round " .. tostring(round) .. ")")
				while i <= n and ok and system.currentSet == AR_WALK_SET and not (stop_when and stop_when()) and not again do
					-- (a way point inside a cheat box of the set (the game moves Guybrush across the box as he walks into it,
					-- GetSectorOppositeEdge) is not walked to: the walk goes on to the next one, through the box, and the box carries
					-- him; walking back to it, he was carried back and forth for ever (Lucre town's bait_hall_cheatbox))
					while i < n and ar_in_cheatbox(pts[i][1], pts[i][3], pts[i][2]) do
						i = i + 1
					end
					-- (a leg ends within 15 cm: the way runs along edges of the floor, a corner passed wide is a wall)
					AR_WALK_TOL = 0.15
					local before = mn:getpos().y
					local d_before = ar_floor_dist(pts[i][1], pts[i][2])
					A3R_CARRIED = nil
					ok = ar_walk_direct(pts[i][1], pts[i][3], pts[i][2], stop_when, max_ms)
					AR_WALK_TOL = nil
					-- (or carried off on the same level: 3 units further from the leg's end than before it, a trigger took him elsewhere)
					if A3R_CARRIED or (system.currentSet == AR_WALK_SET and ar_floor_dist(pts[i][1], pts[i][2]) > d_before + 3) then
						A3R_CARRIED = nil
						ar_log("walk: carried off the way, planned again from here")
						again = TRUE
						ok = TRUE
					elseif abs(mn:getpos().y - before) > 0.8 then
						-- hopped to another level: plan again from here
						again = TRUE
						ok = TRUE
					end
					i = i + 1
				end
				-- (the last leg went into a cheat box, whose hop came a moment later; a box is entered by walking on into it, the forward key
				-- held, as a player runs down a stair)
				if not again and i > n and AR_PATH_CHEAT then
					local t = 0
					local lx = pts[n][1]
					local lz = pts[n][3]
					while abs(mn:getpos().y - p.y) < 0.8 and t < 3500 and system.currentSet == AR_WALK_SET do
						if not ar_steer(lx, p.y, lz, 8) then
							ar_step(mn)
						end
						break_here()
						t = t + system.frameTime
					end
					ar_drive_stop()
					ok = TRUE
				end
				if not again and ok and i > n then
					sleep_for(300)
					if abs(mn:getpos().y - p.y) > 0.8 then
						again = TRUE
					end
				end
			end
		end
		round = round + 1
	end
	if not (stop_when and stop_when()) and system.currentSet == AR_WALK_SET then
		return ar_walk_direct(x, y, z, stop_when, max_ms)
	end
	return ok
end

-- Every movie of the game is played by RunFullscreenMovie (_cut_scenes.lua): it starts the movie and loops with break_here while it
-- plays, ending it (EscapeMovie) when the OVERRIDE control is held. The skipper holds Escape when a movie plays, as a player does, so
-- the movies start and are skipped (Nov 10: it was thought the scripts did not run during a movie in a simulated run, and the movies
-- were not started at all). AR_NO_MOVIES: the old way, not started; the flag the game reads for "this movie was seen" and the music
-- state are set as the original function does.
if not AR_OLD_RFM then
	AR_OLD_RFM = RunFullscreenMovie
	RunFullscreenMovie = function(name, mode)
		if AR_REAL or not AR_NO_MOVIES then
			ar_log("movie started: " .. tostring(name))
			local r = AR_OLD_RFM(name, mode)
			ar_log("movie over: " .. tostring(name))
			return r
		end
		ar_log("movie skipped, not started: " .. tostring(name))
		music_state:set_state(STATE_NULL, TRUE)
		glob["_cs_" .. strlower(name)] = TRUE
		return TRUE
	end
end

-- Walking to a place: with the keys only (the held walk keys and the turns), along the way planned on the floor (a player cannot send
-- Guybrush to a point; the game's own walk to a point belongs to the verbs, which walk up to their objects by themselves)
ar_walk_to = function(x, y, z, stop_when, max_ms)
	if not AR_NO_HOPS then
		ar_level_hop(y)
	end
	ar_wait_for_control()
	return ar_walk_planned(x, y, z, stop_when, max_ms)
end

-- So it is cleared as soon as the verb is done.
AR_DO_EMI = ar_do
ar_not_switching = function()
	return not set_switching and (cutSceneLevel == 0 or (AR_DLG_CONTROL and ar_dialog_waiting())) and system.currentSet and find_script(TrackGuybrush)
end

-- The new set is entered when the sets, the cutscene and TrackGuybrush are all ready (the objects of a set only get their actors then)
ar_settled = function()
	AR_DLG_CONTROL = TRUE
	ar_try_wait(ar_not_switching, 15000)
	sleep_for(300)
	ar_wait_for_control()
	AR_DLG_CONTROL = nil
end

-- (AR_DOOR_STAYS: a door that leads to another place of the same set, Knuttin's rock field: says when it has been gone through)
ar_door_left = function()
	return system.currentSet ~= AR_DOOR_SET or (AR_DOOR_STAYS and AR_DOOR_STAYS())
end

ar_do = function(verb, noun1, noun2)
	AR_DOOR_SET = system.currentSet
	if verb == "use" and noun1.walkOut then
		AR_IN_DOOR = TRUE
		AR_DLG_CONTROL = TRUE
	end
	local r = AR_DO_EMI(verb, noun1, noun2)
	AR_IN_DOOR = nil
	-- a door: the walk through it, the door's animation and the new set take a while after the verb's script is done
	if r and verb == "use" and noun1.walkOut and system.currentSet == AR_DOOR_SET then
		ar_try_wait(ar_door_left, 20000)
		ar_settled()
	end
	AR_DLG_CONTROL = nil
	return r
end

-- Where to stand for an object to be offered: the game offers an object within its range of Guybrush (a 3D distance from the
-- object's actor), so a point of the floor near the object that is inside the range, the nearest to Guybrush first. The floor height is
-- found by asking the sectors at heights from -1 to 5.
-- where an object is: its actor's position (what the survey prints)
ar_obj_pos = function(obj)
	if obj.interest_actor then
		local p = obj.interest_actor:getpos()
		if p and p.x then
			return p
		end
	end
	if obj.obj_x then
		return { x = obj.obj_x, y = obj.obj_y, z = obj.obj_z }
	end
	if obj.use_pnt_x then
		return { x = obj.use_pnt_x, y = obj.use_pnt_y, z = obj.use_pnt_z }
	end
	return { }
end

-- The heights of the floors of the current set: the sectors of some sets are exact planes (tolerance a centimetre), so a scan in steps
-- misses them. The designers put the use points and out points of the objects on the floor, so those heights (and Guybrush's) are
-- the levels. Cached per set; ar_level_note(y) adds one.
ar_levels = function()
	local set = ar_set_name()
	if AR_LEVELS_SET ~= set then
		AR_LEVELS_SET = set
		AR_LEVELS = { }
		AR_LEVELS_N = 0
		local s = system.currentSet
		local k, v = next(s, nil)
		while k do
			if type(v) == "table" and v.interest_actor then
				if v.use_pnt_y then ar_level_note(v.use_pnt_y) end
				if v.out_pnt_y then ar_level_note(v.out_pnt_y) end
			end
			k, v = next(s, k)
		end
	end
	ar_level_note(manny:getpos().y)
	return AR_LEVELS, AR_LEVELS_N
end

ar_level_note = function(y)
	if not AR_LEVELS then
		return
	end
	local i = 1
	while i <= AR_LEVELS_N do
		if abs(AR_LEVELS[i] - y) < 0.02 then
			return
		end
		i = i + 1
	end
	AR_LEVELS_N = AR_LEVELS_N + 1
	AR_LEVELS[AR_LEVELS_N] = y
end

ar_floor_ys = function(x, z)
	local ys = { }
	local n = 0
	local lv, ln = ar_levels()
	local i = 1
	while i <= ln do
		if GetPointSector(x, lv[i], z) then
			n = n + 1
			ys[n] = lv[i]
		end
		i = i + 1
	end
	-- (and a scan for the sets whose floors are sloped, which the level heights do not name)
	local y = -1
	while y <= 6 do
		if GetPointSector(x, y, z) then
			local known = nil
			local j = 1
			while j <= n do
				if abs(ys[j] - y) < 0.35 then
					known = TRUE
				end
				j = j + 1
			end
			if not known then
				n = n + 1
				ys[n] = y
			end
		end
		y = y + 0.1
	end
	return ys, n
end

-- the candidates, best first: { x, y, z, d } (d the distance from Guybrush)
ar_stand_points = function(obj)
	local o = ar_obj_pos(obj)
	local p = manny:getpos()
	if not o or not o.x or not o.y or not o.z then
		return { }, 0
	end
	local r = (tonumber(obj.range) or 3) - 0.2
	if r < 0.5 then
		r = 0.5
	end
	local best = { }
	local nb = 0
	-- (the grid of points is 0.5 apart, coarser for a huge range: at most 40 points an axis)
	local step = 0.5
	if r / 20 > step then
		step = r / 20
	end
	local dx = -r
	while dx <= r do
		local dz = -r
		while dz <= r do
			local x = o.x + dx
			local z = o.z + dz
			if dx * dx + dz * dz <= r * r then
				local ys, n = ar_floor_ys(x, z)
				local i = 1
				while i <= n do
					local dy = o.y - ys[i]
					if dx * dx + dz * dz + dy * dy <= r * r and abs(ys[i] - p.y) < 2.5 then
						nb = nb + 1
						best[nb] = { x, ys[i], z, sqrt((x - p.x) * (x - p.x) + (z - p.z) * (z - p.z)) + 3 * abs(ys[i] - p.y) }
					end
					i = i + 1
				end
			end
			dz = dz + step
		end
		dx = dx + step
	end
	-- insertion sort by d (a few hundred entries at most)
	local i = 2
	while i <= nb do
		local v = best[i]
		local j = i - 1
		while j >= 1 and best[j][4] > v[4] do
			best[j + 1] = best[j]
			j = j - 1
		end
		best[j + 1] = v
		i = i + 1
	end
	return best, nb
end

-- Lists the sectors of the current set of one type (WALK, HOT, ...) with the area and heights where each was found, for planning:
-- every name once, x/z from the scan (step) and the heights that answered.
ar_sectors = function(sectype, x0, x1, z0, z1, step)
	local seen = { }
	local order = { }
	local n = 0
	local x = x0
	while x <= x1 do
		local z = z0
		while z <= z1 do
			local y = -1
			while y <= 5 do
				local id, name = GetPointSector(x, y, z, sectype)
				if id then
					local e = seen[name]
					if not e then
						e = { x0 = x, x1 = x, z0 = z, z1 = z, y0 = y, y1 = y }
						seen[name] = e
						n = n + 1
						order[n] = name
					end
					if x < e.x0 then e.x0 = x end
					if x > e.x1 then e.x1 = x end
					if z < e.z0 then e.z0 = z end
					if z > e.z1 then e.z1 = z end
					if y < e.y0 then e.y0 = y end
					if y > e.y1 then e.y1 = y end
				end
				y = y + 0.1
			end
			z = z + step
		end
		x = x + step
	end
	local i = 1
	while i <= n do
		local e = seen[order[i]]
		ar_log(format("SECTORS %s: x %.1f..%.1f z %.1f..%.1f y %.2f..%.2f", tostring(order[i]), e.x0, e.x1, e.z0, e.z1, e.y0, e.y1))
		i = i + 1
	end
end

-- Dialogs: the table of a dialog (dart1, nv1 ...) only exists once Dialog:run has loaded its file, so lines are named by the global's
-- name. Same ar_pick of the library underneath.
ar_dlg = function(name)
	local waited = 0
	while not getglobal(name) and waited < 20000 do
		sleep_for(100)
		waited = waited + 100
	end
	return getglobal(name)
end

-- Waits for the dialog to want a choice; nil (and a log line) when the conversation has ended by itself: 3 s with the dialog not running.
-- (ar_pick's own wait gives up only after 4 s of the normal controls, which a Guybrush on a stool never has: he sat 341 s at the Lua
-- Bar's counter after the waitress had gone, 5 minutes twice at Planet Threepwood's, 352 s on Casaba's ship)
ar_dlg_choice = function(name, what)
	local d = getglobal(name)
	local waited = 0
	local gone = 0
	while waited < 300000 do
		d = getglobal(name)
		if d and d.running and system.buttonHandler == d then
			return d
		end
		if d and d.running then
			gone = 0
		else
			gone = gone + 100
		end
		if gone >= 3000 then
			ar_log("the dialog " .. name .. " is over, " .. tostring(what) .. " is not said")
			return nil
		end
		sleep_for(100)
		waited = waited + 100
	end
	return d
end

ar_say = function(name, line)
	local d = ar_dlg(name)
	if not d then
		return ar_fail("the dialog " .. name .. " never started")
	end
	d = ar_dlg_choice(name, "line " .. tostring(line))
	if not d then
		return nil
	end
	return ar_pick(d, line)
end

ar_say_exit = function(name)
	local d = ar_dlg(name)
	if not d then
		return ar_fail("the dialog " .. name .. " never started")
	end
	d = ar_dlg_choice(name, "the exit line")
	if not d then
		return nil
	end
	return ar_pick_exit(d)
end

-- waits until the dialog has ended (the game has the normal controls back)
ar_dlg_ended = function()
	local d = getglobal(AR_DLG_NAME)
	return not d or not d.running
end

ar_dlg_done = function(name)
	AR_DLG_NAME = name
	ar_wait_for(ar_dlg_ended, 60000, "the dialog " .. name .. " to end")
	ar_wait_for_control()
end

-- The lines a dialog offers now: numbers and texts (for planning a conversation)
ar_lines = function(name)
	local d = getglobal(name)
	if not d then
		ar_log("LINES " .. name .. ": no such dialog")
		return
	end
	local s = ""
	local k, v = next(d, nil)
	while k do
		if type(k) == "number" and type(v) == "table" and v.text and v[d.node] and not v.off then
			s = s .. tostring(k) .. "=" .. strsub(tostring(v.text), 1, 60) .. " | "
		end
		k, v = next(d, k)
	end
	ar_log("LINES " .. name .. " node=" .. tostring(d.node) .. ": " .. s)
end

-- The first line of a dialog that is offered now and is not an exit line (nil when none), and whether line n is offered
ar_first_line = function(name)
	local d = getglobal(name)
	local best = nil
	local k, v = next(d, nil)
	while k do
		if type(k) == "number" and type(v) == "table" and v.text and v[d.node] and not v.off and (not best or k < best) then
			best = k
		end
		k, v = next(d, k)
	end
	return best
end

ar_offered_line = function(name, n)
	local d = getglobal(name)
	return d and d[n] and d[n][d.node] and not d[n].off
end

-- Hops that the game does with a trigger strip (HOT sector) and the walk planner cannot see. Melee town: the patio of the SCUMM bar is
-- 0.5 higher than the plaza; walking into the strip at its edge (x 13.5) hops down (or up, from the plaza side).
ar_mel_patio_down = function()
	if ar_set_name() == "melee town" and manny:getpos().y > 0.3 then
		ar_walk_to(13.1, 0.5, 2.4)
		ar_settled()
	end
end

-- EMI: the number keys are bound to items by glob.item_bindings[KEYn - KEY1] (the game binds an item when it is picked up; the player
-- rebinds with shift + key). Grim's keys are the places of the inventory.
ar_hold_done = function()
	return manny.is_holding == AR_HOLD_ITEM
end

ar_hold = function(item)
	if manny.is_holding == item then
		return TRUE
	end
	-- the game's hot keys are 1..9 and 0, and their binding is item_bindings[key - KEY1] (so the 0 key's is not the tenth after 1's)
	local keys = { KEY1, KEY2, KEY3, KEY4, KEY5, KEY6, KEY7, KEY8, KEY9, KEY0 }
	local key = nil
	local free = nil
	local i = 1
	while i <= 10 do
		local b = glob.item_bindings[keys[i] - KEY1]
		if b == item then
			key = keys[i]
		end
		-- (a binding of an item that is gone from the inventory is free: the game does not clear it)
		if (not b or b.owner ~= manny) and not free then
			free = keys[i]
		end
		i = i + 1
	end
	if not key then
		-- no number key holds it (the game binds nothing by itself): the player binds it in the inventory, shift and a key
		if not free then
			ar_log("no key free for " .. tostring(item.name))
			return nil
		end
		ar_log("no key is bound to " .. tostring(item.name) .. ", binding it to key " .. tostring(free - KEY1 + 1) .. " in the inventory")
		ar_inv_bind(item, free)
		key = free
	end
	AR_HOLD_ITEM = item
	ar_press_key(key)
	ar_wait_for(ar_hold_done, 30000, "the item in hand")
	ar_wait_for_control()
	return manny.is_holding == item
end

-- The game's third key, DEFAULT_ACT ("Talk to", "Look at" ... whatever the object calls its default), as a verb of ar_do: ar_do("default_action", obj)
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
	elseif verb == "default_action" then
		map = control_map.DEFAULT_ACT
	end
	return next(map, nil)
end

-- Talking: the conversation runs inside the verb's script until it is over, so (unlike the other verbs) this returns as soon as the
-- game has started it; the caller picks the lines (ar_say) and waits for the end (ar_dlg_done)
ar_talk = function(obj)
	ar_wait_for_control()
	AR_START_SET = system.currentSet
	AR_CODE = obj.default_action
	ar_log("talk: " .. tostring(obj.name))
	ar_approach(obj)
	if ar_send_verb("default_action", obj, "talk to " .. tostring(obj.name)) then
		AR_KEYS_USED = AR_KEYS_USED + 1
	end
	return TRUE
end

-- Looks at an item of the inventory the way a player does: it in hand and Look-at (SampleButtonHandler: look_at_item_in_hand)
ar_look_item = function(item)
	ar_wait_for_control()
	if not ar_hold(item) then
		return ar_fail("could not take " .. tostring(item.name) .. " in hand to look at it")
	end
	-- (the held item is one of the entries of the game's list too: the choice is moved to it with the CHANGE_HOT keys, then the handler
	-- starts look_at_item_in_hand)
	if hot_object ~= item and not ar_cycle_to(item) then
		ar_log("the held " .. tostring(item.name) .. " cannot be chosen: the choice is " .. tostring(hot_object and hot_object.name))
	end
	ar_press("lookAt")
	sleep_for(300)
	ar_wait_for(ar_no_look_script, 60000, "the look at the item")
	ar_wait_for_control()
	return TRUE
end

ar_no_look_script = function()
	return not find_script(Sentence) and cutSceneLevel == 0
end

-- Asks everything: picks the offered lines in order (each at most AR_EXH_REPEAT times, 1 by default) until the dialog offers nothing new,
-- or stop() is true. For conversations whose goal comes from exhausting the topics.
ar_exhaust_stop = function()
	return nil
end

ar_exhaust = function(name, stop_when, max_picks)
	local used = { }
	local picks = 0
	local again = AR_EXH_REPEAT or 1
	while getglobal(name) and getglobal(name).running and picks < (max_picks or 60) and not (stop_when and stop_when()) do
		local d = getglobal(name)
		ar_dialog_ready(d, 20000)
		local best = nil
		local k, v = next(d, nil)
		while k do
			if type(k) == "number" and type(v) == "table" and v.text and v[d.node] and not v.off and (used[k] or 0) < again and (not best or k < best) then
				best = k
			end
			k, v = next(d, k)
		end
		if not best then
			return picks
		end
		used[best] = (used[best] or 0) + 1
		ar_pick(d, best)
		picks = picks + 1
		sleep_for(600)
	end
	return picks
end

-- Checkpoints. Same names and use as the Grim library (ar_checkpoint(slot) at the end of a chapter, ar_load(slot) at the start of the
-- next, the file is grim<slot>.gsv in the save path of the run), but the save is Save(file) alone: EMI has no cur_puzzle_state, dialog_log
-- or the Grim menu's last-saved registry value to keep up. The strings for a load list are only the name of the checkpoint.
ar_set_save_info = function(slot)
	AR_SAVE_TABLE = { }
	AR_SAVE_TABLE[0] = format("Autorun checkpoint %02d", slot)
	AR_SAVE_TABLE[1] = "autorun"
	AR_SAVE_TABLE[2] = system.currentSet.setFile
	system.saveGameCallback = ar_save_game_callback
end

ar_save_game_callback = function()
	SubmitSaveGameData(AR_SAVE_TABLE)
end

ar_menu_save = function(slot)
	local fname = format("grim%02d.gsv", slot)
	ar_set_save_info(slot)
	JustLoaded()
	Save(fname)
	break_here()
	break_here()
end

ar_checkpoint_ready = function()
	return cutSceneLevel == 0 and ar_handler_normal() and not find_script(Sentence) and not IsMessageGoing()
end

ar_checkpoint = function(slot)
	ar_try_wait(ar_checkpoint_ready, 60000)
	ar_wait_for_control()
	sleep_for(1000)
	ar_menu_save(slot)
	sleep_for(1500)
	ar_log("saved checkpoint grim" .. format("%02d", slot) .. ".gsv")
	-- (the original brings the task that made a save back with it: a resume (run_orig.sh) loads the save and runs the new script at
	-- once, which stops this task; it waits here meanwhile, 20 s of game time. The same on both engines)
	sleep_for(20000)
	if not AR_CONTINUE then
		-- one chapter run: the save is the result
		ar_finish()
	end
end

-- Level hops of a set that the planner cannot find (a stair that is a cheat box: the game moves Guybrush on contact, from a floor strip
-- that touches it): { from level y, to level y, entry point (a floor point of the strip), a point inside the box beyond it }.
-- Walked before a walk to a point on the other level.
AR_HOPS = { }
AR_HOPS["Lucre Island Town"] = { { fromy = 0, toy = 3.67, ex = -40.18, ez = -204.64, nx = -40.0, nz = -197.0 } }

ar_level_hop = function(ty)
	local hops = AR_HOPS[ar_set_name()]
	if not hops then
		return
	end
	local i = 1
	while hops[i] do
		local h = hops[i]
		local p = manny:getpos()
		if abs(p.y - h.fromy) < 1.2 and ty and ty > h.toy - 1 and abs(ty - h.fromy) > 2 then
			ar_log("level hop through the stair at " .. format("%.1f %.1f", h.ex, h.ez))
			AR_NO_HOPS = TRUE
			ar_walk_to(h.ex, h.fromy, h.ez, nil, nil)
			AR_NO_HOPS = nil
			-- into the box: straight on
			local t = 0
			local y0 = manny:getpos().y
			while abs(manny:getpos().y - y0) < 1 and t < 6000 do
				if not ar_steer(h.nx, 0, h.nz, 8) then
					ar_step(manny)
				end
				break_here()
				t = t + system.frameTime
			end
			ar_drive_stop()
			sleep_for(300)
		end
		i = i + 1
	end
end

-- Every line spoken goes to the log (SAY lines): the story tells what the next puzzle wants. Actor.say_line of the game, wrapped.
if not AR_OLD_SAY then
	AR_OLD_SAY = Actor.say_line
	Actor.say_line = function(a, text, b, c, d)
		if type(text) == "string" and not AR_NO_SAYLOG then
			ar_log("SAY " .. tostring(a.name) .. ": " .. text)
		end
		return AR_OLD_SAY(a, text, b, c, d)
	end
end

-- Choosing a line of a dialog with the keys. A dialog that scrolls (Insult Arm Wrestling lists a dozen comebacks and shows five at a time)
-- is scrolled: the selection is moved down past the last line shown and the list slides. The other dialogs show the first lines of the
-- node (Dialog.max_line, 4 with the exit line) and a line further down comes when the ones before it have been used up: then the
-- first line shown that has not been said yet is said (a line that stays, like "No, really, I AM a grog-swilling ...", is said once
-- only), until the one wanted is among them.
-- The answer to a chosen line is over when the dialog offers its lines again, when the game has its normal controls back, or (EMI) when
-- the conversation is no longer running: on the raft, a stool or a ship the controls are never the normal ones, and the library's wait
-- ran its full 300 s after every conversation that ended by itself (ten times a game: the gate of Mysts o' Tyme three times, the Lua Bar's
-- stool, Planet Threepwood's, Casaba's ship, the academy). What comes after (a cutscene) is the next step's to wait for.
ar_wait_line_done = function(dlg)
	local waited = 0
	local gone = 0
	while waited < 300000 and gone < 500 do
		if system.buttonHandler == dlg or ar_handler_normal() then
			gone = 99999
		else
			if dlg.running then
				gone = 0
			else
				gone = gone + 100
			end
			sleep_for(100)
			waited = waited + 100
		end
	end
	sleep_for(100)
end

ar_dialog_select = function(dlg, line)
	-- the selection moved to the line (looked up again after every key: the list can slide) and the choose key
	local n = 0
	while dlg.current_choices[dlg.selected_line] ~= line and n < 40 do
		local at = nil
		local i = 1
		while dlg.current_choices and dlg.current_choices[i] do
			if dlg.current_choices[i] == line then
				at = i
			end
			i = i + 1
		end
		if not at then
			n = 40
		elseif dlg.selected_line < at then
			ar_press_key(ar_real_key("DIALOG_DOWN"))
			break_here()
			n = n + 1
		else
			ar_press_key(ar_real_key("DIALOG_UP"))
			break_here()
			n = n + 1
		end
	end
	ar_log("choose: selection " .. tostring(dlg.selected_line) .. ": " .. tostring(dlg.current_choices[dlg.selected_line] and dlg.current_choices[dlg.selected_line].text))
	ar_press_key(ar_real_key("DIALOG_CHOOSE"))
	sleep_for(300)
	ar_wait_line_done(dlg)
end

ar_choose_line = function(dlg, line)
	local presses = 0
	if dlg.scroll_mode then
		-- down first, then (the end of the list reached) up: the window starts wherever the last round left it
		local dir = "DIALOG_DOWN"
		while not ar_line_shown(dlg, line) and presses < 60 do
			local before = dlg.current_choices and dlg.current_choices[1]
			local sel = dlg.selected_line
			ar_press_key(ar_real_key(dir))
			break_here()
			presses = presses + 1
			-- (nothing moved: the end of the list)
			if dlg.current_choices and dlg.current_choices[1] == before and dlg.selected_line == sel then
				if dir == "DIALOG_DOWN" then
					dir = "DIALOG_UP"
				else
					presses = 60
				end
			end
		end
		if presses > 0 and ar_line_shown(dlg, line) then
			ar_log("choose: scrolled " .. presses .. " lines to " .. tostring(line.text))
		end
	end
	local said = { }
	local rounds = 0
	while not ar_line_shown(dlg, line) and rounds < 20 do
		rounds = rounds + 1
		-- the first line shown that is not the exit line and has not been said in this search
		local pick = nil
		local i = 1
		while dlg.current_choices and dlg.current_choices[i] and not pick do
			local c = dlg.current_choices[i]
			if c ~= dlg.exit_lines[dlg.node] and not said[c] then
				pick = c
			end
			i = i + 1
		end
		if not pick then
			ar_log("choose: the line is not offered and there is nothing new to say first (node " .. tostring(dlg.node) .. "): " .. tostring(line.text))
			return
		end
		ar_log("choose: " .. tostring(line.text) .. " is not shown yet, saying " .. tostring(pick.text) .. " first")
		said[pick] = TRUE
		ar_dialog_select(dlg, pick)
		if not ar_dialog_ready(dlg) then
			ar_log("choose: the dialog ended while saying the lines before " .. tostring(line.text))
			return
		end
	end
	if ar_line_shown(dlg, line) then
		ar_dialog_select(dlg, line)
	end
end

-- The library's skip timer (500 ms after an override is set) presses Escape whatever the override is. A door's own walk (the override of
-- Object:play_door, a few seconds) is left to run, as ar_skipper does: Escape would stop the walk short of the door.
if not AR_ORIG_SKIP_TIMER then
	AR_ORIG_SKIP_TIMER = ar_skip_timer
end
ar_skip_timer = function(serial)
	sleep_for(500)
	if serial == AR_OV_SERIAL and system.override and system.override.is_active and ar_override_is_door() and not AR_NO_SKIP and not AR_REAL then
		-- (looked at again later: the override may turn into something else)
		AR_OV_TASK = start_script(ar_skip_timer, serial)
		return
	end
	return AR_ORIG_SKIP_TIMER(serial)
end

-- The game's time in ms as the scripts see it (the frame times added up), for the chapters that have to be quick
if not AR_CLOCK_TASK then
	AR_CLOCK = 0
	-- (a CLOCK line in the log every second of game time, and Guybrush's place: game_time.py finds where the time goes and where he stands
	-- still. Not an AUTORUN line, so run_emi.sh's watch for a stuck run does not take it for progress)
	AR_CLOCK_NEXT = 0
	ar_clock_task = function()
		while TRUE do
			AR_CLOCK = AR_CLOCK + system.frameTime
			if AR_CLOCK >= AR_CLOCK_NEXT then
				AR_CLOCK_NEXT = AR_CLOCK_NEXT + 1000
				local p = manny and manny.hActor and manny:getpos()
				-- (on the raft of Mysts o' Tyme his place is the raft's: his own is one on the raft)
				if mot and mot.guybrush_on_raft and swampraft and swampraft.hActor then
					p = swampraft:getpos()
				end
				if p and p.x then
					PrintDebug(format("CLOCK %d %.2f %.2f %d ", AR_CLOCK, p.x, p.z, cutSceneLevel or 0) .. tostring(ar_set_name and ar_set_name() or "?") .. "\n")
				else
					PrintDebug(format("CLOCK %d\n", AR_CLOCK))
				end
			end
			break_here()
		end
	end
	AR_CLOCK_TASK = start_script(ar_clock_task)
end

