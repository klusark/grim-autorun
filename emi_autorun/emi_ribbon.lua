-- Ribbon floors (Act 2's plank diving competition, Act 3's lava field and canyon): the floor is a chain of sectors a hand wide, which the coarse
-- grid planner does not connect. A walk with the keys is planned on a fine grid and walked leg by leg (a3_ribbon_walk). Loaded after the act's
-- own library, as its walk and approach are put in front of that library's. AR_RIBBON_SETS names the sets.
A3R_AVOID_DOORS = TRUE
AR_RIBBON_SETS = { }
AR_RIBBON_SETS["field of lava"] = TRUE
AR_RIBBON_SETS["canyon"] = TRUE
AR_RIBBON_SETS["plank diving competition"] = TRUE
AR_RIBBON_SETS["church of lechuck"] = TRUE
-- Ribbon floors (the lava field's hill, the canyon): the floor is a chain of sectors a hand wide, which the coarse grid planner does
-- not connect (a cell of its grid hits a ribbon only by chance). The way along them is found on a fine grid (a tenth of a unit, the
-- height scanned finely about the neighbour's) and walked with the keys, leg by leg, planned again when Guybrush comes off the way.
a3_is_ribbon = function()
	return AR_RIBBON_SETS[ar_set_name()]
end
a3r_floor = function(x, y, z)
	-- the floor under the place nearest to the height y, a step at the most (the port's GetFloorHeights: the planes of the walk sectors
	-- over/under x, z, so a ribbon is found whatever its slope)
	local fh = GetFloorHeights(x, z)
	local fi = 1
	local fb = nil
	local fd = 0.8
	while fh[fi] do
		local d = abs(fh[fi] - y)
		if d <= fd then
			fd = d
			fb = fh[fi]
		end
		fi = fi + 1
	end
	return fb
end
-- the way from Guybrush toward (gx, gz): a list of { x, z } every half unit, ending at the goal or at the cell nearest to it; nil when
-- there is no floor about him at all
A3R_BLOCK = { }
A3R_BLOCK_SET = nil
A3R_JX = { 5, -5, 0, 0, 4, 4, -4, -4, 8, -8, 0, 0, 6, 6, -6, -6 }
A3R_JZ = { 0, 0, 5, -5, 4, -4, 4, -4, 0, 0, 8, -8, 6, -6, 6, -6 }
a3r_plan = function(gx, gz)
	if A3R_BLOCK_SET ~= ar_set_name() then
		A3R_BLOCK_SET = ar_set_name()
		A3R_BLOCK = { }
	end
	local p = manny:getpos()
	local px = floor(p.x * 10 + 0.5)
	local pz = floor(p.z * 10 + 0.5)
	local prev = { }
	local cy = { }
	local qx = { }
	local qz = { }
	local sk = (px + 1000) * 3000 + (pz + 1000)
	local sid, startdoor = GetPointSector(p.x, p.y, p.z, HOT)
	prev[sk] = -1
	cy[sk] = p.y
	qx[1] = px
	qz[1] = pz
	local head = 1
	local tail = 1
	local bestk = sk
	local bestd = (px / 10 - gx) * (px / 10 - gx) + (pz / 10 - gz) * (pz / 10 - gz)
	local dxs = { 1, -1, 0, 0, 1, 1, -1, -1 }
	local dzs = { 0, 0, 1, -1, 1, -1, 1, -1 }
	local found = nil
	A3R_TN = 0
	A3R_TX = { }
	A3R_TZ = { }
	A3R_TD = { }
	while head <= tail and not found and head < 30000 do
		local cx = qx[head]
		local cz = qz[head]
		local ck = (cx + 1000) * 3000 + (cz + 1000)
		head = head + 1
		local k = 1
		while k <= 8 do
			local nx = cx + dxs[k]
			local nz = cz + dzs[k]
			local nk = (nx + 1000) * 3000 + (nz + 1000)
			if not prev[nk] then
				local ny = nil
				if not A3R_BLOCK[nk] then
					ny = a3r_floor(nx / 10, cy[ck], nz / 10)
				end
				if ny and A3R_AVOID_DOORS then
					-- (not through the boxes of the set's doors on the way: the box would take Guybrush out of the set)
					local hid, hname = GetPointSector(nx / 10, ny, nz / 10, HOT)
					if hid and hname and strfind(hname, "door", 1, TRUE) and hname ~= startdoor and hname ~= A3R_DOOR then
						local door = nil
						if a3_hot_door_exact then
							door = a3_hot_door_exact(nx / 10, ny, nz / 10)
						end
						if not door or (door ~= A3_TARGET_OBJ and door ~= A3_START_OBJ) then
							ny = nil
						end
					end
				end
				if ny then
					prev[nk] = ck
					cy[nk] = ny
					tail = tail + 1
					qx[tail] = nx
					qz[tail] = nz
					local d = (nx / 10 - gx) * (nx / 10 - gx) + (nz / 10 - gz) * (nz / 10 - gz)
					if d < bestd then
						bestd = d
						bestk = nk
					end
					if d < 0.16 then
						found = nk
						bestk = nk
					end
					if A3R_DOOR then
						local hid, hname = GetPointSector(nx / 10, ny, nz / 10, HOT)
						if hid and hname == A3R_DOOR then
							found = nk
							bestk = nk
						end
					end
					if A3R_OBJ then
						local ddy = ny - A3R_OBJ.y
						if (nx / 10 - A3R_OBJ.x) * (nx / 10 - A3R_OBJ.x) + (nz / 10 - A3R_OBJ.z) * (nz / 10 - A3R_OBJ.z) + ddy * ddy <= A3R_RANGE * A3R_RANGE then
							found = nk
							bestk = nk
						end
					end
				else
					prev[nk] = -2
				end
			end
			k = k + 1
		end
		-- A dead end of the ribbon (few floor cells about it): the next piece can lie a little beyond a gap, which the keys take
		-- Guybrush over when it is no wider than a few steps of the grid
		local nfloor = 0
		k = 1
		while k <= 8 do
			if cy[((cx + dxs[k]) + 1000) * 3000 + ((cz + dzs[k]) + 1000)] then
				nfloor = nfloor + 1
			end
			k = k + 1
		end
		if nfloor <= 3 then
			A3R_TN = A3R_TN + 1
			A3R_TX[A3R_TN] = cx / 10
			A3R_TZ[A3R_TN] = cz / 10
			A3R_TD[A3R_TN] = (cx / 10 - gx) * (cx / 10 - gx) + (cz / 10 - gz) * (cz / 10 - gz)
			k = 1
			while k <= 16 do
				local nx = cx + A3R_JX[k]
				local nz = cz + A3R_JZ[k]
				local nk = (nx + 1000) * 3000 + (nz + 1000)
				if not prev[nk] and not A3R_BLOCK[nk] then
					local ny = a3r_floor(nx / 10, cy[ck], nz / 10)
					if ny then
						prev[nk] = ck
						cy[nk] = ny
						tail = tail + 1
						qx[tail] = nx
						qz[tail] = nz
						local d = (nx / 10 - gx) * (nx / 10 - gx) + (nz / 10 - gz) * (nz / 10 - gz)
						if d < bestd then
							bestd = d
							bestk = nk
						end
					end
				end
				k = k + 1
			end
		end
	end
	A3R_LASTN = tail
	A3R_FOUND = found
	-- the dead ends nearest to the goal, a couple of units apart
	local tips = { }
	local nt = 0
	local want = 0
	while want < 6 do
		local bi = nil
		local bdv = 1e9
		local i = 1
		while i <= A3R_TN do
			if A3R_TD[i] < bdv then
				local clear = TRUE
				local j = 1
				while j <= nt do
					if abs(tips[j][1] - A3R_TX[i]) + abs(tips[j][2] - A3R_TZ[i]) < 2.5 then
						clear = nil
					end
					j = j + 1
				end
				if clear then
					bdv = A3R_TD[i]
					bi = i
				end
			end
			i = i + 1
		end
		if not bi then
			want = 6
		else
			nt = nt + 1
			tips[nt] = { A3R_TX[bi], A3R_TZ[bi] }
			want = want + 1
		end
	end
	A3R_TIPS = tips
	if bestk == sk then
		return nil, sqrt(bestd)
	end
	local rev = { }
	local n = 0
	local k = bestk
	while k ~= sk do
		n = n + 1
		local cz = mod(k, 3000)
		local cx = (k - cz) / 3000 - 1000
		cz = cz - 1000
		rev[n] = { cx / 10, cz / 10 }
		k = prev[k]
	end
	local path = { }
	local m = 0
	local i = n
	while i >= 1 do
		m = m + 1
		path[m] = rev[i]
		i = i - 5
	end
	if path[m][1] ~= rev[1][1] or path[m][2] ~= rev[1][2] then
		m = m + 1
		path[m] = rev[1]
	end
	return path, sqrt(bestd)
end
A3R_PX = { 0.0, 0.342, 0.643, 0.866, 0.985, 0.985, 0.866, 0.643, 0.342, 0.0, -0.342, -0.643, -0.866, -0.985, -0.985, -0.866, -0.643, -0.342 }
A3R_PZ = { 1.0, 0.94, 0.766, 0.5, 0.174, -0.174, -0.5, -0.766, -0.94, -1.0, -0.94, -0.766, -0.5, -0.174, 0.174, 0.5, 0.766, 0.94 }
-- At the end of the floor that was found: the ways out of that spot felt for with the keys, those leading toward the goal first. A step
-- of a metre toward each; the first that gets Guybrush on (nearer to the goal than he was, or higher up/lower down onto other floor)
-- counts. nil when none does.
a3r_feel_out = function(gx, gz)
	local p = manny:getpos()
	local gd = ar_floor_dist(gx, gz)
	local gdx = (gx - p.x) / gd
	local gdz = (gz - p.z) / gd
	local used = { }
	local n = 0
	while n < 18 do
		local best = nil
		local bs = -9
		local i = 1
		while i <= 18 do
			if not used[i] then
				local sc = A3R_PX[i] * gdx + A3R_PZ[i] * gdz
				if sc > bs then
					bs = sc
					best = i
				end
			end
			i = i + 1
		end
		used[best] = TRUE
		n = n + 1
		local keep = AR_WALK_TOL
		AR_WALK_TOL = 0.1
		A3_WALK_DIRECT_PLAIN(p.x + A3R_PX[best] * 1.0, p.y, p.z + A3R_PZ[best] * 1.0, nil, 1500)
		AR_WALK_TOL = keep
		local q = manny:getpos()
		local moved = abs(q.x - p.x) + abs(q.z - p.z)
		if moved > 0.5 and (ar_floor_dist(gx, gz) < gd - 0.2 or abs(q.y - p.y) > 0.4) then
			return TRUE
		end
		-- (back to where it was begun from, for the next try)
		if moved > 0.2 then
			A3_WALK_DIRECT_PLAIN(p.x, p.y, p.z, nil, 1500)
		end
	end
	return nil
end
A3R_TRIED = { }
a3r_tipkey = function(x, z)
	return (floor(x * 0.4 + 0.5) + 1000) * 3000 + (floor(z * 0.4 + 0.5) + 1000)
end
a3r_len = function(t)
	local n = 0
	while t[n + 1] do
		n = n + 1
	end
	return n
end
a3_ribbon_walk = function(gx, gz, stop_when, max_ms)
	local budget = max_ms or AR_WALK_MAX or 150000
	local waited = 0
	local startset = system.currentSet
	local rounds = 0
	local tol = AR_WALK_TOL or 0.3
	if not A3R_NESTED then
		A3R_TRIED = { }
	end
	ar_wait_for_control()
	manny:set_run(TRUE)
	while ar_floor_dist(gx, gz) > tol and waited < budget and system.currentSet == startset and not (stop_when and stop_when()) and rounds < 80 do
		rounds = rounds + 1
		local path, left = a3r_plan(gx, gz)
		if not path then
			ar_log(format("ribbon walk: no way nearer to %.2f %.2f (%.1f away)", gx, gz, left))
			return nil
		end
		ar_log(format("ribbon way: %d points from %.1f %.1f, first %.1f %.1f, last %.1f %.1f, %.1f from the goal", a3r_len(path), manny:getpos().x, manny:getpos().z, path[1][1], path[1][2], path[a3r_len(path)][1], path[a3r_len(path)][2], left))
		local i = 1
		local off = nil
		while path[i] and not off and system.currentSet == startset and not (stop_when and stop_when()) do
			local keep = AR_WALK_TOL
			AR_WALK_TOL = 0.2
			local before = manny:getpos()
			A3_WALK_DIRECT_PLAIN(path[i][1], before.y, path[i][2], nil, 3000)
			AR_WALK_TOL = keep
			waited = waited + 1000
			if ar_floor_dist(path[i][1], path[i][2]) > 0.6 then
				off = TRUE
				-- (the engine does not take Guybrush there, though the floor is: not planned through again)
				if path[i + 1] then
					local bx = floor(path[i][1] * 10 + 0.5)
					local bz = floor(path[i][2] * 10 + 0.5)
					local ox = 0
					while ox <= 0 do
						local oz = 0
						while oz <= 0 do
							A3R_BLOCK[(bx + ox + 1000) * 3000 + (bz + oz + 1000)] = TRUE
							oz = oz + 1
						end
						ox = ox + 1
					end
				end
			end
			i = i + 1
		end
		if not off and ar_floor_dist(gx, gz) <= left + 0.35 and left <= 1.0 then
			-- (the nearest floor to the point reached: the point itself is a little off the ribbon)
			return TRUE
		end
		if not off and left > 1.5 then
			-- (the end of the floor that could be found: not at the goal)
			if ar_floor_dist(gx, gz) > left + 0.5 then
				off = TRUE
			elseif a3r_feel_out(gx, gz) then
				ar_log(format("ribbon walk: on from the end of the floor, at %.2f %.2f", manny:getpos().x, manny:getpos().z))
			else
				-- (not from here: from the other dead ends of the floor, the nearest to the goal first)
				local tips = A3R_TIPS
				local ti = 1
				local got = nil
				while tips[ti] and not got and ti <= 6 do
					if not A3R_TRIED[a3r_tipkey(tips[ti][1], tips[ti][2])] then
						A3R_TRIED[a3r_tipkey(tips[ti][1], tips[ti][2])] = TRUE
						ar_log(format("ribbon walk: feeling for a way on at the dead end %.1f %.1f", tips[ti][1], tips[ti][2]))
						A3R_NESTED = TRUE
						a3_ribbon_walk(tips[ti][1], tips[ti][2], stop_when, 60000)
						A3R_NESTED = nil
						if a3r_feel_out(gx, gz) then
							got = TRUE
						end
					end
					ti = ti + 1
				end
				if not got then
					rounds = 80
				end
			end
		end
	end
	if ar_floor_dist(gx, gz) > tol and system.currentSet == startset and not (stop_when and stop_when()) then
		-- (the floor found ends short of the point: the last bit straight on, as far as the floor goes)
		local p0 = manny:getpos()
		A3_WALK_DIRECT_PLAIN(gx, p0.y, gz, stop_when, 4000)
	end
	if ar_floor_dist(gx, gz) > tol and system.currentSet == startset and not (stop_when and stop_when()) then
		local p = manny:getpos()
		ar_log(format("ribbon walk stopped at %.2f %.2f after %d rounds toward %.2f %.2f", p.x, p.z, rounds, gx, gz))
		return nil
	end
	return TRUE
end
A3_WALK_DIRECT_PLAIN = ar_walk_direct
ar_walk_direct = function(x, y, z, stop_when, max_ms)
	if a3_is_ribbon() then
		return a3_ribbon_walk(x, z, stop_when, max_ms)
	end
	return A3_WALK_DIRECT_PLAIN(x, y, z, stop_when, max_ms)
end

-- On a ribbon floor an object is approached to a cell of the ribbon inside its range (the nearest by way), not to the use point of the
-- object, which can lie on floor that is not joined to the ribbon
A3_APPROACH_RIBBON = ar_approach
a3r_in_range = function(o, r)
	local p = manny:getpos()
	return (p.x - o.x) * (p.x - o.x) + (p.y - o.y) * (p.y - o.y) + (p.z - o.z) * (p.z - o.z) <= r * r
end
-- the names the object has in the set (the door's trigger sector is named as one of them)
a3r_keys_of = function(obj)
	local set = system.currentSet
	local keys = { }
	local n = 0
	local k, v = next(set, nil)
	while k do
		if v == obj and type(k) == "string" then
			n = n + 1
			keys[n] = k
		end
		k, v = next(set, k)
	end
	return keys, n
end
ar_approach = function(obj)
	-- a door on a ribbon floor: walked to by way of the floor into its box (the trigger sector of the door, named as the object)
	if a3_is_ribbon() and type(obj) == "table" and obj.walkOut then
		local keys, nk = a3r_keys_of(obj)
		ar_log("ribbon door keys " .. nk .. " first " .. tostring(keys[1]) .. " is_path " .. tostring(lav and obj == lav.mom_door_path) .. " out " .. tostring(obj.out_pnt_x) .. " " .. tostring(obj.out_pnt_z))
		local startset = system.currentSet
		local ki = 1
		while ki <= nk and system.currentSet == startset do
			local rounds = 0
			while rounds < 6 and system.currentSet == startset do
				rounds = rounds + 1
				A3R_DOOR = keys[ki]
				local path, left = a3r_plan(99999, 99999)
				A3R_DOOR = nil
				ar_log("ribbon door try " .. tostring(keys[ki]) .. ": cells " .. tostring(A3R_LASTN) .. " found " .. tostring(A3R_FOUND) .. " path " .. tostring(path ~= nil))
				if not path or not A3R_FOUND then
					rounds = 6
				else
					ar_log(format("ribbon door %s: %d points", keys[ki], a3r_len(path)))
					local i = 1
					while path[i] and system.currentSet == startset do
						local keep = AR_WALK_TOL
						AR_WALK_TOL = 0.15
						A3_WALK_DIRECT_PLAIN(path[i][1], manny:getpos().y, path[i][2], nil, 3000)
						AR_WALK_TOL = keep
						i = i + 1
					end
				end
			end
			ki = ki + 1
		end
		if system.currentSet ~= startset then
			return TRUE
		end
	end
	if a3_is_ribbon() and type(obj) == "table" and obj.range then
		local o = ar_obj_pos(obj)
		if o and o.x then
			local r = (tonumber(obj.range) or 3) - 0.25
			local rounds = 0
			while rounds < 8 and not a3r_in_range(o, r + 0.1) do
				rounds = rounds + 1
				A3R_OBJ = o
				A3R_RANGE = r
				local path, left = a3r_plan(o.x, o.z)
				A3R_OBJ = nil
				if not path then
					rounds = 8
				else
					local i = 1
					while path[i] and not a3r_in_range(o, r + 0.1) do
						local keep = AR_WALK_TOL
						AR_WALK_TOL = 0.2
						A3_WALK_DIRECT_PLAIN(path[i][1], manny:getpos().y, path[i][2], nil, 3000)
						AR_WALK_TOL = keep
						i = i + 1
					end
				end
			end
			ar_log(format("ribbon approach: %s in range %s", tostring(obj.name), tostring(a3r_in_range(o, r + 0.1))))
		end
	end
	return A3_APPROACH_RIBBON(obj)
end
