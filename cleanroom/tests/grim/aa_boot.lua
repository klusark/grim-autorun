-- The first test of a run (the file name sorts first): the state of the engine as it starts, before any test changed it.
-- (ScummVM's MoviePlayer starts with _videoFinished false: IsMoviePlaying is true until a movie call deinits it)

cr_t_boot_state = function()
	cr_log("movie_playing", IsMoviePlaying())
	cr_log("fullscreen_movie_playing", IsFullscreenMoviePlaying())
	cr_log("message_going", IsMessageGoing())
	cr_log("sound_playing", IsSoundPlaying("cr_tone.wav"))
end
cr_scummvm_differs("boot_state") cr_test("boot_state", cr_t_boot_state)
