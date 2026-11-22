-- Where EMI puts text on the screen, seen on pictures of it (cr_snap: the box of the white text, x0 y0 x1 y1; EMI's original
-- saves them with -gl, grimlaunch's debuglog and patch.dll). cr_font.laf: a space advances 5 pixels, a digit 7, a capital 9,
-- any other character 6. The background of cr_flat is a dark checker.
-- SayLine (Actor_CreateSayText 0x42c6f0, ScummVM bugs 11790 and 11807): the text is measured before its x is set, at x 0, where
-- every word is a line of its own, and x - width / 2 and x + width / 2 are kept 40 pixels inside the screen; the table's x and
-- y (from -1 to 1) are 320 * (v + 1) both (0x41d470: the width for y too), and y is the top of the text; the top is kept 25
-- pixels from the top and the bottom 25 from the bottom. An actor without a costume has an empty screen rectangle at (0, 0): its
-- line goes to the top left corner, clamped (seen on the original). SetSayLineDefaults' width and height go to the defaults'
-- rectangle (+0x24, +0x28), which
-- Actor_CreateSayText replaces by the screen's. Each line has a voice (crt*.wVC): a SayLine without one crashes Monkey4.exe.

-- (a picture with nothing drawn: the background has no bright pixel)
cr_test("ets_nothing", function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(2)
	cr_snap("text")
end)

-- text objects (MakeTextObject's x and y: x 320 * (v + 1), y 240 - 240 * v)
local objs = {
	{ "centre", { x = 0, y = 0 } },
	{ "left", { x = -1, y = 0.5 } },
	{ "right", { x = 0.9, y = -0.5 } },
	{ "centred", { x = 0, y = 0, center = TRUE } },
	{ "centred_left", { x = -0.95, y = 0, center = TRUE } },
	{ "width", { x = -0.5, y = 0, width = 100 } },
}
local o = 1
while objs[o] do
	cr_test("ets_obj_" .. objs[o][1], function()
		MakeCurrentSet("cr_flat.set")
		cr_frames(2)
		local opts = %objs[%o][2]
		opts.font = "cr_font.laf"
		opts.fgcolor = MakeColor(255, 255, 255)
		local t = MakeTextObject("Clean room text one", opts)
		cr_frames(2)
		cr_snap("text")
		KillTextObject(t)
		cr_frames(1)
	end)
	o = o + 1
end

-- (a line said by an actor without a costume; opts: SayLine's table; defaults: SetSayLineDefaults' more than the font)
cr_ets_say = function(id, opts, defaults)
	local a = cr_ea_actor("cr_flat.set")
	-- (the original starts in speech mode 2, the voice only: 3 shows the text as well)
	local mode = GetSpeechMode()
	SetSpeechMode(3)
	SetActorTalkColor(a, MakeColor(255, 255, 255))
	SetSayLineDefaults({ font = "cr_font.laf" })
	if defaults then
		SetSayLineDefaults(defaults)
	end
	if opts then
		SayLine(a, "/" .. id .. "/", opts)
	else
		SayLine(a, "/" .. id .. "/")
	end
	cr_frames(3)
	cr_log("going", IsMessageGoing())
	cr_snap("text")
	ShutUpActor(a)
	cr_frames(2)
	PutActorInSet(a, nil)
	ExpireText()
	-- (the size of the screen: Actor_CreateSayText puts the screen's rectangle over the defaults' anyway)
	SetSayLineDefaults({ font = "cr_font.laf", width = 640, height = 480 })
	SetSpeechMode(mode)
	cr_frames(1)
end

-- (a number in a test name: m for minus, p for the point)
cr_ets_num = function(v)
	local s = "" .. v
	if v < 0 then
		s = "m" .. -v
	end
	return gsub(s, "%.", "p")
end

-- without a table: the bottom centre
local ids = { { "one", "crt001" }, { "punct", "crt002" }, { "long", "crt004" }, { "word", "crt005" }, { "narrow", "crt008" } }
local d = 1
while ids[d] do
	cr_test("ets_" .. ids[d][1] .. "_default", function()
		cr_ets_say(%ids[%d][2])
	end)
	d = d + 1
end

-- the table's x across the screen, y at the middle
local xs = { -1, -0.95, -0.9, -0.8, -0.5, 0, 0.5, 0.8, 0.9, 0.95, 1 }
d = 1
while ids[d] do
	local i = 1
	while xs[i] do
		cr_test("ets_" .. ids[d][1] .. "_x" .. cr_ets_num(xs[i]), function()
			cr_ets_say(%ids[%d][2], { x = %xs[%i], y = 0 })
		end)
		i = i + 1
	end
	d = d + 1
end

-- the table's y from the top to the bottom, x at the middle; one line and several (at the left)
local ys = { -1, -0.95, -0.9, -0.5, 0, 0.3, 0.4, 0.45, 0.5 }
local i = 1
while ys[i] do
	cr_test("ets_one_y" .. cr_ets_num(ys[i]), function()
		cr_ets_say("crt001", { x = 0, y = %ys[%i] })
	end)
	cr_test("ets_narrow_y" .. cr_ets_num(ys[i]), function()
		cr_ets_say("crt008", { x = -1, y = %ys[%i] })
	end)
	i = i + 1
end

-- only one of x and y
cr_test("ets_one_x_only", function() cr_ets_say("crt001", { x = 0.5 }) end)
cr_test("ets_one_y_only", function() cr_ets_say("crt001", { y = 0.5 }) end)

-- SetSayLineDefaults' width and height: narrower and wider than the screen, at the left, the middle and the right
local sizes = { { "w200", { width = 200 } }, { "w1000", { width = 1000 } }, { "h100", { height = 100 } } }
local places = { { "left", -1 }, { "mid", 0 }, { "right", 1 } }
local s = 1
while sizes[s] do
	local p = 1
	while places[p] do
		cr_test("ets_punct_" .. sizes[s][1] .. "_" .. places[p][1], function()
			cr_ets_say("crt002", { x = %places[%p][2], y = 0 }, %sizes[%s][2])
		end)
		cr_test("ets_long_" .. sizes[s][1] .. "_" .. places[p][1], function()
			cr_ets_say("crt004", { x = %places[%p][2], y = 0 }, %sizes[%s][2])
		end)
		p = p + 1
	end
	cr_test("ets_one_" .. sizes[s][1] .. "_default", function()
		cr_ets_say("crt001", nil, %sizes[%s][2])
	end)
	s = s + 1
end

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("ets_long_default")
cr_scummvm_differs("ets_long_h100_left")
cr_scummvm_differs("ets_long_h100_mid")
cr_scummvm_differs("ets_long_h100_right")
cr_scummvm_differs("ets_long_w1000_left")
cr_scummvm_differs("ets_long_w1000_mid")
cr_scummvm_differs("ets_long_w1000_right")
cr_scummvm_differs("ets_long_w200_left")
cr_scummvm_differs("ets_long_w200_mid")
cr_scummvm_differs("ets_long_w200_right")
cr_scummvm_differs("ets_long_x0")
cr_scummvm_differs("ets_long_x0p5")
cr_scummvm_differs("ets_long_x0p8")
cr_scummvm_differs("ets_long_x0p9")
cr_scummvm_differs("ets_long_x0p95")
cr_scummvm_differs("ets_long_x1")
cr_scummvm_differs("ets_long_xm0p5")
cr_scummvm_differs("ets_long_xm0p8")
cr_scummvm_differs("ets_long_xm0p9")
cr_scummvm_differs("ets_long_xm0p95")
cr_scummvm_differs("ets_long_xm1")
cr_scummvm_differs("ets_narrow_default")
cr_scummvm_differs("ets_narrow_x0")
cr_scummvm_differs("ets_narrow_x0p5")
cr_scummvm_differs("ets_narrow_x0p8")
cr_scummvm_differs("ets_narrow_x0p9")
cr_scummvm_differs("ets_narrow_x0p95")
cr_scummvm_differs("ets_narrow_x1")
cr_scummvm_differs("ets_narrow_xm0p5")
cr_scummvm_differs("ets_narrow_xm0p8")
cr_scummvm_differs("ets_narrow_xm0p9")
cr_scummvm_differs("ets_narrow_xm0p95")
cr_scummvm_differs("ets_narrow_xm1")
cr_scummvm_differs("ets_narrow_y0")
cr_scummvm_differs("ets_narrow_y0p3")
cr_scummvm_differs("ets_narrow_y0p4")
cr_scummvm_differs("ets_narrow_y0p45")
cr_scummvm_differs("ets_narrow_y0p5")
cr_scummvm_differs("ets_narrow_ym0p5")
cr_scummvm_differs("ets_narrow_ym0p9")
cr_scummvm_differs("ets_narrow_ym0p95")
cr_scummvm_differs("ets_narrow_ym1")
cr_scummvm_differs("ets_obj_centred_left")
cr_scummvm_differs("ets_obj_right")
cr_scummvm_differs("ets_obj_width")
cr_scummvm_differs("ets_one_default")
cr_scummvm_differs("ets_one_h100_default")
cr_scummvm_differs("ets_one_w1000_default")
cr_scummvm_differs("ets_one_w200_default")
cr_scummvm_differs("ets_one_x0")
cr_scummvm_differs("ets_one_x0p5")
cr_scummvm_differs("ets_one_x0p8")
cr_scummvm_differs("ets_one_x0p9")
cr_scummvm_differs("ets_one_x0p95")
cr_scummvm_differs("ets_one_x1")
cr_scummvm_differs("ets_one_x_only")
cr_scummvm_differs("ets_one_xm0p5")
cr_scummvm_differs("ets_one_xm0p8")
cr_scummvm_differs("ets_one_xm0p9")
cr_scummvm_differs("ets_one_xm0p95")
cr_scummvm_differs("ets_one_xm1")
cr_scummvm_differs("ets_one_y0")
cr_scummvm_differs("ets_one_y0p3")
cr_scummvm_differs("ets_one_y0p4")
cr_scummvm_differs("ets_one_y0p45")
cr_scummvm_differs("ets_one_y0p5")
cr_scummvm_differs("ets_one_y_only")
cr_scummvm_differs("ets_one_ym0p5")
cr_scummvm_differs("ets_one_ym0p9")
cr_scummvm_differs("ets_one_ym0p95")
cr_scummvm_differs("ets_one_ym1")
cr_scummvm_differs("ets_punct_default")
cr_scummvm_differs("ets_punct_h100_left")
cr_scummvm_differs("ets_punct_h100_mid")
cr_scummvm_differs("ets_punct_h100_right")
cr_scummvm_differs("ets_punct_w1000_left")
cr_scummvm_differs("ets_punct_w1000_mid")
cr_scummvm_differs("ets_punct_w1000_right")
cr_scummvm_differs("ets_punct_w200_left")
cr_scummvm_differs("ets_punct_w200_mid")
cr_scummvm_differs("ets_punct_w200_right")
cr_scummvm_differs("ets_punct_x0")
cr_scummvm_differs("ets_punct_x0p5")
cr_scummvm_differs("ets_punct_x0p8")
cr_scummvm_differs("ets_punct_x0p9")
cr_scummvm_differs("ets_punct_x0p95")
cr_scummvm_differs("ets_punct_x1")
cr_scummvm_differs("ets_punct_xm0p5")
cr_scummvm_differs("ets_punct_xm0p8")
cr_scummvm_differs("ets_punct_xm0p9")
cr_scummvm_differs("ets_punct_xm0p95")
cr_scummvm_differs("ets_punct_xm1")
cr_scummvm_differs("ets_word_default")
cr_scummvm_differs("ets_word_x0")
cr_scummvm_differs("ets_word_x0p5")
cr_scummvm_differs("ets_word_x0p8")
cr_scummvm_differs("ets_word_x0p9")
cr_scummvm_differs("ets_word_x0p95")
cr_scummvm_differs("ets_word_x1")
cr_scummvm_differs("ets_word_xm0p5")
cr_scummvm_differs("ets_word_xm0p8")
cr_scummvm_differs("ets_word_xm0p9")
cr_scummvm_differs("ets_word_xm0p95")
cr_scummvm_differs("ets_word_xm1")
