-- Act 3 helpers (loaded after emi_lib.lua via EXTRA)
AR_TIMEOUT = 60000000

-- A walk that is cut short by a change of set (a wild monkey on the map takes Guybrush to the jungle) must not die in the stand-point
-- search: the object belongs to the old set.
A3_SP_ORIG = ar_stand_points
ar_stand_points = function(obj)
	if AR_DOOR_SET and system.currentSet ~= AR_DOOR_SET then
		return { }, 0
	end
	return A3_SP_ORIG(obj)
end

A3_SET_JUN = "Monkey Island Jungle"
-- The jungle's way back to the map: the set tables are built while the set is entered (the name is there before the door object is)
a3_jun_door = function()
	ar_try_wait(function() return jun and jun.mom_doorr and cutSceneLevel == 0 end, 20000)
	return jun and jun.mom_doorr
end
A3_SET_MOM = "Monkey Island Map"

-- Walks to a door of the map (mom.xxx_door) and through it; a wild monkey that catches Guybrush on the way (the jungle set) is left
-- by the jungle's way back and the walk tried again. `want` is the set name the door leads to.
a3_go = function(door, want)
	local tries = 0
	local keep = AR_KEEP_GOING
	while tries < 8 do
		if A3_STAY_JUN and ar_set_name() == A3_SET_JUN then
			return TRUE
		end
		if ar_set_name() == A3_SET_JUN then
			ar_log("caught by a monkey in the jungle, going back")
			ar_do("use", a3_jun_door())
			ar_wait_for_control()
		end
		AR_KEEP_GOING = TRUE
		AR_FAILED = FALSE
		ar_do("use", door)
		AR_KEEP_GOING = keep
		ar_wait_for_control()
		if ar_set_name() == want then
			AR_FAILED = FALSE
			return TRUE
		end
		tries = tries + 1
	end
	return ar_fail("could not get through " .. tostring(door.name) .. " to " .. tostring(want) .. ", in " .. ar_set_name())
end

A3_FACE_ORIG = ar_face
ar_face = function(obj)
	if AR_DOOR_SET and system.currentSet ~= AR_DOOR_SET then
		return
	end
	return A3_FACE_ORIG(obj)
end
A3_WALK_ORIG = ar_walk_to
ar_walk_to = function(x, y, z, stop_when, max_ms)
	if AR_DOOR_SET and system.currentSet ~= AR_DOOR_SET then
		return
	end
	return A3_WALK_ORIG(x, y, z, stop_when, max_ms)
end

-- Walk planning keeps out of the trigger boxes (HOT sectors) of doors other than the one walked to: on the island map the paths
-- pass right through them and the game walks Guybrush out of the set on contact.
A3_CELL_ORIG = ar_cell_y
A3_HOTC = { }
A3_HOTC_SET = nil
a3_hot_door = function(x, y, z)
	local set = ar_set_name()
	if A3_HOTC_SET ~= set then
		A3_HOTC_SET = set
		A3_HOTC = { }
	end
	local key = (floor(x * 4 + 0.5) + 2000) * 100000 + (floor(z * 4 + 0.5) + 2000) * 40 + floor(y * 2 + 0.5) + 20
	local c = A3_HOTC[key]
	if c == nil then
		c = 0
		local id, name = GetPointSector(x, y, z, HOT)
		if id and name then
			local o = system.currentSet[tostring(name)]
			-- (only the doors: the other triggers (the mouth of the Monkey Head, the ends of the lone palm tree) are floor to walk over)
			if type(o) == "table" and o.walkOut and strfind(tostring(name), "door", 1, TRUE) then
				c = o
			end
		end
		A3_HOTC[key] = c
	end
	if c == 0 then
		return nil
	end
	return c
end
ar_cell_y = function(x, z, y)
	local ny, cheat = A3_CELL_ORIG(x, z, y)
	if ny and not cheat then
		local d = a3_hot_door(x, ny, z)
		if d and not A3_NO_AVOID and d ~= A3_TARGET_OBJ and d ~= A3_START_OBJ then
			return nil
		end
	end
	return ny, cheat
end
A3_APPROACH_ORIG = ar_approach
ar_approach = function(obj)
	A3_TARGET_OBJ = obj
	local r = A3_APPROACH_ORIG(obj)
	A3_TARGET_OBJ = nil
	return r
end

-- The island as a graph: every place is reached from the map (mom). a3_to_map() leaves the current place for the map, a3_goto(place)
-- goes from wherever Guybrush is to the place (names are the set names).
a3_exit_door = function()
	local s = ar_set_name()
	if s == "monkey beach" then return mib.mom_door end
	if s == "toothrot camp" then return toc.mom_door end
	if s == "canyon" then
		-- (the canyon's two doors lead to different pieces of the map: the plateau has the right one)
		if manny:getpos().y > 5 then
			return can.mom_door_right
		end
		return can.mom_door_left
	end
	if s == "monkey head" then return moh.mom_door end
	if s == "monkey town" then return mon.mom_door end
	if s == "Pachinko Rock" then return pac.mom_door end
	if s == "church of lechuck" then return col.lav_door end
	if s == "field of lava" then return lav.mom_door_path end
	return nil
end
a3_map_door = function(place)
	if place == "monkey beach" then return mom.mib_door end
	if place == "toothrot camp" then return mom.toc_door end
	if place == "canyon" then return mom.can_door_left end
	if place == "monkey head" then return mom.moh_door end
	if place == "monkey town" then return mom.mon_door end
	if place == "Pachinko Rock" then return mom.sco_door end
	if place == "field of lava" then return mom.lav_door end
	if place == "church of lechuck" then return mom.col_door end
	return nil
end
a3_to_map = function()
	local s = ar_set_name()
	if s == A3_SET_MOM then
		return TRUE
	end
	if s == A3_SET_JUN then
		ar_do("use", a3_jun_door())
		ar_wait_for_control()
		return ar_set_name() == A3_SET_MOM
	end
	local d = a3_exit_door()
	if not d then
		return ar_fail("no known way out of " .. s .. " to the map")
	end
	ar_do("use", d)
	ar_wait_for_control()
	return ar_set_name() == A3_SET_MOM
end
a3_goto = function(place)
	if ar_set_name() == place then
		return TRUE
	end
	a3_to_map()
	local d = a3_map_door(place)
	if not d then
		return ar_fail("no map door to " .. place)
	end
	return a3_go(d, place)
end

-- Asks every line the dialog offers (each once, lowest number first), says the exit line of a node when nothing new is left; the
-- exit line of the first node ends the conversation. skip: table of line numbers not to pick.
a3_ask_all = function(name, skip)
	local used = { }
	local guard = 0
	local d = a3_dlg_running(name, 900000)
	while d and d.running and guard < 300 do
		guard = guard + 1
		ar_dialog_ready(d, 20000)
		if d.running then
			local best = nil
			local k, v = next(d, nil)
			while k do
				if type(k) == "number" and type(v) == "table" and v.text and v[d.node] and not v.off and not used[k] and not (skip and skip[k]) and (not best or k < best) then
					best = k
				end
				k, v = next(d, k)
			end
			if best then
				used[best] = TRUE
				ar_pick(d, best)
			else
				ar_pick_exit(d)
			end
			sleep_for(600)
		end
	end
end
a3_auto_dialog = function()
	a3_ask_all(A3_DLG, A3_DLG_SKIP)
end
a3_dialog = function(name, skip)
	A3_DLG = name
	A3_DLG_SKIP = skip
	return start_script(a3_auto_dialog)
end

-- (the guards above only hold while a verb is being given)
A3_DO_ORIG = ar_do
ar_do = function(verb, noun1, noun2)
	local r = A3_DO_ORIG(verb, noun1, noun2)
	AR_DOOR_SET = nil
	return r
end

AR_CONTROL_TIMEOUT = 600000
-- A conversation left at once (the exit line of its first node)
a3_quick_dialog_task = function()
	local d = a3_dlg_running(A3_DLG, 900000)
	if d then
		ar_say_exit(A3_DLG)
	end
end
a3_quick_dialog = function(name)
	A3_DLG = name
	return start_script(a3_quick_dialog_task)
end

-- A map of the walkable floor at any height (sloped sets): one character per cell, the sector id mod 36, 'M' Guybrush
a3_map = function(x0, x1, z0, z1, step, y0, y1)
	local p = manny:getpos()
	local z = z1
	ar_log(format("A3MAP set %s x %.0f..%.0f", ar_set_name(), x0, x1))
	while z >= z0 do
		local row = ""
		local x = x0
		while x <= x1 do
			local c = "."
			local y = y0 or -1
			while y <= (y1 or 20) and c == "." do
				local id = GetPointSector(x, y, z)
				if id then
					c = strsub("abcdefghijklmnopqrstuvwxyz0123456789", mod(id, 36) + 1, mod(id, 36) + 1)
				end
				y = y + (A3_YSTEP or 0.25)
			end
			if abs(x - p.x) < step / 2 and abs(z - p.z) < step / 2 then
				c = "M"
			end
			row = row .. c
			x = x + step
		end
		ar_log(format("A3MAP %6.1f ", z) .. row)
		z = z - step
	end
end

-- (the box Guybrush stands in when a walk starts is not avoided: he comes out of a door inside its trigger box)
A3_CELL_ORIG2 = ar_cell_y
ar_cell_y = function(x, z, y)
	return A3_CELL_ORIG2(x, z, y)
end
A3_APPROACH_ORIG2 = ar_approach
ar_approach = function(obj)
	local p = manny:getpos()
	A3_START_OBJ = a3_hot_door(p.x, p.y, p.z)
	local r = A3_APPROACH_ORIG2(obj)
	A3_START_OBJ = nil
	return r
end

-- A conversation where exactly these lines are picked, in order (then the exit line if it is still running)
a3_lines_task = function()
	local d = a3_dlg_running(A3_DLG, 900000)
	local i = 1
	while d and d.running and A3_LINES[i] do
		ar_dialog_ready(d, 30000)
		if d.running then
			ar_pick(d, A3_LINES[i])
			sleep_for(600)
		end
		i = i + 1
	end
	if d and d.running then
		ar_pick_exit(d)
	end
end
a3_dialog_lines = function(name, lines)
	A3_DLG = name
	A3_LINES = lines
	return start_script(a3_lines_task)
end

-- The lava ride (church of LeChuck -> boat down the flume, lava_flume2.lua). Left/right keys choose the branch at a fork; the bot
-- taps the key for the next step of the shortest way to the node where the milk bottle shows up (puzzle 1: node 9, puzzle 2: node 12).
-- The planner of the lava ride. The other boats sit on their nodes (node.blocked is the boat) like bumpers: a boat that is run into leaves
-- its node by the opposite branch, and the boat that ran into it is turned to the other branch of the node it came from (or of the node's
-- "backbounce" node: the chain 10-11-12 bounces back to node 8). A node whose boat was just kicked out is free for a while.
-- Breadth first search over (node, kicked boats) with that rule; returns the first direction (1 left, 2 right) toward the target.
a3_flume_first_dir = function(from, target)
	if from == target then
		return nil
	end
	local queue = { }
	local qn = 1
	queue[1] = { from, "", nil, nil }
	local head = 1
	local seen = { }
	seen[from.name .. "|"] = TRUE
	local steps = 0
	while head <= qn and steps < 4000 do
		steps = steps + 1
		local st = queue[head]
		head = head + 1
		local n = st[1]
		local kicked = st[2]
		local first = st[3]
		local forced = st[4]
		local d = 1
		while d <= 2 do
			if (not forced or forced == d) and n.branches[d] and type(n.branches[d]) == "table" then
				local b = n.branches[d]
				local f = first
				if not f then
					f = d
				end
				local occupied = type(b.blocked) == "table" and not strfind(kicked, "," .. b.name .. ",", 1, TRUE)
				if b == target and (not occupied or TRUE) and not occupied then
					return f
				end
				if b.is_sink and b ~= target then
					-- (never leave the ride by accident)
				elseif not occupied then
					local key = b.name .. "|" .. kicked
					if not seen[key] then
						seen[key] = TRUE
						qn = qn + 1
						queue[qn] = { b, kicked, f, nil }
					end
				else
					-- run into a boat: it is kicked out, Guybrush turns to the other branch of this node (or of its backbounce node)
					local k2 = kicked .. "," .. b.name .. ","
					local p = n.backbounce or n
					local d2 = 3 - d
					if p.branches[d2] and type(p.branches[d2]) == "table" then
						local key = p.name .. "|" .. k2 .. "f" .. d2
						if not seen[key] then
							seen[key] = TRUE
							qn = qn + 1
							queue[qn] = { p, k2, f, d2 }
						end
					end
					-- the bounce itself can land on the target (node 8's right branch is node 9)
					if p.branches[d2] == target then
						return f
					end
				end
			end
			d = d + 1
		end
	end
	return nil
end
a3_tap = function(name)
	ar_press_key(ar_real_key(name))
	sleep_for(60)
	ar_release_key(ar_real_key(name))
end
a3_ride_bot = function()
	local last = nil
	local d = nil
	while TRUE do
		if flume and flume.guyboat and not flume.demo and flume.guyboat.at_node then
			local n = flume.guyboat.at_node
			if n ~= last then
				last = n
				local tname = "9"
				if glob.flume_puzzle == 2 then tname = "12" end
				if props.milk_bottle.state ~= PROP_INITIAL or A3_RIDE_ABORT then tname = "dookie" end
				if A3_RIDE_TARGET then tname = A3_RIDE_TARGET end
				local target = flume.nodes[tname]
				d = a3_flume_first_dir(n, target)
				ar_log("ride: at node " .. tostring(n.name) .. " want " .. tostring(d))
			end
			-- (the key is pressed again and again: the game clears the wanted direction at the end of the node before, which can
			-- come just after a first press)
			if d == 1 then
				a3_tap("TURN_LEFT")
			elseif d == 2 then
				a3_tap("TURN_RIGHT")
			end
		else
			last = nil
			d = nil
		end
		sleep_for(80)
	end
end
a3_bottle_hot = function()
	return forced_hotlist and forced_hotlist[props.milk_bottle] and props.milk_bottle.state == PROP_INITIAL
end
a3_riding = function()
	return flume and flume.guyboat and not flume.demo
end

-- ar_dlg returns the table of an earlier run of the conversation; this waits until it is running
a3_dlg_running = function(name, timeout)
	local waited = 0
	local d = getglobal(name)
	while not (d and d.running) and waited < (timeout or 30000) do
		sleep_for(100)
		waited = waited + 100
		d = getglobal(name)
	end
	if d and d.running then
		return d
	end
	return nil
end
ar_dlg = function(name)
	return a3_dlg_running(name, 20000)
end

-- Talks to an object until the named conversation is running (the walk up to a moving person can be cut short)
a3_talk = function(obj, dlg)
	local tries = 0
	while tries < 5 do
		ar_talk(obj)
		local d = a3_dlg_running(dlg, 6000)
		if d then
			return d
		end
		tries = tries + 1
		ar_wait_for_control()
	end
	return ar_fail("could not start the conversation " .. dlg)
end

a3_to_map_once = a3_to_map
a3_to_map = function()
	local n = 0
	while ar_set_name() ~= A3_SET_MOM and n < 4 do
		a3_to_map_once()
		n = n + 1
	end
	return ar_set_name() == A3_SET_MOM
end

-- A door that only works by stepping into its trigger box (the lava field's way back to the map): after the verb, walk to the door's
-- own point
a3_step_into = function(door)
	local startset = system.currentSet
	ar_do("use", door)
	if system.currentSet == startset then
		local o = ar_obj_pos(door)
		ar_walk_to(o.x, o.y, o.z)
		ar_try_wait(ar_door_left, 15000)
		ar_settled()
	end
end
a3_to_map_once2 = a3_to_map_once
a3_to_map_once = function()
	if ar_set_name() == "field of lava" then
		AR_DOOR_SET = system.currentSet
		-- Two ways out to the map: the path at the end of the hill, and the door at the far end of the field. The one that the floor
		-- under Guybrush leads to (a floor of thin ribbons: the planner of the ribbons finds out which door box can be reached)
		local door = lav.hot_out_door or lav.mom_door_path
		if a3r_plan then
			A3R_DOOR = "mom_door_path"
			a3r_plan(99999, 99999)
			A3R_DOOR = nil
			if A3R_FOUND then
				door = lav.mom_door_path
			end
		end
		a3_step_into(door)
		AR_DOOR_SET = nil
		ar_wait_for_control()
		return ar_set_name() == A3_SET_MOM
	end
	return a3_to_map_once2()
end

-- like a3_map but the cells inside a trigger box (HOT) of a door show the first letter of its name in capitals
a3_map_hot = function(x0, x1, z0, z1, step, y0, y1)
	local p = manny:getpos()
	local z = z1
	ar_log(format("A3MAP set %s x %.0f..%.0f", ar_set_name(), x0, x1))
	while z >= z0 do
		local row = ""
		local x = x0
		while x <= x1 do
			local c = "."
			local y = y0
			while y <= y1 and c == "." do
				local id = GetPointSector(x, y, z)
				if id then
					c = "+"
					local hid, hname = GetPointSector(x, y, z, HOT)
					if hid and hname then
						c = strupper(strsub(hname, 1, 1))
					end
				end
				y = y + (A3_YSTEP or 0.25)
			end
			if abs(x - p.x) < step / 2 and abs(z - p.z) < step / 2 then
				c = "M"
			end
			row = row .. c
			x = x + step
		end
		ar_log(format("A3MAP %6.1f ", z) .. row)
		z = z - step
	end
end

-- The island's map is two pieces that are not joined by floor: the east piece (beach, camp, canyon, vista point, volcano castle, the
-- lava field's south door) and the west piece (village, monkey head, the lava field's east door). The lava field joins them: in at
-- the south, over the fallen palm tree, out at the east door.
a3_is_west_place = function(place)
	return place == "monkey town" or place == "monkey head"
end
a3_map_side = function()
	local p = manny:getpos()
	if (p.z < -3 and p.x < 19) or p.x < -3 then
		return "W"
	end
	return "E"
end
a3_cross_lava = function(to_west)
	if to_west then
		a3_go(mom.lav_door, "field of lava")
		if not glob.knocked_lav_tree then
			return ar_fail("the lone palm tree is not down: no way over the lava field")
		end
		ar_do("use", lav.mom_door_east)
	else
		a3_go(mom.lav_door_east, "field of lava")
		ar_do("use", lav.mom_door2)
	end
	ar_wait_for_control()
	if ar_set_name() ~= A3_SET_MOM then
		return ar_fail("did not get across the lava field")
	end
	return TRUE
end
a3_goto = function(place)
	if ar_set_name() == place then
		return TRUE
	end
	a3_to_map()
	if ar_set_name() ~= A3_SET_MOM then
		return ar_fail("not on the map")
	end
	-- (the map is two pieces that the lava field joins: the way to a place on the other piece is through the lava field)
	local side = a3_map_side()
	if place ~= "field of lava" and a3_is_west_place(place) ~= (side == "W") then
		if not a3_cross_lava(a3_is_west_place(place)) then
			return nil
		end
	end
	local d = a3_map_door(place)
	if place == "field of lava" and a3_map_side() == "W" then
		d = mom.lav_door_east
	end
	if not d then
		return ar_fail("no map door to " .. place)
	end
	return a3_go(d, place)
end

-- Floors that are thin sloped ribbons (the canyon, the lava field's hill): a sector there only answers within about a centimetre of
-- its plane, so the planner's cell test also scans the height finely (A3_FINE = TRUE)
A3_FINEC = { }
A3_FINEC_SET = nil
a3_fine_y = function(x, z, y)
	local set = ar_set_name()
	if A3_FINEC_SET ~= set then
		A3_FINEC_SET = set
		A3_FINEC = { }
	end
	local key = (floor(x * 4 + 0.5) + 2000) * 100000 + (floor(z * 4 + 0.5) + 2000) * 40 + floor(y * 1 + 0.5) + 20
	local c = A3_FINEC[key]
	if c then
		if c == -999 then
			return nil
		end
		return c
	end
	local d = 0
	while d <= (A3_FINE_RANGE or 0.9) do
		if GetPointSector(x, y + d, z) then
			A3_FINEC[key] = y + d
			return y + d
		end
		if d > 0 and GetPointSector(x, y - d, z) then
			A3_FINEC[key] = y - d
			return y - d
		end
		d = d + 0.01
	end
	A3_FINEC[key] = -999
	return nil
end
A3_CELL_ORIG3 = ar_cell_y
ar_cell_y = function(x, z, y)
	local ny, cheat = A3_CELL_ORIG3(x, z, y)
	if not ny and (A3_FINE or ar_set_name() == "field of lava" or ar_set_name() == "canyon") then
		ny = a3_fine_y(x, z, y)
		if ny then
			local d = a3_hot_door(x, ny, z)
			if d and not A3_NO_AVOID and d ~= A3_TARGET_OBJ and d ~= A3_START_OBJ then
				return nil
			end
		end
	end
	return ny, cheat
end

-- Map of a sloped set: for every cell the sector id (mod 36) found by scanning the height finely; prints the heights of a few columns
a3_fine_map = function(x0, x1, z0, z1, step, y0, y1)
	local z = z1
	ar_log(format("A3FINE set %s x %.0f..%.0f step %.2f", ar_set_name(), x0, x1, step))
	while z >= z0 do
		local row = ""
		local x = x0
		while x <= x1 do
			local c = "."
			local y = y0
			while y <= y1 and c == "." do
				local id = GetPointSector(x, y, z)
				if id then
					c = strsub("abcdefghijklmnopqrstuvwxyz0123456789", mod(id, 36) + 1, mod(id, 36) + 1)
				end
				y = y + 0.02
			end
			row = row .. c
			x = x + step
		end
		ar_log(format("A3FINE %6.1f ", z) .. row)
		z = z - step
	end
end

-- like a3_fine_map but the character is the floor height (0-9 = floor of y+1, so -1..8)
a3_fine_map_y = function(x0, x1, z0, z1, step, y0, y1)
	local z = z1
	ar_log(format("A3FINEY set %s x %.1f..%.1f step %.2f (digit = floor(y)+1)", ar_set_name(), x0, x1, step))
	while z >= z0 do
		local row = ""
		local x = x0
		while x <= x1 do
			local c = "."
			local y = y0
			while y <= y1 and c == "." do
				local id = GetPointSector(x, y, z)
				if id then
					c = tostring(floor(y) + 1)
				end
				y = y + 0.01
			end
			row = row .. c
			x = x + step
		end
		ar_log(format("A3FINEY %6.1f ", z) .. row)
		z = z - step
	end
end

-- A finer line test (the stock one samples every 0.4: a gap between two sectors of the map that is narrower slips through, and the
-- walk then stops at the edge)
ar_line_ok = function(x1, z1, x2, z2, y1, y2)
	local d = sqrt((x2 - x1) * (x2 - x1) + (z2 - z1) * (z2 - z1))
	local n = floor(d / 0.15) + 1
	local i = 1
	local y = y1
	while i <= n do
		y = ar_cell_y(x1 + (x2 - x1) * i / n, z1 + (z2 - z1) * i / n, y)
		if not y then
			return nil
		end
		i = i + 1
	end
	return TRUE
end
AR_GRID = 0.25

-- (the objects of the map are made again after a visit to the jungle: a door is named by its key and looked up at each try)
a3_go_obj = a3_go
a3_go = function(door, want)
	local key = nil
	if type(door) == "table" then
		local k, v = next(mom, nil)
		while k do
			if v == door then
				key = k
			end
			k, v = next(mom, k)
		end
	end
	if not key then
		return a3_go_obj(door, want)
	end
	local tries = 0
	local keep = AR_KEEP_GOING
	while tries < 8 do
		if A3_STAY_JUN and ar_set_name() == A3_SET_JUN then
			return TRUE
		end
		if ar_set_name() == A3_SET_JUN then
			ar_log("caught by a monkey in the jungle, going back")
			ar_do("use", a3_jun_door())
			ar_wait_for_control()
		end
		AR_KEEP_GOING = TRUE
		AR_FAILED = FALSE
		ar_do("use", mom[key])
		AR_KEEP_GOING = keep
		ar_wait_for_control()
		if ar_set_name() == want then
			AR_FAILED = FALSE
			return TRUE
		end
		tries = tries + 1
	end
	return ar_fail("could not get through " .. key .. " to " .. tostring(want) .. ", in " .. ar_set_name())
end

-- A task that logs where the run is every few seconds (for finding where a run hangs)
a3_watcher = function()
	while TRUE do
		local p = manny:getpos()
		local bh = "normal"
		if type(system.buttonHandler) == "table" then bh = "dialog" end
		ar_log(format("WATCH %s %.1f %.1f %.1f cut=%d msg=%s bh=%s", ar_set_name(), p.x, p.y, p.z, cutSceneLevel, tostring(IsMessageGoing()), bh))
		sleep_for(A3_WATCH_MS or 10000)
	end
end

-- A verb whose walk ended in another set (the door fired on the way) is not a failure
A3_FAIL_ORIG = ar_fail
ar_fail = function(msg)
	if AR_DOOR_SET and system.currentSet ~= AR_DOOR_SET then
		ar_log("(set changed during the verb, not a failure: " .. msg .. ")")
		return nil
	end
	return A3_FAIL_ORIG(msg)
end

-- waits for a conversation to end (as long as it takes: some are minutes of speech)
a3_dlg_done = function(name, ms)
	AR_DLG_NAME = name
	ar_wait_for(ar_dlg_ended, ms or 900000, "the dialog " .. name .. " to end")
	ar_wait_for_control()
end

-- Monkey Kombat (monkey_kombat2.lua): five stances, each beaten by two others; a turn is three of the four words (Ack Oop Eek Chee,
-- the four direction keys) that make the phrase for the move from the stance one is in to the stance wanted (glob.mk_phrase_table),
-- the same word three times keeps the stance. The monkey says its phrase first (its stance is shown on the screen); the bot answers
-- with a stance that beats the monkey's, so every exchange is won.
A3_KOMBAT_KEYS = { "MOVE_FORWARD", "TURN_RIGHT", "MOVE_BACKWARD", "TURN_LEFT" }
a3_kombat_ready = function()
	return mk and mk.guybrush_meter and not mk.quitting and not mk.monkey_turn and not mk.no_input and not mk.no_press_buttons
		and mk.cur_button == 1 and mk.last_button == 1 and mk.current_guybrush_stance and mk.current_monkey_stance
end
a3_kombat_bot = function()
	while TRUE do
		if a3_kombat_ready() then
			local g = mk.current_guybrush_stance
			local m = mk.current_monkey_stance
			local target = mk.what_beats_me[m][1]
			if target == g or mk.what_beats_me[m][2] == g then
				target = g
			end
			local words
			if target == g then
				words = { 1, 1, 1 }
			else
				words = glob.mk_phrase_table[g][target]
			end
			ar_log(format("KOMBAT me %d monkey %d -> stance %d, words %d %d %d (health %.1f / %.1f)", g, m, target, words[1], words[2], words[3], mk.guybrush_health, mk.monkey_health))
			local i = 1
			while i <= 3 do
				-- (the game says the word and waits for the line to end before it takes the next key: the press is made when no line is up.
				-- On the original a word pressed while the line before it ("Ack") was still up was lost, and the exchange waited for its
				-- third word for good, Nov 11)
				ar_try_wait(function() return not IsMessageGoing() end, 5000)
				sleep_for(100)
				ar_press_key(ar_real_key(A3_KOMBAT_KEYS[words[i]]))
				sleep_for(80)
				ar_release_key(ar_real_key(A3_KOMBAT_KEYS[words[i]]))
				sleep_for(150)
				i = i + 1
			end
			-- wait until the game has taken the phrase (it leaves the ready state: the turn passes, the buttons lock), then until the next
			-- turn. Waiting only for the ready state, the original was still in it 1.5 s after the third word, and the words were pressed a
			-- second time: the two phrases mixed and every fight was lost (Nov 11)
			local taken = 0
			while mk and a3_kombat_ready() and taken < 8000 do
				sleep_for(100)
				taken = taken + 100
			end
			local waited = 0
			while mk and a3_kombat_ready() == nil and waited < 20000 do
				sleep_for(100)
				waited = waited + 100
			end
			sleep_for(1500)
		end
		sleep_for(100)
	end
end
a3_kombat_active = function()
	return mk ~= nil
end

a3_go_keyed = a3_go
a3_go = function(door, want)
	if A3_STAY_JUN then
		-- (look for a monkey: the walk is stopped when the wild monkey of the map has caught Guybrush)
		A3_JUN_WAIT = TRUE
	end
	return a3_go_keyed(door, want)
end

-- The lava field crossing, both ways. The fallen palm tree is the bridge: the game's own "use the tree" walks Guybrush across it.
a3_cross_lava = function(to_west)
	if to_west then
		a3_go(mom.lav_door, "field of lava")
		if not glob.knocked_lav_tree then
			ar_do("use", lav.tree)
		end
		-- (over the tree to the ledge side, then out by the east door)
		if lav and lav.tree and ar_set_name() == "field of lava" then
			local p = manny:getpos()
			if p.x < 22.5 then
				ar_do("use", lav.tree)
			end
		end
		ar_do("use", lav.mom_door_east)
	else
		a3_go(mom.lav_door_east, "field of lava")
		local p = manny:getpos()
		if p.x > 22.5 then
			ar_do("use", lav.tree)
		end
		ar_do("use", lav.mom_door2)
	end
	ar_wait_for_control()
	if ar_set_name() ~= A3_SET_MOM then
		return ar_fail("did not get across the lava field")
	end
	return TRUE
end

a3_cross_lava = function(to_west)
	if to_west then
		a3_go(mom.lav_door, "field of lava")
		if ar_set_name() ~= "field of lava" then
			-- (a wild monkey caught Guybrush on the way: the caller deals with the jungle)
			return nil
		end
		if not glob.knocked_lav_tree then
			ar_do("use", lav.tree)
		end
		local p = manny:getpos()
		local n = 0
		while p.x < 22.5 and n < 3 do
			ar_do("use", lav.tree)
			p = manny:getpos()
			n = n + 1
		end
		ar_do("use", lav.mom_door_east)
	else
		a3_go(mom.lav_door_east, "field of lava")
		if ar_set_name() ~= "field of lava" then
			return nil
		end
		local p = manny:getpos()
		local n = 0
		while p.x > 22.5 and n < 3 do
			ar_do("use", lav.tree)
			p = manny:getpos()
			n = n + 1
		end
		ar_do("use", lav.mom_door2)
	end
	ar_wait_for_control()
	if ar_set_name() ~= A3_SET_MOM then
		return ar_fail("did not get across the lava field")
	end
	return TRUE
end

-- A walk on the map that ended in another place (a door's box was crossed on the way): out again and another try
a3_go_inner = a3_go
a3_go = function(door, want)
	local n = 0
	local keep = AR_KEEP_GOING
	AR_KEEP_GOING = TRUE
	while n < 4 do
		if ar_set_name() ~= A3_SET_MOM and ar_set_name() ~= A3_SET_JUN and ar_set_name() ~= want then
			a3_to_map()
		end
		AR_FAILED = FALSE
		a3_go_inner(door, want)
		if ar_set_name() == want or (A3_STAY_JUN and ar_set_name() == A3_SET_JUN) then
			AR_KEEP_GOING = keep
			AR_FAILED = FALSE
			return TRUE
		end
		n = n + 1
	end
	AR_KEEP_GOING = keep
	return ar_fail("could not reach " .. tostring(want))
end

a3_go_outer = a3_go
a3_go = function(door, want)
	local key = nil
	if type(door) == "table" then
		local k, v = next(mom, nil)
		while k do
			if v == door then
				key = k
			end
			k, v = next(mom, k)
		end
	end
	if not key then
		return a3_go_outer(door, want)
	end
	local n = 0
	local keep = AR_KEEP_GOING
	AR_KEEP_GOING = TRUE
	while n < 8 do
		if ar_set_name() == A3_SET_JUN and not A3_STAY_JUN then
			-- (caught by a wild monkey of the map: back to the map by the door of the jungle, and on)
			ar_log("caught by a monkey in the jungle, going back")
			ar_do("use", a3_jun_door())
			ar_wait_for_control()
		end
		if ar_set_name() ~= A3_SET_MOM and ar_set_name() ~= A3_SET_JUN and ar_set_name() ~= want then
			a3_to_map()
		end
		AR_FAILED = FALSE
		if ar_set_name() == A3_SET_MOM and mom[key] then
			-- (the game's own walk to a place goes straight, through the trigger strips of the places on the way: Guybrush walks the
			-- planned way, round the strips, to the place's use point first)
			local d = mom[key]
			if d.use_pnt_x then
				ar_walk_to(d.use_pnt_x, d.use_pnt_y, d.use_pnt_z, function() return ar_set_name() ~= A3_SET_MOM end)
			end
			if ar_set_name() == A3_SET_MOM then
				a3_go_inner(d, want)
			else
				-- (the walk went into the place's strip: the place is entered as by the verb, and settles)
				ar_settled()
			end
		end
		if ar_set_name() == want or (A3_STAY_JUN and ar_set_name() == A3_SET_JUN) then
			AR_KEEP_GOING = keep
			AR_FAILED = FALSE
			return TRUE
		end
		n = n + 1
	end
	AR_KEEP_GOING = keep
	return ar_fail("could not reach " .. tostring(want))
end

-- A margin around the trigger boxes to be avoided: a walk drifts a little off its straight legs
a3_hot_door_exact = a3_hot_door
a3_hot_door = function(x, y, z)
	local d = a3_hot_door_exact(x, y, z)
	if d then
		return d
	end
	local m = A3_MARGIN or 0.45
	d = a3_hot_door_exact(x + m, y, z)
	if d then return d end
	d = a3_hot_door_exact(x - m, y, z)
	if d then return d end
	d = a3_hot_door_exact(x, y, z + m)
	if d then return d end
	return a3_hot_door_exact(x, y, z - m)
end

-- A frame-exact clock (ms): A3_CLK
A3_CLK = 0
a3_clock_task = function()
	while TRUE do
		break_here()
		A3_CLK = A3_CLK + system.frameTime
	end
end
if not A3_CLOCK_TASK or not find_script(A3_CLOCK_TASK) then
	A3_CLOCK_TASK = start_script(a3_clock_task)
end

-- The time the rocks of the Pachinko Rock are made (the game's make_rock), logged with the clock
a3_pac_wrap = function()
	if A3_PAC_WRAPPED then
		return
	end
	A3_PAC_WRAPPED = TRUE
	A3_MAKE_ROCK_ORIG = pac.make_rock
	pac.make_rock = function(self)
		A3_LAST_CREATE = A3_CLK
		ar_log("ROCK made at clock " .. floor(A3_CLK))
		return A3_MAKE_ROCK_ORIG(self)
	end
end

-- a plain wait: no "nothing happened" check, for events that take a long game time and show nothing (the rocks, a long speech)
a3_wait = function(cond, ms, what)
	local waited = 0
	while not cond() and waited < ms do
		sleep_for(250)
		waited = waited + 250
	end
	if not cond() then
		return ar_fail("timed out waiting for " .. tostring(what))
	end
	return TRUE
end

-- the bottle shows only while the boat is at its node: a finer look
a3_bottle_hot_fine = a3_bottle_hot

-- Feeds Timmy a banana. Timmy wanders about a set: Guybrush walks up to where he is now before each try (stands 1.5 west of him); up to 6 tries.
a3_feed_timmy = function(obj)
	local n = 0
	local fed = nil
	local failed_before = AR_FAILED
	while not fed and n < 6 do
		n = n + 1
		-- (Guybrush walks up to where Timmy is now, until the game offers him, and then the verb is given; Timmy runs in after the set
		-- is entered: until then his place is that of the set before)
		ar_try_wait(function() return timmy.in_set == system.currentSet end, 10000)
		sleep_for(1500)
		local tp = timmy:getpos()
		AR_OBJ = obj
		if not ar_obj_offered() then
			ar_walk_to(tp.x - 1.5, tp.y, tp.z, ar_obj_offered)
		end
		AR_KEEP_GOING = TRUE
		fed = ar_do("use", obj, props.bananas)
		AR_KEEP_GOING = FALSE
		ar_wait_for_control()
		sleep_for(1000)
	end
	AR_FAILED = failed_before
	return fed
end

