-- Offline sweep over every set: from the first door of the set (stepped out of it) the way to each other door. A door that cannot be
-- reached from the first one is listed; the sets are in the state they start in. Not a pass/fail test: the
-- list is read by a person, a door that is not reachable at the start can be right (a locked or still closed one).
AR_VERBOSE = nil
SW_SETS = 0
SW_PAIRS = 0
SW_OK = 0
SW_BAD = 0
sw_door_list = function(set, d)
	local list = { }
	local n = 0
	local hot, keys = next(d.door, nil)
	while hot do
		n = n + 1
		list[n] = set[hot]
		hot, keys = next(d.door, hot)
	end
	return list
end
sw_set = function(name, d)
	system.currentSet = ar_off_set(name)
	local nav = ar_nav_of(system.currentSet)
	if not nav then
		return
	end
	local set = system.currentSet
	AR_OFF = { }
	local i = 1
	while nav.off[i] do
		AR_OFF[nav.off[i]] = TRUE
		i = i + 1
	end
	nav.w = nil
	local doors = sw_door_list(set, d)
	if not doors[2] then
		return
	end
	SW_SETS = SW_SETS + 1
	local a = 1
	local first = nil
	while doors[a] and not first do
		local x, y, z = ar_nav_hot_point(doors[a])
		if x then
			first = a
			manny.pos = { x = x, y = y, z = z }
		end
		a = a + 1
	end
	if not first then
		return
	end
	local w = ar_w(nav)
	local b = 1
	local bad = ""
	while doors[b] do
		if b ~= first then
			SW_PAIRS = SW_PAIRS + 1
			local hotlist = ar_nav_door_hot(nav, doors[b])
			if hotlist then
				AR_GOAL_REGION = TRUE
				AR_GOAL_HOT = hotlist
				w.tmp = { }
				local cx, cy = ar_nav_centre(ar_nav_hotnav(nav), next(hotlist, nil))
				local path = ar_w_plan(nav, w, cx, cy, manny.pos.z)
				AR_GOAL_REGION = nil
				AR_GOAL_HOT = { }
				if path then
					SW_OK = SW_OK + 1
				else
					SW_BAD = SW_BAD + 1
					bad = bad .. " " .. tostring(doors[b].name)
				end
			end
		end
		b = b + 1
	end
	if bad ~= "" then
		PrintDebug("SWEEP " .. name .. ": from " .. tostring(doors[first].name) .. " no way to:" .. bad .. "\n")
	end
end
local n, d = next(AR_SETS, nil)
while n do
	sw_set(n, d)
	n, d = next(AR_SETS, n)
end
PrintDebug("SWEEP SUMMARY " .. SW_SETS .. " sets, " .. SW_PAIRS .. " door pairs, " .. SW_OK .. " with a way, " .. SW_BAD .. " without\n")
