-- EMI's sounds across Save and Load (prefix esn; as emi_actor_save.lua: the Load brings back the Lua task, so the test
-- goes on after its Save a second time, and JustLoaded() tells the passes apart). Each test saves one kind of sound
-- (esn_save_<kind>): none; three sounds of the pool, only loaded; those with two of them playing, looping, one of them
-- positioned; a sound played by name; music (a state playing, one on the stack, faded out and so paused, and an empty
-- entry under it); a voiced line. After the Load: what plays, the volumes, the handles used, the stack popped.

esn_sv_state = function(h)
	if not h then
		return "-"
	end
	return tostring(IsSoundPlaying(h)) .. " " .. tostring(GetSoundVolume(h))
end

cr_t_esn_save = function()
	cr_allow_frames(1000000000)
	-- (without a font for the lines, Monkey4.exe's Save crashes at 0x434042, a glyph of no font: emi_actor_misc.lua and
	-- emi_actor_talk.lua set this before in a full run)
	SetSayLineDefaults({ font = "cr_font.laf" })
	MakeCurrentSet("cr_flat.set")
	ESN_SV_A = LoadActor("esn_sv_talker")
	PutActorInSet(ESN_SV_A, "cr_flat.set")
	PutActorAt(ESN_SV_A, 0, 0, 0)
	ESN_SV_H1 = nil
	ESN_SV_H2 = nil
	ESN_SV_H3 = nil
	if ESN_SV_KIND == "loaded" or ESN_SV_KIND == "pool" or ESN_SV_KIND == "all" then
		ESN_SV_H1 = LoadSound("cr_long")
		ESN_SV_H2 = LoadSound("cr_long")
		ESN_SV_H3 = LoadSound("cr_tone")
	end
	if ESN_SV_KIND == "pool" or ESN_SV_KIND == "all" then
		PlayLoadedSound(ESN_SV_H1, 1, 70)
		PlayLoadedSoundFrom(ESN_SV_H2, 1, 0, 1, 1, 60)
	end
	if ESN_SV_KIND == "name" or ESN_SV_KIND == "all" then
		PlaySound("cr_long", 80)
	end
	if ESN_SV_KIND == "music" or ESN_SV_KIND == "all" then
		ImPushState()
		ImSetState(2)
		esn_wait(1)
		ImPushState()
		ImSetState(1)
		esn_wait(3)
	end
	if ESN_SV_KIND == "voice" or ESN_SV_KIND == "all" then
		SayLine(ESN_SV_A, "/esnv02/")
	end
	cr_frames(3)
	cr_log("before", esn_sv_state(ESN_SV_H1), esn_sv_state(ESN_SV_H2), esn_sv_state(ESN_SV_H3), IsMessageGoing())
	cr_log("just_loaded_before", JustLoaded())
	ESN_SV_VERSION = system.version
	system.version = "cr 1.0"
	Save("cresn_sound.gsv")
	cr_frames(3)
	if not JustLoaded() then
		if ESN_SV_H1 then
			StopSound(ESN_SV_H1)
			StopSound(ESN_SV_H2)
		end
		ShutUpActor(ESN_SV_A)
		ImSetState(0)
		ImFlushStack()
		cr_frames(2)
		cr_log("changed", esn_sv_state(ESN_SV_H1), esn_sv_state(ESN_SV_H2), IsMessageGoing())
		Load("cresn_sound.gsv")
		cr_frames(10)
		cr_log("not_loaded", 1)
	else
		cr_log("pass", "loaded")
		cr_frames(2)
		cr_log("after", esn_sv_state(ESN_SV_H1), esn_sv_state(ESN_SV_H2), esn_sv_state(ESN_SV_H3), IsMessageGoing())
		-- (the pool's handles still work)
		if ESN_SV_H1 then
			SetSoundVolume(ESN_SV_H1, 30)
			PlayLoadedSound(ESN_SV_H3, 1, 90)
		end
		cr_frames(2)
		cr_log("used", esn_sv_state(ESN_SV_H1), esn_sv_state(ESN_SV_H3))
		ImPopState()
		esn_wait(1)
		ImPopState()
		cr_frames(2)
		cr_log("popped", 1)
	end
	system.version = ESN_SV_VERSION
	ShutUpActor(ESN_SV_A)
	if ESN_SV_H1 then
		StopSound(ESN_SV_H1)
		StopSound(ESN_SV_H2)
		StopSound(ESN_SV_H3)
		FreeSound(ESN_SV_H1)
		FreeSound(ESN_SV_H2)
		FreeSound(ESN_SV_H3)
	end
	ImSetState(0)
	ImFlushStack()
	StopAllSounds()
	cr_frames(2)
	PutActorInSet(ESN_SV_A, nil)
	cr_frames(1)
end
cr_scummvm_differs("esn_save_none") cr_test("esn_save_none", function() ESN_SV_KIND = "none" cr_t_esn_save() end)
cr_scummvm_differs("esn_save_loaded", "volumes lose 1 in ScummVM's round trip to the mixer (lua_v2_sound.cpp:40-51)") cr_test("esn_save_loaded", function() ESN_SV_KIND = "loaded" cr_t_esn_save() end)
cr_scummvm_differs("esn_save_pool", "the original does not play the sounds again after the Load, ScummVM does (emisound.cpp:1080); volumes lose 1 (lua_v2_sound.cpp:40-51)") cr_test("esn_save_pool", function() ESN_SV_KIND = "pool" cr_t_esn_save() end)
cr_scummvm_differs("esn_save_name") cr_test("esn_save_name", function() ESN_SV_KIND = "name" cr_t_esn_save() end)
cr_test("esn_save_music", function() ESN_SV_KIND = "music" cr_t_esn_save() end)
cr_scummvm_differs("esn_save_voice", "after the Load the original's line has ended, ScummVM plays the voice again (emisound.cpp:1080)") cr_test("esn_save_voice", function() ESN_SV_KIND = "voice" cr_t_esn_save() end)
