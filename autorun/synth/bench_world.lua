-- The large world of the benchmarks: 8 x 4 rooms, written to synth/sets/bench.set; GX, GY is the middle of the last room.
local f = io.open("synth/sets/bench.set", "w")
f:write("section: sectors\n\n")
local id = 0
local x = 0
GX, GY = 0, 0
math.randomseed(7)
for c = 1, 8 do
	local w = 3 + math.random() * 1.5
	local y = 0
	for r = 1, 4 do
		local h = 2.5 + math.random() * 1.5
		-- (holes, so that the way winds: every third room of every other column is left out, except the first and the last rooms)
		if not ((c % 2 == 0) and (r == 2 or r == 3) and c < 8) then
			f:write(string.format("sector room%d\n\tid %d\n\ttype walk\n\tdefault visibility visible\n\tnumvertices 4\n\tvertices: %g %g 0\n\t%g %g 0\n\t%g %g 0\n\t%g %g 0\n\n",
				id, id, x, y, x, y + h, x + w, y + h, x + w, y))
		end
		id = id + 1
		GX, GY = x + w / 2, y + h / 2
		y = y + h
	end
	x = x + w
end
f:close()
AR_SETS["bench"] = { file = "bench.set", global = "bench", cheat = { }, door = { } }

