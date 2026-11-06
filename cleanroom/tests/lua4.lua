-- The rest of the interpreter's builtins: raw access, tag methods, globals, random numbers, the extra math, errors, scripts  -- games: grim emi

cr_t_raw = function()
	local t = { a = 1 }
	cr_log("rawget", rawgettable(t, "a"), rawgettable(t, "b"))
	rawsettable(t, "b", 2)
	cr_log("rawset", t.b)
	CR_G1 = 5
	cr_log("rawglobal", rawgetglobal("CR_G1"), getglobal("CR_G1"))
	rawsetglobal("CR_G2", 6)
	setglobal("CR_G3", 7)
	cr_log("set_globals", CR_G2, CR_G3)
	cr_log("missing_global", getglobal("CR_NEVER_SET"))
end
cr_test("raw", cr_t_raw)

cr_t_tagmethods = function()
	local tg = newtag()
	local t = { }
	settag(t, tg)
	settagmethod(tg, "gettable", cr_t_tm_get)
	cr_log("gettable", t.x)
	cr_log("method_type", type(gettagmethod(tg, "gettable")), type(gettagmethod(tg, "settable")))
	local tg2 = newtag()
	copytagmethods(tg2, tg)
	local u = { }
	settag(u, tg2)
	cr_log("copied", u.y)
	settagmethod(tg, "add", cr_t_tm_add)
	cr_log("add", t + 1)
end
cr_t_tm_get = function(t, k)
	return "got:" .. k
end
cr_t_tm_add = function(a, b)
	return 42
end
cr_test("tagmethods", cr_t_tagmethods)

cr_t_foreachvar = function()
	CR_FV = 0
	foreachvar(cr_t_fv_count)
	cr_log("counted_some", CR_FV > 50)
end
cr_t_fv_count = function(k, v)
	CR_FV = CR_FV + 1
end
cr_test("foreachvar", cr_t_foreachvar)

-- (the sequence of the random generator after a seed: the game seeds it with randomseed(5) in BOOT)
cr_t_random = function()
	randomseed(5)
	local s = ""
	local i = 0
	while i < 8 do
		s = s .. format("%.6f", random()) .. " "
		i = i + 1
	end
	cr_log("floats", s)
	randomseed(5)
	s = ""
	i = 0
	while i < 8 do
		s = s .. tostring(random(10)) .. " "
		i = i + 1
	end
	cr_log("ints", s)
	randomseed(1234)
	s = ""
	i = 0
	while i < 8 do
		s = s .. tostring(random(3, 7)) .. " "
		i = i + 1
	end
	cr_log("ranges", s)
end
cr_test("random", cr_t_random)

cr_t_more_math = function()
	local names = { "exp", "log", "log10", "atan2" }
	local i = 1
	while i <= 4 do
		cr_fn(names[i])
		i = i + 1
	end
	if type(exp) == "function" or type(exp) == "cfunction" then
		cr_log("exp", exp(1), exp(0))
	end
	if type(log) == "function" or type(log) == "cfunction" then
		cr_log("log", log(10), log(1))
	end
	if type(log10) == "function" or type(log10) == "cfunction" then
		cr_log("log10", log10(1000))
	end
	if type(atan2) == "function" or type(atan2) == "cfunction" then
		cr_log("atan2", atan2(1, 1), atan2(-1, -1), atan2(0, -1))
	end
	cr_log("mod_neg", mod(-1, 5), mod(5.5, -2))
end
cr_scummvm_differs("more_math", nil, "grim") cr_test("more_math", cr_t_more_math)

cr_t_assert_ok = function()
	assert(1)
	cr_log("passed", 1)
end
cr_test("assert_ok", cr_t_assert_ok)

cr_t_assert_fails = function()
	assert(nil)
	cr_log("not_reached", 1)
end
cr_test("assert_fails", cr_t_assert_fails)

cr_t_error_call = function()
	error("cr raised")
	cr_log("not_reached", 1)
end
cr_test("error_call", cr_t_error_call)

cr_t_call_handler = function()
	CR_HANDLED = nil
	local r = call(cr_t_raiser, { }, "x", cr_t_handler)
	cr_log("result", r, CR_HANDLED)
	cr_log("after", 1)
end
cr_t_raiser = function()
	error("inner")
end
cr_t_handler = function(m)
	CR_HANDLED = m
end
cr_test("call_handler", cr_t_call_handler)

cr_t_collect = function()
	cr_log("type", type(collectgarbage()))
	cr_log("count_type", type(collectgarbage(0)))
end
cr_test("collect", cr_t_collect)

cr_t_script_names = function()
	local id = start_script(cr_t_named_task)
	cr_log("identify_type", type(identify_script(id)))
	cr_log("function_name", FunctionName(cr_t_named_task))
	cr_log("name_of_id", FunctionName(identify_script(id)))
	local n = 0
	local s = next_script(nil)
	while s and n < 100 do
		n = n + 1
		s = next_script(s)
	end
	cr_log("tasks_some", n > 0)
	stop_script(id)
end
cr_t_named_task = function()
	while TRUE do
		break_here()
	end
end
cr_scummvm_differs("script_names", nil, "grim") cr_scummvm_differs("script_names", nil, "emi") cr_test("script_names", cr_t_script_names)

cr_t_misc_engine = function()
	cr_log("tick_type", type(GetTickCount and GetTickCount()))
	cr_log("memory_type", type(GetMemoryUsage()))
	cr_log("disk_type", type(GetDiskFreeSpace()))
	cr_log("just_loaded", JustLoaded())
	cr_log("hw", Is3DHardwareEnabled(), HardwareAccelerated and HardwareAccelerated())
	EnableDebugKeys()
	PrintDebug("CRX a debug line that is not a CR line\n")
	PrintWarning("cr warning\n")
	PrintError("cr error\n")
	cr_log("ok", 1)
end
cr_scummvm_differs("misc_engine", nil, "grim") cr_scummvm_differs("misc_engine", nil, "emi") cr_test("misc_engine", cr_t_misc_engine)

cr_t_file_find = function()
	local f = FileFindFirst("*.set")
	local n = 0
	while f and n < 50 do
		n = n + 1
		f = FileFindNext()
	end
	FileFindDispose()
	cr_log("sets_found", n)
	cr_log("none", FileFindFirst("*.nosuchext"))
	FileFindDispose()
end
cr_test("file_find", cr_t_file_find)
