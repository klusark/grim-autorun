-- More of the interpreter: dostring, call, foreach, tag methods, script handles  -- games: grim emi

cr_t_dostring = function()
	cr_log("value", dostring("return 1 + 2"))
	cr_log("multi", dostring("return 'a', 'b'"))
	CR_X = nil
	dostring("CR_X = 7")
	cr_log("side_effect", CR_X)
end
cr_test("dostring", cr_t_dostring)

cr_t_dostring_bad = function()
	cr_log("bad_syntax", dostring("return +"))
	cr_log("after", 1)
end
cr_test("dostring_bad", cr_t_dostring_bad)

cr_t_call = function()
	cr_log("ok", call(strsub, { "abcdef", 2, 3 }))
	cr_log("packed", type(call(strfind, { "hello", "l" }, "pack")))
end
cr_test("call", cr_t_call)

cr_t_foreach = function()
	local t = { 10, 20, 30; n = 3 }
	CR_SUM = 0
	foreach(t, cr_t_foreach_add)
	cr_log("sum", CR_SUM)
	cr_log("n", t.n, type(t[4]))
end
cr_t_foreach_add = function(k, v)
	if type(v) == "number" then
		CR_SUM = CR_SUM + v
	end
end
cr_test("foreach", cr_t_foreach)

cr_t_tags = function()
	local tg = newtag()
	local t = { }
	settag(t, tg)
	settagmethod(tg, "index", cr_t_tags_index)
	cr_log("index_method", t.missing, t.other)
	t.present = 5
	cr_log("present", t.present)
	cr_log("tag_same", tag(t) == tg)
	cr_log("tag_of_number", tag(1) == tag(2), tag("a") == tag("b"), tag(1) == tag("a"))
end
cr_t_tags_index = function(t, k)
	return "idx:" .. k
end
cr_test("tags", cr_t_tags)

cr_t_scripts = function()
	local id = start_script(cr_t_scripts_wait)
	cr_log("found", find_script(id) ~= nil)
	cr_log("is_number", type(id))
	cr_log("current", type(GetCurrentScript()))
	stop_script(id)
	cr_log("found_after_stop", find_script(id) ~= nil)
	local id2 = start_script(cr_t_scripts_wait)
	stop_script(cr_t_scripts_wait)
	cr_log("stopped_by_function", find_script(id2) ~= nil)
	CR_RAN = 0
	start_script(cr_t_scripts_count)
	start_script(cr_t_scripts_count)
	cr_frames(2)
	cr_log("two_ran", CR_RAN)
end
cr_t_scripts_wait = function()
	while TRUE do
		break_here()
	end
end
cr_t_scripts_count = function()
	CR_RAN = CR_RAN + 1
end
cr_test("scripts", cr_t_scripts)
