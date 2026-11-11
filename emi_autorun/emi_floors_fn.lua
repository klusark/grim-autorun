-- GetFloorHeights(x, z [, margin]) in Lua, for the original Monkey4.exe (ScummVM's is an opcode the port added): the heights of the
-- walk sectors of the current set over the floor point (x, z) that are active, the point at least margin inside. Same test as the
-- port's Sector::containsXZ, on the sectors of emi_floors.lua (gen_floors.py, from the set files). Whether a sector is active is
-- asked of the game (IsSectorActive, the original's own). AR_LUA_FLOORS: the Lua one in ScummVM too; AR_FLOORS_CHECK: both, and a
-- line for every difference.
AR_FLOOR_CELL = 4
AR_FLOOR_IDX = { }
ar_floor_index = function(key)
	local secs = AR_FLOORS[key]
	if not secs then
		return nil
	end
	local idx = { }
	local i = 1
	while secs[i] do
		local s = secs[i]
		local minx = s[7]
		local maxx = s[7]
		local minz = s[8]
		local maxz = s[8]
		local k = 9
		while s[k] do
			if s[k] < minx then minx = s[k] end
			if s[k] > maxx then maxx = s[k] end
			if s[k + 1] < minz then minz = s[k + 1] end
			if s[k + 1] > maxz then maxz = s[k + 1] end
			k = k + 2
		end
		local cx = floor(minx / AR_FLOOR_CELL)
		while cx <= floor(maxx / AR_FLOOR_CELL) do
			local cz = floor(minz / AR_FLOOR_CELL)
			while cz <= floor(maxz / AR_FLOOR_CELL) do
				local ck = cx * 100000 + cz
				if not idx[ck] then
					idx[ck] = { n = 0 }
				end
				idx[ck].n = idx[ck].n + 1
				idx[ck][idx[ck].n] = i
				cz = cz + 1
			end
			cx = cx + 1
		end
		i = i + 1
	end
	return idx
end
ar_floor_key = function()
	local set = system.currentSet
	local f = set and set.setFile
	if not f then
		return nil
	end
	f = strlower(f)
	local dot = strfind(f, ".", 1, 1)
	if dot then
		f = strsub(f, 1, dot - 1)
	end
	return f
end
ar_floor_contains = function(s, x, z, margin)
	local ny = s[4]
	local w = 1
	if ny < 0 then
		w = -1
	end
	local k = 7
	while s[k] do
		local x0 = s[k]
		local z0 = s[k + 1]
		local x1 = s[k + 2]
		local z1 = s[k + 3]
		if not x1 then
			x1 = s[7]
			z1 = s[8]
		end
		local ex = x1 - x0
		local ez = z1 - z0
		local len = sqrt(ex * ex + ez * ez)
		if len > 0 and w * (ez * (x - x0) - ex * (z - z0)) / len < margin - 0.00001 then
			return nil
		end
		k = k + 2
	end
	return s[6] - (s[3] * (x - s[7]) + s[5] * (z - s[8])) / ny
end
ar_lua_floor_heights = function(x, z, margin)
	local out = { }
	local key = ar_floor_key()
	if not key or not x or not z then
		return out
	end
	if not AR_FLOOR_IDX[key] then
		AR_FLOOR_IDX[key] = ar_floor_index(key) or { }
	end
	local cell = AR_FLOOR_IDX[key][floor(x / AR_FLOOR_CELL) * 100000 + floor(z / AR_FLOOR_CELL)]
	if not cell then
		return out
	end
	local secs = AR_FLOORS[key]
	local n = 0
	local i = 1
	while i <= cell.n do
		local s = secs[cell[i]]
		local y = ar_floor_contains(s, x, z, margin or 0)
		if y and IsSectorActive(s[1]) then
			n = n + 1
			out[n] = y
		end
		i = i + 1
	end
	return out
end
ar_floors_install = function()
	if not AR_ENGINE_FLOORS then
		AR_ENGINE_FLOORS = GetFloorHeights or "none"
	end
	if AR_ENGINE_FLOORS == "none" or AR_LUA_FLOORS then
		GetFloorHeights = ar_lua_floor_heights
	elseif AR_FLOORS_CHECK then
		GetFloorHeights = function(x, z, margin)
			local a = AR_ENGINE_FLOORS(x, z, margin)
			local b = ar_lua_floor_heights(x, z, margin)
			local sa = ""
			local sb = ""
			local i = 1
			while a[i] do sa = sa .. format(" %.3f", a[i]) i = i + 1 end
			i = 1
			while b[i] do sb = sb .. format(" %.3f", b[i]) i = i + 1 end
			AR_FLOORS_CHECKED = (AR_FLOORS_CHECKED or 0) + 1
			if sa ~= sb then
				AR_FLOORS_DIFF = (AR_FLOORS_DIFF or 0) + 1
				if AR_FLOORS_DIFF <= 40 then
					ar_log(format("FLOORS differ at %.3f %.3f margin %s in ", x, z, tostring(margin)) .. tostring(ar_floor_key()) .. ": engine" .. sa .. " / lua" .. sb)
				end
			end
			return a
		end
	end
end
ar_floors_install()
