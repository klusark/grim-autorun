-- The game as far as the planner (ar_nav.lua) looks at it, for the offline tests: Lua 3.1 of the game (LUA.DLL) in tools/lua31.
TRUE = 1
FALSE = nil
-- The sectors come from the set files, read out of the game archives by the host (host.c) through nav_setfile.lua, as in the game;
-- AR_SETS (ar_nav_sets.lua) gives each set its file, cheat boxes and doors; the sectors that are off are listed in AR_OFF.
AR_OFFLINE = TRUE
AR_OFF = { }
ar_log = function(msg)
	if AR_VERBOSE then
		PrintDebug("  log: " .. msg .. "\n")
	end
end
system = { }
manny = { pos = { x = 0, y = 0, z = 0 }, rot = { x = 0, y = 0, z = 0 }, hActor = 1 }
manny.getpos = function(self)
	return self.pos
end
manny.getrot = function(self)
	return self.rot
end
GetActorYawToPoint = function(h, x, y, z)
	return 0
end

-- IsPointInSector as the games have it: the first sector whose name holds the given one that is on and holds the point
IsPointInSector = function(x, y, z, name)
	local nav = ar_nav_of(system.currentSet)
	local lists = { nav, ar_nav_hotnav(nav) }
	local l = 1
	while lists[l] do
		local list = lists[l]
		local count = ar_nav_count(list)
		local i = 1
		while i <= count do
			if strfind(list.n[i], name, 1, 1) and not AR_OFF[list.n[i]] and ar_nav_inside(list, i, x, y) and abs(ar_nav_z(list, i, x, y) - z) < 0.2 then
				return i, list.n[i], 0
			end
			i = i + 1
		end
		l = l + 1
	end
	return nil
end

-- the set of AR_SETS under its name as the planner reads it: the cheat boxes and the door objects of the hot sectors
ar_off_set = function(name)
	local d = AR_SETS[name]
	local set = { name = name, setFile = d.file, cheat_boxes = { } }
	local i = 1
	while d.cheat[i] do
		set.cheat_boxes[d.cheat[i]] = TRUE
		i = i + 1
	end
	local hot, keys = next(d.door, nil)
	while hot do
		local obj = { name = hot, walkOut = function() end }
		set[hot] = obj
		local k = 1
		while keys[k] do
			set[keys[k]] = obj
			obj.name = keys[k]
			k = k + 1
		end
		hot, keys = next(d.door, hot)
	end
	set.by_global = d.global
	return set
end
