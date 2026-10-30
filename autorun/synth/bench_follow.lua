-- How long a frame of the follower takes, and where:   lua5.1 synth/bench_follow.lua   (a long walk across the large world of bench.lua, simulated Manny)
SYNTH_NOEXIT = true
arg = { "no check has this in its name" }
dofile("synth/run.lua")
dofile("synth/bench_world.lua")

local path, nav, w = plan("bench", 1.5, 1.5, GX, GY)
nav_now = nav
manny.rot.y = 0
local n = ar_nav_len(path)
local cum = ar_way_cum(path)
local i = 2
local counts, total = { }, 0
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
local frames = 0
while frames < 3000 and i <= n and math.sqrt((manny.pos.x - GX) ^ 2 + (manny.pos.y - GY) ^ 2) > 0.15 do
	frames = frames + 1
	ar_follow_frame(nav, w, path, n, cum, i)
	i = AR_FOLLOW_I or i
end
debug.sethook()
local dt = os.clock() - t0
print(string.format("BENCH FOLLOW %d frames, %.2f ms a frame, at point %d of %d", frames, 1000 * dt / frames, i, n))
local list = { }
for k, v in pairs(counts) do list[#list + 1] = { k, v } end
table.sort(list, function(a, b) return a[2] > b[2] end)
for k = 1, math.min(10, #list) do
	print(string.format("  %5.1f%%  %s", 100 * list[k][2] / total, list[k][1]))
end
