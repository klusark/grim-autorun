-- NAVDEBUG=1: draws the nav on the screen, for watching a run. Not part of the library: run_all.sh and run_chapter.sh add this file after the helpers.
--   the planned path, one mark per point: p yellow (a point of the way), x orange (a door or trigger sector), c magenta (a cheat box, the game moves Manny
--   over it), G green (the goal); the corners of the camera sectors that are on, + in a colour of the setup they give, with the number of the setup at the
--   middle; Manny's own mark M; and in the top right the camera sector the engine finds for Manny (GetPointSector with CAMERA, which is what the game's
--   cameraman asks) and the setup that is showing.
-- Text objects are part of a save: do not save a checkpoint with it on.
AR_DBG_POOL = AR_DBG_POOL or { }
AR_DBG_COLORS = { Cyan, Green, Orange, Magenta, Yellow, Red, Blue, White }

-- The camera of the current setup, read once a frame (the engine's own WorldToScreen reads the matrices of the graphics driver, which at the time a script
-- runs are those of whatever was drawn last, not the camera): the point of view, the three axes, the width of the view and the roll. A frustum of the width
-- fov and a 3 : 4 height, looking from the position to the interest, z up, rolled, as the engine sets it up.
-- (a function of Lua 3.1 has 32 local variables at most)
ar_dbg_camera = function()
	local px, py, pz = GetCameraPosition()
	local look = GetCameraLookVector()
	if not px or not look then
		AR_DBG_CAM = nil
		return
	end
	local fx, fy, fz = -look.x, -look.y, -look.z
	local ux, uy, uz = 0, 0, 1
	if abs(fx) < 0.00001 and abs(fy) < 0.00001 then
		ux, uy, uz = 0, 1, 0
	end
	local rx, ry, rz = fy * uz - fz * uy, fz * ux - fx * uz, fx * uy - fy * ux
	local l = sqrt(rx * rx + ry * ry + rz * rz)
	rx, ry, rz = rx / l, ry / l, rz / l
	ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx
	local roll = GetCameraRoll() or 0
	AR_DBG_CAM = { px = px, py = py, pz = pz, fx = fx, fy = fy, fz = fz, rx = rx, ry = ry, rz = rz, ux = ux, uy = uy, uz = uz,
		t = tan((GetCameraFOV() or 60) / 2), cr = cos(-roll), sr = sin(-roll) }
end

-- the point on the 640 x 480 screen, by the camera of ar_dbg_camera
ar_dbg_project = function(x, y, z)
	local c = AR_DBG_CAM
	if not c then
		return nil
	end
	local dx, dy, dz = x - c.px, y - c.py, z - c.pz
	local zv = dx * c.fx + dy * c.fy + dz * c.fz
	if zv <= 0.05 then
		return nil
	end
	local xv = dx * c.rx + dy * c.ry + dz * c.rz
	local yv = dx * c.ux + dy * c.uy + dz * c.uz
	local sx = ((xv * c.cr - yv * c.sr) / (zv * c.t) + 1) / 2 * 640
	local sy = 480 - ((xv * c.sr + yv * c.cr) / (zv * c.t * 0.75) + 1) / 2 * 480
	if sx < 0 or sx >= 640 or sy < 0 or sy >= 480 then
		return nil
	end
	return sx, sy
end

-- The mark n of the pool: the text object is only touched when the text, the place or the colour changed (every ChangeTextObject makes the bitmap of the text again,
-- which is what made it slow when it was done for every mark in every frame)
ar_dbg_put = function(n, text, sx, sy, color, just)
	local m = AR_DBG_POOL[n]
	if not m then
		m = { h = MakeTextObject(" ", { x = 0, y = 0, font = AR_FONT, fgcolor = White }), text = " ", x = 0, y = 0, color = White }
		AR_DBG_POOL[n] = m
	end
	if not sx then
		text = " "
		sx = 0
		sy = 0
	end
	if m.text ~= text or m.x ~= sx or m.y ~= sy or m.color ~= color then
		m.text = text
		m.x = sx
		m.y = sy
		m.color = color
		if just then
			ChangeTextObject(m.h, text, { x = sx, y = sy, font = AR_FONT, fgcolor = color, rjustify = TRUE })
		else
			ChangeTextObject(m.h, text, { x = sx, y = sy, font = AR_FONT, fgcolor = color })
		end
	end
end

-- The marks that stand still while the path, the set and the setup are the same: { x, y, z, text, color }. The path points are at their own height, the corners of
-- the camera sectors at the height Manny stands at (their own is 0 in the set files).
ar_dbg_build = function(nav, mp)
	local list = { }
	local n = 0
	local path = AR_DBG_PATH
	if path and AR_DBG_PATH_SET == system.currentSet then
		local i = 1
		local last = ar_nav_len(path)
		while path[i] and n < 120 do
			n = n + 1
			local kind = path[i][4] or "p"
			local color = Yellow
			local text = "p"
			if i == last then
				color = Green
				text = "G"
			elseif kind == "x" then
				color = Orange
				text = "x"
			elseif kind == "c" then
				color = Magenta
				text = "c"
			end
			list[n] = { path[i][1], path[i][2], type(path[i][3]) == "number" and path[i][3] or mp.z, text, color }
			i = i + 1
		end
	end
	if nav and nav.cn then
		nav.camnav = nav.camnav or { p = nav.cp, n = nav.cn }
		local sets = system.currentSet.setups
		local c = 1
		while nav.cn[c] do
			local setup = sets and sets[nav.cn[c]]
			if setup and ar_nav_active(nav.camnav, c) then
				local color = AR_DBG_COLORS[(setup - 8 * floor(setup / 8)) + 1]
				local p = nav.cp[c]
				local m = ar_nav_len(p) / 3
				local k = 0
				local sx, sy = 0, 0
				while k < m and n < 200 do
					n = n + 1
					list[n] = { p[k * 3 + 1], p[k * 3 + 2], mp.z, "+", color }
					sx = sx + p[k * 3 + 1]
					sy = sy + p[k * 3 + 2]
					k = k + 1
				end
				n = n + 1
				list[n] = { sx / m, sy / m, mp.z, "cam" .. tostring(setup), color }
			end
			c = c + 1
		end
	end
	return list
end

ar_dbg_frame = function()
	ar_dbg_ring_push()
	local mp = manny:getpos()
	local nav = system.currentSet and AR_NAV and AR_NAV[system.currentSet.setFile]
	local setup = system.currentSet:current_setup()
	ar_dbg_camera()
	-- (the marks are made again when the path, the set or the setup is another, or the floor Manny stands at: not every frame)
	local key = tostring(AR_DBG_PATH) .. tostring(system.currentSet.name) .. tostring(setup) .. format("%.1f", mp.z)
	if key ~= AR_DBG_KEY then
		AR_DBG_KEY = key
		AR_DBG_LIST = ar_dbg_build(nav, mp)
		AR_DBG_LISTN = ar_nav_len(AR_DBG_LIST)
	end
	local n = 0
	local i = 1
	while i <= AR_DBG_LISTN do
		local e = AR_DBG_LIST[i]
		n = n + 1
		local sx, sy = ar_dbg_project(e[1], e[2], e[3])
		ar_dbg_put(n, e[4], sx, sy, e[5])
		i = i + 1
	end
	n = n + 1
	local sx, sy = ar_dbg_project(mp.x, mp.y, mp.z)
	ar_dbg_put(n, "M", sx, sy, White)
	local id, name = GetPointSector(mp.x, mp.y, mp.z, CAMERA)
	n = n + 1
	ar_dbg_put(n, "camera sector " .. tostring(name) .. ", setup " .. tostring(setup), 630, 8, White, TRUE)
	-- the marks of an earlier, longer list are blanked
	local m = n + 1
	while AR_DBG_POOL[m] do
		ar_dbg_put(m, " ", nil, nil, White)
		m = m + 1
	end
end

ar_dbg_task = function()
	while TRUE do
		if system.currentSet and manny and not AR_DBG_OFF then
			ar_dbg_frame()
		end
		break_here()
	end
end
if AR_NAVDEBUG and not AR_DBG_TASK then
	AR_DBG_TASK = start_script(ar_dbg_task)
end

-- The first camera sector that is on and holds the point, by the polygons of the set file (the engine asks the sectors in that order).
ar_dbg_cam_at = function(nav, x, y)
	if not nav.cn then
		return nil
	end
	nav.camnav = nav.camnav or { p = nav.cp, n = nav.cn }
	local i = 1
	while nav.cn[i] do
		if ar_nav_inside(nav.camnav, i, x, y) and ar_nav_active(nav.camnav, i) then
			return nav.cn[i]
		end
		i = i + 1
	end
	return nil
end

-- The cameras along a planned path, asked of the engine (the camera sector it finds, GetPointSector with CAMERA, which is what the game's cameraman asks) and of
-- the polygons of the set file (the first camera sector that is on and holds the point): logged where they differ, and the run of camera sectors the path goes
-- through. The path is sampled every 10 cm (ar_dbg_report, called by the planner when AR_NAVDEBUG is on).
ar_dbg_report = function(nav, path)
	if not path or not nav or not nav.cn then
		return
	end
	local z = manny:getpos().z
	local sets = system.currentSet.setups
	local runs = ""
	local lastname = "?"
	local diff = 0
	local samples = 0
	local i = 1
	local n = ar_nav_len(path)
	while i < n do
		local x1, y1, x2, y2 = path[i][1], path[i][2], path[i + 1][1], path[i + 1][2]
		local len = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
		local steps = floor(len / 0.1) + 1
		local s = 0
		while s <= steps do
			local x = x1 + (x2 - x1) * s / steps
			local y = y1 + (y2 - y1) * s / steps
			local id, ename = GetPointSector(x, y, z, CAMERA)
			local pname = ar_dbg_cam_at(nav, x, y)
			samples = samples + 1
			if tostring(ename) ~= tostring(pname) then
				diff = diff + 1
				if diff <= 8 then
					ar_log("navdebug: at " .. format("%.2f %.2f", x, y) .. " the engine finds camera sector " .. tostring(ename) .. ", the polygons " .. tostring(pname))
				end
			end
			if tostring(ename) ~= lastname then
				lastname = tostring(ename)
				runs = runs .. " " .. lastname .. "[" .. tostring(sets and ename and sets[ename]) .. "]@" .. format("%.2f,%.2f", x, y)
			end
			s = s + 1
		end
		i = i + 1
	end
	ar_log("navdebug: path cameras (engine):" .. runs)
	ar_log("navdebug: " .. tostring(diff) .. " of " .. tostring(samples) .. " samples differ between the engine and the polygons")
end

-- The raw way of the search, before it is pulled straight: a line for every tenth cell, with the cost so far G, and
-- every link, with its own cost. rev is the cells from the goal back (ar_w_way).
ar_dbg_raw = function(nav, w, rev, n)
	local dl = "raw way of the search, " .. tostring(n) .. " cells:"
	local di = n
	local cnt = 0
	while di >= 1 do
		local kk = rev[di]
		local l = AR_VIA[kk]
		if l then
			dl = dl .. format("\n    LINK %s from %.2f %.2f to %.2f %.2f cost %s, G %.2f", tostring(l.kind), l.px, l.py, l.lx, l.ly, tostring(l.cost), AR_G[kk] or -1)
		elseif cnt - 10 * floor(cnt / 10) == 0 then
			dl = dl .. format("\n    cell %.2f %.2f G %.2f", AR_PX[kk] or 0, AR_PY[kk] or 0, AR_G[kk] or -1)
		end
		cnt = cnt + 1
		di = di - 1
	end
	ar_log("navdebug: " .. dl)
end

-- What stopped him: called by the follower when it logs a hold-up (NAVDEBUG). The engine's answer (GetPointSector, without a type: the constant WALK of the
-- scripts is not the engine's) at the floor under points 3 and 6 cm from Manny toward the aim of the follower and along his yaw, each at the height of the floor
-- there (a stair or a step is more than the 5 mm of the plane test off Manny's height); whether the engine holds him to the line of a stair or a curb
-- (GetActorConstrain) and the angles of his yaw and of the aim to it; the sector names stairman and curbman look for; and the last second of frames.
ar_dbg_floor = function(nav, x, y, z)
	local si = ar_nav_find_z(nav, x, y, z, 0.7)
	if si then
		return ar_nav_z(nav, si, x, y)
	end
	return z
end
ar_dbg_sec = function(nav, x, y, z)
	local id, name = GetPointSector(x, y, ar_dbg_floor(nav, x, y, z))
	return tostring(name)
end
-- the angle in degrees between the directions (ax, ay) and (bx, by) (0 to 90: a line has two ways)
ar_dbg_angle = function(ax, ay, bx, by)
	local la = sqrt(ax * ax + ay * ay)
	local lb = sqrt(bx * bx + by * by)
	if la < 0.0001 or lb < 0.0001 then
		return -1
	end
	local c = abs(ax * bx + ay * by) / (la * lb)
	if c > 1 then
		c = 1
	end
	return acos(c)
end
ar_dbg_holdup = function(q, nav, path, i, n)
	local yaw = manny:getrot().y
	local fx, fy = -sin(yaw), cos(yaw)
	local wp = path[i] or path[n]
	local ux, uy = wp[1] - q.x, wp[2] - q.y
	local ul = sqrt(ux * ux + uy * uy)
	if ul > 0.0001 then
		ux, uy = ux / ul, uy / ul
	end
	local hid, hname = manny:find_sector_type(HOT)
	local cons, cx, cy = GetActorConstrain(manny.hActor)
	local text = "navdebug: held up at " .. format("%.3f %.3f", q.x, q.y) .. " yaw " .. format("%.0f", yaw) .. ", aim " .. format("%.2f %.2f", wp[1], wp[2]) .. " (" .. tostring(wp[4]) .. ", point " .. tostring(i) .. " of " .. tostring(n) .. "): in " ..
		ar_dbg_sec(nav, q.x, q.y, q.z) .. ", toward the aim 3 cm " .. ar_dbg_sec(nav, q.x + ux * 0.03, q.y + uy * 0.03, q.z) .. " 6 cm " .. ar_dbg_sec(nav, q.x + ux * 0.06, q.y + uy * 0.06, q.z) ..
		", along the yaw 3 cm " .. ar_dbg_sec(nav, q.x + fx * 0.03, q.y + fy * 0.03, q.z) .. " 6 cm " .. ar_dbg_sec(nav, q.x + fx * 0.06, q.y + fy * 0.06, q.z) ..
		", boxes shrunk " .. tostring(system.currentSet.boxes_shrunk) .. ", hot " .. tostring(hname) ..
		", stair/curb sector " .. tostring(manny:find_sector_name("stair")) .. "/" .. tostring(manny:find_sector_name("curb"))
	if cons then
		text = text .. ", CONSTRAINED to the line " .. format("%.3f %.3f", cx, cy) .. ": yaw off it " .. format("%.0f", ar_dbg_angle(fx, fy, cx, cy)) .. ", aim off it " .. format("%.0f", ar_dbg_angle(ux, uy, cx, cy))
	else
		text = text .. ", not constrained"
	end
	ar_log(text)
	-- the last second: every 5th frame, x y yaw, m = moving
	local ring = AR_DBG_RING
	if ring then
		local line = "navdebug: the last second (every 5th frame):"
		local k = AR_DBG_RING_N + 1
		local c = 0
		while c < 60 do
			local e = ring[k - 60 * floor(k / 60)]
			if e and c - 5 * floor(c / 5) == 0 then
				line = line .. " [" .. e .. "]"
			end
			k = k + 1
			c = c + 1
		end
		ar_log(line)
	end
end

-- the ring of the last 60 frames, filled by ar_dbg_frame
AR_DBG_RING = AR_DBG_RING or { }
AR_DBG_RING_N = AR_DBG_RING_N or 0
ar_dbg_ring_push = function()
	local p = manny:getpos()
	local m = "-"
	if manny:is_moving() then
		m = "m"
	end
	AR_DBG_RING_N = AR_DBG_RING_N + 1
	AR_DBG_RING[AR_DBG_RING_N - 60 * floor(AR_DBG_RING_N / 60)] = format("%.2f %.2f %.0f %s", p.x, p.y, manny:getrot().y, m)
end
