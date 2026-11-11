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
		if verb == "use" and not AR_IN_EXTRA and ar_is_talker and ar_is_talker(noun1) then
			-- (Manny stays by the person after the talk: he is about to use them, and the walk back and to them again ended out of reach of Chepito, who
			-- moves about the mine, chapters 41 and 42)
			AR_NO_PUT_BACK = TRUE
			ar_people_once()
			AR_NO_PUT_BACK = nil
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
ar_look_all = function(set)
	if system.currentSet ~= set then
		return
	end
	local list, n = ar_set_objects(set)
	local i = 1
	while i <= n and system.currentSet == set do
		local o = list[i]
		-- (a door is not looked at here: standing at it is standing in its door sector, and the game walks Manny out)
		if o.touchable and not o.owner and o.range and o.range > 0 and not o.walkOut and not o.climbOut and not AR_NO_LOOK[o.string_name] and ar_has_verb(o, "lookAt") then
			ar_do("lookAt", o)
		end
		i = i + 1
	end
end

-- Uses and picks up what the set has code for, except the objects the caller names (a table keyed by object: doors, and what moves the story on).
-- Doors are never used here, the chapters walk through them.
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
			if ar_has_verb(o, "pickUp") then
				ar_do("pickUp", o)
				ar_settle()
			end
			if system.currentSet == set and ar_has_verb(o, "use") and not except[o] then
				ar_do("use", o)
				ar_settle()
			end
			ar_left_by(set, o, before)
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
		if item.owner == manny and obj[ "use_" .. trim_header(item.string_name) ]
			and not (item == mo.scythe and system.currentSet.setFile and in(system.currentSet.setFile, no_scythe_sets)) then
			ar_do("use", obj, item)
		end
		i = i + 1
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
			ar_log("setups: the middle of " .. tostring(c.name) .. " is off the floor, not visited")
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
ar_visit_set = function()
	ar_look_all(AR_VISIT_SET)
	ar_visit_setups(AR_VISIT_SET)
end
ar_sweep = function()
	-- (not while a handler of its own has the keys: in the Bone Wagon at the end of chapter 56 the items step left the remote in hand, and the
	-- inventory key of chapter 57 then put it away instead of taking it out)
	if not AR_FULL or not system.currentSet or cutSceneLevel > 0 or not ar_handler_normal() then
		return
	end
	local name = system.currentSet.name
	if AR_VISITED[name] then
		return
	end
	AR_VISITED[name] = TRUE
	if AR_NO_SWEEP[name] then
		ar_log("extra: no sweep of " .. tostring(name) .. " (" .. AR_NO_SWEEP[name] .. ")")
		return
	end
	AR_VISIT_SET = system.currentSet
	ar_extra_run("visit " .. tostring(name), ar_visit_set)
	-- (use, pick up and the items: as a step of its own, so that a set where it breaks the story loses only this)
	if system.currentSet == AR_VISIT_SET and not AR_NO_HEAVY[name] then
		ar_extra_run("heavy " .. tostring(name), ar_heavy_set)
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
-- Whether this chapter or a later one picks line n of the dialog itself (AR_DLG_PICKS): such a line is left to that pick
ar_picked_later = function(name, n)
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

-- Says one line (an extra of its own: what fails in it is logged, the story goes on)
AR_TALK_N = AR_TALK_N or 0
ar_talk_say = function(name, dlg, c, what)
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
-- the talk ends in it (ar_talk_ended tells the caller). One level of sub-menus; each is entered once a visit.
ar_talk_before = function(dlg, target)
	local name = ar_dialog_name(dlg)
	-- (first: a dialog of AR_NO_TALK returns at once, and a TRUE left from an earlier talk made ar_pick_exit leave Celso's talk open, chapter 13)
	AR_TALK_ENDED = nil
	if AR_NO_TALK[name] or not dlg.current_choices then
		return
	end
	-- (an extra says nothing in a dialog that this chapter or a later one talks in itself, AR_DLG_LAST of ex04_dlg_later.lua, chapter 14: the people step
	-- said all of Lupe before the chapter used her, and her talk did not open again. Celso's pitch said by the people step
	-- at the end of chapter 59 took the line chapter 60 picks. That chapter's own talk says the lines, before its pick)
	local now = ar_cur_chapter()
	if AR_IN_EXTRA and AR_DLG_LAST and AR_DLG_LAST[name] and now and not (AR_DLG_LAST[name] < now) then
		ar_log("extra: " .. name .. " is left to " .. AR_DLG_LAST[name])
		return
	end
	local failed = AR_FAILED
	local keep = AR_KEEP_GOING
	AR_KEEP_GOING = TRUE
	local home = dlg.node
	local ending = target and dlg.exit_lines and target == dlg.exit_lines[home]
	local entered = { }
	local last_sub = nil
	local rounds = 0
	local picked = TRUE
	while picked and rounds < 80 and system.buttonHandler == dlg do
		picked = nil
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
		if not picked and dlg.node ~= home and system.buttonHandler == dlg then
			-- a sub-menu talked through: back by a line that moves home, or by its exit line
			local sub = dlg.node
			local back = ar_talk_mover(name, dlg, home)
			if back then
				ar_talk_say(name, dlg, back, " (back to " .. tostring(home) .. ")")
			elseif AR_DLG_EXIT[name] and AR_DLG_EXIT[name][sub] == home and dlg.exit_lines[sub] then
				ar_log("extra: talk " .. name .. " exit of " .. tostring(sub))
				AR_PICK_OLD(dlg, dlg.exit_lines[sub])
				ar_log("extra: done talk " .. name .. " exit of " .. tostring(sub))
			elseif ending and dlg.exit_lines[sub] then
				-- (a sub-menu that does not come back, entered because the talk was to end anyway: its exit ends it)
				ar_log("extra: talk " .. name .. " exit of " .. tostring(sub) .. " (ends the talk)")
				AR_PICK_EXIT_OLD(dlg)
				ar_log("extra: done talk " .. name .. " exit of " .. tostring(sub))
			end
			picked = TRUE
			if system.buttonHandler == dlg and dlg.node ~= home then
				ar_log("extra: talk " .. name .. ": could not come back from " .. tostring(sub) .. " to " .. tostring(home))
				picked = nil
			end
		elseif not picked and dlg.node == home and system.buttonHandler == dlg then
			-- a sub-menu not entered yet that the talk comes back from (or, when it is to end anyway, one that does not, but only when no other is left)
			local moves = AR_DLG_MOVE[name]
			local best = nil
			local best_back = nil
			i = 1
			while moves and dlg.current_choices and dlg.current_choices[i] do
				local c = dlg.current_choices[i]
				local n = ar_line_number(dlg, c)
				local to = n and moves[n]
				if to and to ~= home and not entered[to] and not AR_SAID[c] and c ~= target then
					if ar_talk_returns(name, dlg, to, home) then
						best_back = best_back or c
					elseif ending then
						best = best or c
					end
				end
				i = i + 1
			end
			local c = best_back or best
			if c then
				local n = ar_line_number(dlg, c)
				entered[moves[n]] = TRUE
				ar_talk_say(name, dlg, c, " (into " .. tostring(moves[n]) .. ")")
				picked = TRUE
			end
		end
		rounds = rounds + 1
	end
	-- (the talk is to end now anyway: one line that does nothing but end it, AR_DLG_END, in place of the exit line; the others on a later visit)
	if ending and system.buttonHandler == dlg and dlg.node == home and AR_DLG_END[name] then
		local i = 1
		local c = nil
		while dlg.current_choices and dlg.current_choices[i] and not c do
			local n = ar_line_number(dlg, dlg.current_choices[i])
			if n and AR_DLG_END[name][n] and not AR_SAID[dlg.current_choices[i]] then
				c = dlg.current_choices[i]
			end
			i = i + 1
		end
		if c then
			ar_talk_say(name, dlg, c, " (ends the talk)")
		end
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
		ar_talk_before(dlg, target)
		return AR_PICK_OLD(dlg, line)
	end
end

-- A chapter that ends a conversation with ar_pick_exit gets the other lines said first as well
if AR_FULL and not AR_PICK_EXIT_OLD then
	AR_PICK_EXIT_OLD = ar_pick_exit
	ar_pick_exit = function(dlg)
		if dlg.exit_lines and dlg.exit_lines[dlg.node] then
			ar_talk_before(dlg, dlg.exit_lines[dlg.node])
			-- (the talk ended in a sub-menu that does not come back, which the extras entered because it was to end now anyway)
			if AR_TALK_ENDED then
				ar_log("extra: the talk ended in a sub-menu, no exit line to say")
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
-- Talks to one person (AR_TALK_OBJ): every line on offer, the sub-menus, and the end; when the talk ended on a line that only ends it and that visit said
-- something new, the person is talked to again, for the lines left (at most 4 times)
ar_talk_one = function()
	local obj = AR_TALK_OBJ
	local visits = 0
	local again = TRUE
	while again and visits < 4 and system.currentSet == obj.obj_set do
		again = nil
		visits = visits + 1
		local before = AR_TALK_N
		ar_do("use", obj)
		local dlg = system.buttonHandler
		if type(dlg) == "table" and ar_dialog_name(dlg) ~= "?" then
			AR_TALKER_DLG[obj] = dlg
			ar_talk_before(dlg, nil)
			if system.buttonHandler == dlg then
				ar_pick_exit(dlg)
			end
			-- (and only when the dialog has a line left to say: a use with nothing to talk about moved Membrillo, chapter 35, and the morgue had no way left)
			if AR_TALK_ENDED and AR_TALK_N > before and ar_dialog_has_new(dlg) then
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
-- Whether a dialog has a line that is not said yet and not off (the lines the game could still offer; lines of nodes not reached count too)
ar_dialog_has_new = function(dlg)
	local k, v = next(dlg, nil)
	while k do
		if type(k) == "number" and type(v) == "table" and v.text and not v.off and not AR_SAID[v] then
			return TRUE
		end
		k, v = next(dlg, k)
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
			if ar_talker_left(global .. "." .. list[i]) then
				ar_log("extra: no talk to " .. list[i] .. " in " .. tostring(set.name) .. " (its dialog is left to the chapter that talks in it)")
			elseif ar_no_talker(tostring(set.name) .. " " .. list[i]) then
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
