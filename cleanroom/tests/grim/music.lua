-- Music through iMUSE's state and sequence tables (ImSetState(n), ImSetSequence(n): the soundId of an entry, the file its
-- name and ".IMC"), with files of our own (assets.py, formats.imus): 1001 "Manny's Office" and 1008 "Domino's Office" loop,
-- 1002 "Mr. Frustration" (the file of states 1002-1007) has a hook 8 jump, the sequence 2001 "Climb Rope" plays once and
-- ends with "_end". The params of each file (cr_im of sound.lua: play count, pending, group, priority, volume, pan) after
-- each change. Neither engine moves a sound on in a test (sound.lua): what is seen is which files are open, with what.

CR_MUSIC = { "1001 - Manny's Office.IMC", "1008 - Domino's Office.IMC", "1002 - Mr. Frustration.IMC", "2001 - Climb Rope.IMC" }

-- (the params of every music file, one key each)
cr_music_log = function(k)
	local i = 1
	while CR_MUSIC[i] do
		cr_log(k .. "_" .. i, cr_im(CR_MUSIC[i]))
		i = i + 1
	end
end

cr_music_reset = function()
	ImSetSequence(2000)
	ImSetState(1000)
	cr_frames(5)
	ImStopAllSounds()
	cr_frames(2)
end

cr_music_test = function(name, fn)
	cr_test("music_" .. name, function()
		cr_music_reset()
		%fn()
		cr_music_reset()
	end)
end

-- a state, another, none
cr_music_test("states", function()
	cr_music_log("before")
	ImSetState(1001)
	cr_frames(1)
	cr_music_log("mo_at_once")
	cr_frames(10)
	cr_music_log("mo")
	ImSetState(1008)
	cr_frames(10)
	cr_music_log("do")
	ImSetState(1000)
	cr_frames(10)
	cr_music_log("null")
end)

-- the same state again, and "no change"
cr_music_test("same_state", function()
	ImSetState(1001)
	cr_frames(10)
	ImSetState(1001)
	cr_frames(10)
	cr_music_log("again")
	ImSetState(1999)
	cr_frames(10)
	cr_music_log("no_change")
end)

-- states of the same file (1002-1007: the attribute position 3, hook 8, their own volume and pan)
cr_music_test("same_file", function()
	ImSetState(1002)
	cr_frames(10)
	cr_music_log("intls")
	ImSetState(1003)
	cr_frames(10)
	cr_music_log("revls")
	ImSetState(1005)
	cr_frames(10)
	cr_music_log("mnycu")
end)

-- a state whose file is not there (1009 Copal's Office), while one plays
cr_music_test("missing_file", function()
	ImSetState(1001)
	cr_frames(10)
	ImSetState(1009)
	cr_frames(10)
	cr_music_log("missing")
end)

-- a sequence over a state, and the state after it
cr_music_test("sequence", function()
	ImSetState(1001)
	cr_frames(10)
	ImSetSequence(2001)
	cr_frames(10)
	cr_music_log("seq")
	ImSetSequence(2000)
	cr_frames(10)
	cr_music_log("seq_null")
end)

-- the music volume and an attribute while a state plays
cr_scummvm_differs("music_volume", "no ImSetAttribute on ScummVM")
cr_music_test("volume", function()
	ImSetState(1001)
	cr_frames(10)
	ImSetMusicVol(40)
	cr_frames(2)
	cr_log("music_vol", ImGetMusicVol())
	cr_music_log("vol40")
	ImSetMusicVol(127)
	local f = cr_fn("ImSetAttribute")
	if f then
		f(3, 1)
		cr_frames(2)
		cr_music_log("attribute")
	end
end)
