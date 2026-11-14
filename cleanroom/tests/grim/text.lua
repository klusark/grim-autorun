-- Fonts and text objects (cr_font.laf: space 4 pixels wide, digits 6, upper case 8, the rest 5; line height 12)

cr_t_font = function()
	CR_FONT = LockFont("cr_font.laf")
	cr_log("font", type(CR_FONT))
	cr_log("again_same", LockFont("cr_font.laf") == CR_FONT)
end
cr_scummvm_differs("font") cr_test("font", cr_t_font)

cr_t_font_missing = function()
	cr_log("missing", LockFont("no_such.laf"))
end
cr_test("font_missing", cr_t_font_missing)

cr_t_font_dims_handle = function()
	local f = cr_fn("GetFontDimensions")
	if f then
		cr_log("dimensions", f(CR_FONT))
	end
end
cr_test("font_dims_handle", cr_t_font_dims_handle)

cr_t_font_dims_name = function()
	local f = cr_fn("GetFontDimensions")
	if f then
		cr_log("dimensions", f("cr_font.laf"))
	end
end
cr_test("font_dims_name", cr_t_font_dims_name)

-- (a text object and its size; widths add the advance of each character)
cr_text_dims = function(key, text, opts)
	local t = MakeTextObject(text, opts)
	if t then
		local w, h = GetTextObjectDimensions(t)
		cr_log(key, w, h)
		KillTextObject(t)
	else
		cr_log(key, nil)
	end
end

cr_t_text_objects = function()
	local white = MakeColor(255, 255, 255)
	cr_text_dims("lower", "abc", { font = CR_FONT, fgcolor = white, x = 10, y = 20 })
	cr_text_dims("upper", "ABC", { font = CR_FONT, fgcolor = white, x = 10, y = 20 })
	cr_text_dims("digits_space", "12 34", { font = CR_FONT, fgcolor = white, x = 10, y = 20 })
	cr_text_dims("empty", "", { font = CR_FONT, fgcolor = white, x = 10, y = 20 })
	cr_text_dims("long", "The quick brown fox jumps over the lazy dog and keeps on running far away", { font = CR_FONT, x = 0, y = 0 })
	cr_text_dims("wrapped", "The quick brown fox jumps over the lazy dog and keeps on running", { font = CR_FONT, x = 0, y = 0, width = 100 })
	cr_text_dims("centered", "Middle", { font = CR_FONT, x = 320, y = 240, center = TRUE })
	cr_text_dims("ljustify", "Left", { font = CR_FONT, x = 320, y = 240, ljustify = TRUE })
	cr_text_dims("localized", "/crt002/", { font = CR_FONT, x = 0, y = 0 })
end
cr_scummvm_differs("text_objects") cr_test("text_objects", cr_t_text_objects)

cr_t_text_no_font = function()
	cr_text_dims("no_font", "abc", { x = 0, y = 0 })
end
cr_scummvm_differs("text_no_font") cr_test("text_no_font", cr_t_text_no_font)

-- characters above 0x7f (accented letters, inverted marks): Text_NextChar reads them unsigned, 0xfe breaks a line like
-- the space (grim-decomp sign-extended them and indexed before the glyph table: the whole-game run crashed in
-- Font_GlyphAdvance on a 0xa1 in ch19)
cr_t_text_high_chars = function()
	local white = MakeColor(255, 255, 255)
	local hi = format("a%cb%c%c", 161, 233, 191)
	cr_text_dims("high", hi, { font = CR_FONT, fgcolor = white, x = 10, y = 20 })
	cr_text_dims("high_only", format("%c%c%c%c", 128, 200, 255, 161), { font = CR_FONT, x = 10, y = 20 })
	cr_text_dims("high_wrapped", hi .. " " .. hi .. " " .. hi .. " " .. hi, { font = CR_FONT, x = 0, y = 0, width = 40 })
	cr_text_dims("high_fe_break", format("abcd%cefgh%cijkl", 254, 254), { font = CR_FONT, x = 0, y = 0, width = 40 })
end
cr_scummvm_differs("text_high_chars") cr_test("text_high_chars", cr_t_text_high_chars)

-- (the same characters drawn: grim-decomp's main build crashed in Glyph_Blit16Clipped at the start of the whole-game run)
cr_t_text_high_drawn = function()
	MakeCurrentSet("cr_flat.set")
	local t = MakeTextObject(format("A%c%c%c%cB", 161, 233, 191, 255), { font = CR_FONT, fgcolor = MakeColor(255, 255, 255), x = 100, y = 100 })
	cr_frames(3)
	cr_snap("high_drawn")
	KillTextObject(t)
	cr_frames(1)
end
cr_scummvm_differs("text_high_drawn") cr_test("text_high_drawn", cr_t_text_high_drawn)

cr_t_text_change = function()
	local t = MakeTextObject("abc", { font = CR_FONT, x = 10, y = 20 })
	ChangeTextObject(t, "abcdef")
	local w, h = GetTextObjectDimensions(t)
	cr_log("longer", w, h)
	ChangeTextObject(t, { x = 50 })
	w, h = GetTextObjectDimensions(t)
	cr_log("moved", w, h)
	cr_log("char_pos", GetTextCharPosition(t, 0), GetTextCharPosition(t, 3))
	KillTextObject(t)
end
cr_test("text_change", cr_t_text_change)

cr_t_text_char_pos_past_end = function()
	local t = MakeTextObject("abc", { font = CR_FONT, x = 10, y = 20 })
	cr_log("past_end", GetTextCharPosition(t, 99))
	KillTextObject(t)
end
cr_test("text_char_pos_past_end", cr_t_text_char_pos_past_end)

cr_t_text_char_pos_killed = function()
	local t = MakeTextObject("abc", { font = CR_FONT, x = 10, y = 20 })
	KillTextObject(t)
	cr_log("killed", GetTextCharPosition(t, 1))
end
cr_scummvm_differs("text_char_pos_killed") cr_test("text_char_pos_killed", cr_t_text_char_pos_killed)

cr_t_blast_print = function()
	BlastText("blasted", { font = CR_FONT, x = 5, y = 5 })
	PrintLine("printed", { font = CR_FONT, x = 5, y = 30 })
	SetEmergencyFont("cr_font.laf")
	SetOffscreenTextPos(320, 0)
	SetOffscreenTextPos(nil, nil)
	cr_frames(1)
	cr_log("ok", 1)
end
cr_test("blast_print", cr_t_blast_print)

-- (SayLine without a voice file: the text is shown for a time that depends on its length and the text speed. The original
-- ends it by real time, not by the game's clock, so with simtime the frame counts vary from run to run (unstable.txt);
-- everything the test changes is put back in cr_t_say_line_restore, which runs as its own test right after it)
cr_t_say_line = function()
	local a = cr_attr_actor("cr_talker")
	SetSayLineDefaults({ font = CR_FONT })
	SetActorTalkColor(a, MakeColor(255, 255, 0))
	SetTextSpeed(7)
	SayLine(a, "/crt001/", { x = 100, y = 100 })
	cr_log("going_at_once", IsMessageGoing())
	local f = 0
	while IsMessageGoing() and f < 600 do
		break_here()
		f = f + 1
	end
	cr_log("frames_short", f)
	SetTextSpeed(1)
	SayLine(a, "/crt002/", { x = 100, y = 100 })
	f = 0
	while IsMessageGoing() and f < 900 do
		break_here()
		f = f + 1
	end
	cr_log("frames_slow", f)
	SayLine(a, "/crt003/", { x = 100, y = 100 })
	cr_frames(2)
	ShutUpActor(a)
	cr_log("after_shut_up", IsMessageGoing())
	cr_frames(1)
	cr_log("next_frame", IsMessageGoing())
	SetTextSpeed(7)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("say_line") cr_test("say_line", cr_t_say_line)

cr_t_say_line_restore = function()
	ShutUpActor(nil)
	ExpireText()
	SetTextSpeed(7)
	cr_frames(1)
	cr_log("speed", GetTextSpeed())
end
cr_test("say_line_restore", cr_t_say_line_restore)

-- the dimensions of a text object that was killed (ScummVM: a text object handle of the pool, no longer there)
cr_t_text_dims_killed = function()
	local t = MakeTextObject("Gone", { font = LockFont("cr_font.laf"), x = 10, y = 10 })
	KillTextObject(t)
	cr_log("killed", GetTextObjectDimensions(t))
	cr_log("after", 1)
end
cr_scummvm_differs("text_dims_killed") cr_test("text_dims_killed", cr_t_text_dims_killed)

-- blank text: the dialog log viewer turns every <BR> line into " " and adds up the heights to lay out
-- the page (ScummVM gave such a text object a height of 0)
cr_t_text_blank = function()
	cr_text_dims("space", " ", { font = CR_FONT, x = 10, y = 20 })
	cr_text_dims("spaces", "   ", { font = CR_FONT, x = 10, y = 20 })
	cr_text_dims("space_ljustify", " ", { font = CR_FONT, x = 10, y = 20, ljustify = TRUE })
	cr_text_dims("space_center", " ", { font = CR_FONT, x = 320, y = 20, center = TRUE })
	cr_text_dims("trailing", "ab  ", { font = CR_FONT, x = 10, y = 20 })
	cr_text_dims("leading", "  ab", { font = CR_FONT, x = 10, y = 20 })
	local t = MakeTextObject(" ", { x = 0, y = 400, font = CR_FONT })
	local w, h = GetTextObjectDimensions(t)
	cr_log("make_space", w, h)
	ChangeTextObject(t, "abc")
	w, h = GetTextObjectDimensions(t)
	cr_log("change_text", w, h)
	ChangeTextObject(t, " ")
	w, h = GetTextObjectDimensions(t)
	cr_log("change_space", w, h)
	ChangeTextObject(t, "")
	w, h = GetTextObjectDimensions(t)
	cr_log("change_empty", w, h)
	KillTextObject(t)
end
cr_scummvm_differs("text_blank") cr_test("text_blank", cr_t_text_blank)
