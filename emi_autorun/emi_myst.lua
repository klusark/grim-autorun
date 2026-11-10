-- Helpers for the raft in Mysts o' Tyme (chapters ch23..): the raft is steered to the exit trigger of the screen. The triggers are HOT
-- sectors (up_trigger, right_trigger, down_trigger, left_trigger); where one overlaps the sectors the raft can float on the Doorman of the
-- game fires mot:leave(direction) as for a player.
AR_TRIGGER_NAMES = { "up_trigger", "right_trigger", "down_trigger", "left_trigger" }

-- the cells where the raft can float and the trigger of the direction is: { x, z } nearest to the raft first
ar_raft_cells = function(dir)
	-- (dir: 1..4, or the name of a HOT sector)
	local name = AR_TRIGGER_NAMES[dir] or dir
	local rp = swampraft:getpos()
	local cx = { }
	local cz = { }
	local nc = 0
	local ox = { }
	local oz = { }
	local no = 0
	local x = rp.x - 45
	while x <= rp.x + 45 do
		local z = rp.z - 50
		while z <= rp.z + 50 do
			local id, n = GetPointSector(x, rp.y, z, HOT)
			if id and n and strfind(n, "_trigger", 1, TRUE) then
				if n == name then
					-- (a cell inside the trigger: its neighbours half a unit off are in it as well; the raft stops a hand short of
					-- a point, and a cell on the very edge is not reached)
					local i1, n1 = GetPointSector(x + 0.5, rp.y, z, HOT)
					local i2, n2 = GetPointSector(x - 0.5, rp.y, z, HOT)
					local i3, n3 = GetPointSector(x, rp.y, z + 0.5, HOT)
					local i4, n4 = GetPointSector(x, rp.y, z - 0.5, HOT)
					if GetPointSector(x, rp.y, z) and n1 == name and n2 == name and n3 == name and n4 == name then
						nc = nc + 1
						cx[nc] = x
						cz[nc] = z
					end
				elseif mod(floor(x), 2) == 0 and mod(floor(z), 2) == 0 and GetPointSector(x, rp.y, z) then
					no = no + 1
					ox[no] = x
					oz[no] = z
				end
			end
			z = z + 1
		end
		x = x + 1
	end
	-- The cell of the trigger the raft is steered to: the nearest one that is a few units clear of the other triggers (the raft drifts
	-- about a unit off its way, and a touch of another exit trigger sends it to a random screen)
	local bx = nil
	local bz = nil
	local bs = -1
	local bd = 1e9
	local i = 1
	while i <= nc do
		local sc = 4
		local j = 1
		while j <= no and sc > 0 do
			local dd = sqrt((cx[i] - ox[j]) * (cx[i] - ox[j]) + (cz[i] - oz[j]) * (cz[i] - oz[j]))
			if dd < sc then
				sc = dd
			end
			j = j + 1
		end
		local d = (cx[i] - rp.x) * (cx[i] - rp.x) + (cz[i] - rp.z) * (cz[i] - rp.z)
		if sc > bs + 0.01 or (sc > bs - 0.01 and d < bd) then
			bs = sc
			bd = d
			bx = cx[i]
			bz = cz[i]
		end
		i = i + 1
	end
	return bx, bz
end

-- The raft is steered with the keys, as a player does (the raft's button handler reads forward/backward and the two turns, held): the turn key
-- towards the point until the raft points at it, forward while it does. A task of its own (it ends with the screen, or when the raft button
-- handler is gone because a conversation began, or when AR_RAFT_STOP is set), the keys let go at its end.
-- The way round what is in the water: a path over the cells where the raft can float (the walk sectors), as a player steers round the banks.
-- Floor under a place at about the height of the raft (the walk sectors of the set include far higher and lower ones)
-- The clearance (AR_RAFT_EDGE) is from the edge of the water as a whole, not of one sector: the water is cut into big triangles, and a margin
-- inside one of them left a dead strip along every edge they share, which cut the water into islands (the planner found no way on most
-- screens and the raft was driven straight at the banks). So the place and eight points round it at that distance must all have floor.
ar_raft_floor_at = function(x, z, y)
	local fh = GetFloorHeights(x, z, 0)
	local i = 1
	while fh[i] do
		if abs(fh[i] - y) < 0.4 then
			return TRUE
		end
		i = i + 1
	end
	return nil
end
AR_RAFT_RING = { { 1, 0 }, { 0.7071, 0.7071 }, { 0, 1 }, { -0.7071, 0.7071 }, { -1, 0 }, { -0.7071, -0.7071 }, { 0, -1 }, { 0.7071, -0.7071 } }
ar_raft_floor = function(x, z, y)
	if not ar_raft_floor_at(x, z, y) then
		return nil
	end
	local r = AR_RAFT_EDGE or 0.8
	local i = 1
	while AR_RAFT_RING[i] do
		if not ar_raft_floor_at(x + r * AR_RAFT_RING[i][1], z + r * AR_RAFT_RING[i][2], y) then
			return nil
		end
		i = i + 1
	end
	return TRUE
end
ar_raft_path = function(x, z, margin)
	local p = swampraft:getpos()
	local y = p.y
	local step = AR_RAFT_STEP or 1
	local sx = floor(p.x / step + 0.5)
	local sz = floor(p.z / step + 0.5)
	local tx = floor(x / step + 0.5)
	local tz = floor(z / step + 0.5)
	local prev = { }
	local queue = { }
	local head = 1
	local tail = 1
	queue[1] = { sx, sz }
	prev[sx * 4096 + sz] = TRUE
	local found = nil
	local bst = { }
	local tid, tname = GetPointSector(x, y, z, HOT)
	local dx = { 1, -1, 0, 0, 1, 1, -1, -1 }
	local dz = { 0, 0, 1, -1, 1, -1, 1, -1 }
	while head <= tail and not found and head < 30000 / (step * step) do
		local cx = queue[head][1]
		local cz = queue[head][2]
		head = head + 1
		local k = 1
		while k <= 8 and not found do
			local nx = cx + dx[k]
			local nz = cz + dz[k]
			local key = nx * 4096 + nz
			if not prev[key] and abs(nx - sx) < 90 and abs(nz - sz) < 90 then
				-- (with a margin: not through the other exit triggers or near them, the raft drifts about a unit from the way; only one
				-- of overlapping triggers is found at a point, so the surroundings are looked at too)
				local other = nil
				if margin and (abs(nx - tx) > 2 or abs(nz - tz) > 2) and (abs(nx - sx) > 4 or abs(nz - sz) > 4) then
					local ox = -margin
					while ox <= margin + 0.1 and not other do
						local oz = -margin
						while oz <= margin + 0.1 and not other do
							local hid, hname = GetPointSector(nx * step + ox, y, nz * step + oz, HOT)
							other = hid and hname and strfind(hname, "_trigger", 1, TRUE) and hname ~= tname
							oz = oz + margin / 2
						end
						ox = ox + margin / 2
					end
				end
				if (nx == tx and nz == tz) or (ar_raft_floor(nx * step, nz * step, y) and not other) then
					prev[key] = { cx, cz }
					tail = tail + 1
					queue[tail] = { nx, nz }
					local dd = (nx - tx) * (nx - tx) + (nz - tz) * (nz - tz)
					if not bst.d or dd < bst.d then
						bst.d = dd
						bst.x = nx
						bst.z = nz
					end
					if nx == tx and nz == tz then
						found = TRUE
					end
				end
			end
			k = k + 1
		end
	end
	if not found then
		-- (the trigger is not on the floor the raft can float on: the way ends at the cell of the floor nearest to it, within a few
		-- units, and the raft is pushed on into the trigger from there)
		if bst.d and bst.d <= 9 then
			tx = bst.x
			tz = bst.z
		else
			return nil
		end
	end
	local rev = { }
	local n = 0
	local cx = tx
	local cz = tz
	while not (cx == sx and cz == sz) do
		n = n + 1
		rev[n] = { cx * step, cz * step }
		local b = prev[cx * 4096 + cz]
		cx = b[1]
		cz = b[2]
	end
	-- (the way from the raft on: every second cell, the target itself last)
	local path = { }
	local m = 0
	local i = n - 1
	while i >= 1 do
		m = m + 1
		path[m] = rev[i]
		i = i - 1
	end
	m = m + 1
	path[m] = { x, z }
	return path
end

ar_raft_drive_to = function(x, z, tol, max_frames)
	local right = nil
	local left = nil
	local fwd = nil
	local y = swampraft:getpos().y
	local setup = mot.cur_setup_id
	local n = 0
	local run = TRUE
	local best = 1e9
	local still = 0
	local unstuck = 0
	local arrived = nil
	while run and n < max_frames and not AR_RAFT_STOP and mot.cur_setup_id == setup do
		local p = swampraft:getpos()
		local dist = sqrt((p.x - x) * (p.x - x) + (p.z - z) * (p.z - z))
		local d = GetActorYawToPoint(swampraft.hActor, x, y, z) - swampraft:getrot().y
		d = d - 360 * floor(d / 360 + 0.5)
		local want_right = d > 12 and dist > tol
		local want_left = d < -12 and dist > tol
		local want_fwd = abs(d) < 25 and dist > tol
		if dist <= tol then
			arrived = TRUE
			run = nil
		end
		-- (no way nearer to the point for a few seconds: the bank is in the way)
		if dist < best - 0.1 then
			best = dist
			still = 0
		else
			still = still + 1
			if still > 150 and unstuck < 8 then
				-- (against the bank: a player backs off, turns away a little and steers at it again)
				unstuck = unstuck + 1
				if right then ar_key_up("TURN_RIGHT") right = nil end
				if left then ar_key_up("TURN_LEFT") left = nil end
				if fwd then ar_key_up("MOVE_FORWARD") fwd = nil end
				ar_key_down("MOVE_BACKWARD")
				sleep_for(900)
				ar_key_up("MOVE_BACKWARD")
				if mod(unstuck, 2) == 1 then ar_key_down("TURN_RIGHT") else ar_key_down("TURN_LEFT") end
				sleep_for(500 + 120 * unstuck)
				if mod(unstuck, 2) == 1 then ar_key_up("TURN_RIGHT") else ar_key_up("TURN_LEFT") end
				still = 0
				best = 1e9
			end
			if still > 240 then
				run = nil
			end
		end
		if cutSceneLevel > 0 or not ar_raft_handler() then
			run = nil
		end
		if not run then
			want_right = nil
			want_left = nil
			want_fwd = nil
		end
		if want_right and not right then
			ar_key_down("TURN_RIGHT")
			right = TRUE
		elseif not want_right and right then
			ar_key_up("TURN_RIGHT")
			right = nil
		end
		if want_left and not left then
			ar_key_down("TURN_LEFT")
			left = TRUE
		elseif not want_left and left then
			ar_key_up("TURN_LEFT")
			left = nil
		end
		if want_fwd and not fwd then
			ar_key_down("MOVE_FORWARD")
			fwd = TRUE
		elseif not want_fwd and fwd then
			ar_key_up("MOVE_FORWARD")
			fwd = nil
		end
		if run then
			break_here()
		end
		n = n + 1
	end
	if right then
		ar_key_up("TURN_RIGHT")
	end
	if left then
		ar_key_up("TURN_LEFT")
	end
	if fwd then
		ar_key_up("MOVE_FORWARD")
	end
	return arrived
end

ar_raft_walk = function(x, z)
	local setup = mot.cur_setup_id
	-- (the widest margin from the other exit triggers that leaves a way; then the same with less clearance from the banks, for a narrow
	-- inlet such as the arrival of screen 2: the margin from the triggers matters more than the clearance, a touch of a trigger is a random move)
	local edge = AR_RAFT_EDGE
	local edges = { edge or 0.8, 0.5, 0.3 }
	local margins = { 3, 2, 1, 0.5 }
	local path = nil
	local ei = 1
	while not path and edges[ei] do
		AR_RAFT_EDGE = edges[ei]
		local mi = 1
		while not path and margins[mi] do
			AR_RAFT_MARGIN = margins[mi]
			path = ar_raft_path(x, z, margins[mi])
			mi = mi + 1
		end
		ei = ei + 1
	end
	-- (a channel about a unit wide between two exit triggers, screen 2 from its arrival: half-unit cells, small margins)
	local fine = nil
	if not path then
		AR_RAFT_STEP = 0.5
		-- (the neck of that channel is narrower than 0.6: the last try has no clearance, only floor)
		local fe = { 0.3, 0 }
		local fm = { 0.5, 0.25 }
		local fi = 1
		while not path and fe[fi] do
			AR_RAFT_EDGE = fe[fi]
			local mi = 1
			while not path and fm[mi] do
				AR_RAFT_MARGIN = fm[mi]
				path = ar_raft_path(x, z, fm[mi])
				mi = mi + 1
			end
			fi = fi + 1
		end
		AR_RAFT_STEP = nil
		fine = path
		if path then
			ar_log("RAFT half-unit cells")
		end
	end
	ei = 1
	while not path and edges[ei] do
		AR_RAFT_EDGE = edges[ei]
		AR_RAFT_MARGIN = nil
		path = ar_raft_path(x, z)
		ei = ei + 1
	end
	if path and AR_RAFT_EDGE ~= (edge or 0.8) then
		ar_log("RAFT clearance from the banks " .. AR_RAFT_EDGE)
	end
	AR_RAFT_EDGE = edge
	if not path then
		ar_log("RAFT no path to " .. x .. " " .. z .. ", straight")
		path = { { x, z } }
	end
	local ps = ""
	local pk = 1
	while path[pk] do
		ps = ps .. format("(%.0f,%.0f) ", path[pk][1], path[pk][2])
		pk = pk + 1
	end
	ar_log("RAFT way " .. ps .. "(margin " .. tostring(AR_RAFT_MARGIN) .. ")")
	local i = 1
	local tries = 0
	-- (a try for each point of the way and 40 more for new ways: a way of half-unit cells has more than 40 points)
	while path[i] and not AR_RAFT_STOP and mot.cur_setup_id == setup and tries < pk + 40 do
		local last = (path[i + 1] == nil)
		local tol = 1.2
		if fine then
			tol = 0.4
		end
		if last then
			tol = 0.25
		end
		if not ar_raft_drive_to(path[i][1], path[i][2], tol, 1500) and last then
			-- (the last point not reached: from where the raft is now, a new way)
			local np = ar_raft_path(x, z)
			if np then
				path = np
				i = 0
			end
		end
		i = i + 1
		tries = tries + 1
	end
	local pe = swampraft:getpos()
	ar_log(format("RAFT drive ended at %.1f %.1f (target %.1f %.1f) screen %s", pe.x, pe.z, x, z, tostring(mot.cur_setup_id)))
end

-- (the raft's handler: whatever the game put in the button handler while the raft is steered)
ar_raft_handler = function()
	return mot.guybrush_on_raft and not ar_handler_normal()
end

-- steers to the exit of the direction and waits for the game to take the raft out
ar_raft_exit = function(dir)
	-- (dir: 1..4 or a name; waits until the screen or the step of the map changes, or 90 s)
	local before = mot.cur_setup_id
	local step = mot.map_step
	local bx, bz = ar_raft_cells(dir)
	if not bx then
		ar_log("RAFT no cell of the " .. tostring(AR_TRIGGER_NAMES[dir] or dir) .. " to float to")
		return nil
	end
	ar_log("RAFT to " .. tostring(AR_TRIGGER_NAMES[dir] or dir) .. " at " .. bx .. " " .. bz .. " (screen " .. tostring(before) .. ")")
	AR_RAFT_STOP = nil
	start_script(ar_raft_walk, bx, bz)
	local waited = 0
	while mot.cur_setup_id == before and mot.map_step == step and waited < 90000 do
		sleep_for(300)
		waited = waited + 300
	end
	AR_RAFT_STOP = TRUE
	sleep_for(1500)
	return TRUE
end

-- a verb that starts a conversation inside it (the dialog has to be answered before the verb ends): started in a script of its own
ar_do_bg_args = { }
ar_do_bg_run = function()
	ar_do(ar_do_bg_args[1], ar_do_bg_args[2], ar_do_bg_args[3])
end
ar_do_bg = function(verb, a, b)
	ar_do_bg_args = { verb, a, b }
	start_script(ar_do_bg_run)
end

-- the first of the lines (numbers) the dialog offers in its node now (not off), picked; nil when none is offered
ar_pick_avail = function(d, list)
	local i = 1
	while list[i] do
		local v = d[list[i]]
		if type(v) == "table" and v.text and v[d.node] and not v.off then
			ar_pick(d, list[i])
			return TRUE
		end
		i = i + 1
	end
	return nil
end

-- Combines two inventory items the way a player does (the same keys as a2_combine of act2_lib.lua): the inventory key opens the inventory, which
-- pauses every running script, the run's own too, so a task of its own, started by the game when the inventory has been drawn (Inventory.display is
-- wrapped), does the keys: turn to the first item, USE (it is set aside), turn to the second, USE (the game runs combine_<name>), close.
ar_inv_turn_to = function(item)
	local n = 0
	while Inventory.ordered_inventory_table[Inventory.index] ~= item and n < 30 do
		ar_press_key(next(control_map.INVENTORY_NEXT, nil))
		sleep_for(900)
		n = n + 1
	end
	sleep_for(400)
	return Inventory.ordered_inventory_table[Inventory.index] == item
end

ar_comb_driver = function()
	local a = AR_COMB_A
	local b = AR_COMB_B
	sleep_for(1500)
	ar_log("inventory: open " .. tostring(Inventory.open) .. " index " .. tostring(Inventory.index) .. " of " .. tostring(Inventory.ordered_inventory_table.numitems) .. ", turning to " .. tostring(a.name))
	if not ar_inv_turn_to(a) then
		ar_log("FAIL combine: could not turn to " .. tostring(a.name))
	elseif AR_COMB_BIND then
		-- (the item is bound to a number key as a player does it: shift and the key, with the item chosen; the inventory is closed below)
		AR_HELD[SHIFTKEY] = TRUE
		ar_press_key(AR_COMB_BIND)
		sleep_for(200)
		ar_release_key(AR_COMB_BIND)
		AR_HELD[SHIFTKEY] = nil
		sleep_for(800)
		ar_log("inventory: bound " .. tostring(a.name) .. " to key " .. tostring(AR_COMB_BIND))
	else
		ar_press("use")
		sleep_for(2500)
		ar_log("inventory: after use, holding " .. tostring(manny.is_holding and manny.is_holding.name) .. " open " .. tostring(Inventory.open))
		if AR_COMB_ONLY then
			-- (only taken out: the item is in the hand)
		elseif not ar_inv_turn_to(b) then
			ar_log("FAIL combine: could not turn to " .. tostring(b.name))
		else
			ar_press("use")
			sleep_for(3000)
		end
	end
	local n = 0
	while Inventory.open and n < 10 do
		if Inventory.combine_idx or AR_COMB_BIND then
			ar_press("inventory")
		else
			ar_press_key(next(control_map.OVERRIDE, nil))
		end
		sleep_for(2500)
		n = n + 1
	end
	AR_COMB_DONE = TRUE
end

if not AR_OLD_DISPLAY then
	AR_OLD_DISPLAY = Inventory.display
	Inventory.display = function(arg1, arg2, arg3)
		AR_OLD_DISPLAY(arg1, arg2, arg3)
		if AR_COMB_START then
			AR_COMB_START = nil
			start_script(ar_comb_driver)
		end
	end
end

-- The inventory is opened with its key; while the game is busy (a conversation about to start, a cutscene) the key does nothing, and a
-- player presses it again
ar_inv_open = function()
	local n = 0
	while AR_COMB_START and n < 8 do
		n = n + 1
		ar_press("inventory")
		ar_try_wait(function() return not AR_COMB_START end, 3000)
	end
	sleep_for(500)
end

-- An item bound to a number key through the inventory (open it, turn to the item, shift and the key, close it)
ar_inv_bind = function(item, key)
	ar_wait_for_control()
	ar_put_away()
	AR_COMB_BIND = key
	AR_COMB_A = item
	AR_COMB_B = item
	AR_COMB_DONE = nil
	AR_COMB_START = TRUE
	ar_inv_open()
	ar_wait_for(function() return AR_COMB_DONE end, 120000, "the item bound to a key")
	AR_COMB_BIND = nil
	ar_wait_for_control()
end

-- An item into the hand through the inventory (the number keys of the hand: the raft's button handler does not pass the 0 key on)
ar_inv_hold = function(item)
	if manny.is_holding == item then
		return TRUE
	end
	ar_wait_for_control()
	ar_put_away()
	AR_COMB_ONLY = TRUE
	AR_COMB_A = item
	AR_COMB_B = item
	AR_COMB_DONE = nil
	AR_COMB_START = TRUE
	ar_inv_open()
	ar_wait_for(function() return AR_COMB_DONE end, 120000, "the item out of the inventory")
	AR_COMB_ONLY = nil
	ar_wait_for_control()
	return manny.is_holding == item
end

ar_combine = function(a, b)
	ar_wait_for_control()
	ar_put_away()
	ar_log("combine: " .. tostring(a.name) .. " with " .. tostring(b.name))
	AR_COMB_A = a
	AR_COMB_B = b
	AR_COMB_DONE = nil
	AR_COMB_START = TRUE
	ar_inv_open()
	ar_wait_for(function() return AR_COMB_DONE end, 120000, "the combination")
	ar_wait_for_control()
end

-- A door that is entered by walking into its sector (HOT sector of the door's name, no "use" verb): the cell of the sector nearest to
-- Guybrush (the sector is not always at the height of the floor, so the walk goes to its x and z at Guybrush's own height), and the walk with the keys. Returns TRUE when the set changed (the walk stops when it does).
ar_walk_into_door = function(name, radius)
	radius = radius or 20
	local p = manny:getpos()
	-- (the cells of the sector, and the one of them nearest to its middle: the edge can be off the reachable floor)
	local cells = { }
	local n = 0
	local sx = 0
	local sz = 0
	local x = p.x - radius
	while x <= p.x + radius do
		local z = p.z - radius
		while z <= p.z + radius do
			local y = p.y - 3
			local hit = nil
			while y <= p.y + 3 and not hit do
				local id, sn = GetPointSector(x, y, z, HOT)
				if id and sn == name then
					hit = TRUE
				end
				y = y + 0.25
			end
			if hit then
				n = n + 1
				cells[n] = { x, z }
				sx = sx + x
				sz = sz + z
			end
			z = z + 0.5
		end
		x = x + 0.5
	end
	if n == 0 then
		ar_log("DOOR no cell of the sector " .. tostring(name) .. " near Guybrush")
		return nil
	end
	local mx = sx / n
	local mz = sz / n
	local bx, bz
	local bd = 1e9
	local i = 1
	while i <= n do
		local d = (cells[i][1] - mx) * (cells[i][1] - mx) + (cells[i][2] - mz) * (cells[i][2] - mz)
		if d < bd then
			bd = d
			bx = cells[i][1]
			bz = cells[i][2]
		end
		i = i + 1
	end
	ar_log(format("DOOR into %s: %d cells, middle %.2f %.2f", tostring(name), n, bx, bz))
	local startset = system.currentSet
	ar_walk_to(bx, p.y, bz, function() return system.currentSet ~= %startset end)
	return system.currentSet ~= startset
end

-- Waits until the game offers the object (it moves: a school of fish swims by, a player waits for it to come into reach, and turns round to look
-- for it: the game only offers what is in front of Guybrush)
ar_wait_offered = function(obj, ms)
	local waited = 0
	while not (vlist and vlist[obj] and cutSceneLevel == 0) and waited < (ms or 90000) do
		-- (a little turn with the key, then a pause to see)
		ar_key_down("TURN_RIGHT")
		sleep_for(250)
		ar_key_up("TURN_RIGHT")
		sleep_for(700)
		waited = waited + 950
	end
	return vlist and vlist[obj]
end

-- True when the object is the one the game's gaze is on (the hot object)
ar_hot_is = function(obj)
	return hot_object == obj
end
