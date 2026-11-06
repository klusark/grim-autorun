-- The Lua 3.1 language itself: upvalues, varargs, methods, strings, control flow, operators and their errors  -- games: grim emi

cr_t_upvalues = function()
	local base = 10
	local add = function(x)
		return x + %base
	end
	base = 20
	cr_log("upvalue_frozen", add(1))
	CR_CNT = 0
	local inc = function()
		CR_CNT = CR_CNT + 1
		return CR_CNT
	end
	inc()
	cr_log("global_counter", inc())
end
cr_test("upvalues", cr_t_upvalues)

cr_t_varargs = function()
	cr_log("count", cr_t_va())
	cr_log("count3", cr_t_va(1, nil, 3))
	cr_log("first", cr_t_va_first("a", "b"))
	cr_log("extra_args", cr_t_two(1, 2, 3, 4))
	cr_log("missing_args", cr_t_two(1))
end
cr_t_va = function(...)
	return arg.n
end
cr_t_va_first = function(...)
	return arg[1]
end
cr_t_two = function(a, b)
	return a, b
end
cr_test("varargs", cr_t_varargs)

cr_t_methods = function()
	local obj = { value = 3 }
	obj.get = cr_t_get
	cr_log("method", obj:get())
	cr_log("method_dot", obj.get(obj))
	local o2 = { value = 9, get = cr_t_get }
	cr_log("other", o2:get())
end
cr_t_get = function(self)
	return self.value
end
cr_test("methods", cr_t_methods)

cr_t_string_syntax = function()
	cr_log("escapes", strlen("a\nb\tc\\"), "\65" == "A", strlen("\0"))
	cr_log("quotes", 'single "dq"', "double 'sq'")
	local long = [[line one
line two]]
	cr_log("long", strlen(long), strfind(long, "\n"))
	cr_log("nested_long", strlen([[a [[b]] c]]))
end
cr_scummvm_differs("string_syntax", nil, "grim") cr_test("string_syntax", cr_t_string_syntax)

cr_t_control_flow = function()
	local i = 0
	repeat
		i = i + 1
	until i >= 3
	cr_log("repeat", i)
	local s = ""
	local n = 1
	while n <= 4 do
		if n == 1 then
			s = s .. "one"
		elseif n == 2 then
			s = s .. "two"
		elseif n == 3 then
			s = s .. "three"
		else
			s = s .. "other"
		end
		n = n + 1
	end
	cr_log("elseif", s)
	cr_log("early_return", cr_t_early(1), cr_t_early(5))
end
cr_t_early = function(x)
	if x < 3 then
		return "small"
	end
	return "big"
end
cr_test("control_flow", cr_t_control_flow)

cr_t_logic = function()
	cr_log("and_or", 1 and 2, nil and 2, nil or 3, 4 or 5, nil or nil)
	cr_log("not", not nil, not 1, not 0, not "")
	cr_log("compare_eq", 1 == 1.0, "1" == 1, nil == nil, { } == { })
	cr_log("precedence", 2 + 3 * 4 ^ 2, -2 ^ 2, (1 + 2) .. 3, 1 .. 2 + 3)
	cr_log("multi_assign", cr_t_swap(1, 2))
end
cr_t_swap = function(a, b)
	a, b = b, a
	return a, b
end
cr_test("logic", cr_t_logic)

cr_t_err_concat_nil = function()
	local x = "a" .. nil
	cr_log("not_reached", x)
end
cr_test("err_concat_nil", cr_t_err_concat_nil)

cr_t_err_compare_types = function()
	cr_log("not_reached", 1 < "2")
end
cr_test("err_compare_types", cr_t_err_compare_types)

cr_t_err_call_nil = function()
	CR_NOT_A_FUNCTION()
	cr_log("not_reached", 1)
end
cr_test("err_call_nil", cr_t_err_call_nil)

cr_t_err_arith_string = function()
	cr_log("coerced", "10" + 5, "3" * "4")
	cr_log("not_reached", "abc" + 1)
end
cr_test("err_arith_string", cr_t_err_arith_string)

cr_t_tables = function()
	local t = { 1, 2, 3; x = "a", ["y z"] = "b" }
	cr_log("list", t[1], t[3], t[4])
	cr_log("record", t.x, t["y z"])
	t[1.5] = "f"
	cr_log("float_key", t[1.5], t[3 / 2])
	t["1"] = "s"
	cr_log("string_vs_number", t[1], t["1"])
	local nested = { a = { b = { c = 7 } } }
	cr_log("nested", nested.a.b.c)
	cr_log("getn_style", getn and getn(t))
end
cr_test("tables", cr_t_tables)

cr_t_task_return = function()
	CR_TR = nil
	local id = start_script(cr_t_returner)
	cr_frames(2)
	cr_log("finished", find_script(id) ~= nil, CR_TR)
end
cr_t_returner = function()
	CR_TR = "ran"
	return 5
end
cr_test("task_return", cr_t_task_return)
