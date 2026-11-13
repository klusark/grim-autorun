-- iMUSE beyond sound.lua and music.lua (assets_extra_ims.py): sounds of other formats (8 bit, stereo, 11 and 44 kHz, a
-- LIST chunk; float, no data, AIFF, raw: refused), iMUS sound effects with maps of their own (a loop, markers and a SYNC
-- block, the other endianness, stereo, 8 and 12 bits; broken maps), the Lua sound ids, the params iMUSE has besides
-- sound.lua's, fades of other params and of no length, more sounds than tracks and than the cache, a costume's sound
-- component (play, stop looping, stop), music states of the same attribute and with hooks, other music formats, a voice
-- over the music, a background voice, saving with music and a sound effect playing.
-- The original runs on NULLMUSE.DLL, with no sound driver: a sound it starts never ends there, and it does not take
-- jumps, so what is logged is the state at once and after frames (which do not move ScummVM's iMUSE much on either);
-- what depends on the real time is marked cr_unstable. CR_IM_* and cr_im are sound.lua's.

IMS_TRACKNUM = 256
-- (assets_extra_ims.py's IMS_MANY: forty small sounds)
IMS_MANY = { }
IMS_CACHE = { }
IMS_I = 1
while IMS_I <= 40 do
	IMS_MANY[IMS_I] = format("ims_m%02d.wav", IMS_I)
	IMS_CACHE[IMS_I] = format("ims_c%02d.wav", IMS_I)
	IMS_I = IMS_I + 1
end
IMS_P = { 0, 512, 768, 1024, 1280, 1536, 1792, 2048, 2304, 2560, 3840, 6144, 6400 }

-- (every param of a sound in IMS_P but the position, as one string)
ims_params = function(name)
	local s = ""
	local i = 1
	while IMS_P[i] do
		s = s .. tostring(ImGetParam(name, IMS_P[i])) .. " "
		i = i + 1
	end
	return s
end

ims_reset = function()
	IMS_BASE = nil
	ImStopAllSounds()
	ImSetSequence(2000)
	ImSetState(1000)
	cr_frames(3)
end

-- (a sound started: its id, its params at once and after two frames, whether it plays; stopped)
ims_start_log = function(key, name, prio, group)
	local id = ImStartSound(name, prio or 100, group or 1)
	-- (the ids count on from the earlier tests' sounds: the first id of the test is the base, 0 is no sound)
	if type(id) == "number" and id > 0 and not IMS_BASE then
		IMS_BASE = id
	end
	if type(id) == "number" and id > 0 then
		cr_log(key .. "_id", type(id), id - IMS_BASE)
	else
		cr_log(key .. "_id", type(id), id)
	end
	cr_log(key .. "_at_once", cr_im(name), IsSoundPlaying(name))
	cr_frames(2)
	cr_log(key .. "_frame2", cr_im(name))
	ImStopSound(name)
	cr_frames(1)
	cr_log(key .. "_stopped", cr_im(name))
	return id
end

-- the sound effects of other formats, each on its own (ims_raw.wav, bytes without a header, crashes the original's
-- iMUSE.dll at +0x1046: left out)
IMS_FORMATS = { "ims_8m.wav", "ims_16s.wav", "ims_8s.wav", "ims_44k.wav", "ims_11k.wav", "ims_list.wav", "ims_float.wav",
	"ims_nodata.wav", "ims_notwave.wav", "ims_tone.aif", "ims_44k.aif", "ims_11k.aif", "ims_aifc.aif", "ims_nossnd.aif",
	"ims_nofrmt.imu", "ims_loop.imu", "ims_mark.imu", "ims_le.imu", "ims_st.imu", "ims_8.imu", "ims_12.imu", "ims_once.imu", "ims_mcmp.imu", "ims_mcmpw.wav" }
cr_t_ims_formats = function()
	ims_reset()
	local i = 1
	while IMS_FORMATS[i] do
		ims_start_log(IMS_FORMATS[i], IMS_FORMATS[i])
		i = i + 1
	end
	ims_reset()
end
cr_scummvm_differs("ims_formats", "crashes or hangs ScummVM now and then: on the skip list") cr_test("ims_formats", cr_t_ims_formats)

IMS_LIVE = { { "ims_8m.wav", "ims_16s.wav", "ims_8s.wav", "ims_44k.wav", "ims_11k.wav", "ims_list.wav" },
	{ "ims_loop.imu", "ims_mark.imu", "ims_le.imu", "ims_st.imu", "ims_8.imu", "ims_12.imu", "ims_once.imu" } }
-- (ims_nodata.wav, a RIFF without a data chunk, is left out here: playing on, it crashes both engines, the original's
-- iMUSE.dll at +0x58A6 and ScummVM in IMuseInternalMixer::mix16ToStereo, both reading past the file)
-- (a group of sounds for two seconds, fewer than the tracks: their volume, pan and detune changed while they play)
ims_live_group = function(g)
	local t = IMS_LIVE[g]
	local i = 1
	while t[i] do
		ImStartSound(t[i], 60 + i, 1)
		i = i + 1
	end
	cr_wait_s(1)
	i = 1
	while t[i] do
		ImSetParam(t[i], CR_IM_PAN, 10 + 16 * i)
		ImSetParam(t[i], CR_IM_VOL, 127 - 10 * i)
		i = i + 1
	end
	ImSetParam(t[1], 2048, 600)
	ImSetParam(t[2], 2048, 256)
	ImSetParam(t[3], 2304, 1)
	cr_wait_s(1)
	ImSetParam(t[1], CR_IM_PAN, 127)
	ImSetParam(t[2], CR_IM_PAN, 0)
	ImSetParam(t[3], CR_IM_VOL, 0)
	cr_wait_s(1)
	-- (what is still playing after three seconds: ScummVM has ended the short ones, the original none)
	i = 1
	while t[i] do
		cr_unstable("live_" .. t[i])
		cr_log("live_" .. t[i], cr_im(t[i]))
		i = i + 1
	end
	ims_reset()
end

-- the sound effects for seconds of the clock, in two groups (ScummVM mixes them: 8 bit, stereo, other rates, pans,
-- the other endianness, pitch)
cr_t_ims_formats_live = function()
	cr_allow_frames(1000000000)
	ims_reset()
	ims_live_group(1)
	ims_live_group(2)
	cr_log("after", cr_im("ims_loop.imu"), cr_im("ims_16s.wav"))
end
cr_scummvm_differs("ims_formats_live", "crashes or hangs ScummVM now and then: on the skip list") cr_test("ims_formats_live", cr_t_ims_formats_live)

-- iMUS files with broken maps: another tag than MAP, data that does not follow the map, a map whose blocks run past
-- its end, a map too big, an unknown block, no STOP
IMS_MAPS = { "ims_badtag.imu", "ims_badoff.imu", "ims_big.imu", "ims_unknown.imu", "ims_nostop.imu" }
cr_t_ims_maps = function()
	cr_allow_frames(1000000000)
	ims_reset()
	local i = 1
	while IMS_MAPS[i] do
		ims_start_log(IMS_MAPS[i], IMS_MAPS[i])
		i = i + 1
	end
	-- (for a second of the clock: the ones that start reach their broken part)
	i = 1
	while IMS_MAPS[i] do
		ImStartSound(IMS_MAPS[i], 100, 1)
		i = i + 1
	end
	cr_wait_s(2)
	i = 1
	while IMS_MAPS[i] do
		cr_unstable("live_" .. IMS_MAPS[i])
		cr_log("live_" .. IMS_MAPS[i], cr_im(IMS_MAPS[i]))
		i = i + 1
	end
	ims_reset()
end
cr_test("ims_maps", cr_t_ims_maps)

-- (a map whose last block runs past the map's end, ims_odd.imu, crashes the original's iMUSE.dll at +0x2A19 when started,
-- and ScummVM in dispatchPredictFirstStream: left out)

-- a sound by the number ImStartSound gives, numbers and number strings that are no sound, the other params
cr_t_ims_ids = function()
	ims_reset()
	local id = ImStartSound("ims_loop.imu", 90, 1)
	cr_log("id", type(id))
	if type(id) == "number" then
		cr_log("by_id", cr_im(id))
		ImSetParam(id, CR_IM_VOL, 50)
		ImSetParam(id, CR_IM_PAN, 20)
		cr_log("set_by_id", cr_im("ims_loop.imu"))
		cr_log("id_plus_1", ImGetParam(id + 1, CR_IM_PLAY))
	end
	cr_log("n1200", ImGetParam(1200, CR_IM_PLAY), ImGetParam(1200, CR_IM_VOL))
	cr_log("n10000", ImGetParam(10000, CR_IM_PLAY), ImGetParam(10000, CR_IM_VOL))
	cr_log("n5", ImGetParam(5, CR_IM_PLAY), ImGetParam(1111, CR_IM_PLAY))
	cr_log("s10000", ImGetParam("10000", CR_IM_PLAY), ImGetParam("10000", CR_IM_VOL))
	cr_log("s1200", ImGetParam("1200", CR_IM_PLAY), ImGetParam("1200", CR_IM_VOL))
	cr_log("s12", ImGetParam("12", CR_IM_PLAY), ImGetParam("", CR_IM_PLAY))
	cr_log("params", ims_params("ims_loop.imu"))
	cr_log("params_none", ims_params("ims_once.imu"))
	ImSetParam("ims_loop.imu", 2048, 100)
	ImSetParam("ims_loop.imu", 2304, 3)
	ImSetParam("ims_loop.imu", 2560, 7)
	ImSetParam("ims_loop.imu", 3840, 1)
	ImSetParam("ims_loop.imu", 0, 1)
	ImSetParam("ims_loop.imu", 768, 4)
	cr_frames(1)
	cr_log("set", ims_params("ims_loop.imu"))
	ImSetParam("ims_loop.imu", 2048, 10000)
	ImSetParam("ims_loop.imu", 2304, 5000)
	ImSetParam("ims_loop.imu", CR_IM_PRIO, 300)
	ImSetParam("ims_loop.imu", CR_IM_GROUP, 20)
	cr_frames(1)
	cr_log("out_of_range", ims_params("ims_loop.imu"))
	cr_unstable("pos")
	cr_log("pos", ImGetParam("ims_loop.imu", 6656))
	if type(id) == "number" then
		ImStopSound(id)
	end
	cr_frames(1)
	cr_log("stopped_by_id", cr_im("ims_loop.imu"))
	ims_reset()
end
cr_scummvm_differs("ims_ids", "in the whole run the id of the next sound is one apart (ScummVM's ids skip one a cached sound has, as ims_cache)") cr_test("ims_ids", cr_t_ims_ids)

-- (a number from 1367 up, not 10000, as the sound is read as the address of a name: it crashes the original's iMUSE.dll at
-- +0xBEA0 and ScummVM in cacheGetSoundId's string compare (imuse_files.cpp:925-958): left out)

-- fades of the priority and of params that cannot fade, of no length, with a negative length, and more fades at once
-- than iMUSE has (16)
cr_t_ims_fades = function()
	ims_reset()
	ImStartSound("ims_loop.imu", 90, 1)
	ImStartSound("ims_le.imu", 90, 1)
	ImStartSound("ims_st.imu", 90, 1)
	cr_frames(1)
	cr_log("r_prio", ImFadeParam("ims_st.imu", CR_IM_PRIO, 10, 340))
	cr_log("r_detune", ImFadeParam("ims_st.imu", 2048, 50, 340))
	cr_log("r_transpose", ImFadeParam("ims_st.imu", 2304, 50, 340))
	cr_log("r_group", ImFadeParam("ims_st.imu", CR_IM_GROUP, 2, 340))
	cr_log("r_negative", ImFadeParam("ims_loop.imu", CR_IM_VOL, 10, -100))
	cr_log("r_none", ImFadeParam("ims_none.wav", CR_IM_VOL, 10, 100))
	cr_frames(1)
	cr_log("pan0", ImFadeParam("ims_loop.imu", CR_IM_PAN, 100, 0))
	cr_log("vol0", ImFadeParam("ims_le.imu", CR_IM_VOL, 0, 10))
	cr_frames(1)
	cr_log("no_length", cr_im("ims_loop.imu"), cr_im("ims_le.imu"))
	local i = 1
	while i <= 20 do
		ImStartSound(IMS_MANY[i], 100, 1)
		i = i + 1
	end
	i = 1
	while i <= 20 do
		ImFadeParam(IMS_MANY[i], CR_IM_VOL, 0, 2000)
		i = i + 1
	end
	cr_frames(10)
	-- (a fade of 2 s, 10 frames in: only how far it got depends on the timer)
	cr_unstable("many")
	cr_log("many", cr_im(IMS_MANY[1]), cr_im(IMS_MANY[20]))
	cr_unstable("prio_trace")
	cr_log("prio_trace", ims_params("ims_st.imu"))
	ims_reset()
end
cr_test("ims_fades", cr_t_ims_fades)

-- ImResume without ImPause, ImPause twice and ImResume twice
cr_t_ims_pause = function()
	ims_reset()
	ImStartSound("ims_loop.imu", 90, 1)
	ImResume()
	ImResume()
	cr_frames(2)
	cr_log("resumed_twice", cr_im("ims_loop.imu"))
	ImPause()
	ImPause()
	cr_frames(2)
	cr_log("paused_twice", cr_im("ims_loop.imu"))
	ImResume()
	cr_frames(2)
	cr_log("resumed_once", cr_im("ims_loop.imu"))
	ImResume()
	cr_frames(2)
	cr_log("resumed", cr_im("ims_loop.imu"))
	ims_reset()
end
cr_test("ims_pause", cr_t_ims_pause)

-- (the play counts of IMS_MANY, as one string)
ims_many_counts = function(n)
	local s = ""
	local i = 1
	while i <= n do
		s = s .. tostring(ImGetParam(IMS_MANY[i], CR_IM_PLAY))
		i = i + 1
	end
	return s
end

-- more sounds than tracks: of the same priority (a new one takes the track of another), then of a lower priority
cr_t_ims_tracks = function()
	ims_reset()
	local i = 1
	local s = ""
	while i <= 12 do
		ImStartSound(IMS_MANY[i], 50, 1)
		s = s .. ims_many_counts(12) .. " "
		i = i + 1
	end
	cr_log("same_prio", s)
	ims_reset()
	i = 1
	while i <= 10 do
		ImStartSound(IMS_MANY[i], 60 + i, 1)
		i = i + 1
	end
	cr_log("rising", ims_many_counts(10))
	ImStartSound(IMS_MANY[11], 5, 1)
	cr_log("low", ims_many_counts(11))
	ImStartSound(IMS_MANY[12], 127, 1)
	cr_log("high", ims_many_counts(12))
	ims_reset()
end
cr_test("ims_tracks", cr_t_ims_tracks)

-- more sounds than the cache holds (32), none loaded before: each started and stopped; the ids
cr_t_ims_cache = function()
	ims_reset()
	local i = 1
	local ids = { }
	while i <= 40 do
		ids[i] = ImStartSound(IMS_CACHE[i], 50, 1)
		ImStopSound(IMS_CACHE[i])
		i = i + 1
	end
	-- (the ids from the first one's, mod 256: the ids turn at 256, and where the run's first id falls depends on the sounds
	-- the earlier tests started; mod keeps the sign of a negative difference, hence the second one)
	ims_id_diff = function(a, b) return mod(mod(a - b, 256) + 256, 256) end
	cr_log("ids", ims_id_diff(ids[32], ids[1]), ims_id_diff(ids[33], ids[1]), ims_id_diff(ids[40], ids[1]))
	-- (which stopped sound the cache drops first depends on its load time in milliseconds)
	cr_unstable("first_by_id")
	cr_log("first_by_id", ImGetParam(ids[1], CR_IM_PLAY), ImGetParam(ids[40], CR_IM_PLAY))
	-- (a sound that plays is not dropped from the cache: one that keeps playing, then a turn of the ids, 256 of them)
	local keep = ImStartSound("ims_loop.imu", 120, 1)
	cr_log("keep", ims_id_diff(keep, ids[1]))
	local n = 0
	local last
	while n < 270 do
		last = ImStartSound(IMS_MANY[mod(n, 40) + 1], 50, 1)
		ImStopSound(IMS_MANY[mod(n, 40) + 1])
		n = n + 1
	end
	cr_log("last", ims_id_diff(last, keep))
	cr_log("keep_after", cr_im("ims_loop.imu"), tostring(ImGetParam(keep, CR_IM_PLAY)))
	ims_reset()
end
cr_scummvm_differs("ims_cache", "the Lua ids turn round at 256: ScummVM skips an id a sound in the cache still has (imuse_files.cpp:970-982), the original gives it again, and the playing sound's id then finds the other one") cr_test("ims_cache", cr_t_ims_cache)

-- a costume's sound components (ims_sfx.cos: ims_loop.imu and ims_hook.imu with a volume, pan, priority and minimum
-- volume in the name; IMS_LV for the keys): play, stop looping (hook 128), stop
cr_t_ims_component = function()
	cr_allow_frames(1000000000)
	ims_reset()
	MakeCurrentSet("cr_flat.set")
	local a = LoadActor("ims_sfx")
	PutActorInSet(a, "cr_flat.set")
	PutActorAt(a, 0.5, 0, 0)
	SetActorCostume(a, "ims_sfx.cos")
	IMS_LV = 0
	cr_frames(1)
	PlayActorChore(a, 0, "ims_sfx.cos")
	cr_frames(3)
	cr_log("play", IMS_LV, cr_im("ims_loop.imu"), cr_im("ims_hook.imu"))
	cr_log("playing", IsSoundPlaying("ims_loop.imu"), IsSoundPlaying("ims_hook.imu"))
	cr_frames(12)
	PlayActorChore(a, 0, "ims_sfx.cos")
	cr_frames(3)
	cr_log("play_again", IMS_LV, cr_im("ims_loop.imu"))
	cr_wait_s(1)
	PlayActorChore(a, 1, "ims_sfx.cos")
	cr_frames(3)
	cr_log("unloop", IMS_LV, cr_im("ims_loop.imu"), cr_im("ims_hook.imu"))
	cr_wait_s(2)
	cr_unstable("unloop_later")
	cr_log("unloop_later", IsSoundPlaying("ims_loop.imu"), IsSoundPlaying("ims_hook.imu"))
	PlayActorChore(a, 0, "ims_sfx.cos")
	cr_frames(3)
	PlayActorChore(a, 2, "ims_sfx.cos")
	cr_frames(3)
	cr_log("stop", IMS_LV, cr_im("ims_loop.imu"), cr_im("ims_hook.imu"))
	PutActorInSet(a, nil)
	ims_reset()
end
cr_scummvm_differs("ims_component") cr_test("ims_component", cr_t_ims_component)

-- (music for n seconds of the clock, the set changed and back while it plays)
ims_music_wait = function(n)
	cr_wait_s(n)
end

-- music states: two files of the same attribute (1040, 1041: a switch of the stream at once), a sound of the music's
-- group that is not streamed (faded out by the next state), the hook-2 states 1323 and 1328 (the hook counts 2, 3,
-- back to 1), other music files: stereo with a fading marked loop (1010), 8 bit (1011), one stored MCMP block (1020), RIFF
-- (1060, transition 2), and the set changed while music plays
cr_t_ims_states = function()
	cr_allow_frames(1000000000)
	ims_reset()
	MakeCurrentSet("cr_flat.set")
	ImSetState(1040)
	cr_wait_s(1)
	ImSetState(1041)
	cr_wait_s(1)
	ImStartSound("ims_loop.imu", 60, 4)
	cr_frames(2)
	cr_log("musiceff", cr_im("ims_loop.imu"))
	ImSetState(1044)
	cr_wait_s(1)
	cr_unstable("musiceff_faded")
	cr_log("musiceff_faded", cr_im("ims_loop.imu"))
	ImSetState(1323)
	cr_frames(5)
	ImSetState(1001)
	cr_frames(5)
	ImSetState(1323)
	cr_frames(5)
	ImSetState(1328)
	cr_frames(5)
	ImSetState(1323)
	cr_wait_s(1)
	ImSetState(1010)
	cr_wait_s(3)
	MakeCurrentSet("cr_edge.set")
	cr_frames(2)
	MakeCurrentSet("cr_flat.set")
	ImSetState(1011)
	cr_wait_s(1)
	ImSetState(1020)
	cr_wait_s(1)
	ImSetState(1060)
	cr_wait_s(1)
	ImSetState(1070)
	cr_wait_s(1)
	cr_log("music", cr_im("1010 - Ledge.IMC"), cr_im("1060 - Real World.IMC"))
	ims_reset()
	cr_log("ok", 1)
end
cr_test("ims_states", cr_t_ims_states)

-- what ImSetSequence gives: a sequence, the same again, one that is not in the table, 0 and -1, the state under it
cr_t_ims_sequences = function()
	ims_reset()
	ImSetState(1040)
	cr_frames(3)
	cr_log("seq", ImSetSequence(2001))
	cr_frames(3)
	cr_log("again", ImSetSequence(2001))
	cr_log("bogus", ImSetSequence(2002))
	cr_log("current", ImSetSequence(-1))
	ImSetState(1041)
	cr_frames(3)
	cr_log("zero", ImSetSequence(0))
	cr_frames(3)
	cr_log("current_after", ImSetSequence(-1))
	cr_log("null", ImSetSequence(2000))
	cr_log("string", ImSetSequence("2001"))
	cr_log("nil", ImSetSequence())
	cr_frames(3)
	ims_reset()
end
cr_scummvm_differs("ims_sequences", "ImSetSequence gives 0: scriptParse returns 0 for IMUSE_C_SCRIPT_SET_SEQUENCE but in the demo (imuse_scripts.cpp:60-64); the original gives the sequence now playing, -1 for one not in the table") cr_test("ims_sequences", cr_t_ims_sequences)

-- a voice over the music (two streams at once; imsv01 is one stored MCMP block), then a line without a table (a
-- background voice: a sound of its own, with its lip sync) over a voice of stored 8 KB blocks
cr_t_ims_voices = function()
	cr_allow_frames(1000000000)
	ims_reset()
	ImSetState(1040)
	cr_frames(3)
	local a = cr_talker()
	SayLine(a, "/imsv01/", { x = 100, y = 100 })
	cr_frames(2)
	cr_log("voice", CR_LV, IsMessageGoing())
	cr_wait_s(2)
	ShutUpActor(a)
	cr_frames(2)
	cr_log("shut_up", CR_LV, IsMessageGoing())
	SayLine(a, "/imsv02/", { x = 100, y = 100 })
	cr_frames(2)
	local b = LoadActor("ims_bg")
	PutActorInSet(b, "cr_flat.set")
	SetActorCostume(b, "cr_talk.cos")
	local i = 0
	while i < 10 do
		SetActorTalkChore(b, i + 1, i)
		i = i + 1
	end
	SayLine(b, "/imsv01/")
	IMS_C = LoadActor("ims_bg2")
	PutActorInSet(IMS_C, "cr_flat.set")
	SayLine(IMS_C, "/crtv01/")
	IMS_D = LoadActor("ims_bg3")
	PutActorInSet(IMS_D, "cr_flat.set")
	SayLine(IMS_D, "/crtv04/")
	cr_frames(2)
	cr_log("background", IsMessageGoing(), cr_im("imsv01.wav"))
	cr_wait_s(2)
	ShutUpActor(a)
	ShutUpActor(b)
	ShutUpActor(IMS_C)
	ShutUpActor(IMS_D)
	cr_frames(2)
	cr_log("shut_up_both", IsMessageGoing())
	PutActorInSet(a, nil)
	PutActorInSet(b, nil)
	PutActorInSet(IMS_C, nil)
	PutActorInSet(IMS_D, nil)
	ExpireText()
	ims_reset()
	cr_log("after", cr_im("imsv01.wav"))
end
cr_scummvm_differs("ims_voices", "a SayLine without a table is a background voice, a sound of iMUSE's cache, on ScummVM (lua_v1_text.cpp: background starts true); not on the original") cr_test("ims_voices", cr_t_ims_voices)

-- saved with a state of music and an iMUS sound effect playing (its volume and pan set), loaded: as sound.lua's
-- sound_save (a registry value tells the pass)
cr_t_ims_save = function()
	PurgeText()
	ims_reset()
	MakeCurrentSet("cr_flat.set")
	ImSetState(1040)
	ImStartSound("ims_loop.imu", 80, 1)
	ImStartSound("ims_8m.wav", 70, 1)
	cr_frames(3)
	ImSetParam("ims_loop.imu", CR_IM_VOL, 77)
	ImSetParam("ims_loop.imu", CR_IM_PAN, 30)
	cr_frames(3)
	WriteRegistryValue("ImsSavePass", "saving")
	RenderModeUser(TRUE)
	Save("ims_save.gsv")
	cr_frames(3)
	RenderModeUser(nil)
	if ReadRegistryValue("ImsSavePass") == "saving" then
		WriteRegistryValue("ImsSavePass", "loading")
		ims_reset()
		cr_log("stopped", cr_im("ims_loop.imu"))
		Load("ims_save.gsv")
		cr_frames(10)
		cr_log("not_loaded", 1)
	else
		WriteRegistryValue("ImsSavePass", "done")
		cr_frames(2)
		cr_log("loaded", cr_im("ims_loop.imu"), cr_im("ims_8m.wav"))
		cr_log("loaded_playing", IsSoundPlaying("ims_loop.imu"))
		ims_reset()
	end
end
cr_scummvm_differs("ims_save", "in the whole run ScummVM (OpenGL) ended with 0xC0000409 (a stack buffer overrun) in this Save, as gl1_save_nil and smv_save_movie") cr_test("ims_save", cr_t_ims_save)

-- saved while a voice plays over the music, loaded
cr_t_ims_save_voice = function()
	PurgeText()
	ims_reset()
	ImSetState(1041)
	cr_frames(3)
	IMS_A = cr_talker()
	SayLine(IMS_A, "/imsv02/", { x = 100, y = 100 })
	cr_frames(3)
	WriteRegistryValue("ImsSavePass", "saving")
	RenderModeUser(TRUE)
	Save("ims_savev.gsv")
	cr_frames(3)
	RenderModeUser(nil)
	if ReadRegistryValue("ImsSavePass") == "saving" then
		WriteRegistryValue("ImsSavePass", "loading")
		-- (loaded while the voice still plays)
		Load("ims_savev.gsv")
		cr_frames(10)
		cr_log("not_loaded", 1)
	else
		WriteRegistryValue("ImsSavePass", "done")
		cr_frames(2)
		cr_log("loaded", IsMessageGoing())
		ShutUpActor(IMS_A)
		cr_frames(2)
		PutActorInSet(IMS_A, nil)
		ExpireText()
		ims_reset()
	end
end
cr_scummvm_differs("ims_save_voice", "in the whole run, with the shader and software renderers, the voice is still loaded after the Load (nil on the original)") cr_test("ims_save_voice", cr_t_ims_save_voice)
