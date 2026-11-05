-- More of the interpreter: patterns, number formatting, task control  -- games: grim emi

cr_t_patterns = function()
	cr_log("digits", strfind("abc 123 def", "%d+"))
	cr_log("anchor", strfind("hello", "^h"), strfind("hello", "^e"), strfind("hello", "o$"))
	cr_log("class", strfind("a_b-c", "[%-_]"), strfind("ABC", "%l"), strfind("x y", "%s"))
	cr_log("captures", strfind("key=value", "(%w+)=(%w+)"))
	cr_log("gsub_count", gsub("aaa", "a", "b", 2))
	cr_log("gsub_fn", gsub("1 2 3", "(%d)", cr_t_double))
	cr_log("gsub_anchor", gsub("hello hello", "^hello", "x"))
	cr_log("balanced", strfind("f(a(b)c)d", "%b()"))
end
cr_t_double = function(d)
	return tostring(tonumber(d) * 2)
end
cr_test("patterns", cr_t_patterns)

cr_t_number_text = function()
	cr_log("concat", 1 / 3 .. "", 100 / 4 .. "", 1e100 .. "", -0 .. "")
	cr_log("big", tostring(2 ^ 31), tostring(2 ^ 32 + 0.5), tostring(123456789012))
	cr_log("small", tostring(1e-5), tostring(0.1), tostring(1 / 7))
	cr_log("format_g", format("%g", 0.0001), format("%g", 1e20), format("%.3g", 3.14159))
	cr_log("format_d", format("%d", -3.9), format("%5d", 42), format("%-5d|", 42), format("%05d", 42))
	cr_log("tonumber_text", tonumber("1.5e2"), tonumber("  -7 "), tonumber("1,5"), tonumber(""))
	cr_log("compare", "10" < "9", "a" < "B", "abc" < "abd")
end
cr_test("number_text", cr_t_number_text)

cr_t_task_control = function()
	CR_TICKS = 0
	local id = start_script(cr_t_ticker)
	cr_frames(3)
	cr_log("ran_3", CR_TICKS)
	pause_scripts()
	local before = CR_TICKS
	cr_frames(3)
	cr_log("paused_others", CR_TICKS - before)
	unpause_scripts()
	before = CR_TICKS
	cr_frames(3)
	cr_log("unpaused", CR_TICKS - before)
	stop_script(id)
	CR_ARGS = nil
	start_script(cr_t_args, 1, "two", 3)
	cr_frames(1)
	cr_log("args", CR_ARGS)
	CR_NEST = ""
	start_script(cr_t_outer)
	cr_frames(3)
	cr_log("nested", CR_NEST)
end
cr_t_ticker = function()
	while TRUE do
		CR_TICKS = CR_TICKS + 1
		break_here()
	end
end
cr_t_args = function(a, b, c)
	CR_ARGS = tostring(a) .. "," .. tostring(b) .. "," .. tostring(c)
end
cr_t_outer = function()
	CR_NEST = CR_NEST .. "o1"
	start_script(cr_t_inner)
	CR_NEST = CR_NEST .. "o2"
	break_here()
	CR_NEST = CR_NEST .. "o3"
end
cr_t_inner = function()
	CR_NEST = CR_NEST .. "i1"
	break_here()
	CR_NEST = CR_NEST .. "i2"
end
cr_test("task_control", cr_t_task_control)
