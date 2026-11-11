-- The engine core: a font with kerning, a starting column and outline pixels (assets_extra_gco.py font_kerned), text
-- measured and drawn with it; a font whose code table is not in order (gco_perm.laf); the text object keys
-- the other tests do not give; strings joined with an actor (the concat fallback); lip sync files with an unknown
-- phoneme and with no entries.

gco_ft_dims = function(key, text, opts)
	local t = MakeTextObject(text, opts)
	if t then
		local w, h = GetTextObjectDimensions(t)
		cr_log(key, w, h)
		cr_frames(1)
		cr_snap(key .. "_snap")
		KillTextObject(t)
	else
		cr_log(key, nil)
	end
end

cr_t_gco_font_kerned = function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
	local f = LockFont("gco_font.laf")
	cr_log("font", type(f))
	cr_log("again", LockFont("gco_font.laf") == f)
	local white = MakeColor(255, 255, 255)
	gco_ft_dims("lower", "abc", { font = f, fgcolor = white, x = 100, y = 100 })
	gco_ft_dims("upper", "ABC", { font = f, fgcolor = white, x = 100, y = 100 })
	gco_ft_dims("digits", "123", { font = f, fgcolor = white, x = 100, y = 100 })
	gco_ft_dims("mixed", "Ab 1z", { font = f, fgcolor = white, x = 100, y = 100 })
	gco_ft_dims("tab", "a\tb", { font = f, fgcolor = white, x = 100, y = 100 })
	gco_ft_dims("centered", "Middle", { font = f, fgcolor = white, x = 320, y = 240, center = TRUE })
	gco_ft_dims("rjustify", "Right", { font = f, fgcolor = white, x = 320, y = 240, rjustify = TRUE })
	gco_ft_dims("wrapped", "The quick brown fox jumps over the lazy dog again", { font = f, fgcolor = white, x = 0, y = 0, width = 80 })
end
cr_scummvm_differs("gco_font_kerned", "LockFont twice gives the same font on the original only (as text.lua's font); the text is drawn elsewhere (as text_objects)") cr_test("gco_font_kerned", cr_t_gco_font_kerned)

-- the code table of gco_perm.laf with a, b, c in a cycle: the width of each of them alone
cr_t_gco_font_perm = function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
	local f = LockFont("gco_perm.laf")
	local white = MakeColor(255, 255, 255)
	gco_ft_dims("a", "a", { font = f, fgcolor = white, x = 100, y = 100 })
	gco_ft_dims("b", "b", { font = f, fgcolor = white, x = 100, y = 100 })
	gco_ft_dims("c", "c", { font = f, fgcolor = white, x = 100, y = 100 })
	gco_ft_dims("d", "d", { font = f, fgcolor = white, x = 100, y = 100 })
end
cr_scummvm_differs("gco_font_perm", "the original takes the glyph of character c at the code table's place c, ScummVM looks c up in the table (font.cpp:129-150, the reverse)") cr_test("gco_font_perm", cr_t_gco_font_perm)

-- the text object keys height, bgcolor, fxcolor, duration, layer and coords (ScummVM reads them in setTextObjectParams)
cr_t_gco_text_keys = function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(2)
	local f = LockFont("cr_font.laf")
	local white = MakeColor(255, 255, 255)
	local grey = MakeColor(100, 100, 100)
	gco_ft_dims("height", "abc", { font = f, fgcolor = white, x = 100, y = 100, height = 40 })
	gco_ft_dims("bgcolor", "abc", { font = f, fgcolor = white, bgcolor = grey, x = 100, y = 100 })
	gco_ft_dims("fxcolor", "abc", { font = f, fgcolor = white, fxcolor = grey, x = 100, y = 100 })
	gco_ft_dims("duration", "abc", { font = f, fgcolor = white, x = 100, y = 100, duration = 500 })
	gco_ft_dims("layer", "abc", { font = f, fgcolor = white, x = 100, y = 100, layer = 2 })
	gco_ft_dims("coords", "abc", { font = f, fgcolor = white, x = 100, y = 100, coords = 1 })
	-- (a font that is not a font)
	gco_ft_dims("font_string", "abc", { font = "cr_font.laf", fgcolor = white, x = 100, y = 100 })
end
cr_scummvm_differs("gco_text_keys", "a font given by its file name: the original loads it, ScummVM takes a string only for EMI (lua.cpp:517) and gives no text object") cr_test("gco_text_keys", cr_t_gco_text_keys)

-- a string joined with an actor, nil and a number (the concat fallback); with a table it raises an error (last)
cr_t_gco_concat = function()
	local a = cr_costume_actor()
	local s = "x" .. a
	cr_log("actor_prefix", strsub(s, 1, 7))
	cr_log("actor_len", strlen(s) > 7)
	cr_log("actor_root", strfind(s, ":root") ~= nil)
	local n = "x" .. 12
	cr_log("number", n)
	PutActorInSet(a, nil)
	local t = "x" .. { }
	cr_log("table", t)
end
cr_test("gco_concat", cr_t_gco_concat)

cr_t_gco_concat_nil = function()
	local s = "x" .. nil
	cr_log("nil", s)
end
cr_test("gco_concat_nil", cr_t_gco_concat_nil)

-- lip sync: an unknown phoneme first (gcov01: then d, o), a file of no entries (gcov02); lipsync.lua's cr_voice_line
cr_scummvm_differs("gco_lip_unknown", "ScummVM sets stop_talk inside SayLine, the original on the next frame") cr_test("gco_lip_unknown", function() cr_voice_line("gcov01") end)
cr_scummvm_differs("gco_lip_empty", "a lip sync file of no entries: ScummVM mumbles (lipsync.cpp:44 no entries, then the actor takes the mumble chore), the original plays stop_talk") cr_test("gco_lip_empty", function() cr_voice_line("gcov02") end)

-- the same voice twice in a row, the second while the first still plays (the lip sync file loaded once)
cr_t_gco_lip_twice = function()
	local a = cr_talker()
	SayLine(a, "/gcov01/", { x = 100, y = 100 })
	cr_frames(2)
	cr_log("first", CR_LV, IsMessageGoing())
	SayLine(a, "/gcov01/", { x = 100, y = 120 })
	cr_frames(2)
	cr_log("second", CR_LV, IsMessageGoing())
	ShutUpActor(a)
	cr_frames(2)
	PutActorInSet(a, nil)
	ExpireText()
	cr_frames(1)
end
cr_test("gco_lip_twice", cr_t_gco_lip_twice)
