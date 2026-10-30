-- The planner on the synthetic sets

-- a way across two rooms joined along an edge, about as long as the straight line
do
	local path = plan("flat", 1, 1, 7, 1)
	check("flat: a way over the shared edge", path ~= nil, "no way")
	if path then
		local l = pathlen(path)
		check("flat: no detour", l < 6.3, "length " .. l)
		local last = path[ar_nav_len(path)]
		check("flat: ends at the goal", math.abs(last[1] - 7) < 0.1 and math.abs(last[2] - 1) < 0.1, last[1] .. " " .. last[2])
	end
end

-- no way between islands
do
	local path = plan("islands", 1, 1, 4, 1)
	check("islands: no way between them", path == nil, "a way of " .. (path and ar_nav_len(path) or 0) .. " points")
end

-- a gate that is off: no way over the floors that are on, but a way over the sectors that are off (the second try of the planner)
do
	local path = plan("gate", 1, 1, 6, 1)
	check("gate: a way over the sector that is off", path ~= nil, "no way")
	AR_OPTIMISTIC = nil
	local set, nav, w = place("gate", 1, 1)
	local strict = ar_w_plan1(nav, w, 6, 1, 0)
	check("gate: none over the floors that are on", strict == nil, "a way")
end

-- a neck of 12 cm is a way
do
	local path = plan("neck", 1, 1.5, 6, 1.5)
	check("neck: a way through 12 cm", path ~= nil, "no way")
end

-- the foot of a ramp: from the top of the ramp to the west landing
do
	local path = plan("ramp", 0.5, 3.8, -2.5, -0.45)
	check("ramp: a way from the ramp to the west landing", path ~= nil, "no way")
end
