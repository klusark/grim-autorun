-- The corners of the Lua 3.1 interpreter that the other tests do not reach: the lexer's pragmas ($if, $ifnot, $else,
-- $end, $debug, $nodebug, $endinput), escapes and number forms; the parser's scope errors; the "wide" opcodes of code
-- longer than 255 bytes; string patterns; read patterns; tags. Each case is a dostring of its own source (what it gives,
-- and CR_P, which the source may set).

-- (dostring of src with CR_P cleared: what it gives and CR_P after it)
cr_ds = function(key, src)
	CR_P = nil
	local r = dostring(src)
	cr_log(key, r, CR_P)
end

cr_lex_test = function(name, cases)
	cr_test("lex_" .. name, function()
		local i = 1
		while %cases[i] do
			cr_ds(%cases[i][1], %cases[i][2])
			i = i + 1
		end
		cr_f, cr_g, CR_P = nil, nil, nil
	end)
end

-- (a newline in Lua source text built here: "\n" in these strings is the newline character)
cr_lex_test("pragma_if", {
	{ "if_1", "$if 1\nCR_P = 1\n$else\nCR_P = 2\n$end\nreturn 'ok'" },
	{ "if_nil", "$if nil\nCR_P = 1\n$else\nCR_P = 2\n$end\nreturn 'ok'" },
	{ "ifnot_nil", "$ifnot nil\nCR_P = 3\n$end\nreturn 'ok'" },
	{ "if_global", "$if cr_ds\nCR_P = 4\n$end\nreturn 'ok'" },
	{ "if_undefined", "$if CR_NO_SUCH_GLOBAL\nCR_P = 5\n$else\nCR_P = 6\n$end\nreturn 'ok'" },
	{ "nested", "$if 1\n$if nil\nCR_P = 7\n$else\nCR_P = 8\n$end\n$end\nreturn 'ok'" },
	{ "skipped_text", "$if nil\nthis is not lua at all (\n$end\nCR_P = 9\nreturn 'ok'" },
	{ "spaces", "$if 1 \t \nCR_P = 10\n$end\nreturn 'ok'" },
})

cr_lex_test("pragma_other", {
	{ "debug", "$debug\nCR_P = 1\n$nodebug\nreturn 'ok'" },
	{ "endinput", "CR_P = 2\n$endinput\nCR_P = 3\nreturn 'not here'" },
	{ "endinput_in_if", "$if 1\nCR_P = 4\n$endinput\nCR_P = 5" },
})

cr_lex_test("pragma_errors", {
	{ "unknown", "$nosuchpragma\nCR_P = 1" },
	{ "unmatched_end", "$end\nCR_P = 2" },
	{ "double_else", "$if 1\n$else\n$else\n$end\nCR_P = 3" },
	{ "no_end", "$if 1\nCR_P = 4\n" },
	{ "no_end_skipped", "$if nil\nCR_P = 5\n" },
	{ "bad_condition", "$if 2\nCR_P = 6\n$end" },
	{ "trailing", "$if 1 x\nCR_P = 7\n$end" },
	{ "long_name", "$" .. strrep("a", 300) .. "\nCR_P = 8" },
})

cr_lex_test("strings", {
	{ "escape_r", "CR_P = strlen('a\\rb')" },
	{ "escape_newline", "CR_P = strlen('a\\\nb')" },
	{ "escapes", "CR_P = strlen('\\a\\b\\f\\n\\t\\v\\\\\\'\\\"')" },
	{ "decimal", "CR_P = strbyte('\\65')" },
	{ "unfinished", "CR_P = 'abc" },
	{ "newline_in_string", "CR_P = 'ab\ncd'" },
	{ "long", "CR_P = [[one\ntwo [[nested]] three]]" },
	{ "long_unfinished", "CR_P = [[one" },
})

cr_lex_test("numbers", {
	{ "point_first", "CR_P = .5" },
	{ "exponent", "CR_P = .5e2 + 1E1 + 2e-1" },
	{ "concat_ambiguous", "CR_P = 1..2" },
	{ "concat_spaced", "CR_P = 1 .. 2" },
	{ "bad_exponent", "CR_P = 1e" },
	{ "tilde", "CR_P = ~1" },
	{ "not_equal", "CR_P = 1 ~= 2" },
	{ "first_line_hash", "# a first line\nCR_P = 3" },
	{ "control_char", "CR_P = 1 \1 2" },
})

-- the parser: scopes and upvalues
cr_lex_test("scopes", {
	{ "outer_local", "local x = 1\nfunction cr_f() return x end\nCR_P = 1" },
	{ "upvalue", "local x = 2\nCR_P = (function() return %x end)()" },
	{ "upvalue_in_main", "local x = 3\nCR_P = %x" },
	{ "upvalue_global", "cr_g = 4\nCR_P = (function() return %cr_g end)()" },
	{ "upvalue_two_up", "local x = 5\nCR_P = (function() return (function() return %x end)() end)()" },
	{ "many_locals", "local a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17,a18,a19,a20,a21,a22,a23,a24,a25,a26,a27,a28,a29,a30,a31,a32,a33,a34,a35,a36 = 1\nCR_P = 6" },
	{ "parse_error_eof", "CR_P = (" },
	{ "method", "local t = { v = 7 }\nfunction t:get() return self.v end\nCR_P = t:get()" },
	{ "method_dotted", "local t = { u = { v = 8 } }\nfunction t.u:get() return self.v end\nCR_P = t.u:get()" },
})

-- code longer than 255 bytes and more than 255 constants: the wide jumps, tables and names
cr_test("lex_wide", function()
	-- (a loop around 120 statements: its jumps are longer than 255 bytes)
	local body = ""
	local i = 1
	while i <= 120 do
		body = body .. "s = s + " .. i .. "\n"
		i = i + 1
	end
	cr_ds("long_loop", "local s = 0\nlocal n = 0\nwhile n < 2 do\n" .. body .. "n = n + 1\nend\nCR_P = s")
	cr_ds("long_if", "local s = 0\nif CR_NONE then\n" .. body .. "else s = -1 end\nCR_P = s")
	cr_ds("long_and", "local s = 0\nlocal t = CR_NONE and (function()\n" .. body .. "end)()\nCR_P = t")
	cr_ds("long_repeat", "local s = 0\nlocal n = 0\nrepeat\n" .. body .. "n = n + 1\nuntil n >= 2\nCR_P = s")
	-- (a table of 300 items, and of 300 named fields)
	local items = ""
	local fields = ""
	i = 1
	while i <= 300 do
		items = items .. i .. ","
		fields = fields .. "f" .. i .. " = " .. i .. ","
		i = i + 1
	end
	cr_ds("list", "local t = {" .. items .. "}\nCR_P = t[1] + t[300]")
	cr_ds("record", "local t = {" .. fields .. "}\nCR_P = t.f1 + t.f300")
	cr_ds("mixed", "local t = {" .. items .. "; " .. fields .. "}\nCR_P = t[300] + t.f300")
	-- (more than 255 names: the last ones are reached through the wide forms)
	local names = ""
	i = 1
	while i <= 300 do
		names = names .. "cr_n" .. i .. " = " .. i .. "\n"
		i = i + 1
	end
	cr_ds("names", names .. "local t = { a = { b = 2 } }\nCR_P = cr_n300 + t.a.b + cr_n1")
	cr_ds("names_method", names .. "local t = { v = 3 }\nfunction t:get() return self.v end\nCR_P = t:get() + cr_n299")
	-- (the 300 globals go again: with all of this state the original's Save and Load of save.lua go wrong)
	i = 1
	while i <= 300 do
		setglobal("cr_n" .. i, nil)
		i = i + 1
	end
	CR_P = nil
end)

-- string patterns
cr_test("lex_patterns", function()
	cr_log("classes", strfind("ab1 ,\1X", "%a%a%d%s%p%c%u"))
	cr_log("negated", strfind("abc 123", "%A+"), strfind("abc", "%W"))
	cr_log("any", strfind("xyz", "x.z"))
	cr_log("set", strfind("hello", "[a-h]+"), strfind("hello", "[^a-h]+"))
	cr_log("set_class", strfind("a1-", "[%d%-]+"))
	cr_log("optional", strfind("color", "colou?r"), strfind("colour", "colou?r"))
	cr_log("star", strfind("aaab", "a*b"), strfind("b", "a-b"))
	cr_log("anchor", strfind("abc", "^b"), strfind("abc", "c$"))
	cr_log("capture", gsub("hello world", "(o)", "[%1]"))
	cr_log("backref", strfind("xyzyz", "(yz)%1"))
	cr_log("balanced", strfind("f(a(b)c)d", "%b()"))
	cr_log("gsub_fn", gsub("abc", "%w", function(c) return strupper(tostring(c)) .. "." end))
	cr_log("gsub_n", gsub("aaa", "a", "b", 2))
	cr_log("plain_find", strfind("a.b", ".", 1, 1))
	cr_log("init", strfind("abcabc", "b", 3))
	cr_log("escape_end", call(strfind, { "abc", "a%" }, "x", nil))
	cr_log("missing_bracket", call(strfind, { "abc", "[ab" }, "x", nil))
	cr_log("unfinished_capture", call(strfind, { "abc", "(a" }, "x", nil))
	cr_log("bad_capture_index", call(strfind, { "abc", "(a)%2" }, "x", nil))
	cr_log("unbalanced", call(gsub, { "abc", "a)", "x" }, "x", nil))
	cr_log("bad_b", call(strfind, { "abc", "%b" }, "x", nil))
end)

-- read patterns of the io library (cr_lines.txt: "line1", "line2", "line3")
cr_scummvm_differs("lex_read", "the original EMI does not open cr_lines.txt (_INPUT is not a file handle); ScummVM does", "emi")
cr_test("lex_read", function()
	if not readfrom then
		cr_log("no_io", 1)
		return
	end
	readfrom("cr_lines.txt")
	cr_log("word", read("[a-z]*"))
	cr_log("digit", read("%d"))
	cr_log("skip", read("{\n}[a-z]*"))
	cr_log("optional", read("x?%d"))
	cr_log("rest_line", read("[^\n]*"))
	cr_log("unbalanced", call(read, { "{a" }, "x", nil))
	readfrom()
end)

-- tags and types
cr_test("lex_tags", function()
	local t = newtag()
	local x = {}
	settag(x, t)
	cr_log("tag", tag(x) == t)
	cr_log("tag_number", call(settag, { 1, t }, "x", nil))
	cr_log("tag_function", tag(print) ~= tag(cr_ds), tag(cr_ds) == tag(function() end))
	cr_log("types", type(print), type(cr_ds), type(nil), type(x))
	cr_log("rawget_number", call(rawgettable, { 1, "a" }, "x", nil))
	cr_log("rawset", rawsettable(x, "a", 1), rawgettable(x, "a"))
	cr_log("error_nil", call(error, { }, "x", nil))
end)

