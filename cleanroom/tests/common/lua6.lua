-- More corners of the Lua 3.1 interpreter, picked from the lines the coverage run (scummvm-coverage.yml) found never run
-- in ScummVM's engines/grim/lua: tables keyed by functions, C functions and tasks; arithmetic and indexing on values
-- that are not numbers or tables, with and without tag methods; the opcodes only long or unusual code emits (PUSHSELF,
-- SETTABLE, SETLISTW, ONTJMPW, ONFJMPW, SETLINEW); string library errors; tag errors; foreach that stops; dostring of
-- binary chunks that are not right; the stack overflow; print_stack; the old error fallback.

-- (the error message of a call, through call()'s own error method: CR_EM)
-- (its first line only: a parse error's message goes on with the source)
cr6_err = function(m)
	CR_EM = m
	local i = type(m) == "string" and strfind(m, "\n")
	if i then
		CR_EM = strsub(m, 1, i - 1)
	end
end

-- (key: what f(a) gives, whether it failed, and the error's message)
cr6_try = function(key, f, a)
	CR_EM = nil
	local r = call(f, a or { }, "x", cr6_err)
	cr_log(key, r, CR_EM)
end

-- (key: dostring of src, CR_P after it and the error's message)
cr6_ds = function(key, src)
	CR_P = nil
	CR_EM = nil
	local r = call(dostring, { src }, "x", cr6_err)
	cr_log(key, type(r), CR_P, CR_EM)
end

cr6_id = function(x)
	return x
end

cr6_idle = function()
	while 1 do
		break_here()
	end
end

cr_test("lua6_keys", function()
	local t = { }
	local a = { }
	local b = { }
	local up = 3
	local cl = function() return %up end
	local id = start_script(cr6_idle)
	local id2 = start_script(cr6_idle)
	t[a] = "table a"
	t[b] = "table b"
	t[cr6_id] = "lua function"
	t[cl] = "closure"
	t[strlen] = "c function"
	t[id] = "task"
	cr_log("tables", t[a], t[b], t[{ }])
	cr_log("functions", t[cr6_id], t[cl], t[strlen])
	cr_log("task", t[id], t[id2])
	t[a] = nil
	cr_log("removed", t[a], t[b])
	cr_log("same_function", cr6_id == cr6_id, cl == cl, cl == cr6_id)
	cr_log("same_c_function", strlen == strlen, strlen == strsub)
	cr_log("same_task", id == id, id == id2)
	cr_log("types", type(cl), type(strlen), type(id))
	-- (the addresses and task numbers vary: only what tostring starts with)
	cr_log("tostring", strsub(tostring(cl), 1, 9), strsub(tostring(strlen), 1, 9), strsub(tostring(id), 1, 4))
	stop_script(id)
	stop_script(id2)
end)

-- arithmetic on what is not a number: the error, then the tag methods of a tag of our own
cr6_sub = function(a, b)
	return "sub"
end
cr6_mul = function(a, b)
	return "mul"
end
cr6_div = function(a, b)
	return "div"
end
cr6_unm = function(a, b)
	return "unm"
end

cr_test("lua6_arith", function()
	cr6_ds("sub", "CR_P = { } - 1")
	cr6_ds("mul", "CR_P = 2 * { }")
	cr6_ds("div", "CR_P = 'x' / 2")
	cr6_ds("unm", "CR_P = -{ }")
	cr6_ds("unm_string", "CR_P = -'2'")
	cr6_ds("sub_strings", "CR_P = '5' - '2'")
	CR_TAG = newtag()
	CR_TT = { }
	settag(CR_TT, CR_TAG)
	settagmethod(CR_TAG, "sub", cr6_sub)
	settagmethod(CR_TAG, "mul", cr6_mul)
	settagmethod(CR_TAG, "div", cr6_div)
	settagmethod(CR_TAG, "unm", cr6_unm)
	cr6_ds("tm_sub", "CR_P = CR_TT - 1")
	cr6_ds("tm_mul", "CR_P = 1 * CR_TT")
	cr6_ds("tm_div", "CR_P = CR_TT / CR_TT")
	cr6_ds("tm_unm", "CR_P = -CR_TT")
	CR_TT = nil
end)

-- indexing what is not a table; a "settable" tag method through a multiple assignment
cr6_settable = function(t, k, v)
	CR_SET = (CR_SET or "") .. tostring(k) .. "=" .. tostring(v) .. " "
end

cr_test("lua6_index", function()
	cr6_ds("get_number", "local x = 5\nCR_P = x.y")
	cr6_ds("get_nil", "local x\nCR_P = x[1]")
	cr6_ds("set_number", "local x = 5\nx.y = 1\nCR_P = 1")
	cr6_ds("set_string", "local x = 'abc'\nx[1] = 1\nCR_P = 1")
	CR_TAG2 = newtag()
	CR_TS = { }
	settag(CR_TS, CR_TAG2)
	settagmethod(CR_TAG2, "settable", cr6_settable)
	CR_SET = nil
	cr6_ds("tm_single", "CR_TS.a = 1\nCR_P = rawgettable(CR_TS, 'a')")
	cr_log("tm_single_set", CR_SET)
	CR_SET = nil
	cr6_ds("tm_multiple", "CR_TS[1], CR_TS[2], CR_Q = 10, 20, 30\nCR_P = CR_Q")
	cr_log("tm_multiple_set", CR_SET)
	CR_TS, CR_SET, CR_Q = nil, nil, nil
end)

-- the opcodes the other tests' code does not emit
cr_test("lua6_opcodes", function()
	-- (a method call on a table with few constants: PUSHSELF)
	CR_O = { v = 4 }
	CR_O.get = function(self, n) return self.v + n end
	cr6_ds("method", "CR_P = CR_O:get(3)")
	-- (an assignment of more than one indexed target: SETTABLE)
	cr6_ds("multiple", "local t = { }\nt[1], t[2], t.x = 'a', 'b', 'c'\nCR_P = t[1] .. t[2] .. t.x")
	cr6_ds("swap", "local t = { 1, 2 }\nt[1], t[2] = t[2], t[1]\nCR_P = t[1] * 10 + t[2]")
	-- (a list of more than 255 x 64 items: SETLISTW)
	cr6_ds("long_list", "local t = {" .. strrep("7,", 16400) .. "8}\nCR_P = t[1] + t[16400] + t[16401]")
	-- (an or / and whose right side is more than 255 bytes: ONTJMPW, ONFJMPW)
	cr6_ds("long_or", "CR_P = nil or (" .. strrep("1+", 200) .. "1)")
	cr6_ds("long_or_true", "CR_P = 2 or (" .. strrep("1+", 200) .. "1)")
	cr6_ds("long_and", "CR_P = 3 and (" .. strrep("1+", 200) .. "1)")
	cr6_ds("long_and_nil", "CR_P = 3 and nil and (" .. strrep("1+", 200) .. "1)")
	-- (line numbers past 255 in debug code: SETLINEW)
	cr6_ds("long_lines", "$debug\n" .. strrep("\n", 300) .. "CR_P = 5\n" .. strrep("\n", 300) .. "CR_P = CR_P + 1\n$nodebug")
	CR_O = nil
end)

cr6_upper = function(s)
	return strupper(s)
end
cr6_fail = function(s)
	return { } + 1
end

cr_test("lua6_strings", function()
	cr_log("sub_empty", strsub("abc", 3, 2), strsub("abc", 5), strsub("abc", 0, 9))
	cr6_try("format_wide", format, { "%99999d", 1 })
	cr6_try("format_precise", format, { "%.1000f", 1 })
	cr6_try("format_position", format, { "%1$d", 5 })
	cr6_try("format_bad_option", format, { "%y", 1 })
	cr_log("balance", strfind("(abc", "%b()"), strfind("(a(b)c)", "%b()"))
	cr_log("back_reference", strfind("abab", "(a)%1"), strfind("abaa", "(a)b%1%1"))
	cr6_try("too_many_captures", strfind, { "aaaaaaaaaaaa", "(a)(a)(a)(a)(a)(a)(a)(a)(a)(a)(a)" })
	cr6_try("pattern_ends_in_escape", strfind, { "a%", "a%" })
	cr6_try("gsub_table", gsub, { "abc", "b", { } })
	cr6_try("gsub_function", gsub, { "abc", "(b)", cr6_upper })
	cr6_try("gsub_error", gsub, { "abc", "(b)", cr6_fail })
end)

cr6_any = function(a, b)
	return 1
end

cr_test("lua6_tags", function()
	cr6_try("bad_event", settagmethod, { newtag(), "nosuchevent", cr6_any })
	cr6_try("bad_tag", settagmethod, { 12345, "gettable", cr6_any })
	cr6_try("not_a_new_tag", settag, { { }, 12345 })
	cr6_try("number_tag", settagmethod, { tag(1), "add", cr6_any })
	cr6_try("tag_of_number", settag, { 1, newtag() })
	cr_log("get_bad_event", gettagmethod(tag(1), "gettable"), gettagmethod(tag(1), "add"))
	-- (more tags than the table of tag methods starts with)
	local i = 0
	local last
	while i < 40 do
		last = newtag()
		i = i + 1
	end
	settagmethod(last, "index", cr6_any)
	local t = { }
	settag(t, last)
	cr_log("many_tags", t.nothing, type(gettagmethod(last, "index")))
	local other = newtag()
	copytagmethods(other, last)
	cr_log("copied", type(gettagmethod(other, "index")))
end)

-- foreach and foreachvar stop at the first value the function gives
cr6_count = function(k, v)
	CR_N6 = CR_N6 + 1
	return "stop"
end

cr_test("lua6_foreach_stop", function()
	CR_N6 = 0
	cr_log("foreach", foreach({ a = 1, b = 2, c = 3 }, cr6_count), CR_N6)
	CR_N6 = 0
	cr_log("foreachvar", foreachvar(cr6_count), CR_N6)
	CR_N6 = 0
	cr_log("foreach_empty", foreach({ }, cr6_count), CR_N6)
	cr6_try("dostring_second_argument", dostring, { "CR_P = 1", 1 })
	-- (call without "x": the error of the call goes on)
	CR_EM = nil
	cr_log("call_error", call(call, { cr6_fail, { } }, "x", cr6_err), CR_EM)
	cr_log("call_packed", call(cr6_id, { 4 }, "p").n)
end)

-- dostring of text that starts like a binary chunk (ESC): ScummVM's dostring takes text only
cr_test("lua6_undump", function()
	cr6_ds("bad_signature", "\27Lux")
	cr6_ds("too_new", "\27Lua\127")
	cr6_ds("old", "\27Lua\1")
	cr6_ds("float_size", "\27Lua\49\9")
	cr6_ds("short", "\27Lua\49")
	cr6_ds("only_esc", "\27")
end)

-- files through their handles: readfrom and writeto of a handle, read and write with one, a global _INPUT that is not
-- a file (Grim: the other tests of files are there)
-- (a line of the file read through h, or of _INPUT without h: [^\n]* and then the newline skipped)
cr6_line = function(h)
	local l
	if h then
		l = read(h, "[^\n]*")
		read(h, "{\n}")
	else
		l = read("[^\n]*")
		read("{\n}")
	end
	return l
end

cr_test("lua6_io", function()
	if CR_GAME ~= "grim" then
		return
	end
	local out = writeto("cr_io6.txt")
	cr_log("writeto", type(out))
	write(out, "one\n")
	write("two\n")
	cr_log("writeto_handle", type(writeto(out)))
	write(out, "three\n")
	writeto()
	local inp = readfrom("cr_io6.txt")
	cr_log("readfrom", type(inp))
	cr_log("read_handle", cr6_line(inp), cr6_line())
	cr_log("readfrom_handle", type(readfrom(inp)))
	cr_log("read_after", cr6_line(inp))
	CR_SAVED_INPUT = _INPUT
	_INPUT = 5
	cr6_try("input_not_a_file", read, { "[^\n]*" })
	_INPUT = CR_SAVED_INPUT
	CR_SAVED_INPUT = nil
	readfrom()
	cr_log("removed", type(remove("cr_io6.txt")))
end)

-- a handle used after readfrom() or writeto() closed its file: an error on the original
cr_scummvm_differs("lua6_io_closed", "ScummVM crashes: the handle keeps its id, and the closed file is used")
cr_test("lua6_io_closed", function()
	if CR_GAME ~= "grim" then
		return
	end
	local out = writeto("cr_io6c.txt")
	write("one\n")
	writeto()
	cr6_try("writeto_closed", writeto, { out })
	cr6_try("write_closed", write, { out, "x" })
	local inp = readfrom("cr_io6c.txt")
	readfrom()
	cr6_try("readfrom_closed", readfrom, { inp })
	cr6_try("read_closed", read, { inp, "[^\n]*" })
	readfrom()
	writeto()
	cr_log("removed", type(remove("cr_io6c.txt")))
end)

-- calls without end: the stack overflow
cr6_deep = function(n)
	return cr6_deep(n + 1) + 1
end

cr_test("lua6_stack_overflow", function()
	cr6_try("recursion", cr6_deep, { 1 })
	-- (and the interpreter still runs afterwards)
	cr_log("after", cr6_id(5))
end)

-- print_stack in a function, in a tag method and in a dostring (it writes to stderr; only that it returns is logged)
cr6_stack = function(a, b)
	print_stack()
	return 1
end

cr6_stack_outer = function()
	return cr6_stack()
end

cr_test("lua6_print_stack", function()
	cr_log("function", cr6_stack_outer())
	local tg = newtag()
	settagmethod(tg, "index", cr6_stack)
	local t = { }
	settag(t, tg)
	cr_log("tag_method", t.x)
	cr6_ds("dostring", "$debug\nCR_P = 1\nprint_stack()\nCR_P = 2\n$nodebug")
end)

-- the old error fallback: setfallback("error", f) puts f in place of the error method
cr6_fallback = function(m)
	CR_FB = m
end

cr_test("lua6_fallback", function()
	CR_FB = nil
	local old = setfallback("error", cr6_fallback)
	dostring("CR_P = { } + 1")
	seterrormethod(cr_error)
	cr_log("fallback", CR_FB, type(old))
end)
