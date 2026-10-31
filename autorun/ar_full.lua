-- The 100% modes (speed100, full100: AR_FULL, see MODES_PLAN.md): helpers that do everything there is to do in a place, and ar_extra, the hook the chapters call
-- where a 100% run has more to do. In the other modes ar_extra does nothing, so those runs are not changed by a frame.
-- Lua 3.1: no for loops, no # operator, no local functions.

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

ar_extra_run = function(tag, f)
	ar_log("extra: " .. tag)
	local failed = AR_FAILED
	local keep = AR_KEEP_GOING
	AR_FAILED = nil
	AR_KEEP_GOING = TRUE
	ar_wait_for_control()
	-- (the extras walk about: Manny is put back where he stood, so that the story goes on from there)
	local back = manny:getpos()
	AR_EX_SET = system.currentSet
	AR_EX_X, AR_EX_Y, AR_EX_Z = back.x, back.y, back.z
	f()
	ar_wait_for_control()
	if system.currentSet == AR_EX_SET then
		local now = manny:getpos()
		-- (not onto a spot that is no floor now, such as the sector of a door that Manny came through: the game would take him out through it)
		local nav = ar_nav_of(AR_EX_SET)
		if abs(now.x - AR_EX_X) + abs(now.y - AR_EX_Y) > 0.3 and nav and ar_nav_find(nav, AR_EX_X, AR_EX_Y, AR_EX_Z) then
			ar_walk_to(AR_EX_X, AR_EX_Y, AR_EX_Z)
			ar_wait_for_control()
		end
	end
	if AR_FAILED then
		AR_EXTRA_MISS = AR_EXTRA_MISS + 1
		ar_log("extra: " .. tag .. " did not all work")
	end
	AR_KEEP_GOING = keep
	AR_FAILED = failed
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

-- The objects of a set (the ones Object:create made for it), the nearest to Manny first, each once
ar_set_objects = function(set)
	local list = { }
	local n = 0
	local seen = { }
	local k, v = next(set, nil)
	while k do
		if type(v) == "table" and v.obj_set == set and v.name and v.obj_x and not seen[v] then
			seen[v] = TRUE
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
		if o.touchable and not o.owner and o.range and o.range > 0 and not except[o] and not o.walkOut and not o.climbOut then
			if ar_has_verb(o, "pickUp") then
				ar_do("pickUp", o)
				ar_settle()
			end
			if system.currentSet == set and ar_has_verb(o, "use") and not except[o] then
				ar_do("use", o)
				ar_settle()
			end
		end
		i = i + 1
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
		if item.owner == manny and obj[ "use_" .. trim_header(item.string_name) ] then
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
		if o.touchable and not o.owner and o.range and o.range > 0 and not o.walkOut and not o.climbOut and not AR_NO_ITEMS[o.string_name] then
			ar_items_on(o)
			ar_settle()
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
	if not AR_FULL or not system.currentSet or cutSceneLevel > 0 then
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

ar_talk_before = function(dlg, target)
	local name = ar_dialog_name(dlg)
	if AR_NO_TALK[name] or not dlg.current_choices then
		return
	end
	local failed = AR_FAILED
	local keep = AR_KEEP_GOING
	AR_KEEP_GOING = TRUE
	local said = 0
	local rounds = 0
	local picked = TRUE
	while picked and rounds < 60 and system.buttonHandler == dlg do
		picked = nil
		local i = 1
		while dlg.current_choices and dlg.current_choices[i] and not picked do
			local c = dlg.current_choices[i]
			local n = ar_line_number(dlg, c)
			if c ~= target and c ~= dlg.exit_lines[dlg.node] and not AR_SAID[c] and n and not (AR_NO_AUTO[name] and AR_NO_AUTO[name][n]) then
				AR_SAID[c] = TRUE
				ar_log("extra: talk " .. name .. " " .. tostring(n))
				AR_PICK_OLD(dlg, c)
				ar_log("extra: done talk " .. name .. " " .. tostring(n))
				said = said + 1
				picked = TRUE
			end
			i = i + 1
		end
		rounds = rounds + 1
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
		end
		return AR_PICK_EXIT_OLD(dlg)
	end
end

-- The people of a set (AR_TALKERS in ex03_talkers.lua: the objects whose use starts a dialog) are used, and the dialog they open is talked through, before the
-- set is left or the chapter ends in it. AR_NO_PEOPLE["set name"] = "why" keeps a set out (ex00_sweep.lua).
AR_NO_PEOPLE = AR_NO_PEOPLE or { }
AR_TALKERS = AR_TALKERS or { }
ar_talk_one = function()
	local obj = AR_TALK_OBJ
	ar_do("use", obj)
	local dlg = system.buttonHandler
	if type(dlg) == "table" and ar_dialog_name(dlg) ~= "?" then
		ar_talk_before(dlg, nil)
		if system.buttonHandler == dlg then
			ar_pick_exit(dlg)
		end
	end
	ar_wait_for_control()
end
ar_talk_people = function()
	local set = system.currentSet
	-- (the global of a set is the name of its set file: ha.set is ha)
	local global = set.setFile and strsub(set.setFile, 1, strlen(set.setFile) - 4)
	if not global or not AR_TALKERS[global] or AR_NO_PEOPLE[set.name] then
		return
	end
	local list = AR_TALKERS[global]
	local i = 1
	while list[i] and system.currentSet == set do
		local obj = set[list[i]]
		if type(obj) == "table" and obj.touchable and not obj.owner then
			AR_TALK_OBJ = obj
			ar_extra_run("people " .. tostring(set.name) .. " " .. list[i], ar_talk_one)
		end
		i = i + 1
	end
end
AR_PEOPLE_DONE = AR_PEOPLE_DONE or { }
if AR_FULL and not AR_SWEEP_OLD then
	AR_SWEEP_OLD = ar_sweep
	ar_sweep = function()
		if AR_FULL and system.currentSet and cutSceneLevel == 0 and not AR_PEOPLE_DONE[system.currentSet.name] then
			AR_PEOPLE_DONE[system.currentSet.name] = TRUE
			ar_talk_people()
		end
		return AR_SWEEP_OLD()
	end
end
