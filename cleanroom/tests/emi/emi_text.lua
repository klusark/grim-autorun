-- EMI's text objects with a font of ours (assets.FONT, cr_font.laf, in EMI's archive too): a font is named by its file
-- (MakeTextObject's font field); EMI's x and y in the table are fractions of the screen (y: 240 - y * 240 on it).

-- (GetFontDimensions crashes Monkey4.exe, as it does Grim's original: not tested)

cr_test("et_text", function()
	local t = MakeTextObject("Clean room", { font = "cr_font.laf", x = -0.5, y = 0.5 })
	cr_log("type", type(t))
	cr_log("dims", GetTextObjectDimensions(t))
	ChangeTextObject(t, "Other words here", { font = "cr_font.laf" })
	cr_log("changed", GetTextObjectDimensions(t))
	cr_log("char_pos", GetTextCharPosition(t, 3))
	KillTextObject(t)
	local u = MakeTextObject("x", { font = "cr_font.laf", y = 0, fgcolor = MakeColor(255, 255, 255) })
	cr_log("second", GetTextObjectDimensions(u))
	KillTextObject(u)
	ExpireText()
end)

-- blank text (Monkey4.exe 0x433bf0 adds a line height for each line, at least one with a font): ScummVM gave 0
cr_et_dims = function(key, text, opts)
	local t = MakeTextObject(text, opts)
	local w, h = GetTextObjectDimensions(t)
	cr_log(key, w, h)
	KillTextObject(t)
end
cr_scummvm_differs("et_text_blank") cr_test("et_text_blank", function()
	cr_et_dims("word", "x", { font = "cr_font.laf", x = 0, y = 0 })
	cr_et_dims("space", " ", { font = "cr_font.laf", x = 0, y = 0 })
	cr_et_dims("spaces", "   ", { font = "cr_font.laf", x = 0, y = 0 })
	cr_et_dims("empty", "", { font = "cr_font.laf", x = 0, y = 0 })
	cr_et_dims("trailing", "ab  ", { font = "cr_font.laf", x = 0, y = 0 })
	local t = MakeTextObject("abc", { font = "cr_font.laf", x = 0, y = 0 })
	ChangeTextObject(t, " ", { font = "cr_font.laf" })
	local w, h = GetTextObjectDimensions(t)
	cr_log("change_space", w, h)
	KillTextObject(t)
	ExpireText()
end)
