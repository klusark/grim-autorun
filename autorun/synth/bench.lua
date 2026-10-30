-- How long the planner takes, and where:   lua5.1 synth/bench.lua [count]   (cpu seconds of Lua 5.1, not of the game's Lua 3.1: the shares are the point)
-- A world of 8 x 4 rooms, 30 m across, planned across, ar_w_plan including the way (smoothing) of the result.

SYNTH_NOEXIT = true
local count = tonumber(arg and arg[1]) or 5
arg = { "no check has this in its name" }
dofile("synth/run.lua")

dofile("synth/bench_world.lua")

local counts = { }
local total = 0
local function hook()
	local info = debug.getinfo(2, "Sn")
	if info then
		local key = (info.name or "?") .. " (" .. info.short_src .. ":" .. info.linedefined .. ")"
		counts[key] = (counts[key] or 0) + 1
		total = total + 1
	end
end

local t0 = os.clock()
debug.sethook(hook, "", 1000)
local n = 0
for i = 1, count do
	AR_NAV = { }
	local path = plan("bench", 1.5, 1.5, GX, GY)
	if path then
		n = n + ar_nav_len(path)
	end
end
debug.sethook()
local dt = os.clock() - t0
print(string.format("BENCH %d plans, %.2f s each, %d way points in all", count, dt / count, n))
local list = { }
for k, v in pairs(counts) do
	list[#list + 1] = { k, v }
end
table.sort(list, function(a, b) return a[2] > b[2] end)
for i = 1, math.min(12, #list) do
	print(string.format("  %5.1f%%  %s", 100 * list[i][2] / total, list[i][1]))
end
os.remove("synth/sets/bench.set")
