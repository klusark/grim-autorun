-- Fixtures of the navigation tests (STATE_PLAN.md, steps 1 and 2): the state a case starts from is declared and applied here, and what a case leaves behind is
-- measured here. Loaded after nav_cases.lua, before test_nav.lua, on both engines.
--   ar_fx_snapshot()      the state that a case must not change, as a table of words
--   ar_fx_close(case)     the end of a case: what it changed since the baseline is told (NAVTEST leak) and put back
--   ar_fx_open(case)      the start of a case: the one before it is closed first
-- The engine has no way to ask for the collision mode of an actor, the scale or the constraint: the three builtins are wrapped to keep what was set.

AR_FX_MODE = { }
AR_FX_SCALE = { }
AR_FX_CONSTRAIN = { }
AR_FX_ACTOR = { }
AR_FX_OLD_MODE = SetActorCollisionMode
SetActorCollisionMode = function(a, m)
	AR_FX_MODE[tostring(a)] = m
	AR_FX_ACTOR[tostring(a)] = a
	return AR_FX_OLD_MODE(a, m)
end
AR_FX_OLD_SCALE = SetActorCollisionScale
SetActorCollisionScale = function(a, s)
	AR_FX_SCALE[tostring(a)] = s
	return AR_FX_OLD_SCALE(a, s)
end
AR_FX_OLD_CONSTRAIN = SetActorConstrain
SetActorConstrain = function(a, c)
	AR_FX_CONSTRAIN[tostring(a)] = c
	return AR_FX_OLD_CONSTRAIN(a, c)
end

AR_NT_RUN.leak = 0
AR_NT_PASS.leak = 0
AR_FX_BASE = nil
AR_FX_OPEN = nil

ar_fx_word = function(v)
	if v == nil then
		return "nil"
	end
	return tostring(v)
end

-- (a count of the actors other than Manny with a collision mode on, and Manny's own)
ar_fx_snapshot = function()
	local s = { }
	local m = tostring(manny.hActor)
	s.manny_mode = ar_fx_word(AR_FX_MODE[m])
	s.manny_scale = ar_fx_word(AR_FX_SCALE[m])
	local others = 0
	local k, v = next(AR_FX_MODE, nil)
	while k do
		if k ~= m and v and v ~= COLLISION_OFF then
			others = others + 1
		end
		k, v = next(AR_FX_MODE, k)
	end
	s.other_actors_colliding = others
	s.climbing = ar_fx_word(manny.is_climbing)
	local h = nil
	if manny.is_holding then
		h = manny.is_holding.name
	end
	s.holding = ar_fx_word(h)
	s.boxes_shrunk = ar_fx_word(AR_NT_SHRUNK)
	s.cutscene = cutSceneLevel
	return s
end

-- A fresh manny of the fixture: nothing is on, nothing is held, nothing is running
ar_fx_defaults = function()
	ar_nt_reset()
	-- (a mode that was never set is the engine's default: off)
	SetActorCollisionMode(manny.hActor, COLLISION_OFF)
	SetActorCollisionScale(manny.hActor, 1)
	SetActorConstrain(manny.hActor, nil)
	-- (the other actors that a scene put in a collision mode: only Manny's own mode is the fixture's)
	local k, v = next(AR_FX_MODE, nil)
	while k do
		if k ~= tostring(manny.hActor) and v and v ~= COLLISION_OFF then
			SetActorCollisionMode(AR_FX_ACTOR[k], COLLISION_OFF)
		end
		k, v = next(AR_FX_MODE, k)
	end
end

ar_fx_close = function()
	if not AR_FX_OPEN then
		return
	end
	local case = AR_FX_OPEN
	AR_FX_OPEN = nil
	-- (a door that was gone through plays its scene: the case is over when the game has the control again)
	ar_wait_for(function() return cutSceneLevel == 0 and not find_script(Sentence) end, 30000)
	local now = ar_fx_snapshot()
	local diffs = ""
	local count = 0
	local k, v = next(AR_FX_BASE, nil)
	while k do
		-- (a case that goes through a door is in the scene of the next set, which sets the scale and the mode of Manny as it likes; a case that
		-- climbs ends on the ladder: both are put back below, and declared in the case)
		local exempt = (case.door and (k == "manny_scale" or k == "manny_mode" or k == "other_actors_colliding")) or (case.climbs and k == "climbing") or (case.shrink and k == "boxes_shrunk")
		if not exempt and ar_fx_word(now[k]) ~= ar_fx_word(v) then
			diffs = diffs .. " " .. k .. " " .. ar_fx_word(v) .. "->" .. ar_fx_word(now[k])
			count = count + 1
		end
		k, v = next(AR_FX_BASE, k)
	end
	AR_NT_RUN.leak = AR_NT_RUN.leak + 1
	local word = "PASS"
	if count > 0 then
		word = "FAIL"
	else
		AR_NT_PASS.leak = AR_NT_PASS.leak + 1
	end
	PrintDebug("NAVTEST leak " .. case.id .. " " .. word .. diffs .. "\n")
	-- (put back, whatever it was; the boxes are given back in the set that shrank them, before it is left)
	if AR_NT_SHRUNK then
		UnShrinkBoxes()
		AR_NT_SHRUNK = nil
	end
	ar_fx_defaults()
	if manny.is_climbing then
		manny:stop_climb_ladder()
	end
end

-- The set of the case, entered the way a test enters it: the scripts of the set do not run (switch_to_set "noenter" does MakeCurrentSet and nothing
-- else), the objects are made visible, and Manny is where the case says. A case that needs the scripts of the set says enter = TRUE.
ar_fx_enter_set = function(set, case)
	local arg = "noenter"
	if case.enter then
		arg = nil
	end
	set:switch_to_set(arg)
	if not case.enter and set.make_objects_visible then
		set:make_objects_visible()
	end
	-- (Manny is in the set in the frame it is entered, at the start of the case: the scripts that watch him must not find him in the set before, at a
	-- point outside of every sector of this one; the original ends the process there)
	manny:put_in_set(set)
	if type(case.from) == "table" then
		manny:setpos(case.from[1], case.from[2], case.from[3] or 0)
	end
end

ar_fx_open = function(case)
	ar_fx_close()
	if not AR_FX_BASE then
		ar_fx_defaults()
		AR_FX_BASE = ar_fx_snapshot()
	end
	AR_FX_OPEN = case
end

-- Diagnostic (AR_FX_DUMP = TRUE): every global of the autorun (AR_...) with its value at the start of a case, one line each ("FXGLOBAL <id> <name> <value>"),
-- for tools to diff between two orders of the same case. A table is told by its number of entries.
ar_fx_dump = function(case)
	local name = nextvar(nil)
	while name do
		if strsub(name, 1, 3) == "AR_" and name ~= "AR_FX_DUMP" then
			local v = getglobal(name)
			local t = type(v)
			if t == "table" then
				local n = 0
				local k = next(v, nil)
				while k do
					n = n + 1
					k = next(v, k)
				end
				v = "table[" .. n .. "]"
			elseif t == "function" or t == "userdata" then
				v = t
			end
			PrintDebug("FXGLOBAL " .. case.id .. " " .. name .. " " .. tostring(v) .. "\n")
		end
		name = nextvar(name)
	end
end

-- The hand-made sets (tools/mk_set.py, tests/sets, read from the datausr.lab on both engines): made when a test asks, never a set of the story.
AR_FX_SETS = { "t_flat", "t_edge", "t_stair", "t_sliver", "t_hot" }
ar_fx_make_sets = function()
	local i = 1
	while AR_FX_SETS[i] do
		local name = AR_FX_SETS[i]
		if not getglobal(name) then
			setglobal(name, Set:create(name .. ".set", name, { }))
		end
		i = i + 1
	end
end
