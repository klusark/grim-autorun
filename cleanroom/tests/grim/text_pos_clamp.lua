-- How SayLine keeps its text inside the screen (ScummVM bug 11790), seen on a picture of the screen (cr_snap: the box of
-- the white text, x0 y0 x1 y1). The text is put at the off-screen position (SetOffscreenTextPos, an actor in no set),
-- which both engines take as it is. On the original, Actor_CreateSubtitle (0x48b2e0):
--   - measures the text before its x is set, in a copy of the say line defaults: at their x (0 unless SetSayLineDefaults
--     gives one) and with their justification (centred unless it gives one); centred at x = 0 the text is broken at a
--     width of 2 * min(0, 640) = 0, every word is a line of its own and the width is that of the widest word (the
--     spaces of a run but the first lead the word after them);
--   - keeps x - width / 2 at least 40 pixels from the left of the screen and x + width / 2 40 from the right;
--   - keeps the top of the text 10 pixels from the top of the screen and its bottom 10 from the bottom;
--   - lays the text out on the whole screen: SetSayLineDefaults' width and height go to a clip rectangle that the
--     defaults do not have (the pointer is null), so they change nothing.
-- cr_font.laf: a space advances 5 pixels, a digit 7, a capital 9, any other character 6; a line is 12 pixels high.

cr_tc_say = function(key, msg, x, y, defaults)
	SetSayLineDefaults({ font = LockFont("cr_font.laf") })
	if defaults then
		SetSayLineDefaults(defaults)
	end
	SetTextSpeed(1)
	SetOffscreenTextPos(x, y)
	local a = LoadActor("cr_tc_a")
	SetActorTalkColor(a, MakeColor(255, 255, 255))
	SayLine(a, msg)
	cr_frames(3)
	cr_log(key .. "_going", IsMessageGoing())
	cr_snap(key .. "_text")
	cr_frames(3)
	ShutUpActor(a)
	cr_frames(2)
	SetOffscreenTextPos(nil, nil)
end

-- (the say line defaults back as the other tests expect them: centred, x 0, y 0, the width and height of the screen)
cr_tc_reset = function()
	SetSayLineDefaults({ font = LockFont("cr_font.laf"), center = TRUE, x = 0, y = 0, width = 0, height = 0 })
end

cr_tc_test = function(name, fn)
	cr_test("tc_" .. name, function()
		MakeCurrentSet("cr_flat.set")
		cr_frames(2)
		%fn(%name)
		cr_tc_reset()
		SetTextSpeed(7)
	end)
end

-- (a number in a test name: m for minus)
cr_tc_num = function(v)
	if v < 0 then
		return "m" .. -v
	end
	return "" .. v
end

-- every text at x from off the left of the screen to off its right, 300 pixels down
local msgs = {
	{ "one", "/crt001/" },
	{ "punct", "/crt002/" },
	{ "long", "/crt004/" },
	{ "word", "/crt005/" },
	{ "spaces", "/crt006/" },
	{ "narrow", "/crt008/" },
	{ "lead", "/crt009/" },
}
local xs = { -100, 0, 20, 40, 56, 64, 100, 320, 540, 576, 600, 620, 640, 800 }
local m = 1
while msgs[m] do
	local i = 1
	while xs[i] do
		local name = msgs[m][1] .. "_x" .. cr_tc_num(xs[i])
		cr_tc_test(name, function(k)
			cr_tc_say(k, %msgs[%m][2], %xs[%i], 300)
		end)
		i = i + 1
	end
	m = m + 1
end

-- the top and the bottom: one line and several, at the middle and at the edges
local ys = { -50, 0, 5, 10, 22, 30, 300, 460, 470, 480, 600 }
local i = 1
while ys[i] do
	cr_tc_test("one_y" .. cr_tc_num(ys[i]), function(k)
		cr_tc_say(k, "/crt001/", 320, %ys[%i])
	end)
	cr_tc_test("narrow_y" .. cr_tc_num(ys[i]), function(k)
		cr_tc_say(k, "/crt008/", 0, %ys[%i])
	end)
	i = i + 1
end

-- SetSayLineDefaults' width and height: narrower and wider than the screen, at the left, the middle and the right
local sizes = {
	{ "w200", { width = 200 } },
	{ "w400", { width = 400 } },
	{ "w1000", { width = 1000 } },
	{ "h100", { height = 100 } },
	{ "w200h100", { width = 200, height = 100 } },
}
local places = { { "left", 0, 300 }, { "mid", 320, 300 }, { "right", 640, 300 }, { "bottom", 320, 480 } }
local s = 1
while sizes[s] do
	local p = 1
	while places[p] do
		cr_tc_test("punct_" .. sizes[s][1] .. "_" .. places[p][1], function(k)
			cr_tc_say(k, "/crt002/", %places[%p][2], %places[%p][3], %sizes[%s][2])
		end)
		cr_tc_test("long_" .. sizes[s][1] .. "_" .. places[p][1], function(k)
			cr_tc_say(k, "/crt004/", %places[%p][2], %places[%p][3], %sizes[%s][2])
		end)
		p = p + 1
	end
	s = s + 1
end

-- SetSayLineDefaults' x and y: the text is measured at that x (a wider measure keeps it further from the edges)
local defx = { 100, 320, 600 }
local d = 1
while defx[d] do
	local p = 1
	while places[p] do
		cr_tc_test("one_dx" .. defx[d] .. "_" .. places[p][1], function(k)
			cr_tc_say(k, "/crt001/", %places[%p][2], %places[%p][3], { x = %defx[%d] })
		end)
		cr_tc_test("narrow_dx" .. defx[d] .. "_" .. places[p][1], function(k)
			cr_tc_say(k, "/crt008/", %places[%p][2], %places[%p][3], { x = %defx[%d] })
		end)
		p = p + 1
	end
	d = d + 1
end
cr_tc_test("one_dy200_mid", function(k)
	cr_tc_say(k, "/crt001/", 320, 300, { y = 200 })
end)

-- SetSayLineDefaults' justification: measured and laid out left or right justified
local justs = { { "ljust", { ljustify = TRUE } }, { "rjust", { rjustify = TRUE } } }
local j = 1
while justs[j] do
	local p = 1
	while places[p] do
		cr_tc_test("punct_" .. justs[j][1] .. "_" .. places[p][1], function(k)
			cr_tc_say(k, "/crt002/", %places[%p][2], %places[%p][3], %justs[%j][2])
		end)
		cr_tc_test("narrow_" .. justs[j][1] .. "_" .. places[p][1], function(k)
			cr_tc_say(k, "/crt008/", %places[%p][2], %places[%p][3], %justs[%j][2])
		end)
		p = p + 1
	end
	j = j + 1
end

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("tc_lead_x0")
cr_scummvm_differs("tc_lead_x20")
cr_scummvm_differs("tc_lead_x40")
cr_scummvm_differs("tc_lead_x56")
cr_scummvm_differs("tc_lead_x576")
cr_scummvm_differs("tc_lead_x600")
cr_scummvm_differs("tc_lead_x620")
cr_scummvm_differs("tc_lead_x64")
cr_scummvm_differs("tc_lead_x640")
cr_scummvm_differs("tc_lead_x800")
cr_scummvm_differs("tc_lead_xm100")
cr_scummvm_differs("tc_long_h100_bottom")
cr_scummvm_differs("tc_long_h100_left")
cr_scummvm_differs("tc_long_h100_right")
cr_scummvm_differs("tc_long_w1000_bottom")
cr_scummvm_differs("tc_long_w1000_left")
cr_scummvm_differs("tc_long_w1000_right")
cr_scummvm_differs("tc_long_w200_bottom")
cr_scummvm_differs("tc_long_w200_left")
cr_scummvm_differs("tc_long_w200_right")
cr_scummvm_differs("tc_long_w200h100_bottom")
cr_scummvm_differs("tc_long_w200h100_left")
cr_scummvm_differs("tc_long_w200h100_right")
cr_scummvm_differs("tc_long_w400_bottom")
cr_scummvm_differs("tc_long_w400_left")
cr_scummvm_differs("tc_long_w400_right")
cr_scummvm_differs("tc_long_x0")
cr_scummvm_differs("tc_long_x100")
cr_scummvm_differs("tc_long_x20")
cr_scummvm_differs("tc_long_x40")
cr_scummvm_differs("tc_long_x540")
cr_scummvm_differs("tc_long_x56")
cr_scummvm_differs("tc_long_x576")
cr_scummvm_differs("tc_long_x600")
cr_scummvm_differs("tc_long_x620")
cr_scummvm_differs("tc_long_x64")
cr_scummvm_differs("tc_long_x640")
cr_scummvm_differs("tc_long_x800")
cr_scummvm_differs("tc_long_xm100")
cr_scummvm_differs("tc_narrow_dx100_bottom")
cr_scummvm_differs("tc_narrow_dx100_left")
cr_scummvm_differs("tc_narrow_dx100_right")
cr_scummvm_differs("tc_narrow_dx320_bottom")
cr_scummvm_differs("tc_narrow_dx320_left")
cr_scummvm_differs("tc_narrow_dx320_right")
cr_scummvm_differs("tc_narrow_dx600_bottom")
cr_scummvm_differs("tc_narrow_dx600_left")
cr_scummvm_differs("tc_narrow_dx600_right")
cr_scummvm_differs("tc_narrow_ljust_bottom")
cr_scummvm_differs("tc_narrow_ljust_left")
cr_scummvm_differs("tc_narrow_ljust_right")
cr_scummvm_differs("tc_narrow_rjust_bottom")
cr_scummvm_differs("tc_narrow_rjust_left")
cr_scummvm_differs("tc_narrow_rjust_mid")
cr_scummvm_differs("tc_narrow_rjust_right")
cr_scummvm_differs("tc_narrow_x0")
cr_scummvm_differs("tc_narrow_x100")
cr_scummvm_differs("tc_narrow_x20")
cr_scummvm_differs("tc_narrow_x40")
cr_scummvm_differs("tc_narrow_x540")
cr_scummvm_differs("tc_narrow_x56")
cr_scummvm_differs("tc_narrow_x576")
cr_scummvm_differs("tc_narrow_x600")
cr_scummvm_differs("tc_narrow_x620")
cr_scummvm_differs("tc_narrow_x64")
cr_scummvm_differs("tc_narrow_x640")
cr_scummvm_differs("tc_narrow_x800")
cr_scummvm_differs("tc_narrow_xm100")
cr_scummvm_differs("tc_narrow_y0")
cr_scummvm_differs("tc_narrow_y10")
cr_scummvm_differs("tc_narrow_y22")
cr_scummvm_differs("tc_narrow_y30")
cr_scummvm_differs("tc_narrow_y300")
cr_scummvm_differs("tc_narrow_y460")
cr_scummvm_differs("tc_narrow_y470")
cr_scummvm_differs("tc_narrow_y480")
cr_scummvm_differs("tc_narrow_y5")
cr_scummvm_differs("tc_narrow_y600")
cr_scummvm_differs("tc_narrow_ym50")
cr_scummvm_differs("tc_one_dx100_bottom")
cr_scummvm_differs("tc_one_dx100_left")
cr_scummvm_differs("tc_one_dx100_right")
cr_scummvm_differs("tc_one_dx320_bottom")
cr_scummvm_differs("tc_one_dx320_left")
cr_scummvm_differs("tc_one_dx320_right")
cr_scummvm_differs("tc_one_dx600_bottom")
cr_scummvm_differs("tc_one_dx600_left")
cr_scummvm_differs("tc_one_dx600_right")
cr_scummvm_differs("tc_one_x0")
cr_scummvm_differs("tc_one_x20")
cr_scummvm_differs("tc_one_x40")
cr_scummvm_differs("tc_one_x56")
cr_scummvm_differs("tc_one_x600")
cr_scummvm_differs("tc_one_x620")
cr_scummvm_differs("tc_one_x640")
cr_scummvm_differs("tc_one_x800")
cr_scummvm_differs("tc_one_xm100")
cr_scummvm_differs("tc_one_y0")
cr_scummvm_differs("tc_one_y10")
cr_scummvm_differs("tc_one_y22")
cr_scummvm_differs("tc_one_y480")
cr_scummvm_differs("tc_one_y5")
cr_scummvm_differs("tc_one_y600")
cr_scummvm_differs("tc_one_ym50")
cr_scummvm_differs("tc_punct_h100_bottom")
cr_scummvm_differs("tc_punct_h100_left")
cr_scummvm_differs("tc_punct_h100_right")
cr_scummvm_differs("tc_punct_ljust_bottom")
cr_scummvm_differs("tc_punct_ljust_left")
cr_scummvm_differs("tc_punct_ljust_right")
cr_scummvm_differs("tc_punct_rjust_bottom")
cr_scummvm_differs("tc_punct_rjust_left")
cr_scummvm_differs("tc_punct_rjust_mid")
cr_scummvm_differs("tc_punct_rjust_right")
cr_scummvm_differs("tc_punct_w1000_bottom")
cr_scummvm_differs("tc_punct_w1000_left")
cr_scummvm_differs("tc_punct_w1000_right")
cr_scummvm_differs("tc_punct_w200_bottom")
cr_scummvm_differs("tc_punct_w200_left")
cr_scummvm_differs("tc_punct_w200_right")
cr_scummvm_differs("tc_punct_w200h100_bottom")
cr_scummvm_differs("tc_punct_w200h100_left")
cr_scummvm_differs("tc_punct_w200h100_right")
cr_scummvm_differs("tc_punct_w400_bottom")
cr_scummvm_differs("tc_punct_w400_left")
cr_scummvm_differs("tc_punct_w400_right")
cr_scummvm_differs("tc_punct_x0")
cr_scummvm_differs("tc_punct_x100")
cr_scummvm_differs("tc_punct_x20")
cr_scummvm_differs("tc_punct_x40")
cr_scummvm_differs("tc_punct_x540")
cr_scummvm_differs("tc_punct_x56")
cr_scummvm_differs("tc_punct_x576")
cr_scummvm_differs("tc_punct_x600")
cr_scummvm_differs("tc_punct_x620")
cr_scummvm_differs("tc_punct_x64")
cr_scummvm_differs("tc_punct_x640")
cr_scummvm_differs("tc_punct_x800")
cr_scummvm_differs("tc_punct_xm100")
cr_scummvm_differs("tc_spaces_x0")
cr_scummvm_differs("tc_spaces_x20")
cr_scummvm_differs("tc_spaces_x40")
cr_scummvm_differs("tc_spaces_x56")
cr_scummvm_differs("tc_spaces_x576")
cr_scummvm_differs("tc_spaces_x600")
cr_scummvm_differs("tc_spaces_x620")
cr_scummvm_differs("tc_spaces_x64")
cr_scummvm_differs("tc_spaces_x640")
cr_scummvm_differs("tc_spaces_x800")
cr_scummvm_differs("tc_spaces_xm100")
cr_scummvm_differs("tc_word_x0")
cr_scummvm_differs("tc_word_x100")
cr_scummvm_differs("tc_word_x20")
cr_scummvm_differs("tc_word_x40")
cr_scummvm_differs("tc_word_x540")
cr_scummvm_differs("tc_word_x56")
cr_scummvm_differs("tc_word_x576")
cr_scummvm_differs("tc_word_x600")
cr_scummvm_differs("tc_word_x620")
cr_scummvm_differs("tc_word_x64")
cr_scummvm_differs("tc_word_x640")
cr_scummvm_differs("tc_word_x800")
cr_scummvm_differs("tc_word_xm100")
