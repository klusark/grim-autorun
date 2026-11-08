-- The other Blocky16 modes of our movies (assets.py, formats.snm; 640 x 480): 2 grey frames, then 45 white ones (3 s) in mode 6 (a
-- colour table), 8 (the table, BOMP coded), 5 (16-bit pixels, BOMP coded), 3 and 4 (a copy of a delta buffer, white).
-- Seen through cr_snap (the box of the bright pixels: the whole screen when the frames are white) while they play.
-- (cr_wait_s is movie.lua's)

cr_mode_test = function(mode)
	cr_test("movie_mode" .. mode, function()
		cr_allow_frames(1000000000)
		MakeCurrentSet("cr_flat.set")
		cr_frames(2)
		cr_log("start", StartMovie("cr_mode" .. %mode .. ".snm", nil, 0, 0))
		cr_wait_s(2)
		cr_log("playing", IsMoviePlaying())
		cr_snap("snap")
		StopMovie()
		cr_frames(2)
	end)
end

cr_mode_test(6)
cr_mode_test(8)
cr_mode_test(5)
cr_mode_test(3)
cr_mode_test(4)
