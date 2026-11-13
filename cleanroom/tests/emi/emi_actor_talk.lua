-- EMI's talk chores (SetActorTalkChore(actor, index, chore, costume), SetActorMumblechore) with cr_lv.cos: the lip
-- shapes are "short" (CR_LV 10, then 11), the mumble "loop" (20, 21); "endless" (30) keeps the costume on the actor.
-- crtv01 has a voice and a lip sync file, crtv02 a voice only (emi_sound.lua). A line with a place of its own
-- (SayLine's table: x, y from -1 to 1), and a talk chore index out of range. No pictures of the screen on EMI's
-- original: CR_LV, IsMessageGoing and the chores are what is compared.

eatk_talker = function()
	local a = cr_ea_actor("cr_flat.set")
	CR_LV = 0
	PlayActorChore(a, "endless", "cr_lv.cos", 1)
	cr_frames(2)
	local i = 1
	while i < 10 do
		SetActorTalkChore(a, i, "short", "cr_lv.cos")
		i = i + 1
	end
	SetActorMumblechore(a, "loop", "cr_lv.cos")
	SetSayLineDefaults({ font = "cr_font.laf" })
	CR_LV = 0
	return a
end

eatk_done = function(a)
	ShutUpActor(a)
	cr_frames(2)
	StopActorChores(a)
	cr_frames(1)
	PutActorInSet(a, nil)
	ExpireText()
	cr_frames(1)
end

-- (a line: CR_LV and IsMessageGoing at once and over 6 frames)
eatk_line = function(id, opts)
	local a = eatk_talker()
	if opts then
		SayLine(a, "/" .. id .. "/", opts)
	else
		SayLine(a, "/" .. id .. "/")
	end
	cr_log("at_once", CR_LV, IsMessageGoing())
	local s = ""
	local f = 0
	while f < 6 do
		break_here()
		s = s .. tostring(CR_LV) .. " "
		f = f + 1
	end
	cr_log("trace", s)
	cr_log("going", IsMessageGoing())
	eatk_done(a)
end

-- a lip-synced line with talk chores: the shapes play
cr_scummvm_differs("eatk_lip") cr_test("eatk_lip", function() eatk_line("crtv01") end)

-- a line without lip sync: the mumble
cr_test("eatk_mumble", function() eatk_line("crtv02") end)

-- lines with a place on the screen
cr_test("eatk_xy", function() eatk_line("crtv02", { x = 0.5, y = -0.5 }) end)
cr_test("eatk_x_only", function() eatk_line("crtv02", { x = -0.25 }) end)

-- talk chore indexes 15 and 16 (ScummVM: 15 is past its ten talk chores, 16 refused at once), and -1
cr_scummvm_differs("eatk_talk_range") cr_test("eatk_talk_range", function()
	local a = eatk_talker()
	cr_log("set15", SetActorTalkChore(a, 15, "keys", "cr_lv.cos"))
	cr_log("set16", SetActorTalkChore(a, 16, "keys", "cr_lv.cos"))
	cr_log("set_neg", SetActorTalkChore(a, -1, "keys", "cr_lv.cos"))
	cr_frames(1)
	SayLine(a, "/crtv02/")
	cr_frames(3)
	cr_log("line", CR_LV, IsMessageGoing())
	eatk_done(a)
end)
