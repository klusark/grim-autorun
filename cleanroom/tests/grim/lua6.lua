-- Lua 3.1 of the game's LUA.DLL, the parts the other Lua tests leave out: format's conversions (str_format; %q is
-- luaI_addquoted), tonumber with a base, the character classes of patterns (matchclass), gsub's replacement strings (add_s),
-- the fallbacks of setfallback (luaT_setfallback) and the tag methods of globals and tables (luaV_getglobal / setglobal /
-- gettable / settable), setlocale's categories, deep calls (luaD_checkstack). Everything changed is put back.

cr_t_lua6_format = function()
	cr_log("char", format("%c%c%c", 71, 114, 105))
	cr_log("width", format("[%5d][%-5d][%05d][%+d]", 42, 42, 42, 42))
	cr_log("octal_hex", format("%o %x %X %#x", 511, 255, 255, 255))
	cr_log("exp", format("%e|%.3e|%E", 12345.678, 0.000123, 1e20))
	cr_log("fixed", format("%10.2f|%-10.1f|%.0f", 3.14159, 2.5, 2.5))
	cr_log("general", format("%g|%g|%g|%G", 100000, 1e7, 0.0001, 1e-10))
	cr_log("string", format("[%s][%10s][%-6s][%.2s]", "abc", "right", "left", "cut"))
	cr_log("percent", format("100%% %s", "done"))
	cr_log("quoted", format("%q", "a \"quoted\" line\nand a \\ backslash"))
	cr_log("quoted_plain", format("%q", "plain"))
	cr_log("many", format("%d %s %d %s %d", 1, "two", 3, "four", 5))
	cr_log("number_as_string", format("%s", 12.5))
	cr_log("string_as_number", format("%d", "17"))
end
cr_test("lua6_format", cr_t_lua6_format)

cr_t_lua6_tonumber_base = function()
	cr_log("hex", tonumber("ff", 16), tonumber("FF", 16), tonumber("7fffffff", 16))
	cr_log("octal", tonumber("777", 8), tonumber("19", 8))
	cr_log("binary", tonumber("101", 2), tonumber("102", 2))
	cr_log("base36", tonumber("z", 36), tonumber("Zz", 36))
	cr_log("base10", tonumber("123", 10), tonumber("12a", 10))
	cr_log("spaces", tonumber("  ff  ", 16), tonumber("f f", 16))
	cr_log("empty", tonumber("", 16))
	cr_log("number_base", tonumber(10, 16))
end
cr_test("lua6_tonumber_base", cr_t_lua6_tonumber_base)

-- where the first character of each class is in a string with one of everything
cr_t_lua6_classes = function()
	local s = "ab C9 ,;\t_xyZ\1"
	local classes = { "%a", "%c", "%d", "%l", "%p", "%s", "%u", "%w", "%x",
	                  "%A", "%C", "%D", "%L", "%P", "%S", "%U", "%W", "%X",
	                  "[%a_]", "[^%a]", "[a-c]", "[%d%s]", "[^%w%s]", "%.", "%%" }
	local i = 1
	while classes[i] do
		cr_log("find_" .. i, strfind(s, classes[i]))
		i = i + 1
	end
	cr_log("all_digits", gsub("a1b22c333", "%d%d*", "#"))
	cr_log("all_upper", gsub("aBcDeF", "%u", "_"))
	cr_log("not_space", gsub("a b\tc\nd", "%S", "x"))
	cr_log("anchored", strfind("  word", "^%s*(%w+)"))
	cr_log("optional", strfind("color colour", "colou?r", 3))
	cr_log("minimal", strfind("<a><b>", "<(.-)>"))
	cr_log("balanced_like", strfind("f(a(b)c)", "%((.*)%)"))
end
cr_test("lua6_classes", cr_t_lua6_classes)

cr_lua6_upper = function(c)
	return strupper(c)
end
cr_lua6_none = function(c)
	return nil
end

cr_t_lua6_gsub_repl = function()
	cr_log("captures", gsub("hello world", "(%w*) (%w*)", "%2 %1"))
	cr_log("percent", gsub("50", "(%d*)", "%1%%"))
	cr_log("function", gsub("one two", "%w+", cr_lua6_upper))
	cr_log("function_nil", gsub("one two", "%w+", cr_lua6_none))
	cr_log("limit", gsub("aaaa", "a", "b", 3))
	cr_log("limit_zero", gsub("aaaa", "a", "b", 0))
	cr_log("empty_match", gsub("abc", "x*", "-"))
	cr_log("nested", gsub("key=val; k2=v2", "(%w*)=(%w*)", "%2=%1"))
end
cr_test("lua6_gsub_repl", cr_t_lua6_gsub_repl)

-- (%0 is not a capture in Lua 3.1: an error)
cr_t_lua6_gsub_whole = function()
	cr_log("whole", gsub("abc", "%w", "<%0>"))
end
cr_test("lua6_gsub_whole", cr_t_lua6_gsub_whole)

-- each fallback set, triggered, put back (setfallback returns the old one)
cr_lua6_fb_arith = function(a, b, op)
	return "arith:" .. tostring(op)
end
cr_lua6_fb_order = function(a, b, op)
	return 1
end
cr_lua6_fb_concat = function(a, b)
	return "concat"
end
cr_lua6_fb_gettable = function(t, k)
	return "gettable:" .. tostring(k)
end
cr_lua6_fb_settable = function(t, k, v)
	CR_LUA6_SET = tostring(k) .. "=" .. tostring(v)
end
cr_lua6_fb_getglobal = function(name)
	return "global:" .. name
end

-- (one test each: a fallback that loops stops only its own test)
cr_lua6_fb = function(name, fn, trigger)
	cr_test("lua6_fallback_" .. name, function()
		local old = setfallback(%name, %fn)
		cr_log("old", type(old))
		cr_log("result", %trigger())
		setfallback(%name, old)
		cr_log("put_back", 1)
	end)
end
cr_lua6_fb("arith", cr_lua6_fb_arith, function() return { } + 1 end)
cr_lua6_fb("order", cr_lua6_fb_order, function() return { } < { } end)
cr_lua6_fb("concat", cr_lua6_fb_concat, function() return { } .. "x" end)
cr_lua6_fb("gettable", cr_lua6_fb_gettable, function() local n = 5 return n.field end)
cr_lua6_fb("settable", cr_lua6_fb_settable, function() local n = 5 n.field = 7 return CR_LUA6_SET end)
-- (no "function" fallback: calling a number with it set hangs the rebuilt exe, from Lua code and through call() alike, and the
-- original's luaD_call looks the same (README, "Added on Linux"); to be tried on the original first)
cr_lua6_fb("getglobal", cr_lua6_fb_getglobal, function() return cr_lua6_no_such_global end)

-- tag methods of tables with a tag of their own, and of globals
cr_lua6_tm_gettable = function(t, k)
	return "tm_get:" .. k
end
cr_lua6_tm_settable = function(t, k, v)
	rawsettable(t, k, v * 10)
end
cr_lua6_tm_setglobal = function(name, old, new)
	CR_LUA6_SG = name .. ":" .. type(old) .. "->" .. tostring(new)
	rawsetglobal(name, new)
end
cr_lua6_tm_getglobal = function(name, value)
	return "tm_global:" .. name
end

cr_t_lua6_tag_methods = function()
	local tg = newtag()
	local t = { a = 1 }
	settag(t, tg)
	settagmethod(tg, "gettable", cr_lua6_tm_gettable)
	cr_log("gettable", t.a, t.b)
	settagmethod(tg, "gettable", nil)
	settagmethod(tg, "settable", cr_lua6_tm_settable)
	t.c = 4
	cr_log("settable", rawgettable(t, "c"))
	settagmethod(tg, "settable", nil)
	CR_LUA6_G = t
	settagmethod(tg, "setglobal", cr_lua6_tm_setglobal)
	CR_LUA6_G = 3
	cr_log("setglobal", CR_LUA6_SG, CR_LUA6_G)
	settagmethod(tg, "setglobal", nil)
	CR_LUA6_G = t
	settagmethod(tg, "getglobal", cr_lua6_tm_getglobal)
	cr_log("getglobal", CR_LUA6_G)
	settagmethod(tg, "getglobal", nil)
	cr_log("getglobal_off", type(CR_LUA6_G))
	settagmethod(tag(nil), "getglobal", cr_lua6_tm_getglobal)
	cr_log("getglobal_nil", cr_lua6_undefined_one)
	settagmethod(tag(nil), "getglobal", nil)
	cr_log("getglobal_nil_off", cr_lua6_undefined_one)
	CR_LUA6_G = nil
end
cr_test("lua6_tag_methods", cr_t_lua6_tag_methods)

cr_t_lua6_setlocale = function()
	cr_log("all", setlocale("C"))
	-- (the category is a number: 0 all, 1 collate, 2 ctype, 3 monetary, 4 numeric, 5 time; 6 is none)
	local i = 0
	while i <= 6 do
		cr_log("category_" .. i, setlocale("C", i))
		i = i + 1
	end
	cr_log("unknown_locale", setlocale("cr_no_such_locale"))
	cr_log("again", setlocale("C"))
end
cr_test("lua6_setlocale", cr_t_lua6_setlocale)

-- deep recursion with many arguments and locals: the stack grows (luaD_checkstack)
cr_lua6_deep = function(n, a, b, c, d, e, f, g, h)
	local x1, x2, x3, x4, x5, x6, x7, x8 = a, b, c, d, e, f, g, h
	if n == 0 then
		return x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8
	end
	return cr_lua6_deep(n - 1, b, c, d, e, f, g, h, a + 1)
end

cr_t_lua6_deep = function()
	cr_log("depth_50", cr_lua6_deep(50, 1, 2, 3, 4, 5, 6, 7, 8))
	cr_log("depth_150", cr_lua6_deep(150, 1, 2, 3, 4, 5, 6, 7, 8))
	local t = { }
	local i = 1
	while i <= 200 do
		t[i] = i
		i = i + 1
	end
	cr_log("unpacked", call(tostring, t))
	cr_log("strrep", strlen(strrep("ab", 5000)))
end
cr_test("lua6_deep", cr_t_lua6_deep)
