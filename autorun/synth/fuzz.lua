-- Random sets for the planner and the follower, no game data:   lua5.1 synth/fuzz.lua [seed [count]]   (synth/fuzz.sh)
-- A set is a row of columns of rectangular rooms of random sizes that touch along edges (a part of the edge, as the floors of the game do); a few are left out.
-- For each set some random pairs of points are planned and followed. A failure is printed with the seed, so that it can be run again:
--   * the way leaves the floor: a point of it, or a place on a line between two points sampled every 1 cm, is in no sector
--   * the simulated Manny does not arrive (held up, or not within the frames)
-- "no way" is not a failure: the two rooms may not touch.

SYNTH_NOEXIT = true
local seed0 = tonumber(arg and arg[1]) or 1
local count = tonumber(arg and arg[2]) or 50
arg = { "no check has this in its name" }
dofile("synth/run.lua")

local function genset(seed, file)
	math.randomseed(seed)
	local cols = math.random(2, 4)
	local rows = math.random(1, 3)
	local x = 0
	local sectors = { }
	local grid = { }
	for c = 1, cols do
		local w = 0.6 + math.random() * 2.4
		grid[c] = { }
		local y = 0
		for r = 1, rows do
			local h = 0.6 + math.random() * 2.4
			-- (a room touches the one to its left along a part of the edge: the rooms of one column share the row boundaries, so the upper and lower ones touch)
			if not (math.random() < 0.15 and c > 1 and r > 1) then
				grid[c][r] = { x0 = x, x1 = x + w, y0 = y, y1 = y + h }
				sectors[#sectors + 1] = grid[c][r]
			end
			y = y + h
		end
		x = x + w
	end
	local f = io.open("synth/sets/" .. file, "w")
	f:write("section: sectors\n\n")
	for i, s in ipairs(sectors) do
		f:write(string.format("sector room%d\n\tid %d\n\ttype walk\n\tdefault visibility visible\n\tnumvertices 4\n\tvertices: %g %g 0\n\t%g %g 0\n\t%g %g 0\n\t%g %g 0\n\n",
			i, i - 1, s.x0, s.y0, s.x0, s.y1, s.x1, s.y1, s.x1, s.y0))
	end
	f:close()
	return sectors
end

-- (1 cm of tolerance: the planner works on cells of 8 cm, and a line that clips the corner of a doorway by a few millimetres is the follower's to slide along)
local function inside(s, x, y)
	local t = 0.01
	return x >= s.x0 - t and x <= s.x1 + t and y >= s.y0 - t and y <= s.y1 + t
end

local function on_floor(sectors, x, y)
	for _, s in ipairs(sectors) do
		if inside(s, x, y) then
			return true
		end
	end
	return false
end

local failures = { }
local plans, ways, arrived = 0, 0, 0
local fail_kinds = { }
for seed = seed0, seed0 + count - 1 do
	local file = "fuzz.set"
	local sectors = genset(seed, file)
	AR_NAV = { }
	AR_SETS["fuzz"] = { file = file, global = "fuzz", cheat = { }, door = { } }
	local npairs = 4
	for k = 1, npairs do
		local a = sectors[math.random(#sectors)]
		local b = sectors[math.random(#sectors)]
		local x1 = a.x0 + 0.15 + math.random() * (a.x1 - a.x0 - 0.3)
		local y1 = a.y0 + 0.15 + math.random() * (a.y1 - a.y0 - 0.3)
		local x2 = b.x0 + 0.15 + math.random() * (b.x1 - b.x0 - 0.3)
		local y2 = b.y0 + 0.15 + math.random() * (b.y1 - b.y0 - 0.3)
		plans = plans + 1
		FOLLOW_TRACE = (tonumber(os.getenv("FUZZ_PAIR")) == k) and tonumber(os.getenv("FOLLOW_TRACE")) or nil
		local ok, path = pcall(plan, "fuzz", x1, y1, x2, y2)
		if not ok then
			failures[#failures + 1] = string.format("seed %d pair %d: error %s", seed, k, tostring(path))
			fail_kinds.error = (fail_kinds.error or 0) + 1
		elseif path then
			ways = ways + 1
			local n = ar_nav_len(path)
			local bad = nil
			for i = 1, n do
				if not on_floor(sectors, path[i][1], path[i][2]) then
					bad = string.format("point %d (%.3f %.3f) is off the floor", i, path[i][1], path[i][2])
				end
				if i > 1 and not bad then
					local ax, ay, bx, by = path[i - 1][1], path[i - 1][2], path[i][1], path[i][2]
					local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
					local steps = math.floor(len / 0.01) + 1
					for s = 1, steps do
						local px, py = ax + (bx - ax) * s / steps, ay + (by - ay) * s / steps
						if not on_floor(sectors, px, py) then
							bad = string.format("the line from point %d to %d leaves the floor at (%.3f %.3f)", i - 1, i, px, py)
							break
						end
					end
				end
			end
			if bad then
				failures[#failures + 1] = string.format("seed %d pair %d (%.2f %.2f -> %.2f %.2f): %s", seed, k, x1, y1, x2, y2, bad)
				if os.getenv("FUZZ_TRACE") then
					for i, s in ipairs(sectors) do
						print(string.format("  room%d x %.3f..%.3f y %.3f..%.3f", i, s.x0, s.x1, s.y0, s.y1))
					end
					for i = 1, n do
						print(string.format("  way %d: %.3f %.3f %s", i, path[i][1], path[i][2], path[i][4]))
					end
				end
				fail_kinds.leaves = (fail_kinds.leaves or 0) + 1
			else
				local r, f = follow("fuzz", x1, y1, x2, y2, nil)
				if r == "arrived" then
					arrived = arrived + 1
				else
					failures[#failures + 1] = string.format("seed %d pair %d (%.2f %.2f -> %.2f %.2f): follow: %s", seed, k, x1, y1, x2, y2, r)
					if os.getenv("FUZZ_TRACE") then
						for i, s in ipairs(sectors) do
							print(string.format("  room%d x %.3f..%.3f y %.3f..%.3f", i, s.x0, s.x1, s.y0, s.y1))
						end
						for i = 1, n do
							print(string.format("  way %d: %.3f %.3f %s", i, path[i][1], path[i][2], path[i][4]))
						end
					end
					fail_kinds.follow = (fail_kinds.follow or 0) + 1
				end
			end
		end
	end
end
os.remove("synth/sets/fuzz.set")

for i = 1, math.min(#failures, 25) do
	print(failures[i])
end
print(string.format("FUZZ seeds %d..%d: %d plans, %d ways, %d followed to the end, %d failures (leaves the floor %d, follow %d, error %d)",
	seed0, seed0 + count - 1, plans, ways, arrived, #failures, fail_kinds.leaves or 0, fail_kinds.follow or 0, fail_kinds.error or 0))
os.exit(#failures == 0 and 0 or 1)
