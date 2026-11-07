-- Clean-room test runner: the whole _system.lua of the test data, the same file on ScummVM and on the original v1.01 exe.
-- Lua 3.1: no break, no closures over locals, nil is false, at most 32 locals a function.
--
-- Every line the tests write starts with "CR " and goes out through PrintDebug (the original: grimdebug.log through
-- patch.dll; ScummVM: the log with --debugflags=scripts). run.py reads them back and compare.py checks one engine
-- against the other. The tests do not decide what is right: the original is the reference, a test only reports what it
-- sees (cr_log), and the values are compared.
--
--   cr_test(name, fn)        adds a test; fn runs in its own task, so it may wait (break_here, cr_frames)
--   cr_log(key, a, b, c, d)  one observation of the current test; numbers are written with 6 decimals
--   cr_unstable(key)         the key's value is not meant to repeat run to run (a time, an address): it is not compared
--   cr_scummvm_differs(name, why, game)  (next to the cr_test) ScummVM is known to give the test's values differently: a
--                            known difference, not a regression. game: only for that game (CR_GAME) in a file both
--                            games run (tools/mark_known.py adds the marks from a run)
--   cr_frames(n)             waits n frames
--   cr_until(fn, max)        waits until fn() is true or max frames passed; returns the frames waited
--
-- A test that ends normally writes END; one that raises a Lua error or does not finish in CR_MAX_FRAMES writes FAILED
-- and the runner goes on with the next one. The run ends with SUMMARY and exit().

-- (the game defines these in its own scripts, the engine does not)
TRUE = 1
FALSE = nil

CR_TESTS = { }
CR_N = 0
CR_MAX_FRAMES = 1200
CR_CUR = "-"
CR_DONE = nil
CR_FAILS = 0

cr_out = function(s)
	PrintDebug("CR " .. s .. "\n")
end

cr_word = function(v)
	if v == nil then
		return "nil"
	elseif type(v) == "number" then
		return format("%.6f", v)
	elseif type(v) == "string" then
		return "\"" .. v .. "\""
	end
	return type(v)
end

cr_log = function(key, a, b, c, d)
	local s = CR_CUR .. "|" .. key .. "|" .. cr_word(a)
	if b ~= nil or c ~= nil or d ~= nil then
		s = s .. " " .. cr_word(b)
	end
	if c ~= nil or d ~= nil then
		s = s .. " " .. cr_word(c)
	end
	if d ~= nil then
		s = s .. " " .. cr_word(d)
	end
	cr_out("V " .. s)
end

-- (compare.py skips a key marked in either log; "(status)" marks how the test ends)
cr_unstable = function(key)
	cr_out("U " .. CR_CUR .. "|" .. key)
end

-- A picture of the screen: run.py puts the box of the bright pixels of it (x0 y0 x1 y1) in the log under key (snaps.py).
-- The original saves its back buffer at once; ScummVM the next frame it draws: let a frame or two pass before changing what
-- is on the screen.
CR_SNAP_N = 0
cr_snap = function(key, mode)
	CR_SNAP_N = CR_SNAP_N + 1
	local f = "crsnap" .. CR_SNAP_N .. ".bmp"
	PrintDebug("CRSNAP:" .. f)
	if mode == "dark" then
		cr_log(key, "snap:" .. f .. ":dark")
	else
		cr_log(key, "snap:" .. f)
	end
end

-- (written after the test's BEGIN or SKIP, in both engines' logs; compare.py --known reads it)
CR_DIFFERS = { }
cr_scummvm_differs = function(name, why, game)
	if game == nil or game == CR_GAME then
		CR_DIFFERS[name] = why or ""
	end
end

cr_test = function(name, fn)
	CR_N = CR_N + 1
	CR_TESTS[CR_N] = { name = name, fn = fn }
end

cr_frames = function(n)
	local i = 0
	while i < n do
		break_here()
		i = i + 1
	end
end

cr_until = function(fn, max)
	local i = 0
	while not fn() and i < max do
		break_here()
		i = i + 1
	end
	return i
end

-- (a Lua error in a test: told, and the task is ended by the interpreter)
cr_error = function(msg)
	cr_out("ERROR " .. CR_CUR .. " " .. tostring(msg))
end

cr_task = function(fn)
	fn()
	CR_DONE = TRUE
end

cr_main = function()
	local i = 1
	local id, f
	-- (CR_FROM: a run that goes on after a crash starts at the first test of the file that crashed; CR_FAILS0: failures before)
	if CR_FROM then
		while i <= CR_N and CR_TESTS[i].name ~= CR_FROM do
			i = i + 1
		end
		CR_FAILS = CR_FAILS0 or 0
	end
	cr_out("START " .. CR_N .. " tests")
	while i <= CR_N do
		if CR_SKIP and CR_SKIP[CR_TESTS[i].name] then
			cr_out("SKIP " .. CR_TESTS[i].name)
			if CR_DIFFERS[CR_TESTS[i].name] then
				cr_out("DIFFERS " .. CR_TESTS[i].name .. "|" .. CR_DIFFERS[CR_TESTS[i].name])
			end
		elseif CR_ONLY == nil or CR_ONLY[CR_TESTS[i].name] then
			CR_CUR = CR_TESTS[i].name
			CR_DONE = nil
			cr_out("BEGIN " .. CR_CUR)
			if CR_DIFFERS[CR_CUR] then
				cr_out("DIFFERS " .. CR_CUR .. "|" .. CR_DIFFERS[CR_CUR])
			end
			id = start_script(cr_task, CR_TESTS[i].fn)
			f = 0
			while find_script(id) and f < CR_MAX_FRAMES do
				break_here()
				f = f + 1
			end
			if find_script(id) then
				stop_script(id)
				cr_out("TIMEOUT " .. CR_CUR)
			end
			if CR_DONE then
				cr_out("END " .. CR_CUR)
			else
				CR_FAILS = CR_FAILS + 1
				cr_out("FAILED " .. CR_CUR)
			end
		end
		i = i + 1
	end
	CR_CUR = "-"
	cr_out("SUMMARY " .. CR_N .. " tests, " .. CR_FAILS .. " failed")
	break_here()
	exit()
end

seterrormethod(cr_error)
dofile("_cr_tests.lua")

BOOT = function(resumeSave, bootParam)
	start_script(cr_main)
end
