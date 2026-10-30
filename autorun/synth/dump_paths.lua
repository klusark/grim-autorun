-- The ways of many random plans, one per line, to compare two copies of ar_nav.lua:
--   AR_NAV_FILE=/tmp/old.lua lua5.1 synth/dump_paths.lua [seed [count]] > a.txt; lua5.1 synth/dump_paths.lua [seed [count]] > b.txt; diff a.txt b.txt
SYNTH_NOEXIT = true
local seed0 = tonumber(arg and arg[1]) or 1
local count = tonumber(arg and arg[2]) or 100
arg = { "no check has this in its name" }
dofile("synth/run.lua")
for seed = seed0, seed0 + count - 1 do
	math.randomseed(seed)
	local cols, rows = math.random(2, 5), math.random(1, 4)
	local sectors, x = { }, 0
	for c = 1, cols do
		local w, y = 0.6 + math.random() * 2.4, 0
		for r = 1, rows do
			local h = 0.6 + math.random() * 2.4
			if not (math.random() < 0.2 and c > 1 and r > 1) then
				sectors[#sectors + 1] = { x0 = x, x1 = x + w, y0 = y, y1 = y + h }
			end
			y = y + h
		end
		x = x + w
	end
	local f = io.open("synth/sets/dump.set", "w")
	f:write("section: sectors\n\n")
	for i, s in ipairs(sectors) do
		f:write(string.format("sector room%d\n\tid %d\n\ttype walk\n\tdefault visibility visible\n\tnumvertices 4\n\tvertices: %g %g 0\n\t%g %g 0\n\t%g %g 0\n\t%g %g 0\n\n", i, i - 1, s.x0, s.y0, s.x0, s.y1, s.x1, s.y1, s.x1, s.y0))
	end
	f:close()
	AR_NAV = { }
	AR_SETS["dump"] = { file = "dump.set", global = "dump", cheat = { }, door = { } }
	for k = 1, 4 do
		local a, b = sectors[math.random(#sectors)], sectors[math.random(#sectors)]
		local x1, y1 = a.x0 + 0.15 + math.random() * (a.x1 - a.x0 - 0.3), a.y0 + 0.15 + math.random() * (a.y1 - a.y0 - 0.3)
		local x2, y2 = b.x0 + 0.15 + math.random() * (b.x1 - b.x0 - 0.3), b.y0 + 0.15 + math.random() * (b.y1 - b.y0 - 0.3)
		local path = plan("dump", x1, y1, x2, y2)
		local s = string.format("%d.%d:", seed, k)
		if path then
			for i = 1, ar_nav_len(path) do
				s = s .. string.format(" (%.4f %.4f %s)", path[i][1], path[i][2], path[i][4])
			end
		else
			s = s .. " none"
		end
		print(s)
	end
end
os.remove("synth/sets/dump.set")
