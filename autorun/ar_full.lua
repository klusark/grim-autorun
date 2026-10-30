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
		if o.touchable and not o.owner and o.range and o.range > 0 and not o.walkOut and not o.climbOut and ar_has_verb(o, "lookAt") then
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
			end
			if system.currentSet == set and ar_has_verb(o, "use") and not except[o] then
				ar_do("use", o)
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

-- The sets that a 100% run looks over the first time it is in them (a door walked through, a set expected): AR_SWEEP["set name"] = TRUE, switched on by
-- the extras files once the sweep has been tried in that set. It is not on for every set: where Manny arrives on floor that only the sectors that are off
-- give a way over (the garage, at the elevator), or the objects move the floor (the hallway elevators), the look at everything strands him or takes him
-- out through a door. Objects and setups only: nothing that uses or takes.
AR_VISITED = AR_VISITED or { }
AR_SWEEP = AR_SWEEP or { }
ar_visit_set = function()
	ar_look_all(AR_VISIT_SET)
	ar_visit_setups(AR_VISIT_SET)
end
ar_arrived = function()
	if not AR_FULL or not system.currentSet or cutSceneLevel > 0 then
		return
	end
	if AR_VISITED[system.currentSet.name] then
		return
	end
	AR_VISITED[system.currentSet.name] = TRUE
	if not AR_SWEEP[system.currentSet.name] then
		return
	end
	AR_VISIT_SET = system.currentSet
	ar_extra_run("visit " .. tostring(system.currentSet.name), ar_visit_set)
end
if AR_FULL and not AR_GO_OLD then
	AR_GO_OLD = ar_go
	AR_EXPECT_OLD = ar_expect_set
	ar_go = function(door, target, vx, vy, vz)
		local r = AR_GO_OLD(door, target, vx, vy, vz)
		ar_arrived()
		return r
	end
	ar_expect_set = function(target, label)
		local r = AR_EXPECT_OLD(target, label)
		ar_arrived()
		return r
	end
end
