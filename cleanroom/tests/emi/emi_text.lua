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
