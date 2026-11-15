-- The edges of Lua's file library (liolib): a file handle given back to readfrom and writeto, a handle used after it was
-- closed, the standard handles (not written to: on the original a write to _STDOUT or _STDERR hangs the game), read
-- patterns that back up a character, write with several values.
-- (cr_lines.txt: "line1", "line2", "line3"; the scratch files are removed at the end)

cr_t_io_handles = function()
	local h = readfrom("cr_lines.txt")
	cr_log("handle", type(h), tag(h) == tag(_INPUT))
	cr_log("same_again", type(readfrom(h)))
	cr_log("read", read("[a-z]*"))
	readfrom()
	cr_log("closed", call(readfrom, { h }, "x", nil))
	local o = writeto("cr_io_handle.txt")
	cr_log("out", type(o))
	write("a")
	cr_log("out_again", type(writeto(o)))
	write("b")
	writeto()
	readfrom("cr_io_handle.txt")
	cr_log("written", read("[^\n]*"))
	readfrom()
	remove("cr_io_handle.txt")
end
cr_scummvm_differs("io_handles", "readfrom of a handle closed before: nil on the original, ScummVM takes it (its tag is still the file tag, liolib.cpp:177-184)") cr_test("io_handles", cr_t_io_handles)

cr_t_io_std = function()
	cr_log("types", type(_INPUT), type(_OUTPUT), type(_STDIN), type(_STDOUT), type(_STDERR))
	cr_log("same_tag", tag(_STDIN) == tag(_STDOUT), tag(_STDOUT) == tag(_STDERR))
end
cr_test("io_std", cr_t_io_std)

-- a pattern that reads one character too many and puts it back (a single character class at the end, then the next one)
cr_t_io_read_backup = function()
	writeto("cr_io_back.txt")
	write("aab12 xyz\n", "second", 3, "\n")
	writeto()
	readfrom("cr_io_back.txt")
	cr_log("a_then_b", read("a*b"))
	cr_log("digits", read("%d*"))
	cr_log("skip_space", read("{ }[a-z]*"))
	cr_log("newline", strlen(read("\n")))
	cr_log("word_num", read("[a-z]*%d"))
	cr_log("rest", read("[^\n]*"))
	cr_log("eof", read("[^\n]*"))
	readfrom()
	remove("cr_io_back.txt")
end
cr_test("io_read_backup", cr_t_io_read_backup)

cr_t_io_read_errors = function()
	readfrom("cr_lines.txt")
	cr_log("open_brace", call(read, { "{" }, "x", nil))
	cr_log("close_brace", call(read, { "}a" }, "x", nil))
	cr_log("nested", call(read, { "{{a}}" }, "x", nil))
	cr_log("after", read("[a-z0-9]*"))
	readfrom()
end
cr_test("io_read_errors", cr_t_io_read_errors)

-- write's values: numbers (as %g), strings, and what it refuses
cr_t_io_write_values = function()
	writeto("cr_io_vals.txt")
	write(1, " ", 2.5, " ", 1 / 3, " ", -0, " ", 1e20, "\n")
	cr_log("table", call(write, { {} }, "x", nil))
	cr_log("nil", call(write, { nil }, "x", nil))
	writeto()
	readfrom("cr_io_vals.txt")
	cr_log("line", read("[^\n]*"))
	readfrom()
	remove("cr_io_vals.txt")
end
cr_scummvm_differs("io_write_values", "write of 1e20: ScummVM writes two exponent digits (1e+20), the original's MSVC printf three (1e+020)") cr_test("io_write_values", cr_t_io_write_values)
