-- the game's in(item, table) (_system.lua): `in` is a word of Lua 5.1, so the data-free tests (synth/test_talk.lua) could not load this file with it
ar_in_list = function(item, list)
	local k, v = next(list, nil)
	while k do
		if v == item then
			return TRUE
		end
		k, v = next(list, k)
	end
	return nil
end

-- The 100% modes (speed100, full100: AR_FULL, see MODES_PLAN.md): helpers that do everything there is to do in a place, and ar_extra, the hook the chapters call
-- where a 100% run has more to do. In the other modes ar_extra does nothing, so those runs are not changed by a frame.
-- Lua 3.1: no for loops, no # operator, no local functions.

-- (this file is read once a script run, after ar_lib.lua has defined ar_go, ar_do ... afresh. A chapter that loads a save of a 100% run gets the
-- *_OLD of that run back with it, and the guards below took them as wrapped already: a run of one chapter of speed100 had no extras at all)
AR_LOG_X_OLD, AR_GO_OLD, AR_CP_OLD, AR_PICK_OLD, AR_PICK_EXIT_OLD, AR_SWEEP_OLD = nil, nil, nil, nil, nil, nil
-- (so is the chapter of the frames, which the people step goes by: the save of chapter 3 had it at chapter 3. run_all.sh sets it for each chapter after
-- this file; ar_lib.lua sets it itself when frames are taken)
if not AR_FRAMES then
	AR_FRAME_CH = nil
end

AR_EXTRAS = AR_EXTRAS or { }
AR_EXTRA_MISS = AR_EXTRA_MISS or 0

-- Runs what the table AR_EXTRAS holds under the tag (the ex*.lua files define them). What fails in an extra is logged and counted, it does not fail the
-- chapter: the story goes on from wherever Manny stands.
ar_extra = function(tag)
	if not AR_FULL then
		return
	end
	local f = AR_EXTRAS[tag]
	if not f then
		ar_log("extra: " .. tag .. " (nothing defined)")
		return
	end
	ar_extra_run(tag, f)
end

-- What Manny carries: a table of the items he owns (for ar_lost, which names an extra or an object that took one away)
ar_carried = function()
	local t = { }
	local i = 1
	while Inventory.ordered_inventory_table[i] do
		local item = Inventory.ordered_inventory_table[i]
		if item.owner == manny then
			t[item] = TRUE
		end
		i = i + 1
	end
	return t
end
-- Logs each item of `before` that Manny does not carry any more ("an item was taken by <who>"); tools/sweep_blame.py blocks the object it names.
-- Returns TRUE when one went.
ar_lost = function(before, who)
	local lost = nil
	local k, v = next(before, nil)
	while k do
		if k.owner ~= manny then
			ar_log("extra: an item was taken by " .. tostring(who) .. " (" .. tostring(k.name) .. ")")
			lost = TRUE
		end
		k, v = next(before, k)
	end
	return lost
end

-- An extra gives up after AR_EXTRA_MAX_FAILS (2) failures: the steps left of it return at once. A Manny stranded where the floor goes nowhere made every
-- object of the meadow cost a planner search of 162 frames and a walk of 18 s (rounds 9 to 11 of the speed100 loop: 1500 s instead of 160)
if AR_FULL and not AR_LOG_X_OLD then
	AR_LOG_X_OLD = ar_log
	ar_log = function(msg)
		AR_LOG_X_OLD(msg)
		if AR_IN_EXTRA and not AR_EXTRA_ABORT and type(msg) == "string" and strsub(msg, 1, 5) == "FAIL " then
			AR_EXTRA_FAILS = (AR_EXTRA_FAILS or 0) + 1
			if AR_EXTRA_FAILS >= (AR_EXTRA_MAX_FAILS or 2) then
				AR_EXTRA_ABORT = TRUE
				AR_LOG_X_OLD("extra: given up after " .. AR_EXTRA_FAILS .. " failures")
			end
		end
	end
	AR_DO_X_OLD = ar_do
	ar_do = function(verb, noun1, noun2)
		if AR_EXTRA_ABORT then
			return nil
		end
		if not AR_IN_EXTRA and ar_sweep_early then
			ar_sweep_early()
		end
		if verb == "use" and not AR_IN_EXTRA and ar_is_talker and ar_is_talker(noun1) then
			-- (Manny stays by the person after the talk: he is about to use them, and the walk back and to them again ended out of reach of Chepito, who
			-- moves about the mine, chapters 41 and 42)
			AR_NO_PUT_BACK = TRUE
			ar_people_once()
			AR_NO_PUT_BACK = nil
		end
		-- (a door the chapter uses to leave the set: the set is swept first, as for ar_go; Copal's office is left through its window by a use, chapter 2,
		-- and was never swept)
		if not AR_IN_EXTRA and noun1 and not noun2 and (noun1.walkOut or noun1.climbOut) and ar_sweep then
			ar_sweep()
		end
		-- (the fire extinguisher of the Beaver Dam sprays until the USE key is let go, which a press of ar_do never does: chapter 12 lets go itself, an
		-- extra had Manny spray for ever)
		if AR_IN_EXTRA and type(bd) == "table" and bd.extinguisher and (noun2 == bd.extinguisher or noun1 == bd.extinguisher) then
			start_script(ar_extinguisher_release)
		end
		return AR_DO_X_OLD(verb, noun1, noun2)
	end
	AR_WALK_X_OLD = ar_walk_to
	ar_walk_to = function(x, y, z, stop_when, max_ms)
		if AR_EXTRA_ABORT then
			return nil
		end
		if not AR_IN_EXTRA and ar_sweep_early then
			ar_sweep_early()
		end
		return AR_WALK_X_OLD(x, y, z, stop_when, max_ms)
	end
end

-- Lets go of the USE key once the extinguisher sprays (after its least time, 1.5 s, which bd.extinguisher_count_min_time counts)
ar_extinguisher_release = function()
	local t = 0
	while not (bd.firing_extinguisher and system.buttonHandler == fireExtinguisherHandler) and t < 30000 do
		break_here()
		t = t + system.frameTime
	end
	sleep_for(1600)
	if system.buttonHandler == fireExtinguisherHandler then
		system.buttonHandler(ar_key_for("use"), nil, nil)
	end
end

ar_extra_run = function(tag, f)
	ar_log("extra: " .. tag)
	local carried = ar_carried()
	local in_extra = AR_IN_EXTRA
	local fails, abort = AR_EXTRA_FAILS, AR_EXTRA_ABORT
	AR_IN_EXTRA = TRUE
	AR_EXTRA_FAILS = 0
	AR_EXTRA_ABORT = nil
	-- (what Manny holds is taken in hand again after the extra: chapter 57 starts with the remote that chapter 56 ended with, and the items step had used it)
	local held = manny.is_holding
	local failed = AR_FAILED
	local keep = AR_KEEP_GOING
	AR_FAILED = nil
	AR_KEEP_GOING = TRUE
	ar_wait_for_control()
	-- (the extras walk about: Manny is put back where he stood, so that the story goes on from there)
	local back = manny:getpos()
	-- (kept here as well: an extra inside this one, the people step of a side trip, set them to its own set)
	local ex_set = system.currentSet
	AR_EX_SET = ex_set
	AR_EX_X, AR_EX_Y, AR_EX_Z = back.x, back.y, back.z
	f()
	AR_EX_SET = ex_set
	AR_EX_X, AR_EX_Y, AR_EX_Z = back.x, back.y, back.z
	-- (the walk back below is not given up with the extra: the story goes on from where Manny stood)
	AR_EXTRA_ABORT = nil
	ar_wait_for_control()
	if system.currentSet == AR_EX_SET and not AR_NO_PUT_BACK then
		local now = manny:getpos()
		-- (not onto a spot that is no floor now, such as the sector of a door that Manny came through: the game would take him out through it)
		local nav = ar_nav_of(AR_EX_SET)
		if abs(now.x - AR_EX_X) + abs(now.y - AR_EX_Y) > 0.3 and nav and ar_nav_find(nav, AR_EX_X, AR_EX_Y, AR_EX_Z) then
			ar_walk_to(AR_EX_X, AR_EX_Y, AR_EX_Z)
			ar_wait_for_control()
		end
	end
	-- (the extras are not to change the story: an item gone is named; with no object to name it is the extra's tag, in brackets. So is a set left)
	ar_lost(carried, "[" .. tag .. "]")
	if held and manny.is_holding ~= held and held.owner == manny and system.currentSet == AR_EX_SET and cutSceneLevel == 0 then
		ar_log("extra: Manny held " .. tostring(held.name) .. " before " .. tag .. ": taken in hand again")
		ar_hold(held)
		ar_wait_for_control()
	end
	if system.currentSet ~= AR_EX_SET then
		ar_log("extra: the set was left by [" .. tag .. "] (now in " .. tostring(system.currentSet and system.currentSet.name) .. ")")
	end
	if AR_FAILED then
		AR_EXTRA_MISS = AR_EXTRA_MISS + 1
		ar_log("extra: " .. tag .. " did not all work")
	end
	AR_KEEP_GOING = keep
	AR_FAILED = failed
	AR_IN_EXTRA = in_extra
	AR_EXTRA_FAILS, AR_EXTRA_ABORT = fails, abort
	ar_log("extra: done " .. tag)
end

-- Every line a dialog that is waiting for a choice offers, then its exit line. A line that the dialog does not offer again is not said twice (a line
-- that stays on offer after it was said would be said for ever).
ar_talk_all = function(dlg)
	local said = { }
	local rounds = 0
	local picked = TRUE
	while picked and rounds < 120 and ar_dialog_ready(dlg, 20000) do
		picked = nil
		local i = 1
		while dlg.current_choices and dlg.current_choices[i] and not picked do
			local c = dlg.current_choices[i]
			if c ~= dlg.exit_lines[dlg.node] and not said[c] then
				said[c] = TRUE
				ar_pick(dlg, c)
				picked = TRUE
			end
			i = i + 1
		end
		rounds = rounds + 1
	end
	if system.buttonHandler == dlg then
		ar_pick_exit(dlg)
	end
	ar_wait_for_control()
end

AR_OBJ_KEY = AR_OBJ_KEY or { }
-- Objects that use, pick up and the items leave alone, by their name in the scripts: AR_NO_USE["bv.bone_wagon"] = "why" (ex00_sweep.lua; for the objects
-- that take Manny out of the set without being a door, and the ones with no name of their own to put in AR_NO_LOOK or AR_NO_ITEMS)
AR_NO_USE = AR_NO_USE or { }
ar_no_use = function(o)
	local key = AR_OBJ_KEY[o]
	if key and AR_NO_USE[key] then
		ar_log("extra: not used: " .. key .. " (" .. AR_NO_USE[key] .. ")")
		return TRUE
	end
end

-- The objects of a set (the ones Object:create made for it), the nearest to Manny first, each once
-- The global of a set: the name of its set file (bv.set is bv), or else the global that holds it (do.set is dom: do is a word of Lua). Not kept in the set,
-- whose table goes into the saves.
AR_SET_GLOBAL = { }
ar_set_global = function(set)
	if not set then
		return nil
	end
	local stem = set.setFile and strsub(set.setFile, 1, strlen(set.setFile) - 4)
	if stem and getglobal(stem) == set then
		return stem
	end
	if AR_SET_GLOBAL[set] then
		return AR_SET_GLOBAL[set]
	end
	local n, v = nextvar(nil)
	while n do
		-- (a name as the sets have, two to four small letters: AR_TARGET and cameraman_watching_set hold the set too)
		if v == set and strfind(n, "^%l%l%l?%l?$") then
			AR_SET_GLOBAL[set] = n
			return n
		end
		n, v = nextvar(n)
	end
	return stem
end

ar_set_objects = function(set)
	local list = { }
	local n = 0
	local seen = { }
	local global = ar_set_global(set) or tostring(set.name)
	local k, v = next(set, nil)
	while k do
		if type(v) == "table" and v.obj_set == set and v.name and v.obj_x and not seen[v] then
			seen[v] = TRUE
			-- (the name of the object in the scripts, "bv.bone_wagon", for AR_NO_USE; kept out of the object, whose table goes into the saves)
			if not AR_OBJ_KEY[v] then
				AR_OBJ_KEY[v] = global .. "." .. tostring(k)
			end
			n = n + 1
			list[n] = v
		end
		k, v = next(set, k)
	end
	local order = { }
	local m = 0
	local p = manny:getpos()
	local x = p.x
	local y = p.y
	while m < n do
		local best = nil
		local bestd = 0
		local i = 1
		while i <= n do
			local o = list[i]
			if o then
				local d = (o.obj_x - x) * (o.obj_x - x) + (o.obj_y - y) * (o.obj_y - y)
				if not best or d < bestd then
					best = i
					bestd = d
				end
			end
			i = i + 1
		end
		m = m + 1
		order[m] = list[best]
		x = list[best].obj_x
		y = list[best].obj_y
		list[best] = nil
	end
	return order, n
end

-- Whether the object has code of its own for a verb (the others answer with the game's default, which is the same for all)
ar_has_verb = function(obj, verb)
	return rawgettable(obj, verb) ~= nil
end

-- Objects that the look at everything leaves alone: AR_NO_LOOK["object name"] = "why" (looking at them changes the story, or takes Manny somewhere)
AR_NO_LOOK = AR_NO_LOOK or { }

-- Looks at every object of the set that is there to be looked at (touchable, in the room, with a lookAt of its own)
-- Why the sweep left an object alone, once a game for each object, verb and reason (OBJSKIP lines, for tools/luamiss.py): an object of the set that has
-- code for the verb and was not looked at, used or picked up
AR_OBJSKIP_SEEN = AR_OBJSKIP_SEEN or { }
ar_objskip = function(o, verb, why)
	local key = tostring(AR_OBJ_KEY[o]) .. "|" .. verb .. "|" .. why
	if not AR_OBJSKIP_SEEN[key] then
		AR_OBJSKIP_SEEN[key] = TRUE
		ar_log("OBJSKIP " .. tostring(AR_OBJ_KEY[o]) .. " " .. verb .. " " .. why)
	end
end
ar_objskip_why = function(o)
	if not o.touchable then
		return "untouchable"
	elseif o.owner then
		return "owned"
	elseif not o.range or o.range <= 0 then
		return "no-range"
	elseif o.walkOut or o.climbOut then
		return "door"
	end
	return nil
end

-- The objects looked at in this game (AR_LOOKED): a set is looked over again each time it would be swept, for the ones not looked at yet (an object that
-- was not there to touch the first time: Charlie's printer, Copal's papers, the bodies in the Lola)
AR_LOOKED = AR_LOOKED or { }
ar_look_all = function(set)
	if system.currentSet ~= set then
		return
	end
	local list, n = ar_set_objects(set)
	local i = 1
	while i <= n and system.currentSet == set do
		local o = list[i]
		-- (a door is not looked at here: standing at it is standing in its door sector, and the game walks Manny out; ar_look_doors)
		ar_talk_opened()
		if system.currentSet == set and not AR_LOOKED[o] and o.touchable and not o.owner and o.range and o.range > 0 and not o.walkOut and not o.climbOut and not AR_NO_LOOK[o.string_name] and ar_has_verb(o, "lookAt") then
			AR_LOOKED[o] = TRUE
			ar_do("lookAt", o)
		elseif system.currentSet == set and not AR_LOOKED[o] and ar_has_verb(o, "lookAt") and not o.walkOut and not o.climbOut then
			ar_objskip(o, "lookAt", ar_objskip_why(o) or (AR_NO_LOOK[o.string_name] and "no-look") or "?")
		end
		i = i + 1
	end
	ar_talk_opened()
end

-- The doors of the set not looked at yet: from the door's use point, the place in front of it where the game puts Manny when he comes in through it (out of
-- the door's sector, which would walk him out), turned to the door, and only when the game offers it there. Not where the use point is on no walk floor or
-- on a hot sector (a door or a trigger)
ar_look_doors = function(set)
	if system.currentSet ~= set then
		return
	end
	local nav = ar_nav_of(set)
	local list, n = ar_set_objects(set)
	local i = 1
	while i <= n and system.currentSet == set do
		local o = list[i]
		if (o.walkOut or o.climbOut) and not AR_LOOKED[o] and o.touchable and o.range and o.range > 0 and o.use_pnt_x and o.obj_x and not AR_NO_LOOK[o.string_name] and ar_has_verb(o, "lookAt") then
			AR_LOOKED[o] = TRUE
			local z = o.use_pnt_z or 0
			local hot = nav and ar_w_hot_at(nav, o.use_pnt_x, o.use_pnt_y)
			if nav and ar_nav_find(nav, o.use_pnt_x, o.use_pnt_y, z) and not (hot and hot[1]) then
				ar_walk_to(o.use_pnt_x, o.use_pnt_y, z, function() return ar_set_changed() end, 20000)
				if system.currentSet == set then
					AR_OBJ = o
					ar_face(o)
					ar_wait_turn()
					ar_fix_head()
					ar_wait_offered(800)
					if not ar_offered() and system.currentSet == set then
						-- (from the use point, the stick toward the door until the game offers it: 21 doors were not offered there. A step into its
						-- sector walks Manny out, and the sweep comes back through the door on the other side, ar_sweep_back)
						AR_DOOR_SET = set
						ar_walk_stick(o.obj_x, o.obj_y, o.obj_z or z, function() return ar_offered() or system.currentSet ~= AR_DOOR_SET end, 3000)
						ar_wait_offered(400)
					end
					if ar_offered() and system.currentSet == set then
						ar_do("lookAt", o)
					elseif system.currentSet == set then
						ar_log("extra: " .. tostring(o.name) .. " is not offered from its use point, not looked at")
					end
				end
			else
				ar_log("extra: the use point of " .. tostring(o.name) .. " is on no plain floor, not looked at")
			end
		end
		i = i + 1
	end
end

-- (a set swept before: what is new to look at, and its doors)
ar_relook = function()
	ar_look_all(AR_VISIT_SET)
	ar_look_doors(AR_VISIT_SET)
end

-- A dialog the game opened by itself, a set's intro walked into (Maximino greets Manny as he steps in and talks, mx1): every line on offer and the end, as
-- for a person talked to; nothing when no dialog has the keys
ar_talk_opened = function()
	ar_wait_for_control()
	local dlg = system.buttonHandler
	if type(dlg) == "table" and ar_dialog_name(dlg) ~= "?" then
		ar_log("extra: the game opened the dialog " .. ar_dialog_name(dlg))
		ar_talk_before(dlg, nil)
		if system.buttonHandler == dlg then
			ar_pick_exit(dlg)
		end
		ar_wait_for_control()
	end
end

-- Uses and picks up what the set has code for, except the objects the caller names (a table keyed by object: doors, and what moves the story on).
-- Doors are never used here, the chapters walk through them.
AR_USED = AR_USED or { pickUp = { }, use = { } }
ar_use_all = function(set, except)
	if system.currentSet ~= set then
		return
	end
	local list, n = ar_set_objects(set)
	local i = 1
	except = except or { }
	while i <= n and system.currentSet == set do
		local o = list[i]
		if o.touchable and not o.owner and o.range and o.range > 0 and not except[o] and not o.walkOut and not o.climbOut and not ar_no_use(o) then
			local before = ar_carried()
			-- (each verb once a game, AR_USED: a set is gone over again on later visits for the objects that were not there to touch before)
			if ar_has_verb(o, "pickUp") and not AR_USED["pickUp"][o] then
				AR_USED["pickUp"][o] = TRUE
				ar_do("pickUp", o)
				ar_settle()
			end
			if system.currentSet == set and ar_has_verb(o, "use") and not except[o] and not AR_USED["use"][o] then
				AR_USED["use"][o] = TRUE
				ar_do("use", o)
				ar_settle()
			end
			ar_left_by(set, o, before)
		elseif system.currentSet == set and not o.walkOut and not o.climbOut then
			local why = ar_objskip_why(o) or (except[o] and "except") or (ar_no_use(o) and "no-use") or "?"
			if ar_has_verb(o, "pickUp") and not AR_USED["pickUp"][o] then
				ar_objskip(o, "pickUp", why)
			end
			if ar_has_verb(o, "use") and not AR_USED["use"][o] then
				ar_objskip(o, "use", why)
			end
		end
		i = i + 1
	end
end

-- (an object whose use took Manny out of the set, or took an item he carried, is named, for tools/sweep_blame.py: it blocks that object, AR_NO_USE, not the whole set)
ar_left_by = function(set, o, before)
	ar_lost(before, AR_OBJ_KEY[o])
	if system.currentSet ~= set then
		ar_log("extra: the set was left by " .. tostring(AR_OBJ_KEY[o]) .. " (now in " .. tostring(system.currentSet and system.currentSet.name) .. ")")
	end
end

-- Every inventory item that the object has a use_<item> answer for, tried on it, nearest first
AR_ITEM_TRIED = AR_ITEM_TRIED or { }
ar_items_on = function(obj)
	local inv = { }
	local n = 0
	local i = 1
	while Inventory.ordered_inventory_table[i] do
		n = n + 1
		inv[n] = Inventory.ordered_inventory_table[i]
		i = i + 1
	end
	i = 1
	while i <= n and system.currentSet == obj.obj_set do
		local item = inv[i]
		-- (not the scythe where the game keeps it put away, no_scythe_sets of _sets.lua: Domino's office has code for it that no player can reach)
		local key = "use_" .. trim_header(item.string_name)
		-- (each item on each object once a game, AR_ITEM_TRIED: later visits try the items Manny has got since)
		if item.owner == manny and obj[key] and not (AR_ITEM_TRIED[obj] and AR_ITEM_TRIED[obj][key])
			and not (item == mo.scythe and system.currentSet.setFile and ar_in_list(system.currentSet.setFile, no_scythe_sets)) then
			AR_ITEM_TRIED[obj] = AR_ITEM_TRIED[obj] or { }
			AR_ITEM_TRIED[obj][key] = TRUE
			ar_do("use", obj, item)
		end
		i = i + 1
	end
	-- (an object with an answer of its own for any item, default_response: one item it has no answer for, once a game (the florist's gun, Domino's
	-- mouthpiece, Charlie's printer). Not the scythe, where the game keeps it put away)
	if rawgettable(obj, "default_response") and not (AR_ITEM_TRIED[obj] and AR_ITEM_TRIED[obj]["default"]) and system.currentSet == obj.obj_set then
		i = 1
		local any = nil
		while i <= n and not any do
			local item = inv[i]
			if item.owner == manny and item ~= mo.scythe and not obj["use_" .. trim_header(item.string_name)] then
				any = item
			end
			i = i + 1
		end
		if any then
			AR_ITEM_TRIED[obj] = AR_ITEM_TRIED[obj] or { }
			AR_ITEM_TRIED[obj]["default"] = TRUE
			ar_do("use", obj, any)
		end
	end
end

-- A dialog that a verb opened is talked through (the lines of the hook, then the exit line), a cutscene waited out
ar_settle = function()
	local dlg = system.buttonHandler
	if type(dlg) == "table" and ar_dialog_name(dlg) ~= "?" then
		ar_talk_before(dlg, nil)
		if system.buttonHandler == dlg then
			ar_pick_exit(dlg)
		end
	end
	ar_wait_for_control()
end

-- Every item that Manny carries tried on every object of the set that has an answer for it
ar_items_all = function(set)
	local list, n = ar_set_objects(set)
	local i = 1
	while i <= n and system.currentSet == set do
		local o = list[i]
		if o.touchable and not o.owner and o.range and o.range > 0 and not o.walkOut and not o.climbOut and not AR_NO_ITEMS[o.string_name] and not ar_no_use(o) then
			local before = ar_carried()
			ar_items_on(o)
			ar_settle()
			ar_left_by(set, o, before)
		end
		i = i + 1
	end
end

AR_NO_ITEMS = AR_NO_ITEMS or { }
AR_NO_HEAVY = AR_NO_HEAVY or { }
ar_heavy_set = function()
	local set = AR_VISIT_SET
	if system.currentSet == set then
		ar_use_all(set)
	end
	if system.currentSet == set then
		ar_items_all(set)
	end
end

ar_setup_changed = function()
	return AR_SETUP_SET:current_setup() ~= AR_SETUP_BEFORE
end

-- A point of the walk floor (a sector that is on) inside the camera sector c, the nearest to its middle, on a grid of 12 by 12 over its box; nil if
-- there is none
ar_camera_floor_point = function(nav, c)
	local poly = { p = { c.p } }
	ar_nav_prep(poly)
	local x0, x1, y0, y1 = poly.minx[1], poly.maxx[1], poly.miny[1], poly.maxy[1]
	local bx, by, bz = nil, nil, nil
	local bd = 1000000
	local i = 0
	while i <= 12 do
		local j = 0
		while j <= 12 do
			local x = x0 + (x1 - x0) * i / 12
			local y = y0 + (y1 - y0) * j / 12
			if ar_nav_inside(poly, 1, x, y) then
				local s = ar_nav_find(nav, x, y, c.fz)
				if s then
					local d = (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y)
					if d < bd then
						bd = d
						bx = x
						by = y
						bz = ar_nav_z(nav, s, x, y)
					end
				end
			end
			j = j + 1
		end
		i = i + 1
	end
	return bx, by, bz
end

-- The camera sectors of the set, walked into one by one so that each setup is seen once (nav_setfile.lua reads the set file; sectors of type camera
-- are in sf.camera when it keeps them)
ar_visit_setups = function(set)
	local nav = ar_nav_of(set)
	if not nav or not nav.camera then
		ar_log("setups: " .. tostring(set.name) .. " has no camera sectors read")
		return
	end
	local i = 1
	while nav.camera[i] and system.currentSet == set do
		local c = nav.camera[i]
		AR_SETUP_SET = set
		AR_SETUP_BEFORE = set:current_setup()
		-- (only a middle that is on the walk floor: a walk to one that is not goes as near as the floor goes, and can end in a pocket of it)
		if ar_nav_find_any(nav, c.x, c.y, c.z) then
			ar_walk_to(c.x, c.y, c.z, ar_setup_changed, 30000)
		else
			-- (else a point of the floor inside the sector, the nearest to its middle: the camera of the tube room's switch is over the edge of the walk
			-- floor; only for a setup not seen yet)
			local n = set.setups and set.setups[c.name]
			local x, y, z = nil, nil, nil
			if n and not AR_SETUP_SEEN[set.name .. "|" .. tostring(n)] then
				x, y, z = ar_camera_floor_point(nav, c)
			end
			if x then
				ar_log(format("setups: the middle of %s is off the floor, walking to %.2f %.2f in it", tostring(c.name), x, y))
				ar_walk_to(x, y, z, ar_setup_changed, 30000)
			else
				ar_log("setups: the middle of " .. tostring(c.name) .. " is off the floor, not visited")
			end
		end
		ar_log("COV setup | " .. tostring(set.name) .. " | " .. tostring(set:current_setup()))
		i = i + 1
	end
end

-- A 100% run looks over each set once, before it leaves it (a door taken with ar_go) or ends the chapter in it (the checkpoint): Manny has walked
-- on the floor of the story by then, which he has not on arrival (he can stand where the floor is no way anywhere until he steps off, in the garage). Objects and
-- setups only: nothing that uses or takes. AR_NO_SWEEP["set name"] = "why" keeps a set out: where the objects move the floor or take Manny through a door.
AR_VISITED = AR_VISITED or { }
AR_NO_SWEEP = AR_NO_SWEEP or { }
AR_NO_RELOOK = AR_NO_RELOOK or { }
AR_NO_REHEAVY = AR_NO_REHEAVY or { }
ar_visit_set = function()
	ar_look_all(AR_VISIT_SET)
	ar_look_doors(AR_VISIT_SET)
	ar_visit_setups(AR_VISIT_SET)
end
-- A step of the sweep that took Manny out of the set (a walk that crossed a door's sector: the walk to Copal's message board climbed out of his window,
-- chapter 2, and the chapter then used the window from the ledge): back through the door of the set he is in that leads there (<set global>_door), as a
-- player would
ar_sweep_back = function(set)
	local cur = system.currentSet
	if not cur or cur == set then
		return
	end
	ar_wait_for_control()
	local g = ar_set_global(set)
	local door = g and cur[g .. "_door"]
	if type(door) == "table" and (door.walkOut or door.climbOut) and door.touchable then
		ar_log("extra: back to " .. tostring(set.name) .. " through " .. tostring(door.name))
		AR_GO_OLD(door, set)
		ar_wait_for_control()
	else
		ar_log("extra: no door back to " .. tostring(set.name) .. " from " .. tostring(cur.name))
	end
end

-- The game's menus once (100% modes), as a player looks through them (_options.lua): the menu key, then each item by its hot key or the arrows, and back:
-- the help pages, every option turned one step and back, the advanced 3D menu, the dialog transcript, the cutscene menu and one cutscene, the save,
-- load and erase menus (nothing saved, loaded or erased), the credits and the quit question (no). The menus pause every task but the one that pressed
-- the menu key (game_pauser), this one, which drives them.
ar_menu_wait = function(cond, n)
	local k = 0
	while not cond() and k < n do
		break_here()
		k = k + 1
		if game_pauser.is_paused then
			AR_FRAME = AR_FRAME + 1
		end
	end
	return cond()
end
ar_menu_key = function(name)
	ar_press_key(ar_real_key(name))
	ar_menu_wait(function() return FALSE end, 3)
end
ar_menu_hot = function(c)
	if system.characterHandler and system.characterHandler.characterHandler then
		system.characterHandler:characterHandler(c)
	end
	ar_menu_wait(function() return FALSE end, 3)
end
ar_menu_main = function()
	return ar_menu_wait(function() return main_menu.is_active and system.buttonHandler == main_menu end, 90)
end
-- back to the main menu from a menu (its override), TRUE when it is up
ar_menu_up = function(what)
	local k = 0
	while not (main_menu.is_active and system.buttonHandler == main_menu) and k < 4 do
		ar_menu_key("OVERRIDE")
		ar_menu_main()
		k = k + 1
	end
	if not (main_menu.is_active and system.buttonHandler == main_menu) then
		ar_log("MENU no main menu after " .. tostring(what))
		return nil
	end
	return TRUE
end
ar_menu_tour = function()
	ar_wait_for_control()
	ar_log("MENU the tour")
	ar_press_key(ar_real_key("MENU"))
	if not ar_menu_main() then
		ar_log("MENU the main menu did not open")
		return
	end
	ar_menu_key("DIALOG_DOWN")
	ar_menu_key("DIALOG_UP")
	-- help: the pages, both ways
	ar_menu_hot("h")
	if ar_menu_wait(function() return help_menu.is_active end, 30) then
		ar_menu_key("TURN_RIGHT")
		ar_menu_key("TURN_RIGHT")
		ar_menu_key("TURN_LEFT")
		ar_log("MENU help")
	end
	if not ar_menu_up("help") then return end
	-- options: each item one step right and back, then the advanced 3D menu, out of it with nothing chosen
	ar_menu_hot("o")
	if ar_menu_wait(function() return settings_menu.is_active and system.buttonHandler == settings_menu end, 30) then
		local m = settings_menu.menu
		ar_menu_key("PAGE_HOME")
		local i = 0
		while i < (m.num_items or 0) + 1 do
			local cur = m.cur_item
			-- (not the 3D hardware on and off, threed_index: the engine would make its window again, which hung ScummVM at the photofinish)
			if cur ~= settings_menu.exit_index and cur ~= settings_menu.advanced_threed_index and cur ~= settings_menu.threed_index then
				ar_menu_key("TURN_RIGHT")
				ar_menu_wait(function() return not find_script(settings_menu.change_value) end, 30)
				ar_menu_key("TURN_LEFT")
				ar_menu_wait(function() return not find_script(settings_menu.change_value) end, 30)
			end
			ar_menu_key("DIALOG_DOWN")
			i = i + 1
		end
		ar_log("MENU options")
		local k = 0
		while settings_menu.advanced_threed_index and m.cur_item ~= settings_menu.advanced_threed_index and k < 30 do
			ar_menu_key("DIALOG_DOWN")
			k = k + 1
		end
		if m.cur_item == settings_menu.advanced_threed_index then
			ar_menu_key("DIALOG_CHOOSE")
			if ar_menu_wait(function() return display_menu.is_active end, 30) then
				ar_menu_key("DIALOG_DOWN")
				ar_menu_key("DIALOG_UP")
				ar_log("MENU display")
				ar_menu_key("OVERRIDE")
				ar_menu_wait(function() return settings_menu.is_active and system.buttonHandler == settings_menu end, 60)
			end
		end
	end
	if not ar_menu_up("options") then return end
	-- the dialog transcript
	ar_menu_hot("d")
	ar_menu_wait(function() return dialog_log.is_active end, 30)
	ar_menu_key("PAGE_UP")
	ar_menu_key("PAGE_DOWN")
	if not ar_menu_up("the dialog transcript") then return end
	-- the cutscenes: the list, and the first one, stopped by its override (no movie of the game is playing now)
	ar_menu_hot("c")
	if ar_menu_wait(function() return cutscene_menu.is_active and system.buttonHandler == cutscene_menu end, 30) and not IsMoviePlaying() then
		ar_menu_key("PAGE_HOME")
		ar_menu_key("DIALOG_DOWN")
		ar_menu_key("PAGE_HOME")
		ar_menu_key("DIALOG_CHOOSE")
		if ar_menu_wait(function() return system.buttonHandler == cutscene_menu_view_button_handler end, 60) then
			ar_menu_wait(function() return IsMoviePlaying() end, 30)
			ar_menu_key("OVERRIDE")
			ar_menu_wait(function() return system.buttonHandler == cutscene_menu end, 120)
			ar_log("MENU a cutscene")
		end
	end
	if not ar_menu_up("the cutscenes") then return end
	-- save, load and erase: the list of each, nothing chosen
	local modes = { "s", "l", "e" }
	local j = 1
	while modes[j] do
		ar_menu_hot(modes[j])
		ar_menu_wait(function() return saveload_menu.is_active end, 60)
		ar_menu_key("DIALOG_DOWN")
		ar_menu_key("DIALOG_UP")
		if not ar_menu_up("the save menu " .. modes[j]) then return end
		j = j + 1
	end
	ar_log("MENU save, load, erase")
	-- the credits (no hot key: the arrows), a screen of them and out
	ar_menu_key("PAGE_HOME")
	local k = 0
	while main_menu.menu and main_menu.menu.cur_item ~= 8 and k < 12 do
		ar_menu_key("DIALOG_DOWN")
		k = k + 1
	end
	if main_menu.menu and main_menu.menu.cur_item == 8 then
		ar_menu_key("DIALOG_CHOOSE")
		if ar_menu_wait(function() return credits_menu.is_active end, 60) then
			ar_menu_wait(function() return FALSE end, 120)
			ar_log("MENU credits")
		end
	end
	if not ar_menu_up("the credits") then return end
	-- the quit question: the choices both ways, back to no, and out of it
	ar_menu_hot("q")
	if ar_menu_wait(function() return exit_query and exit_query.is_active end, 60) then
		ar_menu_key("INVENTORY_NEXT")
		ar_menu_key("INVENTORY_PREV")
		ar_menu_key("OVERRIDE")
		ar_menu_wait(function() return not (exit_query and exit_query.is_active) end, 60)
		ar_log("MENU the quit question")
	end
	-- back to the game
	local n = 0
	while game_pauser.is_paused and n < 10 do
		ar_menu_key("OVERRIDE")
		n = n + 1
	end
	ar_wait_for_control()
	ar_log("MENU done, paused " .. tostring(game_pauser.is_paused))
end

-- A set not swept yet is looked over (the visit: looks, doors, setups; not the heavy step) before the chapter's first verb or walk in it: a chapter that
-- leaves a set by a cutscene or a script's move, not by a door (the vault interior, the florist, the wine cellar), never swept it. The heavy step comes
-- when the set would be swept again (reheavy). AR_NO_EARLY["set name"] = "why" keeps a set to the sweep when it is left
AR_NO_EARLY = AR_NO_EARLY or { }
ar_sweep_early = function()
	local set = system.currentSet
	if not AR_FULL or AR_IN_EXTRA or AR_SWEEP_EARLY_ON or not set or not set.name or cutSceneLevel > 0 or not ar_handler_normal() then
		return
	end
	local name = set.name
	if AR_VISITED[name] or AR_NO_SWEEP[name] or AR_NO_EARLY[name] then
		return
	end
	AR_SWEEP_EARLY_ON = TRUE
	AR_VISITED[name] = TRUE
	AR_VISIT_SET = set
	ar_extra_run("early " .. tostring(name), ar_visit_set)
	ar_sweep_back(set)
	-- (and use, pick up and the items: a set left by a cutscene is never swept again. As "reheavy", AR_NO_REHEAVY)
	if system.currentSet == set and not AR_NO_HEAVY[name] and not AR_NO_REHEAVY[name] then
		AR_VISIT_SET = set
		ar_extra_run("reheavy " .. tostring(name), ar_heavy_set)
		ar_sweep_back(set)
	end
	AR_SWEEP_EARLY_ON = nil
end
ar_sweep = function()
	-- (not while a handler of its own has the keys: in the Bone Wagon at the end of chapter 56 the items step left the remote in hand, and the
	-- inventory key of chapter 57 then put it away instead of taking it out)
	if not AR_FULL or not system.currentSet or cutSceneLevel > 0 or not ar_handler_normal() then
		return
	end
	local name = system.currentSet.name
	local set = system.currentSet
	if AR_VISITED[name] then
		-- (what is new to look at since, AR_NO_RELOOK["set name"] = "why" keeps a set out)
		if not AR_NO_SWEEP[name] and not AR_NO_RELOOK[name] then
			AR_VISIT_SET = set
			ar_extra_run("relook " .. tostring(name), ar_relook)
			ar_sweep_back(set)
		end
		-- (and what is new to use, pick up and try the items on, with the items got since; AR_NO_REHEAVY["set name"] = "why" keeps a set out)
		if system.currentSet == set and not AR_NO_SWEEP[name] and not AR_NO_HEAVY[name] and not AR_NO_REHEAVY[name] then
			AR_VISIT_SET = set
			ar_extra_run("reheavy " .. tostring(name), ar_heavy_set)
			ar_sweep_back(set)
		end
		-- (the door trips again, each time the set would be swept: the first sweep can end out of the set, the heavy step of the kitchen took Manny to
		-- the lounge)
		if system.currentSet == set then
			ar_door_trips(set)
		end
		return
	end
	AR_VISITED[name] = TRUE
	if AR_NO_SWEEP[name] then
		ar_log("extra: no sweep of " .. tostring(name) .. " (" .. AR_NO_SWEEP[name] .. ")")
	else
		AR_VISIT_SET = set
		ar_extra_run("visit " .. tostring(name), ar_visit_set)
		ar_sweep_back(set)
		-- (use, pick up and the items: as a step of its own, so that a set where it breaks the story loses only this)
		if system.currentSet == AR_VISIT_SET and not AR_NO_HEAVY[name] then
			ar_extra_run("heavy " .. tostring(name), ar_heavy_set)
			ar_sweep_back(set)
		end
	end
	-- (the doors to sets not entered yet: a trip of its own through each, and back; also from a set that is not swept)
	if system.currentSet == set then
		ar_door_trips(set)
	end
end

-- Cutscenes held in the 100% modes until a camera setup that only they show has come up, and a few frames more so that it is drawn; then the skip goes on as
-- usual (ar_skip_timer, ar_lib.lua). Meche's intro in chapter 4 (me1.intro) cuts to the computer, mo_comin, when Manny goes to look her up.
AR_HOLD_FRAMES = AR_HOLD_FRAMES or 0
ar_skip_hold = function(f)
	if not AR_FULL then
		return nil
	end
	if me1 and f == me1.intro_override and mo and mo_comin then
		if mo:current_setup() ~= mo_comin then
			AR_HOLD_FRAMES = 0
			return TRUE
		end
		AR_HOLD_FRAMES = AR_HOLD_FRAMES + 1
		return AR_HOLD_FRAMES < 6
	end
	return nil
end

-- The sets entered in this game (100% modes): the set is looked at every frame; the first time in a set is a COV set line for the coverage report
-- (a set the story only passes through, in a cutscene or a script's move, has no camera notes)
AR_ENTERED = AR_ENTERED or { }
-- The setups too: each new setup of a set is a COV setup line, whatever showed it (a walk, a cutscene, a script's move, a drift)
AR_SETUP_SEEN = AR_SETUP_SEEN or { }
ar_set_watch = function()
	local cur = nil
	local su = nil
	while TRUE do
		if system.currentSet ~= cur then
			cur = system.currentSet
			su = nil
			if cur and cur.name and not AR_ENTERED[cur.name] then
				AR_ENTERED[cur.name] = TRUE
				ar_log("COV set | " .. cur.name)
			end
		end
		if cur and cur.name and cur.current_setup then
			local n = cur:current_setup()
			if n ~= su then
				su = n
				local key = cur.name .. "|" .. tostring(n)
				if n and not AR_SETUP_SEEN[key] then
					AR_SETUP_SEEN[key] = TRUE
					ar_log("COV setup | " .. cur.name .. " | " .. tostring(n))
				end
			end
		end
		break_here()
	end
end
if AR_FULL and not AR_SET_WATCH then
	AR_SET_WATCH = start_script(ar_set_watch)
end

-- Door trips (100% modes): from a set that is swept, through each of its doors (an object <set global>_door that is walked out of) to a set of AR_TRIP_TO
-- (ex05_trips.lua: the story never goes there) not entered yet in this game, when that set has a door back (<this set's global>_door): the side trip of ar_side_trip_run, which looks at everything there, picks up and gives
-- the items to the people and talks to them, and comes back. AR_NO_TRIP["<set global>.<door field>"] = "why" leaves a door alone (ex00_sweep.lua).
AR_NO_TRIP = AR_NO_TRIP or { }
AR_TRIP_TO = AR_TRIP_TO or { }
AR_TRIP_DOOR = AR_TRIP_DOOR or { }
AR_DOOR_DONE = AR_DOOR_DONE or { }
ar_door_trips = function(set)
	local sg = ar_set_global(set)
	if not sg or AR_TRIP then
		return
	end
	local k, v = next(set, nil)
	while k and system.currentSet == set do
		if type(k) == "string" and type(v) == "table" and v.walkOut and strlen(k) > 5 and strsub(k, strlen(k) - 4, strlen(k)) == "_door" then
			local t = getglobal(strsub(k, 1, strlen(k) - 5))
			local key = sg .. "." .. k
			-- (or a door of the coverage list, ex06_doors.lua, AR_TRIP_DOOR: one the run never walks through, this way or the way back; each once a game)
			local tg = t and type(t) == "table" and ar_set_global(t)
			local back_key = tg and (tg .. "." .. sg .. "_door")
			local listed = (AR_TRIP_DOOR[key] and not AR_DOOR_DONE[key]) or (back_key and AR_TRIP_DOOR[back_key] and not AR_DOOR_DONE[back_key])
			if type(t) == "table" and t ~= set and t.come_out_door and t.name and ((AR_TRIP_TO[t.name] and not AR_ENTERED[t.name]) or listed) and type(t[sg .. "_door"]) == "table" then
				AR_DOOR_DONE[key] = TRUE
				if back_key then
					AR_DOOR_DONE[back_key] = TRUE
				end
				if AR_NO_TRIP[key] then
					ar_log("extra: no trip through " .. key .. " (" .. AR_NO_TRIP[key] .. ")")
				else
					AR_TRIP = { v, t, t[sg .. "_door"] }
					ar_extra_run("trip " .. key, ar_side_trip_run)
					AR_TRIP = nil
				end
			end
		end
		k, v = next(set, k)
	end
end
if AR_FULL and not AR_GO_OLD then
	AR_GO_OLD = ar_go
	AR_CP_OLD = ar_checkpoint
	ar_go = function(door, target, vx, vy, vz)
		ar_sweep()
		return AR_GO_OLD(door, target, vx, vy, vz)
	end
	ar_checkpoint = function(slot)
		ar_sweep()
		return AR_CP_OLD(slot)
	end
end


-- Dialogs: before the line that a chapter picks, a 100% run says the other lines the dialog offers (ar_pick below), except the ones in AR_NO_AUTO (ex02_dialogs.lua,
-- made from the scripts: their response ends the dialog or starts a cutscene) and the dialogs in AR_NO_TALK (ex00_sweep.lua: found by running, one that broke a chapter).
AR_DIALOG_NAMES = { "ai1", "an1", "be1", "bo1", "br1", "ca2", "ca1", "ce1", "ce2", "ch1", "cp1", "cp2", "cl1", "do2", "do1", "ev1", "ev2", "gl2", "gl3", "gl1", "gk1", "lu1", "mx1", "mm1", "me1", "me2", "mb1", "mi1", "ol1", "sa2", "sa1", "ve2", "ve1", "vi1", "tb1" }
AR_SAID = AR_SAID or { }
AR_NO_AUTO = AR_NO_AUTO or { }
AR_NO_TALK = AR_NO_TALK or { }

ar_dialog_name = function(dlg)
	local i = 1
	while AR_DIALOG_NAMES[i] do
		if getglobal(AR_DIALOG_NAMES[i]) == dlg then
			return AR_DIALOG_NAMES[i]
		end
		i = i + 1
	end
	return "?"
end

ar_line_number = function(dlg, line)
	local k, v = next(dlg, nil)
	while k do
		if v == line and type(k) == "number" then
			return k
		end
		k, v = next(dlg, k)
	end
	return nil
end

-- Whether a line of the dialog may be said by the 100% run on its own: not said yet, not one that ends the talk or moves the story (AR_NO_AUTO), offered
ar_talk_safe = function(name, dlg, c, target)
	local n = ar_line_number(dlg, c)
	return c ~= target and c ~= dlg.exit_lines[dlg.node] and not AR_SAID[c] and n and not (AR_NO_AUTO[name] and AR_NO_AUTO[name][n]) and not ar_picked_later(name, n)
end

-- The chapter being played, by its file name (AR_CHAPTERS of ex04_dlg_later.lua): a run of one chapter has a tag after the name ("ch13_plunge_s100")
ar_cur_chapter = function()
	local c = AR_FRAME_CH or AR_CHAPTER
	if not c then
		return nil
	end
	if AR_CUR_CH_FOR == c then
		return AR_CUR_CH
	end
	AR_CUR_CH_FOR = c
	AR_CUR_CH = c
	local i = 1
	while AR_CHAPTERS and AR_CHAPTERS[i] do
		if strsub(c, 1, strlen(AR_CHAPTERS[i])) == AR_CHAPTERS[i] then
			AR_CUR_CH = AR_CHAPTERS[i]
		end
		i = i + 1
	end
	return AR_CUR_CH
end
AR_NO_TALK_UNTIL = AR_NO_TALK_UNTIL or { }
AR_NO_EXTRA_TALK = AR_NO_EXTRA_TALK or { }
AR_DLG_HOME = AR_DLG_HOME or { }
-- Whether this chapter or a later one picks line n of the dialog itself (AR_DLG_PICKS): such a line is left to that pick
ar_picked_later = function(name, n)
	-- (not a move that stays on when said, AR_DLG_KEEP, in an extra: it is offered again for the chapter's pick; Salvador's 220, chapter 5)
	if AR_IN_EXTRA and AR_DLG_KEEP and AR_DLG_KEEP[name] and AR_DLG_KEEP[name][n] then
		return nil
	end
	local by = AR_DLG_PICKS and AR_DLG_PICKS[name] and AR_DLG_PICKS[name][n]
	local now = ar_cur_chapter()
	return by and now and not (by < now)
end

-- A line on offer in the node `node` that moves the dialog to node `to` (AR_DLG_MOVE), or nil; one not said yet comes first
ar_talk_mover = function(name, dlg, to)
	local moves = AR_DLG_MOVE[name]
	if not moves then
		return nil
	end
	local found = nil
	local i = 1
	while dlg.current_choices and dlg.current_choices[i] do
		local c = dlg.current_choices[i]
		local n = ar_line_number(dlg, c)
		if n and moves[n] == to then
			if not AR_SAID[c] then
				return c
			end
			found = found or c
		end
		i = i + 1
	end
	return found
end

-- Whether the talk can come back from node `sub` to node `home`: its exit line goes there, or one of its lines moves there (the lines of a node have the
-- name of the node as a field, as the game's display_lines reads them)
ar_talk_returns = function(name, dlg, sub, home)
	if AR_DLG_EXIT[name] and AR_DLG_EXIT[name][sub] == home then
		return TRUE
	end
	local moves = AR_DLG_MOVE[name]
	if moves then
		local n, to = next(moves, nil)
		while n do
			if to == home and type(dlg[n]) == "table" and dlg[n][sub] and not dlg[n].off then
				return TRUE
			end
			n, to = next(moves, n)
		end
	end
	return nil
end

-- The nodes of a dialog (where its lines move to, the nodes with an exit or an abort, and home) and, for each, the number of steps back to home: by
-- the lines on offer that move (AR_DLG_MOVE: a line belongs to node X when it has the field X, as the game's display_lines reads it; a line with
-- several nodes, AR_DLG_MOVES, when each of them comes back, by the longest), by the exit line of the node (AR_DLG_EXIT) or by its abort, which the game
-- runs by itself once the node is talked through (AR_DLG_ABORT). A node with no way home has none
ar_talk_dist = function(name, dlg, home)
	local moves = AR_DLG_MOVE[name] or { }
	local multi = (AR_DLG_MOVES and AR_DLG_MOVES[name]) or { }
	local exits = AR_DLG_EXIT[name] or { }
	local aborts = (AR_DLG_ABORT and AR_DLG_ABORT[name]) or { }
	local nodes = { }
	nodes[home] = TRUE
	local n, to = next(moves, nil)
	while n do
		nodes[to] = TRUE
		n, to = next(moves, n)
	end
	local l = nil
	n, l = next(multi, nil)
	while n do
		local j = 1
		while l[j] do
			nodes[l[j]] = TRUE
			j = j + 1
		end
		n, l = next(multi, n)
	end
	local x, y = next(exits, nil)
	while x do
		nodes[x] = TRUE
		x, y = next(exits, x)
	end
	x, y = next(aborts, nil)
	while x do
		nodes[x] = TRUE
		x, y = next(aborts, x)
	end
	local dist = { }
	dist[home] = 0
	local changed = TRUE
	while changed do
		changed = nil
		x = next(nodes, nil)
		while x do
			if not dist[x] then
				local best = nil
				y = exits[x]
				-- (an exit line the game sets when the node is shown counts too: Meche's n3, me2.delayed_n3_exit)
				if y and dist[y] then
					best = dist[y] + 1
				end
				y = aborts[x]
				if y and dist[y] and (not best or dist[y] + 1 < best) then
					best = dist[y] + 1
				end
				n, to = next(moves, nil)
				while n do
					if dist[to] and to ~= x and type(dlg[n]) == "table" and dlg[n][x] and not dlg[n].off and (not best or dist[to] + 1 < best) then
						best = dist[to] + 1
					end
					n, to = next(moves, n)
				end
				n, l = next(multi, nil)
				while n do
					if type(dlg[n]) == "table" and dlg[n][x] and not dlg[n].off then
						local worst = -1
						local j = 1
						while l[j] and worst do
							if l[j] ~= x then
								if dist[l[j]] then
									if dist[l[j]] > worst then
										worst = dist[l[j]]
									end
								else
									worst = nil
								end
							end
							j = j + 1
						end
						if worst and worst >= 0 and (not best or worst + 1 < best) then
							best = worst + 1
						end
					end
					n, l = next(multi, n)
				end
				if best then
					dist[x] = best
					changed = TRUE
				end
			end
			x = next(nodes, x)
		end
	end
	return dist
end

-- The node line n moves to, from node cur: its node (AR_DLG_MOVE), or for a line with several (AR_DLG_MOVES) the one it can go to that has no way
-- home, else the one farthest from home (the talk follows the node the game goes to); nil for a line that is no move
ar_move_to = function(name, n, dist, cur)
	local to = AR_DLG_MOVE[name] and AR_DLG_MOVE[name][n]
	if to then
		return to
	end
	local l = AR_DLG_MOVES and AR_DLG_MOVES[name] and AR_DLG_MOVES[name][n]
	if not l then
		return nil
	end
	local best = nil
	local j = 1
	while l[j] do
		if l[j] ~= cur then
			if not (dist and dist[l[j]]) then
				return l[j]
			end
			if not best or dist[l[j]] > dist[best] then
				best = l[j]
			end
		end
		j = j + 1
	end
	return best or cur
end

-- Whether line n moves to a node (one, or one of several)
ar_is_move = function(name, n)
	return (AR_DLG_MOVE[name] and AR_DLG_MOVE[name][n]) or (AR_DLG_MOVES and AR_DLG_MOVES[name] and AR_DLG_MOVES[name][n])
end

-- Whether node `node` has a line on offer not said yet that the talk would say there (not one a chapter picks later; a move counts)
ar_talk_node_new = function(name, dlg, node, ends)
	local k, v = next(dlg, nil)
	while k do
		if type(k) == "number" and type(v) == "table" and v[node] and v.text and not v.off and not AR_SAID[v] and not ar_picked_later(name, k) and (not (AR_NO_AUTO[name] and AR_NO_AUTO[name][k]) or ar_is_move(name, k) or (ends and AR_DLG_END and AR_DLG_END[name] and AR_DLG_END[name][k])) then
			return TRUE
		end
		k, v = next(dlg, k)
	end
	return nil
end

-- A line on offer that moves to another node the talk comes back home from: one not said yet (entered nil), or one said before into a node not entered
-- on this visit that has a line not said (entered: the nodes entered); the moves home come last
ar_talk_pick_move = function(name, dlg, target, dist, cur, home, entered)
	local found, found_d = nil, nil
	local found_home = nil
	local i = 1
	while dlg.current_choices and dlg.current_choices[i] do
		local c = dlg.current_choices[i]
		local n = ar_line_number(dlg, c)
		local to = n and ar_move_to(name, n, dist, cur)
		if to and (to ~= cur or not entered) and (dist[to] or to == cur) and c ~= target and not ar_picked_later(name, n) then
			local ok = nil
			if not entered then
				ok = not AR_SAID[c]
			else
				ok = AR_SAID[c] and not entered[to] and to ~= home and ar_talk_node_new(name, dlg, to)
			end
			if ok then
				if to == home then
					found_home = found_home or c
				elseif not found or (dist[to] or 0) > found_d then
					-- (the node farthest from home first: Eva's explain_node has three ways on, and the one through page_node turns more lines on)
					found = c
					found_d = dist[to] or 0
				end
			end
		end
		i = i + 1
	end
	return found or found_home
end

-- The line on offer that moves nearest to home (fewest steps) and its steps; nil when none is nearer than node cur
ar_talk_back = function(name, dlg, dist, cur)
	local best, best_d = nil, dist[cur]
	local i = 1
	while dlg.current_choices and dlg.current_choices[i] do
		local c = dlg.current_choices[i]
		local n = ar_line_number(dlg, c)
		local to = n and ar_move_to(name, n, dist, cur)
		if to and dist[to] and (not best_d or dist[to] < best_d) and not ar_picked_later(name, n) then
			best = c
			best_d = dist[to]
		end
		i = i + 1
	end
	return best, best_d
end

-- How many lines node `node` would show (the lines on offer and its exit line): with one or none the game runs the node's abort by itself
-- (_dialog.lua, min_line), and Nick's aborts say the first line on offer, the one chapter 19 picks (150)
ar_talk_shown = function(dlg, node)
	local n = 0
	if dlg.exit_lines and dlg.exit_lines[node] then
		n = 1
	end
	local k, v = next(dlg, nil)
	while k do
		if type(k) == "number" and type(v) == "table" and v[node] and v.text and not v.off then
			n = n + 1
		end
		k, v = next(dlg, k)
	end
	return n
end

-- Whether node `node` shows enough lines that the game does not act by itself: two or more, where the node has an abort (Mic's poem_node shows its exit
-- line only, and has none)
ar_talk_shown_ok = function(dlg, node)
	return not (dlg.aborts and dlg.aborts[node]) or ar_talk_shown(dlg, node) >= 2
end

-- Whether the talk can end in node `node`: it has an exit line, or a line on offer that only ends the talk (not one a chapter picks later), or one that
-- moves on to a node where it can (up to 4 nodes deep). Nick's best_node, once 220 is said (it turns itself off), has only the chapter's 200: the talk
-- went in, could not end there, and the exit fell back on 200, which chapter 19 needs later
ar_talk_endable = function(name, dlg, node, depth)
	if (dlg.exit_lines and dlg.exit_lines[node]) or (AR_DLG_EXIT[name] and AR_DLG_EXIT[name][node]) then
		return TRUE
	end
	if depth <= 0 then
		return nil
	end
	local ends = (AR_DLG_END and AR_DLG_END[name]) or { }
	local k, v = next(dlg, nil)
	while k do
		if type(k) == "number" and type(v) == "table" and v[node] and v.text and not v.off and not ar_picked_later(name, k) then
			if ends[k] then
				return TRUE
			end
			local to = ar_move_to(name, k, nil, node)
			if to and to ~= node and ar_talk_endable(name, dlg, to, depth - 1) then
				return TRUE
			end
		end
		k, v = next(dlg, k)
	end
	return nil
end

-- Whether the talk may go into node `to` by line n, the talk being to end anyway: it can end there and it shows two lines or more (else the game
-- runs the node's abort by itself); a line with several nodes, every one it may go to (Nick's 240 goes to trouble_node or threats_node)
ar_talk_enterable = function(name, dlg, n, to)
	local l = AR_DLG_MOVES and AR_DLG_MOVES[name] and AR_DLG_MOVES[name][n]
	if not l then
		return ar_talk_endable(name, dlg, to, 4) and ar_talk_shown_ok(dlg, to)
	end
	local j = 1
	while l[j] do
		if l[j] ~= dlg.node and not (ar_talk_endable(name, dlg, l[j], 4) and ar_talk_shown_ok(dlg, l[j])) then
			return nil
		end
		j = j + 1
	end
	return TRUE
end

-- The talk is to end anyway, in a node with no way home or at home with nothing left (ending): a line into a node with no way home that has a line
-- not said (one not said first, then a move that stays on into a node not entered on this visit), else a line not said that only ends the talk
-- (AR_DLG_END); away from home also the exit line of the node, or a line that ends the talk said before. TRUE when a line was said
ar_talk_dead_end = function(name, dlg, target, dist, entered, home)
	local cur = dlg.node
	local ends = (AR_DLG_END and AR_DLG_END[name]) or { }
	local into, into_said, end_new, end_old = nil, nil, nil, nil
	local i = 1
	while dlg.current_choices and dlg.current_choices[i] do
		local c = dlg.current_choices[i]
		local n = ar_line_number(dlg, c)
		local to = n and ar_move_to(name, n, dist, cur)
		if n and c ~= target and not ar_picked_later(name, n) then
			if to and to ~= cur and to ~= home and not dist[to] and not entered[to] and ar_talk_enterable(name, dlg, n, to) then
				if not AR_SAID[c] then
					into = into or c
				elseif ar_talk_node_new(name, dlg, to, TRUE) then
					into_said = into_said or c
				end
			elseif ends[n] then
				if not AR_SAID[c] then
					end_new = end_new or c
				else
					end_old = end_old or c
				end
			end
		end
		i = i + 1
	end
	local c = into or into_said
	if c then
		local to = ar_move_to(name, ar_line_number(dlg, c), dist, cur)
		entered[to] = TRUE
		ar_talk_say(name, dlg, c, " (into " .. tostring(to) .. ", the talk ends there)")
		return TRUE
	end
	if end_new then
		ar_talk_say(name, dlg, end_new, " (ends the talk)")
		return TRUE
	end
	if cur == home then
		return nil
	end
	if dlg.exit_lines and dlg.exit_lines[cur] then
		ar_log("extra: talk " .. name .. " exit of " .. tostring(cur) .. " (ends the talk)")
		AR_PICK_EXIT_OLD(dlg)
		ar_log("extra: done talk " .. name .. " exit of " .. tostring(cur))
		return TRUE
	end
	if end_old then
		ar_talk_say(name, dlg, end_old, " (ends the talk)")
		return TRUE
	end
	return nil
end

-- Says one line (an extra of its own: what fails in it is logged, the story goes on)
AR_TALK_N = AR_TALK_N or 0
AR_TALK_NEW = AR_TALK_NEW or 0
ar_talk_say = function(name, dlg, c, what)
	-- (a line said for the first time, AR_TALK_NEW: what makes a person worth talking to again; 240 said again on each visit to Nick is not)
	if not AR_SAID[c] then
		AR_TALK_NEW = AR_TALK_NEW + 1
	end
	AR_SAID[c] = TRUE
	AR_TALK_N = AR_TALK_N + 1
	local n = ar_line_number(dlg, c)
	ar_log("extra: talk " .. name .. " " .. tostring(n) .. what)
	AR_PICK_OLD(dlg, c)
	ar_log("extra: done talk " .. name .. " " .. tostring(n))
end

-- Before the line that a chapter picks (target), every other line the dialog offers, and the lines of the sub-menus it can come back from (AR_DLG_MOVE,
-- AR_DLG_EXIT of ex02_dialogs.lua): a sub-menu is entered, talked through and left again, and the talk goes on in the node it started in, where the
-- target is. When the target is the exit line of the start node (ar_pick_exit), a sub-menu whose exit ends the talk is entered too, as the last thing:
-- the talk ends in it (ar_talk_ended tells the caller). Nodes at any depth, by every line that moves to one the talk comes back home from
-- (ar_talk_dist); a node already entered on this visit is entered again only by a line not said yet.
ar_talk_before = function(dlg, target, force_end)
	local name = ar_dialog_name(dlg)
	-- (the node a talk starts in, for ar_dialog_has_new)
	if not AR_DLG_HOME[name] and dlg.node then
		AR_DLG_HOME[name] = dlg.node
	end
	-- (first: a dialog of AR_NO_TALK returns at once, and a TRUE left from an earlier talk made ar_pick_exit leave Celso's talk open, chapter 13)
	AR_TALK_ENDED = nil
	-- (AR_NO_TALK_UNTIL[name] = "<chapter>": the block holds up to that chapter only, the one whose own picks the lines said before it broke)
	local now = ar_cur_chapter()
	if AR_NO_TALK[name] and not (AR_NO_TALK_UNTIL[name] and now and AR_NO_TALK_UNTIL[name] < now) then
		return
	end
	-- (AR_NO_EXTRA_TALK[name] = "<chapter>": no extra talks in it up to that chapter, whose own talk says the lines: an extra's talk of Lupe before
	-- chapter 14 and of Celso before chapter 60 broke the chapter's own picks)
	if AR_IN_EXTRA and AR_NO_EXTRA_TALK[name] and now and not (AR_NO_EXTRA_TALK[name] < now) then
		ar_log("extra: " .. name .. " is left to " .. AR_NO_EXTRA_TALK[name])
		return
	end
	if not dlg.current_choices then
		return
	end
	-- (a dialog that this chapter or a later one talks in itself is talked in too: the lines a chapter picks are left to it, ar_picked_later, and where
	-- the talk breaks the chapter the person is blocked in that chapter, AR_NO_TALKER "<set> <field>@<chapter>")
	local failed = AR_FAILED
	local keep = AR_KEEP_GOING
	AR_KEEP_GOING = TRUE
	local home = dlg.node
	local ending = force_end or (target and dlg.exit_lines and target == dlg.exit_lines[home])
	local entered = { }
	local rounds = 0
	local picked = TRUE
	while picked and rounds < 120 and system.buttonHandler == dlg do
		picked = nil
		local cur = dlg.node
		local i = 1
		-- the lines of the node it is in
		while dlg.current_choices and dlg.current_choices[i] and not picked do
			local c = dlg.current_choices[i]
			if ar_talk_safe(name, dlg, c, target) then
				ar_talk_say(name, dlg, c, "")
				picked = TRUE
			end
			i = i + 1
		end
		local dist = nil
		if not picked and system.buttonHandler == dlg then
			dist = ar_talk_dist(name, dlg, home)
			-- a line not said yet that moves to another node the talk comes back home from (at any depth); the ones that go home last
			local c = ar_talk_pick_move(name, dlg, target, dist, cur, home, nil)
			-- or one said before, into a node not entered on this visit that still has a line not said
			if not c then
				c = ar_talk_pick_move(name, dlg, target, dist, cur, home, entered)
			end
			if c then
				local to = ar_move_to(name, ar_line_number(dlg, c), dist, cur)
				entered[to] = TRUE
				ar_talk_say(name, dlg, c, " (into " .. tostring(to) .. ")")
				picked = TRUE
			end
		end
		if not picked and cur ~= home and system.buttonHandler == dlg then
			-- nothing left in this node: one step nearer home, by a line that moves or by the exit line of the node
			local back, back_d = ar_talk_back(name, dlg, dist, cur)
			local ex = AR_DLG_EXIT[name] and AR_DLG_EXIT[name][cur]
			if back and not (ex and dist[ex] and back_d and dist[ex] < back_d) then
				ar_talk_say(name, dlg, back, " (back toward " .. tostring(home) .. ")")
			elseif ex and dist[ex] and dlg.exit_lines[cur] then
				ar_log("extra: talk " .. name .. " exit of " .. tostring(cur))
				AR_PICK_OLD(dlg, dlg.exit_lines[cur])
				ar_log("extra: done talk " .. name .. " exit of " .. tostring(cur))
			elseif ending then
				-- (a node that does not come back, entered because the talk was to end anyway: deeper, or a line that ends it, or its exit)
				ar_talk_dead_end(name, dlg, target, dist, entered, home)
			end
			picked = TRUE
			if system.buttonHandler == dlg and dlg.node == cur then
				ar_log("extra: talk " .. name .. ": could not come back from " .. tostring(cur) .. " to " .. tostring(home))
				picked = nil
			end
		elseif not picked and cur == home and ending and system.buttonHandler == dlg then
			-- (the talk is to end anyway: a node it does not come back from, entered as the last thing, or a line that only ends it)
			picked = ar_talk_dead_end(name, dlg, target, dist, entered, home)
		end
		rounds = rounds + 1
	end
	if system.buttonHandler ~= dlg and dlg.node == "exit_dialog" then
		AR_TALK_ENDED = TRUE
	end
	AR_KEEP_GOING = keep
	AR_FAILED = failed
end

if AR_FULL and not AR_PICK_OLD then
	AR_PICK_OLD = ar_pick
	ar_pick = function(dlg, line)
		local target = line
		if type(line) == "number" then
			target = dlg[line]
		end
		-- (the dialog on screen first: a chapter picks as soon as the talk has started, and the talk before found no lines yet; Salvador's first
		-- menu in chapter 5 was never talked in)
		if ar_dialog_ready(dlg) and type(line) == "number" then
			target = dlg[line]
		end
		ar_talk_before(dlg, target)
		return AR_PICK_OLD(dlg, line)
	end
end

-- A chapter that ends a conversation with ar_pick_exit gets the other lines said first as well
if AR_FULL and not AR_PICK_EXIT_OLD then
	AR_PICK_EXIT_OLD = ar_pick_exit
	ar_pick_exit = function(dlg)
		ar_dialog_ready(dlg)
		if dlg.exit_lines and dlg.exit_lines[dlg.node] then
			ar_talk_before(dlg, dlg.exit_lines[dlg.node])
			-- (the talk ended in a sub-menu that does not come back, which the extras entered because it was to end now anyway)
			if AR_TALK_ENDED then
				ar_log("extra: the talk ended in a sub-menu, no exit line to say")
				return TRUE
			end
		elseif dlg.exit_lines and system.buttonHandler == dlg then
			-- (a node with no exit line, Salvador's fold_node: the talk ends there by a line that ends it)
			ar_talk_before(dlg, nil, TRUE)
			if AR_TALK_ENDED then
				ar_log("extra: the talk ended in a node with no exit line")
				return TRUE
			end
		end
		return AR_PICK_EXIT_OLD(dlg)
	end
end

-- The people of a set (AR_TALKERS in ex03_talkers.lua: the objects whose use starts a dialog) are used, and the dialog they open is talked through, before the
-- set is left or the chapter ends in it. AR_NO_PEOPLE["set name"] = "why" keeps a set out (ex00_sweep.lua).
AR_NO_PEOPLE = AR_NO_PEOPLE or { }
AR_TALKERS = AR_TALKERS or { }
-- Talks to one person (AR_TALK_OBJ): every line on offer, the nodes, and the end; while the dialog has a line left and the visit said something new,
-- the person is talked to again (at most 8 times): lines that come on only on a later visit, nodes with no way back, each ended in on its own visit
-- Waits until a dialog has the keys, or the game has had its normal controls back for 4 s (a use that opens no dialog; Manny walks to Salvador's
-- window before the menu shows)
ar_wait_dialog_or_control = function()
	local waited = 0
	local idle = 0
	while waited < 30000 and idle < 4000 and not (type(system.buttonHandler) == "table" and system.buttonHandler.exit_lines) do
		break_here()
		waited = waited + system.frameTime
		if ar_handler_normal() and cutSceneLevel == 0 and not IsMessageGoing() then
			idle = idle + system.frameTime
		else
			idle = 0
		end
	end
end
ar_talk_one = function()
	local obj = AR_TALK_OBJ
	local visits = 0
	local again = TRUE
	while again and visits < 8 and system.currentSet == obj.obj_set do
		again = nil
		visits = visits + 1
		local before = AR_TALK_NEW
		ar_do("use", obj)
		-- (a talk that starts with a scene of its own: the dialog comes when it is over; Salvador peeks out and Manny walks to the window first)
		ar_wait_dialog_or_control()
		local dlg = system.buttonHandler
		if type(dlg) == "table" and ar_dialog_name(dlg) ~= "?" then
			AR_TALKER_DLG[obj] = dlg
			ar_talk_before(dlg, nil)
			if system.buttonHandler == dlg then
				ar_pick_exit(dlg)
			end
			-- (and only when the dialog has a line left to say: a use with nothing to talk about moved Membrillo, chapter 35, and the morgue had no way left)
			if AR_TALK_NEW > before and ar_dialog_has_new(dlg) then
				again = TRUE
			end
		end
		ar_wait_for_control()
	end
end
-- The dialog each person opened (a later visit skips the person when it has nothing new: each walk to a person is a risk, the walk to Olivia in
-- chapter 19 crossed the door of the Blue Casket)
AR_TALKER_DLG = AR_TALKER_DLG or { }
-- One person of a set left alone: AR_NO_TALKER["<set name> <object field>"] = "why" (ex00_sweep.lua), or in one chapter only:
-- AR_NO_TALKER["<set name> <object field>@<chapter>"] (Meche took the gun only in chapter 44, where Manny holds it; her talks of 42 and 43 are kept)
AR_NO_TALKER = AR_NO_TALKER or { }
ar_no_talker = function(key)
	return AR_NO_TALKER[key] or AR_NO_TALKER[key .. "@" .. tostring(ar_cur_chapter())]
end
-- Whether the talk says line k of the dialog: a plain line, a move or a line that only ends the talk, not one a chapter picks later
ar_talk_sayable = function(dlg, k)
	local name = ar_dialog_name(dlg)
	if ar_picked_later(name, k) then
		return nil
	end
	if not (AR_NO_AUTO[name] and AR_NO_AUTO[name][k]) then
		return TRUE
	end
	return ar_is_move(name, k) or (AR_DLG_END and AR_DLG_END[name] and AR_DLG_END[name][k])
end
-- Whether a dialog has a line that is not said yet and not off (the lines the game could still offer; lines of nodes not reached count too)
ar_dialog_has_new = function(dlg)
	local name = ar_dialog_name(dlg)
	local home = AR_DLG_HOME[name] or dlg.node
	local moves = AR_DLG_MOVE[name] or { }
	-- (the nodes the talk can still get to from home, by the lines that move and are on)
	local reach = { }
	reach[home] = TRUE
	local changed = TRUE
	while changed do
		changed = nil
		local n, to = next(moves, nil)
		while n do
			local v = dlg[n]
			if not reach[to] and type(v) == "table" and not v.off and not ar_picked_later(name, n) then
				local x = next(reach, nil)
				while x do
					if v[x] then
						reach[to] = TRUE
						changed = TRUE
					end
					x = next(reach, x)
				end
			end
			n, to = next(moves, n)
		end
		-- (a line with several nodes: all of them)
		local l = nil
		n, l = next((AR_DLG_MOVES and AR_DLG_MOVES[name]) or { }, nil)
		while n do
			local v = dlg[n]
			if type(v) == "table" and not v.off and not ar_picked_later(name, n) and ar_dialog_in(v, reach) then
				local j = 1
				while l[j] do
					if not reach[l[j]] then
						reach[l[j]] = TRUE
						changed = TRUE
					end
					j = j + 1
				end
			end
			n, l = next(AR_DLG_MOVES[name], n)
		end
	end
	-- (a line the talk would say, in a node it can get to: off too in home, where a later visit's intro turns lines on (Salvador's 110); not one in a
	-- node it can no longer get to (Carla's 51 to 53: a second visit only said goodbye, and chapter 18 then hung))
	local k, v = next(dlg, nil)
	while k do
		if type(k) == "number" and type(v) == "table" and v.text and not AR_SAID[v] and ar_talk_sayable(dlg, k) and (v[home] or (not v.off and ar_dialog_in(v, reach))) then
			return TRUE
		end
		k, v = next(dlg, k)
	end
	return nil
end
-- Whether line v belongs to one of the nodes of the set
ar_dialog_in = function(v, nodes)
	local x = next(nodes, nil)
	while x do
		if v[x] then
			return TRUE
		end
		x = next(nodes, x)
	end
	return nil
end
-- Whether a person's dialog (AR_TALKER_DLGS of ex03_talkers.lua) is talked in by this chapter or a later one (AR_DLG_LAST): only opening and closing
-- Celso's talk before chapter 13 broke the chapter's own talk with him
ar_talker_left = function(key)
	local list = AR_TALKER_DLGS and AR_TALKER_DLGS[key]
	local now = ar_cur_chapter()
	local i = 1
	while list and list[i] and now do
		if AR_DLG_LAST and AR_DLG_LAST[list[i]] and not (AR_DLG_LAST[list[i]] < now) then
			return TRUE
		end
		i = i + 1
	end
	return nil
end
ar_talk_people = function()
	local set = system.currentSet
	local global = ar_set_global(set)
	if not global or not AR_TALKERS[global] or AR_NO_PEOPLE[set.name] then
		if AR_TRIP then
			ar_log("extra: no people step in " .. tostring(set.name) .. " (global " .. tostring(global) .. ")")
		end
		return
	end
	local list = AR_TALKERS[global]
	local i = 1
	while list[i] and system.currentSet == set do
		local obj = set[list[i]]
		if type(obj) ~= "table" or not obj.touchable or obj.owner then
			ar_log("extra: " .. list[i] .. " in " .. tostring(set.name) .. " is not there to talk to")
		else
			-- (a person whose dialog a chapter talks in, this one or a later one, is talked to too: the chapter's own talk picks its lines after, and a
			-- talk that breaks it is blocked for that chapter, AR_NO_TALKER "<set> <field>@<chapter>")
			if ar_no_talker(tostring(set.name) .. " " .. list[i]) then
				ar_log("extra: no talk to " .. list[i] .. " in " .. tostring(set.name) .. " (" .. ar_no_talker(tostring(set.name) .. " " .. list[i]) .. ")")
			elseif AR_TALKER_DLG[obj] and not ar_dialog_has_new(AR_TALKER_DLG[obj]) then
				ar_log("extra: nothing new to say to " .. list[i] .. " in " .. tostring(set.name))
			else
				AR_TALK_OBJ = obj
				ar_extra_run("people " .. tostring(set.name) .. " " .. list[i], ar_talk_one)
			end
		end
		i = i + 1
	end
end
-- Every dialog line the game says is a COV say line (100% modes), also one a script says by itself, not chosen from the menu: chapter 2 uses the work
-- order on Eva, and the game says her line 2 for it (Dialog.execute_line, which every dialog has from Dialog, its parent)
if AR_FULL and Dialog and Dialog.execute_line and not AR_EXEC_LINE_OLD then
	AR_EXEC_LINE_OLD = Dialog.execute_line
	Dialog.execute_line = function(d, line, nowait)
		local l = line
		if type(l) ~= "table" and d.current_choices then
			l = d.current_choices[line]
		end
		if type(l) == "table" and l.text then
			ar_cov("say | " .. tostring(l.text))
		end
		return AR_EXEC_LINE_OLD(d, line, nowait)
	end
end
AR_PEOPLE_DONE = AR_PEOPLE_DONE or { }
if AR_FULL and not AR_SWEEP_OLD then
	AR_SWEEP_OLD = ar_sweep
	ar_sweep = function()
		ar_people_once()
		return AR_SWEEP_OLD()
	end
end
-- The people of the set, once a chapter (not once a game: the lines a dialog offers change with the story, and AR_SAID keeps what was said from being
-- said again): before the set is left by a door or the chapter ends in it, and before a chapter's own use of one of the people, which can move the story
-- on and leave the set without a door (Membrillo in the morgue, chapter 35: the detector on him)
ar_people_once = function()
	local key = tostring(AR_FRAME_CH or AR_CHAPTER) .. "|" .. tostring(system.currentSet and system.currentSet.name)
	if AR_FULL and not AR_IN_EXTRA and system.currentSet and cutSceneLevel == 0 and ar_handler_normal() and not AR_PEOPLE_DONE[key] then
		AR_PEOPLE_DONE[key] = TRUE
		ar_talk_people()
	end
end
-- A side trip, called by a chapter (100% modes only, nothing in the others): through a door to a set the story does not go into while someone is there,
-- everything there looked at, the people picked up, given the items Manny has code for and talked to, and back through the door of that set. Chapter 4:
-- Domino boxes in his office only between Bruno and Meche.
--   ar_side_trip(ha.do_door, dom, dom.ha_door)
ar_side_trip = function(door, target, back)
	if not AR_FULL then
		return
	end
	-- (the door trips of the set first: the kitchen of chapter 19 is left by its heavy step, and the side trip to Aitor is the next time Manny is
	-- there with the control)
	ar_door_trips(system.currentSet)
	AR_TRIP = { door, target, back }
	ar_extra_run("side trip " .. tostring(system.currentSet.name) .. " -> " .. tostring(target.name), ar_side_trip_run)
	AR_TRIP = nil
end
ar_side_trip_run = function()
	local door, target, back = AR_TRIP[1], AR_TRIP[2], AR_TRIP[3]
	local from = system.currentSet
	AR_GO_OLD(door, target)
	ar_wait_for_control()
	if system.currentSet ~= target then
		ar_log("extra: the side trip did not get to " .. tostring(target.name))
		return
	end
	-- (the looks first: the talk can end with Manny sent out, Domino does. Looks only, which change nothing; they are not the sweep of the set, which
	-- a later chapter that goes in does as well, when what the looks say has changed)
	ar_look_all(target)
	-- (the people, picked up and given the items: only here, where the person is not there on the chapters' own visits)
	local list = AR_TALKERS[ar_set_global(target)]
	local i = 1
	while list and list[i] and system.currentSet == target do
		local obj = target[list[i]]
		if type(obj) == "table" and obj.touchable and not obj.owner then
			if ar_has_verb(obj, "pickUp") then
				ar_do("pickUp", obj)
			end
			ar_items_on(obj)
		end
		i = i + 1
	end
	ar_talk_people()
	ar_wait_for_control()
	if system.currentSet == target and cutSceneLevel == 0 then
		AR_GO_OLD(back, from)
		ar_wait_for_control()
	end
end
-- Whether the object is one of the people of the current set (AR_TALKERS)
ar_is_talker = function(obj)
	local set = system.currentSet
	local global = ar_set_global(set)
	local list = global and AR_TALKERS[global]
	local i = 1
	while list and list[i] do
		if set[list[i]] == obj then
			return TRUE
		end
		i = i + 1
	end
	return nil
end
