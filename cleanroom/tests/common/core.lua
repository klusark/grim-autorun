-- The Lua interpreter and its libraries: numbers, strings, tables, the order of next()

cr_t_numbers = function()
	cr_log("arith", 7 / 2, 2 ^ 10, -7 / 3, 1e20 * 1e20)
	cr_log("tostring", tostring(1 / 3), tostring(100), tostring(1e15), tostring(-0.5))
	cr_log("tonumber", tonumber("0x10"), tonumber("  12  "), tonumber("1e3"), tonumber("abc"))
	cr_log("floor_ceil", floor(-2.5), ceil(-2.5), floor(2.5), ceil(2.5))
	cr_log("mod", mod(7, 3), mod(-7, 3), mod(7.5, 2), mod(7, -3))
	cr_log("trig_deg", sin(30), cos(60), tan(45), sin(90))
	cr_log("atrig", asin(0.5), acos(0.5), atan(1), atan(-1))
	cr_log("sqrt_abs", sqrt(2), abs(-3.25), sqrt(1e-10), deg(1))
	cr_log("has", type(min), type(max), type(rad), type(math_pow))
	cr_log("minmax", min(3, 1, 2), max(3, 1, 2))
	cr_log("rad", rad(180))
	if type(math_pow) == "function" then
		cr_log("pow", math_pow(2, 0.5))
	end
	cr_log("float_cmp", 0.1 + 0.2 == 0.3, 1 / 3 * 3 == 1, 2 ^ 53 + 1 == 2 ^ 53)
end
cr_scummvm_differs("numbers", nil, "grim") cr_scummvm_differs("numbers", nil, "emi") cr_test("numbers", cr_t_numbers)

cr_t_strings = function()
	cr_log("strsub", strsub("abcdef", 2, 4), strsub("abcdef", -2), strsub("abcdef", 3), strlen("abcdef"))
	cr_log("strfind", strfind("hello world", "o w"), strfind("hello", "l+"), strfind("a.b", ".", 1, 1))
	cr_log("case", strupper("MiXeD"), strlower("MiXeD"), strrep("ab", 3))
	cr_log("format_num", format("%d", 3.7), format("%5.2f", 3.14159), format("%x", 255), format("%e", 12345.678))
	cr_log("format_str", format("[%5s]", "ab"), format("[%-5s]", "ab"), format("%c", 65))
	cr_log("gsub", gsub("hello world", "o", "0"), gsub("abc", "(%w)", "%1%1"))
	cr_log("concat", "a" .. 1 .. 2.5, 10 .. "")
	if type(ascii) == "function" then
		cr_log("ascii", ascii("A"))
	end
end
cr_scummvm_differs("strings", nil, "grim") cr_scummvm_differs("strings", nil, "emi") cr_test("strings", cr_t_strings)

-- (the order in which next() lists keys depends on the hash of the interpreter: strings, numbers, tables as keys)
cr_t_next_order = function()
	local t = { }
	local names = { "manny", "glottis", "meche", "domino", "salvador", "olivia", "velasco", "chepito", "eva", "lupe" }
	local i = 1
	while i <= 10 do
		t[names[i]] = i
		i = i + 1
	end
	i = 1
	while i <= 20 do
		t[i * 7] = i
		i = i + 1
	end
	local s = ""
	local k, v = next(t, nil)
	while k do
		s = s .. tostring(k) .. ","
		k, v = next(t, k)
	end
	cr_unstable("order") cr_log("order", s)  -- (the original hashes by address, and LUA.DLL's heap moves from run to run)
	local n = 0
	k, v = nextvar(nil)
	while k do
		n = n + 1
		k, v = nextvar(k)
	end
	cr_log("globals_counted", n > 100)
end
cr_test("next_order", cr_t_next_order)

cr_t_tasks = function()
	CR_T_ORDER = ""
	start_script(cr_t_task_a)
	start_script(cr_t_task_b)
	cr_log("right_after_start", CR_T_ORDER)
	break_here()
	cr_log("after_one_frame", CR_T_ORDER)
	cr_frames(3)
	cr_log("after_four_frames", CR_T_ORDER)
end
cr_t_task_a = function()
	CR_T_ORDER = CR_T_ORDER .. "a1"
	break_here()
	CR_T_ORDER = CR_T_ORDER .. "a2"
end
cr_t_task_b = function()
	CR_T_ORDER = CR_T_ORDER .. "b1"
	break_here()
	CR_T_ORDER = CR_T_ORDER .. "b2"
end
cr_test("tasks", cr_t_tasks)

cr_t_error = function()
	cr_log("before", 1)
	local x = nil
	x.field = 1
	cr_log("not_reached", 1)
end
cr_test("lua_error_is_caught", cr_t_error)

-- (every global that is a function before any test ran: the builtins of the engine and of the runner, sorted)
cr_t_builtins = function()
	local names = { }
	local n = 0
	local k, v = nextvar(nil)
	-- (the runner's and the tests' own functions are left out; there are thousands of them with the argument probe)
	while k do
		if (type(v) == "function" or type(v) == "cfunction") and strsub(k, 1, 3) ~= "cr_" then
			n = n + 1
			names[n] = k
		end
		k, v = nextvar(k)
	end
	-- (insertion sort: Lua 3.1 has no sort. The original kills a script that runs "a really long time" without
	-- break_here, so it yields every 50 names)
	local i = 2
	local j, x, moving
	while i <= n do
		if mod(i, 50) == 0 then
			break_here()
		end
		x = names[i]
		j = i - 1
		moving = TRUE
		while moving do
			if j >= 1 and names[j] > x then
				names[j + 1] = names[j]
				j = j - 1
			else
				moving = nil
			end
		end
		names[j + 1] = x
		i = i + 1
	end
	i = 1
	while i <= n do
		if strsub(names[i], 1, 3) ~= "cr_" then
			cr_log("fn_" .. names[i], type(getglobal(names[i])))
		end
		i = i + 1
	end
end
cr_scummvm_differs("builtins", nil, "grim") cr_scummvm_differs("builtins", nil, "emi") cr_test("builtins", cr_t_builtins)
