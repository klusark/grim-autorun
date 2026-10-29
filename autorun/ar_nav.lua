-- Walking Manny with the keys along a planned way, the same on both engines.
--
-- The world of a set is what its sectors are to the game (read from the set file by nav_setfile.lua):
--   * the walk sectors that are on are the floor;
--   * a hot sector is what Doorman makes of it when Manny steps in: one of the set's cheat_boxes puts him on its opposite edge
--     (teleport_out_of_hot_box), one that the set names after an object with walkOut (or climbOut) is a door or a trigger, any
--     other does nothing;
--   * in a sector whose name holds "stair" or "curb" (of any type) stairman and curbman constrain Manny: he walks along one line
--     only, from where he came in to the opposite edge of the walk sector, and not at all with a heading more than the reflection
--     angle (80 degrees) off it.
-- One search plans every walk: A* over cells of 8 centimetres of the floor, with the cheat boxes and the constrained sectors as
-- links of their own (a step into a cheat box lands on its far side; a stair is walked along its line), and a goal that is a point
-- or the sector of a door. A step costs its length, more near anything that is not plain floor (so the way keeps to the middle),
-- much more through the sector of a door or trigger that is not the goal. The way is then pulled straight where the floor allows.
-- One follower walks it: it aims at a point a little ahead on the way, turns on the spot when the heading is far off, and stops
-- exactly only where it has to (the step into a link, the goal). When the way gets no shorter for a while, the cells in front of
-- Manny are taken to be blocked (an actor, a wall the data does not know) and the walk is planned again from where he is; so is a
-- move of the game that was not planned.
--
-- AR_NAV[set name] = { n = { sector names }, t = { types }, p = { { x, y, z, ... } per sector }, hn = { hot sector names },
--                      hp = { { x, y, z, ... } per hot sector } }
-- Lua 3.1: no closures over locals, no for loops, no break, at most 32 locals in a function: globals and while loops.

-- (a save brings back the lists of the run that made it: they are read again)
AR_NAV = { }
AR_SLICE = TRUE

-- Every move of an actor to a place (PutActorAt: setpos, moveto, the cheat boxes' teleport_out_of_hot_box, a script that puts Manny
-- somewhere) goes through one builtin. It is wrapped once, so that every jump of Manny is seen for what it is, with where he was, where
-- he was put and the hot sector he stood in, and not guessed from how far he moved in a frame.
AR_TELE_COUNT = AR_TELE_COUNT or 0
ar_tele_note = function(x, y, z)
	if AR_TELE_QUIET or not system.currentSet then
		return
	end
	local p = manny:getpos()
	local hid, hname = manny:find_sector_type(HOT)
	AR_TELE_COUNT = AR_TELE_COUNT + 1
	AR_TELE = { fx = p.x, fy = p.y, fz = p.z, tx = x, ty = y, tz = z, hot = hname, set = system.currentSet, n = AR_TELE_COUNT }
end
if not AR_PUT_HOOKED then
	AR_PUT_HOOKED = TRUE
	AR_PUT_ORIG = PutActorAt
	PutActorAt = function(h, x, y, z)
		if manny and h == manny.hActor then
			ar_tele_note(x, y, z)
		end
		return AR_PUT_ORIG(h, x, y, z)
	end
end
-- The actors that collide (a box or a sphere that Manny cannot walk through): the mode is set by the scripts through one builtin.
-- AR_COLL[handle] = the mode, nil when it is off. Where Manny is held up against one the walk learns it (AR_OBST) and plans round it.
AR_COLL = AR_COLL or { }
AR_OBST = AR_OBST or { }
if not AR_COLL_HOOKED then
	AR_COLL_HOOKED = TRUE
	AR_COLL_ORIG = SetActorCollisionMode
	SetActorCollisionMode = function(h, mode)
		if mode and mode ~= 0 then
			AR_COLL[h] = mode
		else
			AR_COLL[h] = nil
		end
		return AR_COLL_ORIG(h, mode)
	end
end
-- The set each actor is in (the position of an actor stays when it is taken out of a set, and means nothing then)
AR_ACT_SET = AR_ACT_SET or { }
if not AR_SET_HOOKED then
	AR_SET_HOOKED = TRUE
	AR_SET_ORIG = PutActorInSet
	PutActorInSet = function(h, setfile)
		AR_ACT_SET[h] = setfile
		return AR_SET_ORIG(h, setfile)
	end
end
-- (the size of the box of an actor is not known to the scripts: the middle third of a man's box is round about this)
AR_OBST_DEFAULT = 0.45
AR_CS = 0.08

-- the number of elements of a list (the game has no getn)
ar_nav_len = function(t)
	local n = 0
	while t[n + 1] do
		n = n + 1
	end
	return n
end

-- the count of the corners and the box round each sector, kept with the sectors
ar_nav_prep = function(nav)
	local pn = { }
	local minx = { }
	local maxx = { }
	local miny = { }
	local maxy = { }
	local count = ar_nav_len(nav.p)
	local i = 1
	while i <= count do
		local p = nav.p[i]
		local n = ar_nav_len(p) / 3
		pn[i] = n
		local k = 1
		local x0 = p[1]
		local y0 = p[2]
		local x1 = x0
		local y1 = y0
		while k <= n do
			local x = p[(k - 1) * 3 + 1]
			local y = p[(k - 1) * 3 + 2]
			if x < x0 then x0 = x end
			if x > x1 then x1 = x end
			if y < y0 then y0 = y end
			if y > y1 then y1 = y end
			k = k + 1
		end
		minx[i] = x0
		maxx[i] = x1
		miny[i] = y0
		maxy[i] = y1
		i = i + 1
	end
	nav.cnt = count
	nav.pn = pn
	nav.minx = minx
	nav.maxx = maxx
	nav.miny = miny
	nav.maxy = maxy
end

ar_nav_count = function(nav)
	if not nav.cnt then
		ar_nav_prep(nav)
	end
	return nav.cnt
end

-- the hot sectors as a nav of their own
ar_nav_hotnav = function(nav)
	if not nav.hotnav then
		nav.hotnav = { p = nav.hp or { }, n = nav.hn or { }, hot = TRUE }
	end
	return nav.hotnav
end

ar_nav_hcount = function(nav)
	return ar_nav_count(ar_nav_hotnav(nav))
end

-- is (x, y) inside sector i of nav (the polygon seen from above)
ar_nav_inside = function(nav, i, x, y)
	if not nav.cnt then
		ar_nav_prep(nav)
	end
	if x < nav.minx[i] or x > nav.maxx[i] or y < nav.miny[i] or y > nav.maxy[i] then
		return nil
	end
	local p = nav.p[i]
	local n = nav.pn[i]
	local inside = nil
	local k = 1
	local j = n
	while k <= n do
		local xk = p[(k - 1) * 3 + 1]
		local yk = p[(k - 1) * 3 + 2]
		local xj = p[(j - 1) * 3 + 1]
		local yj = p[(j - 1) * 3 + 2]
		if (yk > y) ~= (yj > y) and x < (xj - xk) * (y - yk) / (yj - yk) + xk then
			if inside then
				inside = nil
			else
				inside = TRUE
			end
		end
		j = k
		k = k + 1
	end
	return inside
end

-- the height of the (planar) sector i at (x, y)
ar_nav_z = function(nav, i, x, y)
	local p = nav.p[i]
	local ax = p[1]
	local ay = p[2]
	local az = p[3]
	local bx = p[4]
	local by = p[5]
	local bz = p[6]
	local cx = p[7]
	local cy = p[8]
	local cz = p[9]
	local den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
	if abs(den) < 0.000001 then
		return az
	end
	local l1 = ((by - cy) * (x - cx) + (cx - bx) * (y - cy)) / den
	local l2 = ((cy - ay) * (x - cx) + (ax - cx) * (y - cy)) / den
	return l1 * az + l2 * bz + (1 - l1 - l2) * cz
end

-- a point inside sector i (the middle of its first corners: the sectors are convex), for the probe of ar_nav_active
ar_nav_probe = function(nav, i)
	local p = nav.p[i]
	return (p[1] + p[4] + p[7]) / 3, (p[2] + p[5] + p[8]) / 3, (p[3] + p[6] + p[9]) / 3
end

-- is sector i switched on? IsPointInSector never finds a point in a sector that is off (on both engines); its answer is the first
-- sector whose name holds the given one, so when another sector answers instead (floor_7 / floor_72) the sector is taken to be on
ar_nav_active = function(nav, i)
	-- (a way that is only there when a floor that is off comes on, as it does when Manny comes near: the planner's second try)
	if AR_OPTIMISTIC and not nav.hot then
		return TRUE
	end
	local x, y, z = ar_nav_probe(nav, i)
	local id, name = IsPointInSector(x, y, z, nav.n[i])
	if not id or name == nav.n[i] then
		return id
	end
	return TRUE
end

-- is the sector of the current set with this name switched on?
ar_sector_on = function(name)
	local nav = ar_nav_of(system.currentSet)
	local i = 1
	while nav.n[i] do
		if nav.n[i] == name then
			if ar_nav_active(nav, i) then
				return TRUE
			end
			return nil
		end
		i = i + 1
	end
	return nil
end

-- the cells round a point as a picture in the log (the code of each cell: . none, 1 floor, 2 stair, 3 cheat box, 4 door), north up
ar_w_picture = function(nav, w, cx, cy, z)
	local y = cy + 0.64
	while y >= cy - 0.64 do
		local line = format("%6.2f ", y)
		local x = cx - 0.8
		while x <= cx + 0.8 do
			local k = ar_w_key(w, x, y)
			local c = k and ar_w_code(nav, w, k, z)
			line = line .. tostring(c or ".")
			x = x + AR_CS
		end
		ar_log("nav: grid " .. line)
		y = y - AR_CS
	end
end

-- the names of the sectors of the set that are off, for a log
ar_nav_off_list = function(nav)
	local off = ""
	local hot = ar_nav_hotnav(nav)
	local i = 1
	while nav.n[i] do
		if not ar_nav_active(nav, i) then
			off = off .. nav.n[i] .. " "
		end
		i = i + 1
	end
	i = 1
	while hot.n[i] do
		if not ar_nav_active(hot, i) then
			off = off .. hot.n[i] .. " "
		end
		i = i + 1
	end
	return off
end

-- the mean of the corners of sector i
ar_nav_centre = function(nav, i)
	local p = nav.p[i]
	local n = ar_nav_len(p) / 3
	local sx = 0
	local sy = 0
	local k = 0
	while k < n do
		sx = sx + p[k * 3 + 1]
		sy = sy + p[k * 3 + 2]
		k = k + 1
	end
	return sx / n, sy / n
end

-- the sector (on) that holds (x, y) nearest to the height z, nil if there is none
ar_nav_find = function(nav, x, y, z)
	local best = nil
	local bestd = 1000000
	local count = ar_nav_count(nav)
	local i = 1
	while i <= count do
		if ar_nav_inside(nav, i, x, y) and ar_nav_active(nav, i) then
			local d = abs(ar_nav_z(nav, i, x, y) - z)
			if d < bestd then
				bestd = d
				best = i
			end
		end
		i = i + 1
	end
	return best
end

-- a sector (on or off) that holds (x, y) at about the height z
ar_nav_find_any = function(nav, x, y, z)
	local count = ar_nav_count(nav)
	local i = 1
	while i <= count do
		if ar_nav_inside(nav, i, x, y) and abs(ar_nav_z(nav, i, x, y) - z) < 0.3 then
			return i
		end
		i = i + 1
	end
	return nil
end

-- a sector (on) that holds (x, y) within tol of the height z, or nil
-- The height of the floor at (x, y) that is nearest to z (the level Manny is on), nil where there is no floor
ar_nav_floor_z = function(nav, x, y, z)
	local count = ar_nav_count(nav)
	local best = nil
	local i = 1
	while i <= count do
		if ar_nav_inside(nav, i, x, y) and ar_nav_active(nav, i) then
			local fz = ar_nav_z(nav, i, x, y)
			if not best or abs(fz - z) < abs(best - z) then
				best = fz
			end
		end
		i = i + 1
	end
	return best
end

ar_nav_find_z = function(nav, x, y, z, tol)
	local count = ar_nav_count(nav)
	local i = 1
	while i <= count do
		if ar_nav_inside(nav, i, x, y) and abs(ar_nav_z(nav, i, x, y) - z) < tol and ar_nav_active(nav, i) then
			return i
		end
		i = i + 1
	end
	return nil
end

-- the closest point of sector i to (x, y): its distance and the point
ar_nav_nearest_on = function(nav, i, x, y)
	local p = nav.p[i]
	local n = ar_nav_len(p) / 3
	local bestd = 1000000
	local bx = x
	local by = y
	local bz = 0
	local k = 1
	while k <= n do
		local k2 = k + 1
		if k2 > n then
			k2 = 1
		end
		local ax = p[(k - 1) * 3 + 1]
		local ay = p[(k - 1) * 3 + 2]
		local az = p[(k - 1) * 3 + 3]
		local dx = p[(k2 - 1) * 3 + 1] - ax
		local dy = p[(k2 - 1) * 3 + 2] - ay
		local len2 = dx * dx + dy * dy
		local t = 0
		if len2 > 0.0000001 then
			t = ((x - ax) * dx + (y - ay) * dy) / len2
		end
		if t < 0 then
			t = 0
		end
		if t > 1 then
			t = 1
		end
		local px = ax + t * dx
		local py = ay + t * dy
		local d = sqrt((px - x) * (px - x) + (py - y) * (py - y))
		if d < bestd then
			bestd = d
			bx = px
			by = py
			bz = az + t * (p[(k2 - 1) * 3 + 3] - az)
		end
		k = k + 1
	end
	return bestd, bx, by, bz
end

-- the sector (on) closest to (x, y), on the level of zf if that is given, and the point of it that is closest
ar_nav_closest = function(nav, x, y, zf)
	local best = nil
	local bestd = 1000000
	local bx = x
	local by = y
	local bz = 0
	local count = ar_nav_count(nav)
	local i = 1
	while i <= count do
		if ar_nav_active(nav, i) then
			local d, px, py, pz = ar_nav_nearest_on(nav, i, x, y)
			if zf and abs(pz - zf) > 0.6 then
				d = 1000000
			end
			if d < bestd then
				bestd = d
				best = i
				bx = px
				by = py
				bz = pz
			end
		end
		i = i + 1
	end
	if zf and (not best or bestd > 1.0) then
		return ar_nav_closest(nav, x, y)
	end
	return best, bx, by, bz
end

ar_heap_push = function(h, key, f)
	local i = h.n + 1
	h.n = i
	h.k[i] = key
	h.f[i] = f
	while i > 1 and h.f[floor(i / 2)] > h.f[i] do
		local p = floor(i / 2)
		local tk = h.k[p]
		local tf = h.f[p]
		h.k[p] = h.k[i]
		h.f[p] = h.f[i]
		h.k[i] = tk
		h.f[i] = tf
		i = p
	end
end

ar_heap_pop = function(h)
	local top = h.k[1]
	h.k[1] = h.k[h.n]
	h.f[1] = h.f[h.n]
	h.n = h.n - 1
	local i = 1
	local moving = TRUE
	while moving do
		local c = i * 2
		if c > h.n then
			moving = nil
		else
			if c + 1 <= h.n and h.f[c + 1] < h.f[c] then
				c = c + 1
			end
			if h.f[c] < h.f[i] then
				local tk = h.k[c]
				local tf = h.f[c]
				h.k[c] = h.k[i]
				h.f[c] = h.f[i]
				h.k[i] = tk
				h.f[i] = tf
				i = c
			else
				moving = nil
			end
		end
	end
	return top
end

---------------------------------------------------------------------------------------------------------------------------------
-- The world of the current set

-- does the name hold the word (a substring, as the game's find_sector_name tests it)
ar_has_word = function(name, word)
	return name and strfind(name, word, 1, 1)
end

-- the world of the set Manny is in: its cells (worked out as they are needed) and what its hot sectors do
ar_w = function(nav)
	if nav.w and nav.w.set == system.currentSet then
		return nav.w
	end
	local w = { set = system.currentSet, geo = { }, cheat = { }, door = { }, cons = { }, hcons = { }, lk = { }, dead = { }, tmp = { } }
	local count = ar_nav_count(nav)
	local x0 = 1000000
	local x1 = -1000000
	local y0 = 1000000
	local y1 = -1000000
	local i = 1
	while i <= count do
		if nav.minx[i] < x0 then x0 = nav.minx[i] end
		if nav.maxx[i] > x1 then x1 = nav.maxx[i] end
		if nav.miny[i] < y0 then y0 = nav.miny[i] end
		if nav.maxy[i] > y1 then y1 = nav.maxy[i] end
		if ar_has_word(nav.n[i], "stair") or ar_has_word(nav.n[i], "curb") then
			w.cons[i] = TRUE
		end
		i = i + 1
	end
	w.x0 = x0 - AR_CS
	w.y0 = y0 - AR_CS
	w.nx = floor((x1 - x0) / AR_CS) + 4
	w.ny = floor((y1 - y0) / AR_CS) + 4
	w.kn = w.nx * w.ny
	-- (what Doorman makes of each hot sector)
	local hot = ar_nav_hotnav(nav)
	local cb = system.currentSet.cheat_boxes or { }
	local hc = ar_nav_hcount(nav)
	i = 1
	while i <= hc do
		local name = hot.n[i]
		local obj = system.currentSet[name]
		if ar_has_word(name, "stair") or ar_has_word(name, "curb") then
			w.hcons[i] = TRUE
		elseif cb[name] then
			w.cheat[i] = TRUE
		elseif type(obj) == "table" and (obj.walkOut or obj.climbOut) then
			w.door[i] = obj
		end
		i = i + 1
	end
	nav.w = w
	ar_w_links(nav, w)
	return w
end

-- the key of the cell that holds (x, y), and the cell's column and row
ar_w_key = function(w, x, y)
	local ix = floor((x - w.x0) / AR_CS + 0.5)
	local iy = floor((y - w.y0) / AR_CS + 0.5)
	if ix < 0 or iy < 0 or ix >= w.nx or iy >= w.ny then
		return nil
	end
	return iy * w.nx + ix + 1
end

-- What lies in the cell k, for every floor that reaches into it: { e = { { si = sector, x, y = its point in the cell, part = TRUE if that
-- is not the centre, h = { hot sectors there } }, ... } }, or FALSE. The point of a sector is the cell's centre if that is in it, else
-- the point of the sector nearest to the centre, a little inside it (a gangway narrower than a cell still has its cells, and a floor
-- under or over another has its own point).
ar_w_geo = function(nav, w, k)
	local g = w.geo[k]
	if g then
		-- (0: no floor reaches into the cell; FALSE would be nil, which stores nothing)
		if g == 0 then
			return nil
		end
		return g
	end
	local ix = (k - 1) - w.nx * floor((k - 1) / w.nx)
	local iy = floor((k - 1) / w.nx)
	local cx = w.x0 + ix * AR_CS
	local cy = w.y0 + iy * AR_CS
	local h = AR_CS / 2
	local e = { }
	local n = 0
	local count = ar_nav_count(nav)
	local i = 1
	while i <= count do
		if nav.minx[i] <= cx + h and nav.maxx[i] >= cx - h and nav.miny[i] <= cy + h and nav.maxy[i] >= cy - h then
			local x, y, part = ar_w_point_in(nav, i, cx, cy)
			if x then
				n = n + 1
				e[n] = { si = i, x = x, y = y, part = part, h = ar_w_hot_at(nav, x, y) }
			end
		end
		i = i + 1
	end
	if n == 0 then
		w.geo[k] = 0
		return nil
	end
	g = { e = e }
	w.geo[k] = g
	return g
end

-- the point of sector i for the cell round (cx, cy) (see ar_w_geo), and whether it is not the centre; nil if the sector does not reach
-- into the cell
ar_w_point_in = function(nav, i, cx, cy)
	if ar_nav_inside(nav, i, cx, cy) then
		return cx, cy, nil
	end
	local h = AR_CS / 2
	local d, px, py = ar_nav_nearest_on(nav, i, cx, cy)
	if abs(px - cx) > h or abs(py - cy) > h then
		return nil
	end
	local mx, my = ar_nav_centre(nav, i)
	local ml = sqrt((mx - px) * (mx - px) + (my - py) * (my - py))
	local step = 0.002
	while ml > 0.0001 and step <= 0.016 do
		local qx = px + (mx - px) / ml * step
		local qy = py + (my - py) / ml * step
		if ar_nav_inside(nav, i, qx, qy) then
			return qx, qy, TRUE
		end
		step = step * 2
	end
	return nil
end

-- the hot sectors (on or off) that hold (x, y)
ar_w_hot_at = function(nav, x, y)
	local hot = ar_nav_hotnav(nav)
	local hc = ar_nav_hcount(nav)
	local list = { }
	local n = 0
	local i = 1
	while i <= hc do
		if ar_nav_inside(hot, i, x, y) then
			n = n + 1
			list[n] = i
		end
		i = i + 1
	end
	return list
end

-- What the cell k is to Manny at about the height zref: nil when no floor (on) is there at that height, else its kind and height: 1
-- floor, 2 constrained (stairs, curbs), 3 a cheat box, 4 a door or trigger. The floor it is (an entry of ar_w_geo) is AR_W_E then, its
-- point AR_W_X, AR_W_Y, and AR_W_HOT the hot sector of a cheat box or door. A cheat box or door that is off does nothing.
ar_w_code = function(nav, w, k, zref)
	local g = ar_w_geo(nav, w, k)
	if not g then
		return nil
	end
	local best = nil
	local bestlvl = 1
	local bestd = 0.35
	local bz = 0
	local i = 1
	while g.e[i] do
		local e = g.e[i]
		if ar_nav_active(nav, e.si) then
			local z = ar_nav_z(nav, e.si, e.x, e.y)
			local d = abs(z - zref)
			-- (the centre rather than a point at the edge, of two floors at the same height)
			if e.part then
				d = d + 0.01
			end
			if d < bestd then
				bestd = d
				best = e
				bestlvl = i
				bz = z
			end
		end
		i = i + 1
	end
	if not best then
		return nil
	end
	AR_W_E = best
	AR_W_LVL = bestlvl
	AR_W_X = best.x
	AR_W_Y = best.y
	AR_W_HOT = nil
	if w.cons[best.si] then
		return 2, bz
	end
	local hot = ar_nav_hotnav(nav)
	local code = 1
	i = 1
	while best.h[i] do
		local h = best.h[i]
		if ar_nav_active(hot, h) then
			if w.hcons[h] then
				return 2, bz
			elseif w.cheat[h] then
				code = 3
				AR_W_HOT = h
			elseif w.door[h] and code == 1 then
				code = 4
				AR_W_HOT = h
			end
		end
		i = i + 1
	end
	return code, bz
end

-- is (x, y) in a constrained sector (on), walk or hot
ar_w_in_cons = function(nav, w, x, y)
	local count = ar_nav_count(nav)
	local i = 1
	while i <= count do
		if w.cons[i] and ar_nav_inside(nav, i, x, y) and ar_nav_active(nav, i) then
			return nav, i
		end
		i = i + 1
	end
	local hot = ar_nav_hotnav(nav)
	local hc = ar_nav_hcount(nav)
	i = 1
	while i <= hc do
		if w.hcons[i] and ar_nav_inside(hot, i, x, y) and ar_nav_active(hot, i) then
			return hot, i
		end
		i = i + 1
	end
	return nil
end

---------------------------------------------------------------------------------------------------------------------------------
-- The links: the cheat boxes and the constrained sectors

-- corner j (counted from 0, any j) of the polygon p with n corners
ar_corner = function(p, n, j)
	j = j - n * floor(j / n)
	return p[j * 3 + 1], p[j * 3 + 2], p[j * 3 + 3]
end

-- The line a constrained Manny walks along, as the engine works it out when he is constrained at (x, y) heading (hx, hy) in walk
-- sector si: a ray back from him leaves the sector through the edge he came in by (from corner k - 1 to corner k); the same
-- fraction of that edge, measured from corner k and kept 15% off the corners, on the opposite edge (from corner k + 1 to corner
-- k - 2) is where the line goes. Returns its direction (the way of the heading), or nil.
ar_w_cons_dir = function(nav, si, x, y, hx, hy, any)
	local p = nav.p[si]
	local n = nav.pn[si]
	local rx = -hx
	local ry = -hy
	local bestt = 1000000
	local bk = nil
	local k = 1
	while k <= n do
		local ax, ay = ar_corner(p, n, k - 1)
		local bx, by = ar_corner(p, n, k)
		local ex = bx - ax
		local ey = by - ay
		local den = rx * ey - ry * ex
		if abs(den) > 0.000001 then
			local t = ((ax - x) * ey - (ay - y) * ex) / den
			local u = ((ax - x) * ry - (ay - y) * rx) / den
			if t > 0 and u >= -0.001 and u <= 1.001 and t < bestt then
				bestt = t
				bk = k
			end
		end
		k = k + 1
	end
	if not bk then
		return nil
	end
	local qx = x + rx * bestt
	local qy = y + ry * bestt
	-- (an exit at a corner, along an edge: the other edge of the corner)
	local ax, ay = ar_corner(p, n, bk - 1)
	local bx, by = ar_corner(p, n, bk)
	local el = sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by))
	if el > 0.0001 then
		local c = abs(((ax - bx) * hx + (ay - by) * hy) / el)
		if c > 0.9998 then
			if (bx - qx) * (bx - qx) + (by - qy) * (by - qy) < 0.0025 then
				bk = bk + 1
			elseif (ax - qx) * (ax - qx) + (ay - qy) * (ay - qy) < 0.0025 then
				bk = bk - 1
			end
			ax, ay = ar_corner(p, n, bk - 1)
			bx, by = ar_corner(p, n, bk)
		end
	end
	local f = 0
	if abs(ax - bx) <= 0.00001 then
		f = (qy - by) / (ay - by)
	else
		f = (qx - bx) / (ax - bx)
	end
	if f < 0.15 then f = 0.15 end
	if f > 0.85 then f = 0.85 end
	local o1x, o1y = ar_corner(p, n, bk + 1)
	local o2x, o2y = ar_corner(p, n, bk - 2)
	local dx = o1x + (o2x - o1x) * f - x
	local dy = o1y + (o2y - o1y) * f - y
	local dl = sqrt(dx * dx + dy * dy)
	if dl < 0.0001 then
		return nil
	end
	dx = dx / dl
	dy = dy / dl
	-- (a heading more than 80 degrees off the line does not move him; within it he goes the way of the line that is nearer)
	local c = dx * hx + dy * hy
	if abs(c) < cos(80) and not any then
		return nil
	end
	if c < 0 and not any then
		return -dx, -dy
	end
	return dx, dy
end

-- the cell of a point that is floor (plain, or the sector of a door), at about the height z: its key and height, or nil
ar_w_floor_at = function(nav, w, x, y, z)
	local k = ar_w_key(w, x, y)
	if not k then
		return nil
	end
	local code, cz = ar_w_code(nav, w, k, z)
	if code == 2 then
		-- (the cell is the end of a stair and a sliver of the floor beyond it: the floor is there if the point itself is on it)
		local count = ar_nav_count(nav)
		local i = 1
		while i <= count do
			if not w.cons[i] and ar_nav_inside(nav, i, x, y) and abs(ar_nav_z(nav, i, x, y) - cz) < 0.35 and ar_nav_active(nav, i) then
				return k, cz
			end
			i = i + 1
		end
		return nil
	end
	if (code ~= 1 and code ~= 4) or not ar_nav_find_z(nav, x, y, cz, 0.35) then
		return nil
	end
	return k, cz
end

-- a link from the floor at (px, py) over a step in at (ex, ey) to the floor at (lx, ly): kind "c" (a cheat box) or "s" (a stair)
ar_w_add_link = function(nav, w, kind, px, py, pz, ex, ey, lx, ly, lz, cost)
	local fk, fz = ar_w_floor_at(nav, w, px, py, pz)
	local tk, tz = ar_w_floor_at(nav, w, lx, ly, lz)
	if not fk or not tk or fk == tk then
		return
	end
	if not w.lk[fk] then
		w.lk[fk] = { }
	end
	local l = w.lk[fk]
	l[ar_nav_len(l) + 1] = { kind = kind, fk = fk, tk = tk, px = px, py = py, pz = fz, ex = ex, ey = ey, lx = lx, ly = ly, lz = tz, cost = cost }
	AR_W_LINKS = AR_W_LINKS + 1
end

-- the polygon's corners round (cx, cy): its inward normal at the edge from corner a to corner b
ar_w_inward = function(ax, ay, bx, by, cx, cy)
	local ex = bx - ax
	local ey = by - ay
	local el = sqrt(ex * ex + ey * ey)
	if el < 0.0001 then
		return 0, 0
	end
	local nx = -ey / el
	local ny = ex / el
	if (cx - ax) * nx + (cy - ay) * ny < 0 then
		return -nx, -ny
	end
	return nx, ny
end

-- A hot sector that moved Manny to another place (a script, not a cheat box): remembered for the set, the next world has a link over it
ar_nav_learn = function(nav, t)
	nav.learned = nav.learned or { }
	if nav.learned[t.hot] then
		return
	end
	nav.learned[t.hot] = { x = t.tx, y = t.ty, z = t.tz }
	ar_log("nav: " .. tostring(t.hot) .. " moves Manny to " .. format("%.2f %.2f %.2f", t.tx, t.ty, t.tz) .. ": a link from now on")
	nav.w = nil
end

ar_w_links = function(nav, w)
	AR_W_LINKS = 0
	local hot = ar_nav_hotnav(nav)
	local hc = ar_nav_hcount(nav)
	-- A cheat box (four corners): stepping in over the edge from corner e to e + 1, at a fraction f of it from corner e + 1, lands on
	-- the edge from corner e - 2 to e - 1 at the fraction f from e - 2 (GetSectorOppositeEdge)
	local h = 1
	while h <= hc do
		if w.cheat[h] and hot.pn[h] == 4 then
			local p = hot.p[h]
			local cx, cy = ar_nav_centre(hot, h)
			local e = 0
			while e < 4 do
				local ax, ay, az = ar_corner(p, 4, e)
				local bx, by = ar_corner(p, 4, e + 1)
				local ccx, ccy = ar_corner(p, 4, e - 2)
				local dx, dy = ar_corner(p, 4, e - 1)
				local nx, ny = ar_w_inward(ax, ay, bx, by, cx, cy)
				local mx, my = ar_w_inward(ccx, ccy, dx, dy, cx, cy)
				local f = 0.25
				while f < 0.8 do
					local xx = bx + (ax - bx) * f
					local xy = by + (ay - by) * f
					local lx = ccx + (dx - ccx) * f
					local ly = ccy + (dy - ccy) * f
					local wi = ar_nav_find(nav, xx - nx * 0.22, xy - ny * 0.22, az)
					local wo = ar_nav_find(nav, lx - mx * 0.12, ly - my * 0.12, az)
					if wi and wo then
						ar_w_add_link(nav, w, "c", xx - nx * 0.22, xy - ny * 0.22, ar_nav_z(nav, wi, xx - nx * 0.22, xy - ny * 0.22), xx + nx * 0.06, xy + ny * 0.06, lx - mx * 0.12, ly - my * 0.12, ar_nav_z(nav, wo, lx - mx * 0.12, ly - my * 0.12), 0.4)
					end
					f = f + 0.25
				end
				e = e + 1
			end
		end
		h = h + 1
	end
	-- A hot sector that a script was seen to move Manny out of: a link over each of its edges, to where he was put
	if nav.learned then
		h = 1
		while h <= hc do
			local l = nav.learned[hot.n[h]]
			if l and not w.cheat[h] then
				local p = hot.p[h]
				local n = hot.pn[h]
				local cx, cy = ar_nav_centre(hot, h)
				local e = 0
				while e < n do
					local ax, ay, az = ar_corner(p, n, e)
					local bx, by = ar_corner(p, n, e + 1)
					local nx, ny = ar_w_inward(ax, ay, bx, by, cx, cy)
					local mx = (ax + bx) / 2
					local my = (ay + by) / 2
					local wi = ar_nav_find(nav, mx - nx * 0.22, my - ny * 0.22, az)
					if wi then
						ar_w_add_link(nav, w, "c", mx - nx * 0.22, my - ny * 0.22, ar_nav_z(nav, wi, mx - nx * 0.22, my - ny * 0.22), mx + nx * 0.06, my + ny * 0.06, l.x, l.y, l.z, 0.4)
					end
					e = e + 1
				end
			end
			h = h + 1
		end
	end
	-- A constrained sector: stepped into over an edge, Manny walks along the engine's line until he is out of all of them
	local count = ar_nav_count(nav)
	local i = 1
	while i <= count + hc do
		local poly = nav
		local idx = i
		if i > count then
			poly = hot
			idx = i - count
		end
		if (i <= count and w.cons[idx]) or (i > count and w.hcons[idx]) then
			ar_w_cons_links(nav, w, poly, idx)
		end
		i = i + 1
	end
	w.nlinks = AR_W_LINKS
	ar_log("nav: the world of " .. tostring(system.currentSet.name) .. ", " .. tostring(AR_W_LINKS) .. " links over cheat boxes and stairs")
end

ar_w_cons_links = function(nav, w, poly, idx)
	local p = poly.p[idx]
	local n = poly.pn[idx]
	local cx, cy = ar_nav_centre(poly, idx)
	local e = 0
	while e < n do
		local ax, ay, az = ar_corner(p, n, e)
		local bx, by = ar_corner(p, n, e + 1)
		local nx, ny = ar_w_inward(ax, ay, bx, by, cx, cy)
		local f = 0.2
		while f < 0.85 do
			AR_CL_X = ax + (bx - ax) * f + nx * 0.04
			AR_CL_Y = ay + (by - ay) * f + ny * 0.04
			AR_CL_S = ar_nav_find(nav, AR_CL_X, AR_CL_Y, az)
			if AR_CL_S then
				-- (the heading he comes in with is the line itself: he is lined up with it before the step)
				local dx, dy = ar_w_cons_dir(nav, AR_CL_S, AR_CL_X, AR_CL_Y, nx, ny)
				if dx then
					dx, dy = ar_w_cons_dir(nav, AR_CL_S, AR_CL_X, AR_CL_Y, dx, dy)
				end
				if dx then
					ar_w_cons_link(nav, w, AR_CL_X, AR_CL_Y, ar_nav_z(nav, AR_CL_S, AR_CL_X, AR_CL_Y), dx, dy)
				end
			end
			f = f + 0.15
		end
		e = e + 1
	end
end

-- along the line from (x, y) until out of the constrained sectors, on the floor all the way
ar_w_cons_link = function(nav, w, x, y, z, dx, dy)
	local t = 0
	local qx = x
	local qy = y
	local qz = z
	local ok = TRUE
	local lastx = x
	local lasty = y
	while ok and t < 15 and ar_w_in_cons(nav, w, qx, qy) do
		-- (small steps: the floor at the end of a stair can be a strip 3 cm wide)
		t = t + 0.01
		lastx = qx
		lasty = qy
		qx = x + dx * t
		qy = y + dy * t
		local s = ar_nav_find(nav, qx, qy, qz)
		if not s or abs(ar_nav_z(nav, s, qx, qy) - qz) > 0.35 then
			ok = nil
		else
			qz = ar_nav_z(nav, s, qx, qy)
		end
	end
	if not ok and t >= 0.2 then
		-- (a stair that ends in no floor, a door's sector over its top: no way on, but a way to walk up: a goal for a door over it)
		local back = 0.3
		local done = nil
		while back > 0.05 and not done do
			local fk, fz = ar_w_floor_at(nav, w, x - dx * back, y - dy * back, z)
			if fk then
				w.dead[ar_nav_len(w.dead) + 1] = { kind = "s", fk = fk, px = x - dx * back, py = y - dy * back, pz = fz, ex = x, ey = y, lx = lastx, ly = lasty, lz = qz }
				done = TRUE
			end
			back = back - 0.08
		end
	end
	if not ok or t >= 15 or t < 0.05 then
		return
	end
	-- (on a little past the stair, as far as there is floor: a landing can be a sliver)
	local more = 0.1
	while more >= 0 and not ar_w_floor_at(nav, w, qx + dx * more, qy + dy * more, qz) do
		more = more - 0.03
	end
	if more < 0 then
		return
	end
	-- (lined up 30 cm before the edge, or as far before it as the floor goes: a landing can be 8 cm wide)
	local back = 0.3
	local done = nil
	while back > 0.05 and not done do
		if ar_w_floor_at(nav, w, x - dx * back, y - dy * back, z) then
			ar_w_add_link(nav, w, "s", x - dx * back, y - dy * back, z, x, y, qx + dx * more, qy + dy * more, qz, t + 0.4)
			done = TRUE
		end
		back = back - 0.08
	end
end

---------------------------------------------------------------------------------------------------------------------------------
-- The search

-- A node of the search is a cell at one of the floors in it (a stair that winds up on itself has several above one place): the key of
-- the cell and, for the floor, a multiple of the number of cells.
ar_w_node = function(w, k, lvl)
	return k + (lvl - 1) * w.kn
end
ar_w_cell = function(w, n)
	return n - w.kn * floor((n - 1) / w.kn)
end

-- how near the cell k (at the height z) is to what is not plain floor: 2 next to it, 1 a cell further, 0 clear
ar_w_pen = function(nav, w, k, z)
	local pkey = k + w.kn * floor(z * 4 + 400)
	local v = AR_PEN[pkey]
	if v then
		return v
	end
	local nx = w.nx
	local ix = (k - 1) - nx * floor((k - 1) / nx)
	local iy = floor((k - 1) / nx)
	v = 0
	local r = 1
	while r <= 2 and v == 0 do
		local dy = -r
		while dy <= r and v == 0 do
			local dx = -r
			while dx <= r and v == 0 do
				if (abs(dx) == r or abs(dy) == r) then
					local c = nil
					if ix + dx >= 0 and ix + dx < nx and iy + dy >= 0 and iy + dy < w.ny then
						c = ar_w_code(nav, w, (iy + dy) * nx + ix + dx + 1, z)
					end
					if c ~= 1 and not (c == 4 and AR_GOAL_HOT[AR_W_HOT]) then
						v = 3 - r
					end
				end
				dx = dx + 1
			end
			dy = dy + 1
		end
		r = r + 1
	end
	AR_PEN[pkey] = v
	return v
end

-- ar_w_pen at the cell of a point (2 off the grid)
ar_w_pen_at = function(nav, w, x, y, z)
	local k = ar_w_key(w, x, y)
	if not k then
		return 2
	end
	return ar_w_pen(nav, w, k, z)
end

-- The cells round an actor that holds Manny up (w.obst: x, y of the actor and the radius learned): dearer the nearer the middle, so that the
-- way goes round it where the floor lets it
ar_w_obst_cost = function(w, k)
	local cell = ar_w_cell(w, k)
	local ix = (cell - 1) - w.nx * floor((cell - 1) / w.nx)
	local iy = floor((cell - 1) / w.nx)
	local x = w.x0 + ix * AR_CS
	local y = w.y0 + iy * AR_CS
	local m = 1
	local i = 1
	while w.obst[i] do
		local o = w.obst[i]
		local d = sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y))
		if d < o.r then
			m = m + 30 * (1 - d / o.r)
		end
		i = i + 1
	end
	return m
end

-- the cost of a step of length d into the cell k (code c, height z); nil where it is not to be walked
ar_w_step_cost = function(nav, w, k, c, z, d)
	-- (where Manny was held up on this walk: round it if there is a way round)
	local held = 1 + 8 * (w.tmp[k] or 0)
	if w.obst and w.obst[1] then
		held = held * ar_w_obst_cost(w, k)
	end
	if c == 1 or (c == 4 and AR_GOAL_HOT[AR_W_HOT]) then
		local pen = ar_w_pen(nav, w, k, z)
		return d * (1 + pen * pen * 0.6) * held
	end
	if c == 4 then
		-- (the sector of a door or trigger on the way: only if there is no other way)
		return d * 25 * held
	end
	return nil
end

-- is the cell k the goal (or, for a goal on a stair, the start of a walk along the stair that passes it)
ar_w_is_goal = function(nav, w, k, z)
	k = ar_w_cell(w, k)
	if AR_GOAL_LINKS then
		if AR_GOAL_LINKS[k] then
			return TRUE
		end
		if not AR_GOAL_REGION then
			return nil
		end
	end
	if AR_GOAL_CELLS and AR_GOAL_CELLS[k] then
		return TRUE
	end
	if AR_GOAL_K then
		return k == AR_GOAL_K
	end
	if not ar_w_code(nav, w, k, z) then
		return nil
	end
	local h = AR_W_E.h
	local i = 1
	while h[i] do
		if AR_GOAL_HOT[h[i]] and ar_w_hot_zok(nav, h[i], z) then
			return TRUE
		end
		i = i + 1
	end
	return nil
end

-- is the height z that of the hot sector h (floors over one another have sectors over them at their own height)
ar_w_hot_zok = function(nav, h, z)
	local p = ar_nav_hotnav(nav).p[h]
	local lo = 1000000
	local hi = -1000000
	local k = 3
	while p[k] do
		if p[k] < lo then
			lo = p[k]
		end
		if p[k] > hi then
			hi = p[k]
		end
		k = k + 3
	end
	return z > lo - 0.6 and z < hi + 0.6
end

ar_w_relax = function(nav, w, k, k2c, d, extra, link, thin)
	local zref = AR_SZ[k]
	if link then
		zref = link.lz
	end
	local c, z = ar_w_code(nav, w, k2c, zref)
	if not c then
		return
	end
	local k2 = ar_w_node(w, k2c, AR_W_LVL)
	if AR_CLOSED[k2] then
		return
	end
	local x2 = AR_W_X
	local y2 = AR_W_Y
	local si2 = AR_W_E.si
	local part2 = AR_W_E.part
	if not link and (part2 or AR_PPART[k] or si2 ~= AR_PSI[k]) then
		-- (from one sector into another, or a cell that is only partly floor: the floor goes on between the two points, no wall
		-- or gap between them)
		if not ar_nav_find_z(nav, (AR_PX[k] + x2) / 2, (AR_PY[k] + y2) / 2, (AR_SZ[k] + z) / 2, 0.35) then
			return
		end
	end
	if thin then
		-- (a step across a corner that is not floor: only where floor, at about the height, is under every quarter of it)
		local q = 1
		while q <= 3 do
			local qx = AR_PX[k] + (x2 - AR_PX[k]) * q / 4
			local qy = AR_PY[k] + (y2 - AR_PY[k]) * q / 4
			if not ar_nav_find_z(nav, qx, qy, AR_SZ[k] + (z - AR_SZ[k]) * q / 4, 0.35) then
				return
			end
			q = q + 1
		end
		if c ~= 1 then
			return
		end
	end
	local cost = extra
	if not link then
		cost = ar_w_step_cost(nav, w, k2c, c, z, d)
	end
	if not cost then
		return
	end
	local t = AR_G[k] + cost
	if not AR_G[k2] or t < AR_G[k2] then
		AR_G[k2] = t
		AR_PARENT[k2] = k
		AR_VIA[k2] = link
		AR_SZ[k2] = z
		AR_PX[k2] = x2
		AR_PY[k2] = y2
		AR_PSI[k2] = si2
		AR_PPART[k2] = part2
		local hx = x2 - AR_HX
		local hy = y2 - AR_HY
		ar_heap_push(AR_HEAP, k2, t + sqrt(hx * hx + hy * hy))
	end
end

-- A* from the cell sk (at the height sz) to the goal (AR_GOAL_K, or a cell of a hot sector of AR_GOAL_HOT; AR_HX, AR_HY is where
-- it is, for the estimate). Returns the goal cell that was reached, or nil.
-- the wall clock in ms, where the engine's Lua has clock() (nil where not)
ar_nav_ms = function()
	if clock then
		return clock() * 1000
	end
	return nil
end

-- the cost of the search just done, for the log: cells, frames it was spread over, and ms since t0 (where there is a clock)
ar_nav_cost = function(t0)
	local s = AR_SEARCH_STEPS .. " cells, " .. AR_SEARCH_SLICES .. " frames"
	local t1 = ar_nav_ms()
	if t0 and t1 then
		s = s .. ", " .. format("%.0f", t1 - t0) .. " ms"
	end
	return s
end

ar_w_search = function(nav, w, sk, sz)
	AR_SEARCH_STEPS = 0
	AR_SEARCH_SLICES = 0
	AR_G = { }
	AR_PARENT = { }
	AR_VIA = { }
	AR_CLOSED = { }
	AR_SZ = { }
	AR_PX = { }
	AR_PY = { }
	AR_PSI = { }
	AR_PPART = { }
	AR_PEN = { }
	AR_HEAP = { n = 0, k = { }, f = { } }
	if not ar_w_code(nav, w, sk, sz) then
		return nil
	end
	sk = ar_w_node(w, sk, AR_W_LVL)
	AR_SN = sk
	AR_G[sk] = 0
	AR_SZ[sk] = sz
	AR_PX[sk] = AR_W_X
	AR_PY[sk] = AR_W_Y
	AR_PSI[sk] = AR_W_E.si
	AR_PPART[sk] = AR_W_E.part
	ar_heap_push(AR_HEAP, sk, 0)
	local nx = w.nx
	local found = nil
	local steps = 0
	while AR_HEAP.n > 0 and not found and steps < 100000 do
		local k = ar_heap_pop(AR_HEAP)
		if not AR_CLOSED[k] then
			AR_CLOSED[k] = TRUE
			steps = steps + 1
			-- (a big search is spread over frames in the game, not done in one)
			if AR_SLICE and mod(steps, 300) == 0 then
				AR_SEARCH_SLICES = AR_SEARCH_SLICES + 1
				break_here()
			end
			if ar_w_is_goal(nav, w, k, AR_SZ[k]) then
				found = k
			else
				local kc = ar_w_cell(w, k)
				local ix = (kc - 1) - nx * floor((kc - 1) / nx)
				local iy = floor((kc - 1) / nx)
				local dy = -1
				while dy <= 1 do
					local dx = -1
					while dx <= 1 do
						if (dx ~= 0 or dy ~= 0) and ix + dx >= 0 and ix + dx < nx and iy + dy >= 0 and iy + dy < w.ny then
							local k2 = (iy + dy) * nx + ix + dx + 1
							if dx == 0 or dy == 0 then
								ar_w_relax(nav, w, k, k2, AR_CS)
							elseif ar_w_code(nav, w, iy * nx + ix + dx + 1, AR_SZ[k]) == 1 and ar_w_code(nav, w, (iy + dy) * nx + ix + 1, AR_SZ[k]) == 1 then
								-- (no cutting of a corner: both cells beside the diagonal are floor)
								ar_w_relax(nav, w, k, k2, AR_CS * 1.4142)
							else
								-- (or the floor itself is all along the way between the two points: a sliver of a sector is narrower than a cell)
								ar_w_relax(nav, w, k, k2, AR_CS * 1.4142, nil, nil, TRUE)
							end
						end
						dx = dx + 1
					end
					dy = dy + 1
				end
				local l = w.lk[kc]
				local li = 1
				while l and l[li] do
					-- (a link of the floor Manny is on)
					if abs(l[li].pz - AR_SZ[k]) < 0.35 then
						ar_w_relax(nav, w, k, l[li].tk, 0, l[li].cost, l[li])
					end
					li = li + 1
				end
			end
		end
	end
	AR_SEARCH_STEPS = steps
	return found
end

-- the nearest cell to (x, y) at about the height z within r: of any kind, or (kinds TRUE) plain floor, or (kinds "door") floor or the
-- sector of a door
ar_w_near = function(nav, w, x, y, z, r, kinds)
	-- (a point off the grid: the window of cells is laid round the nearest cell of it and made as much larger as it is off)
	local ix = floor((x - w.x0) / AR_CS + 0.5)
	local iy = floor((y - w.y0) / AR_CS + 0.5)
	local extra = 0
	if ix < 0 then extra = -ix; ix = 0 end
	if iy < 0 and -iy > extra then extra = -iy end
	if iy < 0 then iy = 0 end
	if ix >= w.nx then extra = ix - w.nx + 1; ix = w.nx - 1 end
	if iy >= w.ny and iy - w.ny + 1 > extra then extra = iy - w.ny + 1 end
	if iy >= w.ny then iy = w.ny - 1 end
	local nx = w.nx
	local best = nil
	local bestd = 1000000
	local bz = z
	local m = floor(r / AR_CS + 0.5) + extra
	local dy = -m
	while dy <= m do
		local dx = -m
		while dx <= m do
			if ix + dx >= 0 and ix + dx < nx and iy + dy >= 0 and iy + dy < w.ny then
				local k = (iy + dy) * nx + ix + dx + 1
				local c, cz = ar_w_code(nav, w, k, z)
				if c == 1 or (c and not kinds) or (c == 4 and kinds == "door") then
					local d = (AR_W_X - x) * (AR_W_X - x) + (AR_W_Y - y) * (AR_W_Y - y)
					if d < bestd then
						bestd = d
						best = k
						bz = cz
						AR_NEAR_X = AR_W_X
						AR_NEAR_Y = AR_W_Y
					end
				end
			end
			dx = dx + 1
		end
		dy = dy + 1
	end
	return best, bz, AR_NEAR_X, AR_NEAR_Y
end

-- Is the straight way from (x1, y1) to (x2, y2) on plain floor (or in the goal), at a height that goes on smoothly, and no nearer to
-- what is not floor than maxpen?
ar_w_los = function(nav, w, x1, y1, z1, x2, y2, maxpen)
	local dx = x2 - x1
	local dy = y2 - y1
	local len = sqrt(dx * dx + dy * dy)
	local steps = floor(len / 0.04) + 1
	local z = z1
	local s = 1
	while s <= steps do
		local x = x1 + dx * s / steps
		local y = y1 + dy * s / steps
		local k = ar_w_key(w, x, y)
		if not k then
			return nil
		end
		local c, cz = ar_w_code(nav, w, k, z)
		if not (c == 1 or (c == 4 and AR_GOAL_HOT[AR_W_HOT])) or w.tmp[k] then
			return nil
		end
		if w.obst and w.obst[1] and s > 3 and s < steps - 2 and ar_w_obst_cost(w, k) > 8 then
			-- (through the box of an actor: not a line of sight, the way goes round)
			return nil
		end
		local part = AR_W_E.part
		local pen = ar_w_pen(nav, w, k, cz)
		if pen > maxpen and s > 3 and s < steps - 2 then
			return nil
		end
		if pen > 2 then
			return nil
		end
		-- (near a wall, the point itself: a cell is partly floor there)
		if pen > 0 or part then
			local si = ar_nav_find_z(nav, x, y, cz, 0.35)
			if not si then
				return nil
			end
			cz = ar_nav_z(nav, si, x, y)
		end
		z = cz
		s = s + 1
	end
	return TRUE
end

-- The way from the search: the points of the cells from the start to the goal, the links on it as points of their own kinds ("x"
-- a point to be reached exactly, "c" the step into a cheat box, "s" the step onto a stair), pulled straight between them.
-- Each point is { x, y, z, kind }; "p" is a point that is passed, "g" the goal.
ar_w_way = function(nav, w, sk, gk, sx, sy, sz, gx, gy, gz)
	-- the cells, from the goal back
	local rev = { }
	local n = 0
	local k = gk
	sk = AR_SN
	while k do
		n = n + 1
		rev[n] = k
		if k == sk then
			k = nil
		else
			k = AR_PARENT[k]
		end
	end
	-- forward, as runs of cells between the links
	local raw = { }
	local m = 0
	m = m + 1
	raw[m] = { sx, sy, sz, "p", ar_w_pen_at(nav, w, sx, sy, sz) }
	local i = n
	while i >= 1 do
		local kk = rev[i]
		local l = AR_VIA[kk]
		if l then
			m = m + 1
			raw[m] = { l.px, l.py, l.pz, "x", ar_w_pen_at(nav, w, l.px, l.py, l.pz) }
			m = m + 1
			raw[m] = { l.ex, l.ey, l.pz, l.kind, 2 }
			m = m + 1
			raw[m] = { l.lx, l.ly, l.lz, "x", ar_w_pen_at(nav, w, l.lx, l.ly, l.lz) }
		elseif i < n then
			m = m + 1
			raw[m] = { AR_PX[kk], AR_PY[kk], AR_SZ[kk], "p", ar_w_pen(nav, w, ar_w_cell(w, kk), AR_SZ[kk]) }
		end
		i = i - 1
	end
	m = m + 1
	raw[m] = { gx, gy, gz, "g", ar_w_pen_at(nav, w, gx, gy, gz) }
	-- pulled straight: from each point that stays, the farthest of the following points (up to the next link) that the floor
	-- reaches in a straight line no nearer to the walls than the cells it passes over
	local out = { }
	local o = 1
	out[1] = raw[1]
	local a = 1
	while a < m do
		local j = a + 1
		if raw[a][4] == "p" or raw[a][4] == "x" then
			-- (the line may go no nearer to the walls than the way itself does between the two points, and at least a cell away; only
			-- its two ends, where the points are, may be nearer: the goal is often at a wall)
			local maxpen = 1
			local b = a + 1
			while b <= m and raw[b - 1][4] ~= "c" and raw[b - 1][4] ~= "s" and (b == a + 1 or raw[b - 1][4] == "p") do
				if b > a + 1 and raw[b - 1][5] > maxpen then
					maxpen = raw[b - 1][5]
				end
				if b == a + 1 or ar_w_los(nav, w, raw[a][1], raw[a][2], raw[a][3], raw[b][1], raw[b][2], maxpen) then
					j = b
				end
				b = b + 1
			end
		end
		o = o + 1
		out[o] = raw[j]
		a = j
	end
	return out
end

---------------------------------------------------------------------------------------------------------------------------------
-- Planning a walk

-- Plans the way from where Manny stands to the point (x, y, z), or into a hot sector of the door (AR_GOAL_HOT set by the caller).
-- Returns the way, or nil.
ar_w_plan1 = function(nav, w, x, y, z)
	local mp = manny:getpos()
	AR_NAV_GOAL_X = nil
	AR_NAV_GOAL_Y = nil
	-- (the start: the cell he stands in, whatever it is, or the nearest one of floor)
	local sk, sz = ar_w_near(nav, w, mp.x, mp.y, mp.z, 0.08)
	if not sk then
		sk, sz = ar_w_near(nav, w, mp.x, mp.y, mp.z, 0.5, TRUE)
	end
	if not sk then
		-- (the out point of a door, where Manny arrives, is often off the floor, a metre or more: on to the nearest of it)
		sk, sz = ar_w_near(nav, w, mp.x, mp.y, mp.z, 1.5, TRUE)
		if not sk then
			sk, sz = ar_w_near(nav, w, mp.x, mp.y, mp.z, 3.0, TRUE)
		end
		if sk then
			ar_log("nav: Manny is off the floor at " .. format("%.2f %.2f %.2f", mp.x, mp.y, mp.z) .. ", on from the nearest of it")
		end
	end
	if not sk then
		return nil
	end
	-- (standing on a stair: he can only go on along its line, either way; the heading he has is that line)
	local cn, ci = ar_w_in_cons(nav, w, mp.x, mp.y)
	if cn then
		-- (the goal on the same stair: along its line, no further way)
		local gn, gi = ar_w_in_cons(nav, w, x, y)
		if gn == cn and gi == ci then
			-- (the engine takes him along the line of the stair toward the goal, not straight at it: to the point of the line nearest it)
			local ux = x - mp.x
			local uy = y - mp.y
			local ul = sqrt(ux * ux + uy * uy) + 0.0001
			local ldx, ldy = ar_w_cons_dir(cn, ci, mp.x, mp.y, ux / ul, uy / ul, TRUE)
			if ldx then
				local t = (x - mp.x) * ldx + (y - mp.y) * ldy
				local ex = mp.x + ldx * t
				local ey = mp.y + ldy * t
				if ar_w_in_cons(nav, w, ex, ey) == cn then
					return { { mp.x, mp.y, mp.z, "p" }, { ex, ey, ar_nav_z(nav, ci, ex, ey), "g" } }
				end
			end
		end
		local path = ar_w_plan_off_cons(nav, w, mp, x, y, z)
		if path then
			return path
		end
	end
	local gx = x
	local gy = y
	local gz = z
	AR_GOAL_K = nil
	AR_GOAL_CELLS = nil
	if not AR_GOAL_REGION then
		-- (a point off the floor, as a use point often is: the nearest point of the floor, a little inside it)
		if not ar_nav_find_z(nav, x, y, z, 0.6) then
			local gi, px, py, pz = ar_nav_closest(nav, x, y, z)
			if not gi then
				return nil
			end
			-- (a goal this far off the floor is a mistake of the caller, not a use point: no way, said in the log)
			local off = sqrt((px - x) * (px - x) + (py - y) * (py - y))
			if off > 1.5 then
				ar_log("nav: the goal " .. format("%.2f %.2f %.2f", x, y, z) .. " is " .. format("%.2f", off) .. " m off the floor: no way")
				return nil
			end
			ar_log("nav: the goal " .. format("%.2f %.2f", x, y) .. " is " .. format("%.2f", off) .. " m off the floor, walking to " .. format("%.2f %.2f", px, py))
			local cx, cy = ar_nav_centre(nav, gi)
			local dl = sqrt((cx - px) * (cx - px) + (cy - py) * (cy - py))
			if dl > 0.05 then
				px = px + (cx - px) / dl * 0.03
				py = py + (cy - py) / dl * 0.03
			end
			gx = px
			gy = py
			gz = pz
			AR_NAV_GOAL_X = gx
			AR_NAV_GOAL_Y = gy
			AR_NAV_GOAL_FOR_X = x
			AR_NAV_GOAL_FOR_Y = y
		end
		AR_GOAL_LINKS = nil
		if ar_w_in_cons(nav, w, gx, gy) then
			ar_w_goal_links(nav, w, gx, gy)
		else
			AR_GOAL_K, gz = ar_w_near(nav, w, gx, gy, gz, 0.25, "door")
			if not AR_GOAL_K then
				ar_log("nav: no cell of floor or of a door within 25 cm of the goal " .. format("%.2f %.2f %.2f", gx, gy, gz))
				return nil
			end
			-- (and the cells a little further out than the nearest: the nearest can be a cell of a door's sector that the floor does not
			-- reach to, which is not to be walked to; the search ends at the first of them it comes to)
			ar_w_goal_cells(nav, w, gx, gy, gz)
		end
	end
	AR_HX = gx
	AR_HY = gy
	local mode = (AR_PARTIAL_MODE and "partial") or (AR_OPTIMISTIC and "with sectors that are off") or "sectors that are on"
	local t0 = ar_nav_ms()
	local found = ar_w_search(nav, w, sk, sz)
	ar_log("nav: search (" .. mode .. "): " .. ((found and "found") or "none") .. ", " .. ar_nav_cost(t0))
	if not found and AR_GOAL_REGION and not AR_PARTIAL_MODE then
		-- (the sector of the door lies over a stair: along the stair)
		t0 = ar_nav_ms()
		ar_w_region_links(nav, w)
		local nl = 0
		local lk = next(AR_GOAL_LINKS, nil)
		while lk do
			nl = nl + 1
			lk = next(AR_GOAL_LINKS, lk)
		end
		local t1 = ar_nav_ms()
		ar_log("nav: region links: " .. nl .. " stairs into the sector" .. ((t0 and t1 and (", " .. format("%.0f", t1 - t0) .. " ms")) or ""))
		t0 = ar_nav_ms()
		found = ar_w_search(nav, w, sk, sz)
		ar_log("nav: search along stairs (" .. mode .. "): " .. ((found and "found") or "none") .. ", " .. ar_nav_cost(t0))
	end
	AR_GOAL_LINKS = nil
	if not found and AR_PARTIAL_MODE then
		-- (as far toward the goal as the floor goes: the walk of a caller that is carried on by the game from there)
		local best = nil
		local bestd = 1000000
		local ck = next(AR_CLOSED, nil)
		while ck do
			local dd = (AR_PX[ck] - gx) * (AR_PX[ck] - gx) + (AR_PY[ck] - gy) * (AR_PY[ck] - gy)
			if dd < bestd then
				bestd = dd
				best = ck
			end
			ck = next(AR_CLOSED, ck)
		end
		if best then
			found = best
			gx = AR_PX[best]
			gy = AR_PY[best]
			gz = AR_SZ[best]
			ar_log("nav: no way all the way, as far as " .. format("%.2f %.2f", gx, gy))
			AR_PARTIAL_USED = TRUE
		end
	end
	if not found then
		return nil
	end
	if AR_GOAL_LINK_OF and AR_GOAL_LINK_OF[ar_w_cell(w, found)] then
		-- (on along the stair from where it starts)
		local l = AR_GOAL_LINK_OF[ar_w_cell(w, found)]
		local way = ar_w_way(nav, w, sk, found, mp.x, mp.y, mp.z, l.px, l.py, l.pz)
		way[ar_nav_len(way)][4] = "x"
		way[ar_nav_len(way) + 1] = { gx, gy, gz, "g" }
		AR_GOAL_LINK_OF = nil
		return way
	end
	if AR_GOAL_REGION then
		-- (into the sector of the door: its cell that the search reached, a step further in)
		gx = AR_PX[found]
		gy = AR_PY[found]
		gz = AR_SZ[found]
	end
	local way = ar_w_way(nav, w, sk, found, mp.x, mp.y, mp.z, gx, gy, gz)
	if AR_GOAL_REGION then
		local n = ar_nav_len(way)
		if n >= 2 then
			local dx = way[n][1] - way[n - 1][1]
			local dy = way[n][2] - way[n - 1][2]
			local dl = sqrt(dx * dx + dy * dy)
			local d = 0.15
			while dl > 0.001 and d > 0.02 and not ar_w_in_goal_hot(nav, gx + dx / dl * d, gy + dy / dl * d) do
				d = d / 2
			end
			if dl > 0.001 and d > 0.02 then
				way[n][1] = gx + dx / dl * d
				way[n][2] = gy + dy / dl * d
			end
		end
	end
	return way
end

-- the cells round the goal point that the search may end in (AR_GOAL_CELLS): floor and the sectors of doors within 12 cm of the
-- nearest one
ar_w_goal_cells = function(nav, w, x, y, z)
	AR_GOAL_CELLS = { }
	local k0 = ar_w_key(w, x, y)
	if not k0 then
		return
	end
	local nx = w.nx
	local ix = (k0 - 1) - nx * floor((k0 - 1) / nx)
	local iy = floor((k0 - 1) / nx)
	local bestd = 1000000
	local list = { }
	local m = 3
	local dy = -m
	while dy <= m do
		local dx = -m
		while dx <= m do
			if ix + dx >= 0 and ix + dx < nx and iy + dy >= 0 and iy + dy < w.ny then
				local k = (iy + dy) * nx + ix + dx + 1
				local c = ar_w_code(nav, w, k, z)
				if c == 1 or c == 4 then
					local d = sqrt((AR_W_X - x) * (AR_W_X - x) + (AR_W_Y - y) * (AR_W_Y - y))
					list[k] = d
					if d < bestd then
						bestd = d
					end
				end
			end
			dx = dx + 1
		end
		dy = dy + 1
	end
	local k, d = next(list, nil)
	while k do
		if d <= bestd + 0.12 and d <= 0.3 then
			AR_GOAL_CELLS[k] = TRUE
		end
		k, d = next(list, k)
	end
end

-- The way, over the floors that are on; when there is none, once more over every walk sector: a sector that is off may come on when
-- Manny gets near (a gate, a passage that a trigger opens), and if it does not the walk is held up and ends like any other.
ar_w_plan = function(nav, w, x, y, z)
	AR_OPTIMISTIC = nil
	local t0 = ar_nav_ms()
	local path = ar_w_plan1(nav, w, x, y, z)
	if not path then
		local t1 = ar_nav_ms()
		ar_log("nav: no way over sectors that are on" .. ((t0 and t1 and (", " .. format("%.0f", t1 - t0) .. " ms")) or "") .. ", trying sectors that are off")
		AR_OPTIMISTIC = TRUE
		path = ar_w_plan1(nav, w, x, y, z)
		AR_OPTIMISTIC = nil
		if path then
			ar_log("nav: a way only over sectors that are off")
		end
	end
	if not path and AR_ALLOW_PARTIAL then
		AR_PARTIAL_MODE = TRUE
		path = ar_w_plan1(nav, w, x, y, z)
		AR_PARTIAL_MODE = nil
	end
	return path
end

-- the height of the sectors of the door that is the goal
ar_w_goal_hot_z = function(nav)
	local hot = ar_nav_hotnav(nav)
	local h = next(AR_GOAL_HOT, nil)
	return hot.p[h][3]
end

-- The sector of a door that lies over a stair (the door of the shuttle is half way up its winding stairs) is reached along the stair,
-- the cells of which are not walked: the links whose line passes through it are goals (AR_GOAL_LINKS), as for a point on a stair
ar_w_region_links = function(nav, w)
	AR_GOAL_LINKS = { }
	AR_GOAL_LINK_OF = { }
	local all = { }
	local k, list = next(w.lk, nil)
	while k do
		all[ar_nav_len(all) + 1] = list
		k, list = next(w.lk, k)
	end
	all[ar_nav_len(all) + 1] = w.dead
	local ai = 1
	while all[ai] do
		list = all[ai]
		local i = 1
		while list[i] do
			local l = list[i]
			if l.kind == "s" then
				local len = sqrt((l.lx - l.ex) * (l.lx - l.ex) + (l.ly - l.ey) * (l.ly - l.ey))
				local t = 0
				local hit = nil
				while t <= 1 and not hit do
					-- (at the height of the sector: a stair of a winding flight passes over and under others)
					local lz = l.ez or (l.pz + (l.lz - l.pz) * t)
					if ar_w_in_goal_hot(nav, l.ex + (l.lx - l.ex) * t, l.ey + (l.ly - l.ey) * t) and abs(ar_w_goal_hot_z(nav) - lz) < 0.6 then
						hit = TRUE
					end
					t = t + 0.04 / (len + 0.001)
				end
				if hit and not AR_GOAL_LINKS[l.fk] then
					AR_GOAL_LINKS[l.fk] = TRUE
					AR_GOAL_LINK_OF[l.fk] = l
				end
			end
			i = i + 1
		end
		ai = ai + 1
	end
end

-- A goal on a stair is reached along a stair's line that passes within 12 cm of it: the cells such walks start from are the goal
-- (AR_GOAL_LINKS), and AR_GOAL_LINK_OF holds the link of each
ar_w_goal_links = function(nav, w, gx, gy)
	AR_GOAL_LINKS = { }
	AR_GOAL_LINK_OF = { }
	local k, list = next(w.lk, nil)
	while k do
		local i = 1
		while list[i] do
			local l = list[i]
			if l.kind == "s" then
				local dx = l.lx - l.px
				local dy = l.ly - l.py
				local l2 = dx * dx + dy * dy
				local t = ((gx - l.px) * dx + (gy - l.py) * dy) / l2
				if t > 0 and t < 1 then
					local qx = l.px + dx * t - gx
					local qy = l.py + dy * t - gy
					if qx * qx + qy * qy < 0.0144 and not AR_GOAL_LINKS[l.fk] then
						AR_GOAL_LINKS[l.fk] = TRUE
						AR_GOAL_LINK_OF[l.fk] = l
					end
				end
			end
			i = i + 1
		end
		k, list = next(w.lk, k)
	end
	AR_GOAL_K = nil
end

-- From a stair: along the line Manny faces, or back along it, to where it leaves the stair, and planned on from there
ar_w_plan_off_cons1 = function(nav, w, mp, x, y, z, yaw)
	-- (the line the engine took for him when he was constrained, from his heading then: the way he faces and the way back)
	local cnav, ci = ar_w_in_cons(nav, w, mp.x, mp.y)
	local dx, dy = ar_w_cons_dir(cnav, ci, mp.x, mp.y, -sin(yaw), cos(yaw), TRUE)
	if not dx then
		return nil
	end
	local best = nil
	local bestc = 1000000
	local sgn = 1
	while sgn >= -1 do
		local t = 0
		local qx = mp.x
		local qy = mp.y
		while t < 15 and ar_w_in_cons(nav, w, qx, qy) and ar_nav_find(nav, qx, qy, mp.z) do
			t = t + 0.03
			qx = mp.x + sgn * dx * t
			qy = mp.y + sgn * dy * t
		end
		-- (on a little past the stair, as far as there is floor: a landing can be a sliver)
		local ex = qx
		local ey = qy
		local s = nil
		local more = 0.1
		while more >= 0 and not s do
			qx = ex + sgn * dx * more
			qy = ey + sgn * dy * more
			s = ar_nav_find(nav, qx, qy, mp.z)
			more = more - 0.03
		end
		if s and t < 15 then
			local qz = ar_nav_z(nav, s, qx, qy)
			local sk, sz = ar_w_near(nav, w, qx, qy, qz, 0.2, TRUE)
			if sk then
				AR_HX = x
				AR_HY = y
				if not AR_GOAL_REGION then
					AR_GOAL_K = ar_w_near(nav, w, x, y, z, 0.25, "door")
				end
				local found = (AR_GOAL_REGION or AR_GOAL_K) and ar_w_search(nav, w, sk, sz)
				if found and AR_G[found] + t < bestc then
					bestc = AR_G[found] + t
					best = ar_w_way(nav, w, sk, found, qx, qy, qz, (AR_GOAL_REGION and AR_PX[found]) or x, (AR_GOAL_REGION and AR_PY[found]) or y, (AR_GOAL_REGION and AR_SZ[found]) or z)
					-- (the stair first: Manny walks it out along its line)
					local way = { { mp.x, mp.y, mp.z, "p" }, { qx, qy, qz, "s" } }
					local wi = 2
					while best[wi] do
						way[wi + 1] = best[wi]
						wi = wi + 1
					end
					best = way
				end
			end
		end
		sgn = sgn - 2
	end
	return best
end

-- From a stair: by the line the engine took for him (from the heading he has); a heading whose line leads off the stair (a stair
-- narrower than it is long, seen from the side) is turned until one does, as a player turns to face along it
ar_w_plan_off_cons = function(nav, w, mp, x, y, z)
	local yaw = manny:getrot().y
	local k = 0
	while k < 8 do
		local path = ar_w_plan_off_cons1(nav, w, mp, x, y, z, yaw + 45 * k)
		if path then
			return path
		end
		k = k + 1
	end
	return nil
end

---------------------------------------------------------------------------------------------------------------------------------
-- Following a way

-- the length of the way from point i to its end
ar_way_cum = function(path)
	local n = ar_nav_len(path)
	local cum = { }
	cum[n] = 0
	local i = n - 1
	while i >= 1 do
		local dx = path[i + 1][1] - path[i][1]
		local dy = path[i + 1][2] - path[i][2]
		-- (over a cheat box the way is no length)
		if path[i][4] == "c" then
			cum[i] = cum[i + 1]
		else
			cum[i] = cum[i + 1] + sqrt(dx * dx + dy * dy)
		end
		i = i - 1
	end
	return cum
end

-- the point at the distance la ahead of (px, py) on the way, from the stretch that ends at point i, but not past a point that is
-- to be reached exactly
ar_way_ahead = function(path, i, px, py, la)
	local ax = path[i - 1][1]
	local ay = path[i - 1][2]
	local bx = path[i][1]
	local by = path[i][2]
	local dx = bx - ax
	local dy = by - ay
	local l2 = dx * dx + dy * dy
	local t = 0
	if l2 > 0.000001 then
		t = ((px - ax) * dx + (py - ay) * dy) / l2
	end
	if t < 0 then t = 0 end
	if t > 1 then t = 1 end
	local qx = ax + dx * t
	local qy = ay + dy * t
	local left = la
	local j = i
	while TRUE do
		local rx = path[j][1] - qx
		local ry = path[j][2] - qy
		local rl = sqrt(rx * rx + ry * ry)
		if rl >= left or path[j][4] ~= "p" or not path[j + 1] then
			if rl >= left and rl > 0.0001 then
				return qx + rx / rl * left, qy + ry / rl * left
			end
			return path[j][1], path[j][2]
		end
		left = left - rl
		qx = path[j][1]
		qy = path[j][2]
		j = j + 1
	end
end

-- the angle between Manny's heading and the way to (x, y), in degrees (positive to his left)
ar_heading_off = function(x, y, z)
	local d = GetActorYawToPoint(manny.hActor, x, y, z) - manny:getrot().y
	return d - 360 * floor(d / 360 + 0.5)
end

-- Walks the way. Returns "done" (at the goal, or stop_when, or the set changed, or the game took over with a door's walk), or
-- "replan" (Manny is not where the way can be followed from: moved by the game, or held up; the cells in front of him are blocked
-- then), with the time spent in AR_FOLLOW_SPENT.
ar_follow = function(nav, w, path, stop_when, budget)
	local n = ar_nav_len(path)
	local cum = ar_way_cum(path)
	local i = 2
	local startset = system.currentSet
	AR_FOLLOW_SET = startset
	ar_log("nav: walk starts, sectors off: " .. ar_nav_off_list(nav))
	do
		-- (the kinds of the points: p a point, s a stair end, c a cheat box, x a crossing, g the goal)
		local kinds = ""
		local k = 1
		while path[k] do
			kinds = kinds .. path[k][4] .. format("(%.2f %.2f) ", path[k][1], path[k][2])
			k = k + 1
		end
		ar_log("nav: way " .. kinds)
	end
	-- (on a stair the engine walks him along its line, the way he faces: a player turns to face along it first, in place)
	local sp = manny:getpos()
	if ar_w_in_cons(nav, w, sp.x, sp.y) and path[2] then
		local tt = 0
		while ar_steer(path[2][1], path[2][2], sp.z, 5) and tt < 3000 do
			break_here()
			tt = tt + system.frameTime
		end
		ar_log("nav: on a stair, turned toward the way for " .. floor(tt) .. " ms, facing " .. format("%.0f", manny:getrot().y))
		-- (the line of a stair is made when stairman switches the constraint on, as Manny steps onto the stair; during a walk, the walk out of a door that ends on a
		-- stair, the engines do nothing, and he is on the stair with no line and walks where he is steered, over its wall. The same call again, now that he faces the
		-- way: the line is the one he faces along)
		SetActorConstrain(manny.hActor, TRUE)
	end
	local last = manny:getpos()
	AR_FOLLOW_SPENT = 0
	AR_FOLLOW_BEST = 1000000
	AR_FOLLOW_BEST_AT = 0
	AR_FOLLOW_GBEST = 1000000
	AR_FOLLOW_RESULT = nil
	AR_TELE_SEEN = AR_TELE_COUNT
	AR_IN_CONS = nil
	AR_WIGGLE = nil
	AR_WIGGLES = 0
	AR_REENTRIES = 0
	AR_WIGGLE_SIGN = 1
	while not AR_FOLLOW_RESULT do
		AR_WHERE = "follow, point " .. tostring(i) .. " of " .. tostring(n)
		if (stop_when and stop_when()) or system.currentSet ~= startset then
			AR_FOLLOW_RESULT = "done"
		elseif find_script(Sentence) then
			-- (the game's own walk out has begun, a door was entered: it takes Manny from here)
			AR_SENTENCE_STOP = TRUE
			AR_FOLLOW_RESULT = "done"
		elseif ar_walk_blocked() then
			AR_FOLLOW_RESULT = "done"
		elseif cutSceneLevel > 0 then
			ar_wait_for_control()
			AR_FOLLOW_RESULT = "wait"
		elseif AR_FOLLOW_SPENT > budget then
			AR_FOLLOW_RESULT = "budget"
		else
			ar_follow_frame(nav, w, path, n, cum, i)
			i = AR_FOLLOW_I
			break_here()
			AR_FOLLOW_SPENT = AR_FOLLOW_SPENT + system.frameTime
			AR_NAV_TIME = (AR_NAV_TIME or 0) + system.frameTime
			ar_note_camera()
			local q = manny:getpos()
			local moved = sqrt((q.x - last.x) * (q.x - last.x) + (q.y - last.y) * (q.y - last.y))
			if AR_TELE_COUNT ~= AR_TELE_SEEN or moved > 1.5 then
				-- (moved by a script, or by the game: over a cheat box as planned, or somewhere else)
				local t = AR_TELE
				if AR_TELE_COUNT == AR_TELE_SEEN then
					t = nil
				end
				AR_TELE_SEEN = AR_TELE_COUNT
				if path[i][4] == "c" and path[i + 1] and sqrt((q.x - path[i + 1][1]) * (q.x - path[i + 1][1]) + (q.y - path[i + 1][2]) * (q.y - path[i + 1][2])) < 0.5 then
					i = i + 1
					AR_FOLLOW_BEST = 1000000
				else
					if t and t.hot and t.set == system.currentSet then
						ar_nav_learn(nav, t)
					end
					ar_log("nav: Manny was moved by the game from " .. format("%.2f %.2f", last.x, last.y) .. " to " .. format("%.2f %.2f", q.x, q.y))
					AR_FOLLOW_RESULT = "replan"
				end
			end
			last = q
			if not AR_FOLLOW_RESULT then
				ar_follow_progress(nav, w, path, n, cum, i, q)
			end
		end
	end
	if not AR_WALK then
		manny:set_run(TRUE)
	end
	return AR_FOLLOW_RESULT
end

-- one frame of the walk: on past the points that are behind, then the keys
ar_follow_frame = function(nav, w, path, n, cum, i)
	local p = manny:getpos()
	local adv = TRUE
	while adv and i <= n do
		adv = nil
		local wp = path[i]
		local d = sqrt((p.x - wp[1]) * (p.x - wp[1]) + (p.y - wp[2]) * (p.y - wp[2]))
		local kind = wp[4]
		if kind == "p" and i < n then
			-- (beside it, or past it: the line through it, square to the way, is behind)
			local ax = path[i - 1][1]
			local ay = path[i - 1][2]
			local t = (p.x - ax) * (wp[1] - ax) + (p.y - ay) * (wp[2] - ay)
			local l2 = (wp[1] - ax) * (wp[1] - ax) + (wp[2] - ay) * (wp[2] - ay)
			if d < 0.06 or t >= l2 then
				adv = TRUE
			end
		elseif kind == "x" then
			if d < 0.05 then
				adv = TRUE
			end
		elseif kind == "c" and path[i + 1] then
			-- (over the cheat box: nearer to where it puts him than to where he stepped in; a narrow box moves him only a little)
			local nx2 = path[i + 1][1] - p.x
			local ny2 = path[i + 1][2] - p.y
			if nx2 * nx2 + ny2 * ny2 < d * d then
				adv = TRUE
			end
		elseif kind == "s" then
			-- (on the stair: off it again past its end)
			if ar_w_in_cons(nav, w, p.x, p.y) then
				AR_IN_CONS = TRUE
			elseif AR_IN_CONS or d < 0.04 then
				AR_IN_CONS = nil
				adv = TRUE
			end
		end
		if adv then
			i = i + 1
		end
	end
	AR_FOLLOW_I = i
	if i > n then
		return
	end
	local wp = path[i]
	local kind = wp[4]
	local tx = wp[1]
	local ty = wp[2]
	local la = 0
	if kind == "p" then
		-- (a point a little ahead: the turns are cut, a corner is not)
		-- (one that Manny can walk to in a straight line from where he is: not round an inner corner)
		tx, ty = ar_way_ahead(path, i, p.x, p.y, 0.35)
		if w.x0 and not ar_w_los(nav, w, p.x, p.y, p.z, tx, ty, 1) then
			tx, ty = ar_way_ahead(path, i, p.x, p.y, 0.15)
			if not ar_w_los(nav, w, p.x, p.y, p.z, tx, ty, 1) then
				tx = wp[1]
				ty = wp[2]
			end
		end
	elseif kind == "c" or kind == "s" then
		-- (straight on over the step, as far again)
		local ax = path[i - 1][1]
		local ay = path[i - 1][2]
		tx = wp[1] + (wp[1] - ax) * 2
		ty = wp[2] + (wp[2] - ay) * 2
		if kind == "s" and path[i + 1] then
			-- (along the stair to where it ends, however long it is: a stair has its entry and its exit in the way, two points, and from the entry the aim is the exit;
			-- a point that is the exit, the walk beginning on the stair, is the aim itself: the point after it can be 70 degrees and more off the line of the stair, where
			-- the steps are made only now and then)
			tx = path[i + 1][1]
			ty = path[i + 1][2]
			if path[i + 1][4] ~= "s" and not AR_STAIR_BEYOND then
				-- (the way turns at the exit: the point after it is as far off the line as that turn)
				local ax = wp[1] - path[i - 1][1]
				local ay = wp[2] - path[i - 1][2]
				local bx = path[i + 1][1] - wp[1]
				local by = path[i + 1][2] - wp[2]
				local la = sqrt(ax * ax + ay * ay)
				local lb = sqrt(bx * bx + by * by)
				if la > 0.001 and lb > 0.001 and (ax * bx + ay * by) / (la * lb) < 0.5 then
					tx = wp[1] + ax * 0.02
					ty = wp[2] + ay * 0.02
				end
			end
		end
	end
	if AR_WIGGLE and (kind == "p" or kind == "g") then
		local rx = tx - p.x
		local ry = ty - p.y
		tx = p.x + rx * cos(AR_WIGGLE) - ry * sin(AR_WIGGLE)
		ty = p.y + rx * sin(AR_WIGGLE) + ry * cos(AR_WIGGLE)
	end
	-- (a run on a long straight stretch, heading the right way; a walk round the corners and up to where Manny has to be)
	local togo = sqrt((p.x - wp[1]) * (p.x - wp[1]) + (p.y - wp[2]) * (p.y - wp[2]))
	if not AR_WALK and togo > 0.8 and abs(ar_heading_off(tx, ty, p.z)) < 20 then
		manny:set_run(TRUE)
	else
		manny:set_run(FALSE)
	end
	local turning = ar_steer(tx, ty, p.z, 8)
	local off = abs(AR_STEER_D or 0)
	local limit = 40
	if kind == "s" and AR_IN_CONS then
		-- (on the stair the engine keeps him on its line whatever the heading, up to 80 degrees off it)
		limit = 70
	elseif kind ~= "p" then
		limit = 15
	elseif w.x0 and ar_w_pen_at(nav, w, p.x, p.y, p.z) == 0 then
		-- (well clear of the walls: on the way while turning, as a player does with the stick held to one side)
		limit = 75
	end
	if off < limit then
		manny:walk_forward()
	end
	if AR_TRACE then
		ar_log("  follow at " .. format("%.2f %.2f %.2f", p.x, p.y, p.z) .. " point " .. tostring(i) .. "/" .. tostring(n) .. " " .. kind .. " aim " .. format("%.2f %.2f", tx, ty) .. " off " .. format("%.0f", off))
	end
end

-- is (x, y) itself in a sector of the door that is the goal
ar_w_in_goal_hot = function(nav, x, y)
	local hot = ar_nav_hotnav(nav)
	local h, v = next(AR_GOAL_HOT, nil)
	while h do
		if ar_nav_inside(hot, h, x, y) then
			return TRUE
		end
		h, v = next(AR_GOAL_HOT, h)
	end
	return nil
end

-- is Manny in a hot sector that is not the goal
ar_follow_in_trigger = function(nav)
	local hid, hname = manny:find_sector_type(HOT)
	if not hname then
		return nil
	end
	-- (one the game reacts to: a door or trigger with something to run, not a sector that is only a mark)
	local obj = system.currentSet[hname]
	if type(obj) ~= "table" or not (obj.walkOut or obj.climbOut) then
		return nil
	end
	local p = manny:getpos()
	if AR_GOAL_REGION and ar_w_in_goal_hot(nav, p.x, p.y) then
		return nil
	end
	return TRUE
end

-- Back along the way to a point outside every hot sector (at least 25 cm), then a frame or three for Doorman to see Manny out of it
ar_follow_reenter = function(nav, w, path, i)
	local p = manny:getpos()
	local k = i - 1
	local tx = nil
	local ty = nil
	while k >= 1 and not tx do
		local d = sqrt((path[k][1] - p.x) * (path[k][1] - p.x) + (path[k][2] - p.y) * (path[k][2] - p.y))
		local hot = ar_w_hot_at(nav, path[k][1], path[k][2])
		if d >= 0.25 and not next(hot, nil) then
			tx = path[k][1]
			ty = path[k][2]
		end
		k = k - 1
	end
	if not tx then
		return
	end
	ar_log("nav: out of the sector Manny stands in and in again, back to " .. format("%.2f %.2f", tx, ty))
	local t = 0
	while t < 4000 and sqrt((manny:getpos().x - tx) * (manny:getpos().x - tx) + (manny:getpos().y - ty) * (manny:getpos().y - ty)) > 0.08 and system.currentSet == AR_FOLLOW_SET do
		local turning = ar_steer(tx, ty, manny:getpos().z, 8)
		if abs(AR_STEER_D or 0) < 40 then
			manny:walk_forward()
		end
		break_here()
		t = t + system.frameTime
	end
	local f = 0
	while f < 4 do
		break_here()
		f = f + 1
	end
end

-- the goal, and the progress on the way
ar_follow_progress = function(nav, w, path, n, cum, i, q)
	local gx = path[n][1]
	local gy = path[n][2]
	local dg = sqrt((q.x - gx) * (q.x - gx) + (q.y - gy) * (q.y - gy))
	if AR_GOAL_REGION then
		if ar_w_in_goal_hot(nav, q.x, q.y) then
			AR_FOLLOW_RESULT = "done"
			return
		end
	elseif i >= n then
		-- (there, or past it: the distance grows again after it was a step away)
		-- (a goal on a stair: he can only be on its line, which passes a few cm from the point)
		local arrive = 0.025
		if ar_w_in_cons(nav, w, gx, gy) then
			arrive = 0.12
		end
		if dg < arrive or (AR_FOLLOW_GBEST < 0.12 and dg > AR_FOLLOW_GBEST + 0.03) then
			AR_FOLLOW_RESULT = "done"
			return
		end
	end
	if dg < AR_FOLLOW_GBEST then
		AR_FOLLOW_GBEST = dg
	end
	-- (the way left: to the next point, and from there on)
	local j = i
	if j > n then
		j = n
	end
	local left = sqrt((q.x - path[j][1]) * (q.x - path[j][1]) + (q.y - path[j][2]) * (q.y - path[j][2])) + cum[j]
	if left < AR_FOLLOW_BEST - 0.03 then
		AR_FOLLOW_BEST = left
		AR_FOLLOW_BEST_AT = AR_FOLLOW_SPENT
		if AR_WIGGLE and left < AR_WIGGLE_LEFT - 0.15 then
			AR_WIGGLE = nil
		end
	elseif AR_FOLLOW_SPENT - AR_FOLLOW_BEST_AT > 1000 and AR_REENTRIES < 2 and ar_follow_in_trigger(nav) then
		-- Held up standing in a sector that the game reacts to when it is entered (a door that closed on the way, a trigger
		-- that opens one): Doorman is done with it, a step out and in again is what a player does.
		AR_REENTRIES = AR_REENTRIES + 1
		ar_follow_reenter(nav, w, path, i)
		AR_FOLLOW_BEST = left
		AR_FOLLOW_BEST_AT = AR_FOLLOW_SPENT
	elseif AR_FOLLOW_SPENT - AR_FOLLOW_BEST_AT > 2000 and not AR_WIGGLE and AR_WIGGLES < 4 then
		-- Pushing straight at an edge between two floors that do not quite meet (the boxes shrunk round something Manny holds leave
		-- a gap, and the game stops an actor that walks square at one) gets nowhere: a player slants the stick. Aimed 30 degrees to
		-- one side and then the other.
		AR_WIGGLES = AR_WIGGLES + 1
		AR_WIGGLE_SIGN = -AR_WIGGLE_SIGN
		AR_WIGGLE = 30 * AR_WIGGLE_SIGN
		AR_WIGGLE_LEFT = left
		AR_FOLLOW_BEST_AT = AR_FOLLOW_SPENT - 1200
		ar_log("nav: held up at " .. format("%.2f %.2f", q.x, q.y) .. ": aimed " .. tostring(AR_WIGGLE) .. " degrees to one side")
	elseif AR_FOLLOW_SPENT - AR_FOLLOW_BEST_AT > 3000 then
		-- Held up: whatever is in front of him is in the way (the cells there are blocked for the rest of the walk). At the very
		-- end of the way: as near as the walls let him.
		if i >= n and dg < 0.2 and not AR_GOAL_REGION then
			AR_FOLLOW_RESULT = "done"
			return
		end
		ar_w_obst_learn(w, q)
		local select_hid, select_hot_name = manny:find_sector_type(HOT)
		ar_log("nav: held up at " .. format("%.4f %.4f", q.x, q.y) .. ", " .. format("%.2f", left) .. " from the end (hot sector " .. tostring(select_hot_name) .. ", re-entries " .. tostring(AR_REENTRIES) .. ", ms into the walk " .. tostring(AR_FOLLOW_SPENT) .. ", sentence " .. tostring(find_script(Sentence)) .. ", holding " .. tostring(manny.is_holding and manny.is_holding.name) .. ", cut " .. tostring(cutSceneLevel) .. ", moving " .. tostring(manny:is_moving()) .. ", handler " .. tostring(system.buttonHandler == SampleButtonHandler) .. ", costume " .. tostring(manny:get_costume()) .. ", resting " .. tostring(manny:is_resting()) .. ", yaw " .. format("%.0f", manny:getrot().y) .. ", walk rate " .. tostring(GetActorWalkRate(manny.hActor)) .. ")")
		local yx = GetActorYawToPoint(manny.hActor, q.x + 1, q.y, q.z)
		local yy = GetActorYawToPoint(manny.hActor, q.x, q.y + 1, q.z)
		local yaw = manny:getrot().y
		local hx = cos(yaw - yx)
		local hy = cos(yaw - yy)
		local d = 0.08
		while w.x0 and d <= 0.2 do
			local k = ar_w_key(w, q.x + hx * d, q.y + hy * d)
			if k and k ~= ar_w_key(w, q.x, q.y) and not (AR_GOAL_K and k == AR_GOAL_K) then
				w.tmp[k] = (w.tmp[k] or 0) + 1
			end
			d = d + 0.06
		end
		AR_FOLLOW_RESULT = "replan"
	end
end

---------------------------------------------------------------------------------------------------------------------------------
-- The walks

-- the time a way may take: twice what it takes at the rate Manny walks and turns, and a few seconds more
ar_way_budget = function(path)
	if AR_WALK_MAX then
		return AR_WALK_MAX
	end
	local cum = ar_way_cum(path)
	local rate = abs(GetActorWalkRate(manny.hActor))
	if rate < 0.3 then
		rate = 0.3
	end
	local turns = 90
	local i = 2
	while path[i + 1] do
		local ax = path[i][1] - path[i - 1][1]
		local ay = path[i][2] - path[i - 1][2]
		local bx = path[i + 1][1] - path[i][1]
		local by = path[i + 1][2] - path[i][2]
		local l = sqrt(ax * ax + ay * ay) * sqrt(bx * bx + by * by)
		if l > 0.0001 then
			local c = (ax * bx + ay * by) / l
			if c > 1 then c = 1 end
			if c < -1 then c = -1 end
			turns = turns + acos(c)
		end
		i = i + 1
	end
	return 4000 + 2 * (1000 * cum[1] / rate + 1000 * turns / 85)
end

-- Plans and walks, again from where Manny is when the way cannot be followed. Returns TRUE when the walk is over, nil if there
-- is no data for the set or no way.
AR_IN_NAV = nil
-- why there is no way, to the log: the sectors that are off, the cells round both ends, what the search reached
ar_nav_why = function(nav, w, mp, x, y, z)
	ar_log("nav: sectors that are off: " .. ar_nav_off_list(nav))
	local names = ""
	local ni = 1
	while nav.n[ni] do
		names = names .. nav.n[ni] .. " "
		ni = ni + 1
	end
	ar_log("nav: walk sectors (" .. tostring(ar_nav_count(nav)) .. "): " .. names)
	ar_log("nav: goal state: region " .. tostring(AR_GOAL_REGION) .. " k " .. tostring(AR_GOAL_K) .. " links " .. tostring(AR_GOAL_LINKS) .. " hot " .. tostring(next(AR_GOAL_HOT, nil)) .. " tmp " .. tostring(next(w.tmp, nil)))
	local bx0 = 1000000
	local bx1 = -1000000
	local by0 = 1000000
	local by1 = -1000000
	local ck = next(AR_CLOSED, nil)
	while ck do
		local cc = ar_w_cell(w, ck)
		local cix = (cc - 1) - w.nx * floor((cc - 1) / w.nx)
		local ciy = floor((cc - 1) / w.nx)
		if cix < bx0 then bx0 = cix end
		if cix > bx1 then bx1 = cix end
		if ciy < by0 then by0 = ciy end
		if ciy > by1 then by1 = ciy end
		ck = next(AR_CLOSED, ck)
	end
	if AR_GOAL_K then
		local gix = (AR_GOAL_K - 1) - w.nx * floor((AR_GOAL_K - 1) / w.nx)
		local giy = floor((AR_GOAL_K - 1) / w.nx)
		ar_log("nav: goal cell at " .. format("%.2f %.2f", w.x0 + gix * AR_CS, w.y0 + giy * AR_CS) .. " code " .. tostring(ar_w_code(nav, w, AR_GOAL_K, z)) .. " closed " .. tostring(AR_CLOSED[AR_GOAL_K]) .. " g " .. tostring(AR_G[AR_GOAL_K]))
	end
	ar_log("nav: searched cells x " .. format("%.2f to %.2f", w.x0 + bx0 * AR_CS, w.x0 + bx1 * AR_CS) .. " y " .. format("%.2f to %.2f", w.y0 + by0 * AR_CS, w.y0 + by1 * AR_CS) .. ", goal cell " .. tostring(AR_GOAL_K))
	ar_w_picture(nav, w, mp.x, mp.y, mp.z)
	ar_w_picture(nav, w, x, y, mp.z)
	ar_log("nav: no way: Manny at " .. format("%.2f %.2f %.2f", mp.x, mp.y, mp.z) .. " goal " .. format("%.2f %.2f %.2f", x, y, z) .. ", " .. tostring(AR_SEARCH_STEPS) .. " cells searched")
end

-- Hot sectors with a climbOut (a ladder) that can be walked to are walked into, one after the other, when the goal is on another level
-- than Manny and there is no way to it: the game carries him up or down, and the hook (ar_tele_note) learns where to. Each one is tried
-- once for the set. Returns TRUE when Manny ended on another level or somewhere else altogether.
ar_nav_try_climb = function(nav, w, x, y, z, stop_when)
	local mp = manny:getpos()
	local gz = z
	if AR_GOAL_REGION then
		gz = ar_w_goal_hot_z(nav)
	end
	if abs(gz - mp.z) < 0.8 then
		return nil
	end
	nav.tried = nav.tried or { }
	local hot = ar_nav_hotnav(nav)
	local hc = ar_nav_hcount(nav)
	local saved_region = AR_GOAL_REGION
	local saved_hot = AR_GOAL_HOT
	local moved = nil
	local h = 1
	while h <= hc and not moved do
		local obj = system.currentSet[hot.n[h]]
		if not nav.tried[h] and type(obj) == "table" and obj.climbOut and ar_nav_active(hot, h) and not w.cheat[h] then
			nav.tried[h] = TRUE
			ar_log("nav: no way to the other level: up or down " .. tostring(hot.n[h]))
			AR_IN_CLIMB = TRUE
			-- (the sector the way a door is: out of it first if Manny stands in it, then in)
			ar_nav_enter_door(obj, stop_when)
			AR_IN_CLIMB = nil
			-- (a ladder: the climb has begun when the foot of it is stepped into, the player holds the key for up or down)
			-- (the game walks Manny to the foot first, in a cutscene of its own that starts a frame later: wait for the climb)
			ar_try_wait(function() return manny.is_climbing end, 8000)
			ar_wait_for_control()
			if manny.is_climbing then
				ar_climb(gz > mp.z, nil, 40000)
				ar_wait_for_control()
			end
			local q = manny:getpos()
			if abs(q.z - mp.z) > 0.5 or sqrt((q.x - mp.x) * (q.x - mp.x) + (q.y - mp.y) * (q.y - mp.y)) > 1.5 then
				moved = TRUE
			end
			AR_GOAL_REGION = saved_region
			AR_GOAL_HOT = saved_hot
		end
		h = h + 1
	end
	AR_GOAL_REGION = saved_region
	AR_GOAL_HOT = saved_hot
	return moved
end

-- the learned actors that are in the way, with where they are now
ar_w_obst_load = function(w)
	local n = 0
	local setfile = system.currentSet and system.currentSet.setFile
	local h, mode = next(AR_COLL, nil)
	while h do
		if h ~= manny.hActor and AR_ACT_SET[h] == setfile then
			local x, y, z = GetActorPos(h)
			local r = AR_OBST_DEFAULT
			if AR_OBST[h] and AR_OBST[h].r > r then
				r = AR_OBST[h].r
			end
			n = n + 1
			w.obst[n] = { x = x, y = y, r = r }
			if AR_NT_DEBUG then ar_log("nav: obstacle " .. format("%.2f %.2f r %.2f", x, y, r) .. " handle " .. tostring(h)) end
		end
		h, mode = next(AR_COLL, h)
	end
end

-- Held up: an actor that collides and is near is what holds Manny (the box of a man who stands in a narrow way), whatever the floor says.
-- The radius is how near Manny got, and a good deal more for the size of the box.
ar_w_obst_learn = function(w, q)
	local learned = nil
	local h, mode = next(AR_COLL, nil)
	while h do
		if h ~= manny.hActor then
			local x, y, z = GetActorPos(h)
			if x then
				local d = sqrt((x - q.x) * (x - q.x) + (y - q.y) * (y - q.y))
				if d < 0.7 and abs(z - q.z) < 1.5 then
					local r = d + 0.25
					if not AR_OBST[h] or AR_OBST[h].r < r then
						AR_OBST[h] = { r = r }
						ar_log("nav: held up against an actor that collides, at " .. format("%.2f", d) .. " m: planning round it, radius " .. format("%.2f", r))
						learned = TRUE
					end
				end
			end
		end
		h, mode = next(AR_COLL, h)
	end
	if learned then
		w.obst = { }
		ar_w_obst_load(w)
	end
end

ar_nav_go = function(nav, x, y, z, stop_when)
	local w = ar_w(nav)
	w.tmp = { }
	w.obst = { }
	ar_w_obst_load(w)
	local replans = 0
	local waits = 0
	local navset = system.currentSet
	local result = "replan"
	AR_NAV_GOAL_X = nil
	while (result == "replan" or result == "wait") and system.currentSet == navset and not (stop_when and stop_when()) do
		AR_WHERE = "nav: planning"
		local path = ar_w_plan(nav, w, x, y, z)
		-- (a goal on another level and no whole way: a ladder or the like in the set may be the way, the game carries Manny up it)
		if (not path or AR_PARTIAL_USED) and not AR_IN_CLIMB and ar_nav_try_climb(nav, w, x, y, z, stop_when) then
			AR_PARTIAL_USED = nil
			path = ar_w_plan(nav, w, x, y, z)
		end
		local tries = 0
		-- (the sector of a door that cannot be reached is not waited for: the door is used instead, which may open the way)
		if AR_GOAL_REGION then
			tries = 60
		end
		while not path and tries < 60 and system.currentSet == navset and not (stop_when and stop_when()) do
			-- (a way can open a while later: the doors of an elevator, a passage that a script switches off for a while)
			sleep_for(300)
			ar_wait_for_control()
			path = ar_w_plan(nav, w, x, y, z)
			tries = tries + 1
		end
		if not path then
			if AR_GOAL_REGION then
				ar_log("nav: no way into the sector of the door")
				ar_nav_why(nav, w, manny:getpos(), x, y, z)
				return nil
			end
			if system.currentSet == navset and not (stop_when and stop_when()) then
				local mp = manny:getpos()
				ar_nav_why(nav, w, mp, x, y, z)
				ar_fail("nav: no way from " .. format("%.2f %.2f", mp.x, mp.y) .. " to " .. format("%.2f %.2f", x, y) .. " in " .. tostring(system.currentSet.name) .. " for 18 seconds")
				return TRUE
			end
			return TRUE
		end
		ar_nav_log_way(path)
		if AR_PARTIAL_USED and ar_way_cum(path)[1] < 0.05 then
			-- (as far as the floor goes and Manny is there: nothing to walk, what carries him on from here is up to the game)
			ar_log("nav: already as near as the floor goes")
			AR_PARTIAL_USED = nil
			return TRUE
		end
		AR_PARTIAL_USED = nil
		AR_IN_NAV = TRUE
		local budget = ar_way_budget(path)
		result = ar_follow(nav, w, path, stop_when, budget)
		AR_IN_NAV = nil
		if result == "budget" then
			local mp = manny:getpos()
			ar_fail("the walk used its whole time budget of " .. tostring(floor(budget)) .. " ms, stopped at " .. format("%.2f %.2f", mp.x, mp.y) .. " toward " .. format("%.2f %.2f", x, y))
			return TRUE
		end
		if result == "wait" then
			waits = waits + 1
			if waits >= 3 then
				-- (the game takes the walk over each time Manny gets there: a sector that starts a scene when it is entered and sends him
				-- back; the walk is at its end, what the caller waits for is the scene)
				ar_log("nav: a cutscene took the walk over " .. tostring(waits) .. " times: the walk ends")
				return TRUE
			end
			-- (a ladder: the scene of the sector put Manny on it, the player holds the key for up or down)
			if manny.is_climbing and not AR_IN_CLIMB and not (stop_when and stop_when()) then
				local gz = z
				if AR_GOAL_REGION then
					gz = ar_w_goal_hot_z(nav)
				end
				ar_log("nav: on a ladder, climbing " .. (gz > manny:getpos().z and "up" or "down"))
				ar_climb(gz > manny:getpos().z, nil, 40000)
				ar_wait_for_control()
			end
			ar_log("nav: planning again after a cutscene, at " .. format("%.2f %.2f %.2f", manny:getpos().x, manny:getpos().y, manny:getpos().z) .. ", climbing " .. tostring(manny.is_climbing))
		elseif result == "replan" then
			replans = replans + 1
			if replans > 6 then
				local mp = manny:getpos()
				ar_fail("the walk to " .. format("%.2f %.2f", x, y) .. " was planned again " .. tostring(replans) .. " times, Manny is at " .. format("%.2f %.2f", mp.x, mp.y))
				return TRUE
			end
			ar_log("nav: planning again from where Manny is (" .. tostring(replans) .. ")")
		end
	end
	-- (the caller's test once more, as the set may have changed: a door that was walked through has to be seen as reached)
	if stop_when then
		stop_when()
	end
	return TRUE
end

ar_nav_log_way = function(path)
	local n = ar_nav_len(path)
	local cum = ar_way_cum(path)
	local links = ""
	local i = 1
	while path[i] do
		if path[i][4] == "c" or path[i][4] == "s" then
			links = links .. " " .. path[i][4] .. format("(%.2f %.2f)", path[i][1], path[i][2])
		end
		i = i + 1
	end
	ar_log("nav: " .. tostring(n) .. " points, " .. format("%.2f", cum[1]) .. " m, to " .. format("%.2f %.2f", path[n][1], path[n][2]) .. " (" .. tostring(AR_SEARCH_STEPS) .. " cells searched)" .. links)
	-- (the walk as a test case: tools/gen_cases.py turns these lines of a run into cases of nav_cases_run.lua)
	local sp = manny:getpos()
	ar_log("NAVCASE " .. tostring(system.currentSet and system.currentSet.setFile) .. " from " .. format("%.3f %.3f %.3f", sp.x, sp.y, sp.z) .. " to " .. format("%.3f %.3f %.3f", path[n][1], path[n][2], path[n][3]) .. " len " .. format("%.2f", cum[1]) .. " points " .. tostring(n))
	if AR_TRACE then
		i = 1
		while path[i] do
			ar_log("  way point " .. format("%.2f %.2f %.2f ", path[i][1], path[i][2], path[i][3]) .. path[i][4])
			i = i + 1
		end
	end
end

-- Walks Manny to (x, y, z) along a planned way. Returns nil if there is no data for the set or no way.
ar_nav_walk = function(x, y, z, stop_when)
	if not system.currentSet then
		return nil
	end
	local nav = ar_nav_of(system.currentSet)
	if not nav then
		ar_log("nav: no sectors of " .. tostring(system.currentSet.name))
		return nil
	end
	AR_GOAL_REGION = nil
	AR_GOAL_HOT = { }
	AR_PATH_DONE = ar_nav_go(nav, x, y, z, stop_when)
	return AR_PATH_DONE
end

-- the hot sectors (on) that the set gives to the door: those it names after it (the set's own table holds the door under the
-- name of its sector, which is how Doorman finds it)
ar_nav_door_hot = function(nav, door)
	local hot = ar_nav_hotnav(nav)
	local list = { }
	local found = nil
	local hc = ar_nav_hcount(nav)
	local i = 1
	while i <= hc do
		if system.currentSet[hot.n[i]] == door and ar_nav_active(hot, i) then
			list[i] = TRUE
			found = TRUE
		end
		i = i + 1
	end
	return found and list
end

-- Walks Manny into the sector of the door (the game takes him through from there). Returns nil if the door has none.
ar_nav_enter_door = function(door, stop_when)
	if not system.currentSet then
		return nil
	end
	local nav = ar_nav_of(system.currentSet)
	if not nav then
		return nil
	end
	ar_w(nav)
	local list = ar_nav_door_hot(nav, door)
	if not list then
		return nil
	end
	ar_log("nav: into the sector of " .. tostring(door.name))
	AR_GOAL_REGION = TRUE
	AR_GOAL_HOT = list
	-- (Doorman reacts when the sector is entered: standing in it already, Manny steps out first)
	local mp = manny:getpos()
	local w = ar_w(nav)
	local out = 0
	while out < 3 and ar_w_in_goal_hot(nav, mp.x, mp.y) and not (stop_when and stop_when()) do
		-- (to plain floor at least a hand clear of the sector: its edge is not out of it for Doorman)
		local ok, oz, ox, oy = ar_w_near(nav, w, mp.x, mp.y, mp.z, 0.8, TRUE)
		if not ok then
			out = 3
		else
			local cx, cy = ar_nav_centre(ar_nav_hotnav(nav), next(list, nil))
			local dl = sqrt((ox - cx) * (ox - cx) + (oy - cy) * (oy - cy))
			if dl > 0.001 then
				local push = 0.12 + 0.12 * out
				local k2, z2, x2, y2 = ar_w_near(nav, w, ox + (ox - cx) / dl * push, oy + (oy - cy) / dl * push, oz, 0.08, TRUE)
				if k2 and not ar_w_in_goal_hot(nav, x2, y2) then
					ox = x2
					oy = y2
					oz = z2
				end
			end
			ar_log("nav: out of the sector of " .. tostring(door.name) .. " first")
			AR_GOAL_REGION = nil
			AR_GOAL_HOT = { }
			ar_nav_go(nav, ox, oy, oz, stop_when)
			AR_GOAL_REGION = TRUE
			AR_GOAL_HOT = list
			mp = manny:getpos()
			out = out + 1
		end
	end
	-- (where the search heads for: the middle of one of its sectors)
	local cx, cy = ar_nav_centre(ar_nav_hotnav(nav), next(list, nil))
	-- (no way all the way: as far as the floor goes, the game may carry Manny on from there, a drop onto a platform, a ride)
	AR_ALLOW_PARTIAL = TRUE
	AR_PATH_DONE = ar_nav_go(nav, cx, cy, door.obj_z or manny:getpos().z, stop_when)
	AR_ALLOW_PARTIAL = nil
	AR_GOAL_REGION = nil
	AR_GOAL_HOT = { }
	return TRUE
end

-- the middle of a hot sector of the door, or nil
ar_nav_hot_point = function(door)
	if not system.currentSet then
		return nil
	end
	local nav = ar_nav_of(system.currentSet)
	if not nav or not nav.hp then
		return nil
	end
	local list = ar_nav_door_hot(nav, door)
	if not list then
		return nil
	end
	local i = next(list, nil)
	local cx, cy = ar_nav_centre(ar_nav_hotnav(nav), i)
	return cx, cy, nav.hp[i][3], nav.hn[i]
end

-- Walks a list of points ({ x, y, z }, ...) placed by hand, with the same follower
ar_walk_path = function(nav, points, k, stop_when)
	local path = { }
	local mp = manny:getpos()
	path[1] = { mp.x, mp.y, mp.z, "p" }
	local n = 1
	local i = k
	while points[i] do
		n = n + 1
		path[n] = { points[i][1], points[i][2], points[i][3], "p" }
		i = i + 1
	end
	path[n][4] = "g"
	if not nav and system.currentSet then
		nav = ar_nav_of(system.currentSet)
	end
	local w = nav and ar_w(nav)
	AR_GOAL_REGION = nil
	AR_GOAL_HOT = { }
	AR_GOAL_K = nil
	local r = ar_follow(nav, w or { tmp = { } }, path, stop_when, ar_way_budget(path))
	if r == "budget" then
		ar_fail("the walk along the route used its whole time budget")
	end
	return r == "done"
end

-- Manny can stand just outside the floor (out of an elevator): the keys then only make him bump the edge. A player steers him onto
-- the nearest floor.
ar_nav_unstick = function(inside)
	if not system.currentSet then
		return nil
	end
	local nav = ar_nav_of(system.currentSet)
	if not nav then
		return nil
	end
	local mp = manny:getpos()
	local w = ar_w(nav)
	local k, kz, gx, gy = ar_w_near(nav, w, mp.x, mp.y, mp.z, 0.5, TRUE)
	if not k then
		return nil
	end
	local t = 0
	local uset = system.currentSet
	while t < 1200 and system.currentSet == uset and sqrt((manny:getpos().x - gx) * (manny:getpos().x - gx) + (manny:getpos().y - gy) * (manny:getpos().y - gy)) > 0.03 do
		if not ar_steer(gx, gy, mp.z, 8) then
			manny:walk_forward()
		end
		break_here()
		t = t + system.frameTime
	end
	return TRUE
end
