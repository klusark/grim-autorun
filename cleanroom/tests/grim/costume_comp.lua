-- Costume components no other test's costume has (assets.py): a SMUSH movie ('HSMS', cr_cc_smush.cos: a key of 0 plays
-- cr_white.snm, SmushChanger), the iMUSE state and sequence ('imst', 'imse': int keys, the number) and a streamed iMUSE
-- sound ('imss', cr_cc_imuse.cos). What is seen: whether a movie plays, the params of music.lua's files (cr_music_log) and of
-- the streamed sound (cr_im of sound.lua).

cr_cc_actor = function(cos)
	MakeCurrentSet("cr_open.set")
	if not CR_CC_ACTOR then
		CR_CC_ACTOR = LoadActor("cr_cc")
	end
	local a = CR_CC_ACTOR
	PutActorInSet(a, "cr_open.set")
	PutActorAt(a, 0, 0, 0)
	SetActorCostume(a, cos)
	cr_frames(2)
	return a
end

cr_cc_done = function(a)
	PopActorCostume(a)
	PutActorInSet(a, nil)
	cr_frames(2)
end

cr_t_costume_smush = function()
	cr_allow_frames(1000000000)
	local a = cr_cc_actor("cr_cc_smush.cos")
	cr_log("before", IsMoviePlaying())
	PlayActorChore(a, 0, "cr_cc_smush.cos")
	cr_frames(3)
	cr_log("played", IsMoviePlaying(), IsActorChoring(a, 0, FALSE, "cr_cc_smush.cos"))
	cr_wait_s(1)
	cr_log("after_1s", IsMoviePlaying())
	cr_snap("snap")
	StopMovie()
	cr_frames(2)
	cr_log("stopped", IsMoviePlaying())
	PlayActorChore(a, 1, "cr_cc_smush.cos")
	cr_frames(3)
	cr_log("key_1", IsMoviePlaying())
	StopMovie()
	cr_cc_done(a)
end
cr_test("costume_smush", cr_t_costume_smush)

cr_t_costume_imuse_state = function()
	cr_music_reset()
	local a = cr_cc_actor("cr_cc_imuse.cos")
	PlayActorChore(a, 0, "cr_cc_imuse.cos")
	cr_frames(5)
	cr_music_log("state_1001")
	PlayActorChore(a, 1, "cr_cc_imuse.cos")
	cr_frames(5)
	cr_music_log("state_1008")
	PlayActorChore(a, 2, "cr_cc_imuse.cos")
	cr_frames(5)
	cr_music_log("seq_2001")
	PlayActorChore(a, 3, "cr_cc_imuse.cos")
	cr_frames(5)
	cr_music_log("seq_2000")
	PlayActorChore(a, 4, "cr_cc_imuse.cos")
	cr_frames(10)
	cr_music_log("both")
	cr_cc_done(a)
	cr_music_reset()
end
cr_test("costume_imuse_state", cr_t_costume_imuse_state)

cr_t_costume_stream = function()
	ImStopAllSounds()
	cr_frames(2)
	local a = cr_cc_actor("cr_cc_imuse.cos")
	cr_log("before", cr_im("cr_long.wav"))
	PlayActorChore(a, 5, "cr_cc_imuse.cos")
	cr_frames(3)
	cr_log("playing", cr_im("cr_long.wav"))
	PlayActorChore(a, 6, "cr_cc_imuse.cos")
	cr_frames(3)
	cr_log("unlooped", cr_im("cr_long.wav"))
	PlayActorChore(a, 7, "cr_cc_imuse.cos")
	cr_frames(3)
	cr_log("stopped", cr_im("cr_long.wav"))
	cr_cc_done(a)
	ImStopAllSounds()
end
cr_test("costume_stream", cr_t_costume_stream)
