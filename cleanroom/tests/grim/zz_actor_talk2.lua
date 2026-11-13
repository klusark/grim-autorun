-- Talking, the corners of Actor::sayLine and the talk chores (ScummVM's actor.cpp): an empty line, a line without a
-- message id, the same line again, ExpireText while a line is shown, a background line beside a foreground one, a line
-- during a fullscreen movie, talk chores out of range, the mumble set again while it plays, IsActorChoring(a, nil) while
-- talk chores play, a costume freed under its talk chores, and an actor looking at another actor's head.
-- The talking costume is lipsync.lua's cr_talk.cos (CR_LV: 100 stop_talk, 1-9 the shapes, 50 the mumble); crtv02 has a
-- voice and no lip sync file (the mumble); crt001 / crt003 have no voice (the text alone, with a duration).

-- (a talker as lipsync.lua's: the talk chores 1-10 = chores 0-9, the mumble chore 10)
atk_talker = function(name, set)
	MakeCurrentSet(set or "cr_flat.set")
	local a = LoadActor(name or "atk_voice")
	PutActorInSet(a, set or "cr_flat.set")
	PutActorAt(a, 0, 0, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, "cr_talk.cos")
	local i = 0
	while i < 10 do
		SetActorTalkChore(a, i + 1, i)
		i = i + 1
	end
	SetActorMumblechore(a, 10)
	SetSayLineDefaults({ font = LockFont("cr_font.laf") })
	SetActorTalkColor(a, MakeColor(255, 255, 255))
	CR_LV = 0
	return a
end

atk_done = function(a)
	ShutUpActor(a)
	cr_frames(2)
	PutActorInSet(a, nil)
	ExpireText()
	cr_frames(1)
end

-- (a line that should not start: CR_LV and IsMessageGoing at once and after 2 frames)
atk_no_line = function(msg)
	local a = atk_talker()
	cr_frames(1)
	CR_LV = 0
	SayLine(a, msg)
	cr_log("at_once", CR_LV, IsMessageGoing(), IsMessageGoing(a))
	cr_frames(2)
	cr_log("frame2", CR_LV, IsMessageGoing(), IsMessageGoing(a))
	cr_snap("text")
	atk_done(a)
end

-- an empty message
cr_scummvm_differs("atk_empty", "ScummVM refuses an empty line (actor.cpp sayLine: Empty message); the original says it (the mumble, IsMessageGoing)") cr_test("atk_empty", function() atk_no_line("") end)

-- a message id without its closing slash
cr_scummvm_differs("atk_no_id", "ScummVM refuses a line without a message id (sayLine: No message ID); the original says it and shows the text") cr_test("atk_no_id", function() atk_no_line("/crtv02") end)

-- a text that does not start with a slash (ScummVM leaves its message id unset: parseMsgText writes it only for "/...")
cr_scummvm_differs("atk_plain", "ScummVM refuses a line without a message id (and leaves the id unset: parseMsgText); the original says it and shows the text") cr_test("atk_plain", function() atk_no_line("plain words") end)

-- the same line again while it is said (ScummVM: nothing happens), then another one
cr_scummvm_differs("atk_same_line") cr_test("atk_same_line", function()
	local a = atk_talker()
	SayLine(a, "/crtv02/", { x = 100, y = 100 })
	cr_frames(3)
	cr_log("first", CR_LV, IsMessageGoing(a), IsActorChoring(a, 10, FALSE))
	CR_LV = 0
	SayLine(a, "/crtv02/", { x = 100, y = 100 })
	cr_log("again_at_once", CR_LV, IsMessageGoing(a))
	cr_frames(1)
	cr_log("again_frame1", CR_LV, IsMessageGoing(a), IsActorChoring(a, 10, FALSE))
	CR_LV = 0
	SayLine(a, "/crtv01/", { x = 100, y = 100 })
	cr_frames(2)
	cr_log("other", CR_LV, IsMessageGoing(a))
	atk_done(a)
end)

-- ExpireText while a line is shown: the text goes, the line?
cr_scummvm_differs("atk_expire", "ScummVM ignores SayLine's x and y in Grim, and ExpireText ends a line without a voice (updateTalk: no text); the original goes on") cr_test("atk_expire", function()
	local a = atk_talker()
	SetActorVisibility(a, FALSE)
	SetTextSpeed(1)
	SayLine(a, "/crt001/", { x = 100, y = 100 })
	cr_frames(3)
	cr_log("before", IsMessageGoing(a))
	cr_snap("shown")
	ExpireText()
	cr_log("at_once", IsMessageGoing(a))
	cr_frames(3)
	cr_log("after", IsMessageGoing(a))
	cr_snap("expired")
	SetTextSpeed(7)
	SetActorVisibility(a, TRUE)
	atk_done(a)
end)

-- (two talkers in cr_open, drawn: a at the left, b at the right)
atk_pair = function()
	local a = atk_talker("atk_a", "cr_open.set")
	PutActorAt(a, -1.5, 0, 0)
	local b = atk_talker("atk_b", "cr_open.set")
	PutActorAt(b, 1.5, 0, 0)
	SetTextSpeed(1)
	cr_frames(2)
	return a, b
end

atk_pair_done = function(a, b)
	ShutUpActor(a)
	ShutUpActor(b)
	cr_frames(2)
	SetTextSpeed(7)
	PutActorInSet(a, nil)
	PutActorInSet(b, nil)
	ExpireText()
	cr_frames(1)
end

-- a foreground line, then another actor's background line: which texts are shown?
cr_scummvm_differs("atk_fg_then_bg", "ScummVM keeps the foreground text and ends the background line at once (no text, no voice); on the original the second line's text replaces the first and both go on; the text 7 pixels higher") cr_test("atk_fg_then_bg", function()
	local a, b = atk_pair()
	SayLine(a, "/crt001/", { volume = 127 })
	cr_frames(3)
	cr_snap("fg")
	SayLine(b, "/crt003/")
	cr_frames(3)
	cr_log("going", IsMessageGoing(a), IsMessageGoing(b))
	cr_snap("both")
	atk_pair_done(a, b)
end)

-- a background line, then another actor's foreground line
cr_scummvm_differs("atk_bg_then_fg", "ScummVM deletes the background text and ends that line at once (no text, no voice); the original goes on; the text 7 pixels higher") cr_test("atk_bg_then_fg", function()
	local a, b = atk_pair()
	SayLine(b, "/crt003/")
	cr_frames(3)
	cr_snap("bg")
	SayLine(a, "/crt001/", { volume = 127 })
	cr_frames(3)
	cr_log("going", IsMessageGoing(a), IsMessageGoing(b))
	cr_snap("both")
	atk_pair_done(a, b)
end)

-- two background lines
cr_scummvm_differs("atk_bg_bg", "the text 7 pixels higher (as tp_spot_bottom_edge)") cr_test("atk_bg_bg", function()
	local a, b = atk_pair()
	SayLine(b, "/crt003/")
	cr_frames(3)
	SayLine(a, "/crt001/")
	cr_frames(3)
	cr_log("going", IsMessageGoing(a), IsMessageGoing(b))
	cr_snap("both")
	atk_pair_done(a, b)
end)

-- a line during a fullscreen movie (the movie's subtitle), and after the movie
cr_scummvm_differs("atk_movie", "ScummVM does not keep a line said during a fullscreen movie as the actor's text and ends it at once; its subtitle at y 456, the original's higher and still shown after the movie") cr_test("atk_movie", function()
	cr_allow_frames(1000000000)
	local a = atk_talker()
	SetTextSpeed(1)
	cr_frames(2)
	StartFullscreenMovie("cr_white.snm")
	cr_wait_s(2)
	SayLine(a, "/crt001/")
	cr_frames(3)
	cr_log("during", IsMessageGoing(), IsMessageGoing(a), IsFullscreenMoviePlaying())
	cr_snap("during")
	StopMovie()
	cr_frames(3)
	cr_log("after_movie", IsMessageGoing(a), IsFullscreenMoviePlaying())
	cr_snap("after_movie")
	SetTextSpeed(7)
	atk_done(a)
end)

-- talk chore indexes out of range (0 and 11), then a line: does anything change?
cr_scummvm_differs("atk_talk_range") cr_test("atk_talk_range", function()
	local a = atk_talker()
	cr_log("set0", SetActorTalkChore(a, 0, 10))
	cr_log("set11", SetActorTalkChore(a, 11, 10))
	cr_frames(1)
	CR_LV = 0
	SayLine(a, "/crtv01/", { x = 100, y = 100 })
	cr_frames(2)
	cr_log("line", CR_LV, IsMessageGoing(a))
	atk_done(a)
end)

-- the mumble chore set again while it plays (ScummVM stops it), and to another chore
cr_scummvm_differs("atk_mumble_reset", "ScummVM stops the mumble when SetActorMumblechore is called while it plays; the original goes on playing it") cr_test("atk_mumble_reset", function()
	local a = atk_talker()
	SayLine(a, "/crtv02/", { x = 100, y = 100 })
	cr_frames(3)
	cr_log("mumbling", CR_LV, IsActorChoring(a, 10, FALSE))
	SetActorMumblechore(a, 10)
	cr_log("reset_at_once", IsActorChoring(a, 10, FALSE))
	CR_LV = 0
	cr_frames(3)
	cr_log("reset", CR_LV, IsActorChoring(a, 10, FALSE), IsMessageGoing(a))
	SetActorMumblechore(a, 5)
	CR_LV = 0
	cr_frames(3)
	cr_log("other", CR_LV, IsActorChoring(a, 10, FALSE), IsActorChoring(a, 5, FALSE))
	atk_done(a)
end)

-- IsActorChoring(a, nil) while the mumble plays, and while a talk chore plays
cr_scummvm_differs("atk_choring_nil", "ScummVM's IsActorChoring(a, nil) skips a chore that is a talk chore even when PlayActorChore played it; the original gives it") cr_test("atk_choring_nil", function()
	local a = atk_talker()
	cr_log("rest", IsActorChoring(a, nil, FALSE))
	SayLine(a, "/crtv02/", { x = 100, y = 100 })
	cr_frames(3)
	cr_log("mumble", IsActorChoring(a, nil, FALSE))
	cr_log("mumble_noloop", IsActorChoring(a, nil, TRUE))
	ShutUpActor(a)
	cr_frames(2)
	PlayActorChore(a, 3)
	cr_log("talk_chore", IsActorChoring(a, nil, FALSE))
	cr_frames(1)
	cr_log("talk_chore_1", IsActorChoring(a, nil, FALSE))
	atk_done(a)
end)

-- the costume taken off and put on again under the talk chores and the mumble: a line after it
cr_test("atk_free_costume", function()
	local a = atk_talker()
	SetActorCostume(a, nil)
	cr_log("costume", type(GetActorCostume(a)))
	SetActorCostume(a, "cr_talk.cos")
	cr_frames(1)
	CR_LV = 0
	SayLine(a, "/crtv02/", { x = 100, y = 100 })
	cr_frames(3)
	cr_log("line", CR_LV, IsMessageGoing(a), IsActorChoring(a, 10, FALSE))
	ShutUpActor(a)
	cr_frames(2)
	cr_log("shut_up", CR_LV)
	atk_done(a)
end)

-- an actor that looks at another actor with a head (cr_head.cos, SetActorHead): where its head turns
atk_look = function(bx, by, bz)
	MakeCurrentSet("cr_open.set")
	local a = LoadActor("atk_la")
	PutActorInSet(a, "cr_open.set")
	PutActorAt(a, 0, 0, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, "cr_head.cos")
	SetActorHead(a, 1, 2, 3, 30, 60, 80)
	local b = LoadActor("atk_lb")
	PutActorInSet(b, "cr_open.set")
	PutActorAt(b, bx, by, bz)
	SetActorRot(b, 0, 90, 0)
	SetActorCostume(b, "cr_head.cos")
	SetActorHead(b, 1, 2, 3, 30, 60, 80)
	cr_frames(2)
	ActorLookAt(a, b, 1000)
	cr_frames(60)
	cr_snap("snap")
	local x, y, z = GetActorNodeLocation(a, 3)
	cr_log("node", x, y, z)
	x, y, z = GetActorNodeLocation(b, 3)
	cr_log("b_node", x, y, z)
	ActorLookAt(a, nil)
	cr_frames(2)
	PutActorInSet(a, nil)
	PutActorInSet(b, nil)
end

cr_scummvm_differs("atk_look_head", "the head turns differently (as head_look_*)") cr_test("atk_look_head", function() atk_look(-1.5, 1.5, 0) end)
cr_scummvm_differs("atk_look_head_up", "the head turns differently (as head_look_*)") cr_test("atk_look_head_up", function() atk_look(1.5, 1.5, 1) end)
