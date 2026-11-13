-- Sounds of our own (assets.py: cr_tone.wav, 0.5 s, and cr_long.wav, 3 s, 16-bit PCM at 22050 Hz) through iMUSE, as the
-- game's _sfx.lua uses it: ImStartSound(name, priority, group), ImGetParam / ImSetParam / ImFadeParam with the params
-- of the game (IM_SOUND_PLAY_COUNT 256, IM_SOUND_PEND_COUNT 512, IM_SOUND_GROUP 1024, IM_SOUND_PRIORITY 1280,
-- IM_SOUND_VOL 1536, IM_SOUND_PAN 1792), ImStopSound. Frames are 17 ms on both engines.

CR_IM_PLAY = 256
CR_IM_PEND = 512
CR_IM_GROUP = 1024
CR_IM_PRIO = 1280
CR_IM_VOL = 1536
CR_IM_PAN = 1792

-- (the params of a sound as one string)
cr_im = function(name)
	return tostring(ImGetParam(name, CR_IM_PLAY)) .. " " .. tostring(ImGetParam(name, CR_IM_PEND)) .. " " ..
		tostring(ImGetParam(name, CR_IM_GROUP)) .. " " .. tostring(ImGetParam(name, CR_IM_PRIO)) .. " " ..
		tostring(ImGetParam(name, CR_IM_VOL)) .. " " .. tostring(ImGetParam(name, CR_IM_PAN))
end

-- (frames until the sound stops playing, at most max)
cr_im_wait = function(name, max)
	local f = 0
	while f < max and ImGetParam(name, CR_IM_PLAY) > 0 do
		break_here()
		f = f + 1
	end
	return f
end

cr_im_stop_all = function()
	ImStopAllSounds()
	cr_frames(2)
end

-- a sound from start to end
cr_t_sound_play = function()
	cr_im_stop_all()
	cr_log("before", cr_im("cr_tone.wav"))
	local id = ImStartSound("cr_tone.wav", 127, 1)
	cr_log("id", type(id))
	cr_log("at_once", cr_im("cr_tone.wav"))
	cr_frames(1)
	cr_log("next_frame", cr_im("cr_tone.wav"))
	-- (0.5 s: about 30 frames)
	local f = cr_im_wait("cr_tone.wav", 120)
	cr_log("frames", f >= 20 and f <= 45, f)
	cr_log("after", cr_im("cr_tone.wav"))
end
cr_scummvm_differs("sound_play") cr_test("sound_play", cr_t_sound_play)

-- the params set while it plays
cr_t_sound_params = function()
	cr_im_stop_all()
	ImStartSound("cr_long.wav", 64, 1)
	cr_frames(2)
	ImSetParam("cr_long.wav", CR_IM_VOL, 90)
	ImSetParam("cr_long.wav", CR_IM_PAN, 20)
	ImSetParam("cr_long.wav", CR_IM_PRIO, 100)
	cr_frames(1)
	cr_log("set", cr_im("cr_long.wav"))
	ImSetParam("cr_long.wav", CR_IM_VOL, 200)
	ImSetParam("cr_long.wav", CR_IM_PAN, -5)
	cr_frames(1)
	cr_log("out_of_range", cr_im("cr_long.wav"))
	ImSetParam("cr_long.wav", CR_IM_GROUP, 3)
	cr_frames(1)
	cr_log("group", cr_im("cr_long.wav"))
	ImStopSound("cr_long.wav")
	cr_frames(1)
	cr_log("stopped", cr_im("cr_long.wav"))
end
cr_test("sound_params", cr_t_sound_params)

-- a fade of the volume and of the pan over 20 frames (340 ms)
cr_t_sound_fade = function()
	cr_im_stop_all()
	ImStartSound("cr_long.wav", 64, 1)
	ImSetParam("cr_long.wav", CR_IM_VOL, 127)
	cr_frames(2)
	ImFadeParam("cr_long.wav", CR_IM_VOL, 0, 340)
	ImFadeParam("cr_long.wav", CR_IM_PAN, 127, 340)
	local s = ""
	local i = 0
	while i < 25 do
		break_here()
		s = s .. tostring(ImGetParam("cr_long.wav", CR_IM_VOL)) .. "/" .. tostring(ImGetParam("cr_long.wav", CR_IM_PAN)) .. " "
		i = i + 1
	end
	cr_log("trace", s)
	cr_log("after", cr_im("cr_long.wav"))
	ImStopSound("cr_long.wav")
	cr_frames(1)
end
cr_scummvm_differs("sound_fade", "the steps of a fade differ a little between the engines' timers") cr_test("sound_fade", cr_t_sound_fade)

-- the same sound twice: a play count of 2, and one stop for both
cr_t_sound_twice = function()
	cr_im_stop_all()
	ImStartSound("cr_long.wav", 64, 1)
	ImStartSound("cr_long.wav", 64, 1)
	cr_frames(1)
	cr_log("two", cr_im("cr_long.wav"))
	ImStopSound("cr_long.wav")
	cr_frames(1)
	cr_log("stopped", cr_im("cr_long.wav"))
end
cr_test("sound_twice", cr_t_sound_twice)

-- the volume of the groups (ImSetSfxVol and the rest) while a sound plays, and ImPause / ImResume
cr_t_sound_groups = function()
	cr_im_stop_all()
	ImStartSound("cr_long.wav", 64, 1)
	cr_frames(2)
	ImSetSfxVol(50)
	cr_frames(1)
	cr_log("sfx_vol", ImGetSfxVol(), cr_im("cr_long.wav"))
	ImSetSfxVol(127)
	ImPause()
	cr_frames(10)
	cr_log("paused", cr_im("cr_long.wav"))
	ImResume()
	cr_frames(1)
	cr_log("resumed", cr_im("cr_long.wav"))
	ImStopAllSounds()
	cr_frames(1)
	cr_log("all_stopped", cr_im("cr_long.wav"))
end
cr_test("sound_groups", cr_t_sound_groups)

-- a pause long enough for the short sound to end, if the pause does not stop it
cr_t_sound_pause_time = function()
	cr_im_stop_all()
	ImStartSound("cr_tone.wav", 127, 1)
	cr_frames(2)
	ImPause()
	cr_frames(60)
	cr_log("paused_1s", ImGetParam("cr_tone.wav", CR_IM_PLAY))
	ImResume()
	local f = cr_im_wait("cr_tone.wav", 120)
	cr_log("left_after_resume", f > 0, f)
end
cr_scummvm_differs("sound_pause_time") cr_test("sound_pause_time", cr_t_sound_pause_time)

-- the old sound builtins: PlaySound, PlaySoundAt, SetSoundPosition, GetSoundVolume, SetSoundVolume
cr_t_sound_old = function()
	cr_im_stop_all()
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
	cr_log("play", PlaySound("cr_long.wav"))
	cr_frames(2)
	cr_log("playing", IsSoundPlaying("cr_long.wav"))
	SetSoundPosition("cr_long.wav", 1, 0, 0)
	cr_frames(1)
	cr_log("pan_right", cr_im("cr_long.wav"))
	SetSoundPosition("cr_long.wav", -1, 0, 0)
	cr_frames(1)
	cr_log("pan_left", cr_im("cr_long.wav"))
	ImStopSound("cr_long.wav")
	cr_frames(1)
	PlaySoundAt("cr_long.wav", 0, 3, 0)
	cr_frames(2)
	cr_log("at", cr_im("cr_long.wav"))
	ImStopAllSounds()
	cr_frames(1)
	cr_log("stopped", IsSoundPlaying("cr_long.wav"))
end
cr_test("sound_old", cr_t_sound_old)

-- a sound that is not there next to one that is
cr_t_sound_missing_file = function()
	cr_im_stop_all()
	cr_log("start", type(ImStartSound("no_such_sound.wav", 127, 1)))
	cr_frames(1)
	cr_log("params", cr_im("no_such_sound.wav"))
end
cr_test("sound_missing_file", cr_t_sound_missing_file)

-- a sound playing when the game is saved (as zy_save.lua's cr_save, which is defined later)
cr_t_sound_save = function()
	PurgeText()
	cr_im_stop_all()
	ImStartSound("cr_long.wav", 64, 1)
	ImSetParam("cr_long.wav", CR_IM_VOL, 77)
	cr_frames(5)
	WriteRegistryValue("CrSavePass", "saving")
	RenderModeUser(TRUE)
	Save("crsound.gsv")
	cr_frames(3)
	RenderModeUser(nil)
	if ReadRegistryValue("CrSavePass") == "saving" then
		WriteRegistryValue("CrSavePass", "loading")
		ImStopAllSounds()
		cr_frames(2)
		cr_log("stopped", cr_im("cr_long.wav"))
		Load("crsound.gsv")
		cr_frames(10)
		cr_log("not_loaded", 1)
	else
		WriteRegistryValue("CrSavePass", "done")
		cr_frames(1)
		cr_log("loaded", cr_im("cr_long.wav"))
		ImStopAllSounds()
		cr_frames(1)
	end
end
cr_test("sound_save", cr_t_sound_save)
