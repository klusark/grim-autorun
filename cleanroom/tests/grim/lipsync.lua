-- Voices and lip sync (assets.py: crtv01-04). SayLine(a, "/id/") plays "<id>.wav" through iMUSE and reads "<id>.lip";
-- the voice files are MCMP with VIMA blocks, as the game's (formats.mcmp, formats.vima). The talking costume
-- (cr_talk.cos) sets CR_LV at the start of each chore: 100 stop_talk, 1-9 the lip sync shapes, 50 the mumble.
-- The original plays sounds on NULLMUSE.DLL, with no sound driver: a voice does not move on (sound.lua), so only the
-- start of a line is compared (the shape of the first phoneme, the mumble), and ShutUpActor ends it.

cr_talker = function()
	MakeCurrentSet("cr_flat.set")
	local a = LoadActor("cr_voice")
	PutActorInSet(a, "cr_flat.set")
	PutActorAt(a, 0, 0, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, "cr_talk.cos")
	-- (index 1 is stop_talk, 2-10 the shapes 1-9)
	local i = 0
	while i < 10 do
		SetActorTalkChore(a, i + 1, i)
		i = i + 1
	end
	SetActorMumblechore(a, 10)
	SetSayLineDefaults({ font = LockFont("cr_font.laf") })
	CR_LV = 0
	return a
end

-- (a line from its start: CR_LV and IsMessageGoing at once and after 1, 2 and 4 frames, then after ShutUpActor)
cr_voice_line = function(id)
	local a = cr_talker()
	SayLine(a, "/" .. id .. "/", { x = 100, y = 100 })
	cr_log("at_once", CR_LV, IsMessageGoing())
	cr_frames(1)
	cr_log("frame1", CR_LV, IsMessageGoing())
	cr_frames(1)
	cr_log("frame2", CR_LV, IsMessageGoing())
	cr_frames(2)
	cr_log("frame4", CR_LV, IsMessageGoing())
	ShutUpActor(a)
	cr_frames(2)
	cr_log("shut_up", CR_LV, IsMessageGoing())
	PutActorInSet(a, nil)
	ExpireText()
	cr_frames(1)
end

-- a voice with a lip sync file: the first phoneme (d) is shape 2
cr_scummvm_differs("lip_voice", "ScummVM sets stop_talk inside SayLine, the original on the next frame") cr_test("lip_voice", function() cr_voice_line("crtv01") end)

-- a voice without one: the mumble
cr_scummvm_differs("lip_no_file", "ScummVM sets stop_talk inside SayLine, the original on the next frame") cr_test("lip_no_file", function() cr_voice_line("crtv02") end)

-- a lip sync file without a voice
cr_scummvm_differs("lip_no_voice", "ScummVM sets stop_talk inside SayLine, the original on the next frame") cr_test("lip_no_voice", function() cr_voice_line("crtv03") end)

-- a lip sync file of silence only
cr_scummvm_differs("lip_silence", "ScummVM sets stop_talk inside SayLine, the original on the next frame") cr_test("lip_silence", function() cr_voice_line("crtv04") end)

-- a voice as a sound of its own (ImStartSound by name): iMUSE loads its lip sync file too
cr_test("lip_sound", function()
	ImStopAllSounds()
	cr_frames(2)
	local id = ImStartSound("crtv01.wav", 127, 1)
	cr_log("id", type(id))
	cr_frames(2)
	cr_log("params", cr_im("crtv01.wav"))
	ImStopSound("crtv01.wav")
	cr_frames(2)
	cr_log("stopped", cr_im("crtv01.wav"))
end)
