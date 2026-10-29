-- Tier A: the plan of every case, offline. Run by tools/lua31/run.sh after prelude.lua, ar_nav.lua, ar_nav_data.lua,
-- ar_nav_sets.lua and nav_cases.lua.
ar_nt_place = function(case)
	local name = nil
	local n, d = next(AR_SETS, nil)
	while n do
		if d.global == case.set then
			name = n
		end
		n, d = next(AR_SETS, n)
	end
	system.currentSet = ar_off_set(name)
	local set = system.currentSet
	local nav = ar_nav_of(set)
	AR_OFF = { }
	local i = 1
	while nav.off[i] do
		AR_OFF[nav.off[i]] = TRUE
		i = i + 1
	end
	i = 1
	while case.on and case.on[i] do
		AR_OFF[case.on[i]] = nil
		i = i + 1
	end
	i = 1
	while case.off and case.off[i] do
		AR_OFF[case.off[i]] = TRUE
		i = i + 1
	end
	local x = 0
	local y = 0
	local z = 0
	if case.from == "door" then
		x, y, z = ar_nav_hot_point(set[case.door])
	elseif case.from then
		x = case.from[1]
		y = case.from[2]
		z = ar_nt_goal_z(nav, case.from[1], case.from[2], case.from[3])
	else
		x, y = ar_nav_centre(nav, 1)
		z = nav.p[1][3]
	end
	manny.pos = { x = x, y = y, z = z }
	manny.rot = { x = 0, y = case.yaw or 0, z = 0 }
	if nav.w then
		nav.w = nil
	end
	return set, nav
end

