-- The other Blocky16 modes of our movies (assets.py, formats.snm; 640 x 480): 2 grey frames, then 45 white ones (3 s) in mode 6 (a
-- colour table), 8 (the table, BOMP coded), 5 (16-bit pixels, BOMP coded), 3 and 4 (a copy of a delta buffer, white).
-- Seen through cr_snap (the box of the bright pixels: the whole screen when the frames are white) while they play.
-- (cr_wait_s is movie.lua's)

cr_mode_test = function(mode, snap)
	cr_test("movie_mode" .. mode, function()
		cr_allow_frames(1000000000)
		MakeCurrentSet("cr_flat.set")
		cr_frames(2)
		cr_log("start", StartMovie("cr_mode" .. %mode .. ".snm", nil, 0, 0))
		cr_wait_s(2)
		cr_log("playing", IsMoviePlaying())
		cr_snap("snap", %snap)
		StopMovie()
		cr_frames(2)
	end)
end

cr_mode_test(6)
cr_mode_test(8)
cr_mode_test(5)
cr_mode_test(3)
cr_mode_test(4)
-- Mode 2 (assets._mode2_frames): the blocks of a frame each coded its own way, copies of the frame before (a delta buffer,
-- at an offset of its own or of the motion table), colours, smaller blocks, blocks cut by the interpolation table's edges:
-- the box of the white pixels and how many there are
cr_mode_test(2, "count")
-- Modes 1 and 7 (half rows: every second row of half the pixels, the rest averaged; 7 through the colour table): white, and
-- white and black alternating (the mean of the pixels that are not dark tells the averaging). ScummVM has neither mode.
cr_mode_test(1)
cr_mode_test(7)
cr_mode_test("1s", "mean")
cr_mode_test("7s", "mean")
cr_scummvm_differs("movie_mode1", "ScummVM's Blocky16 has no mode 1")
cr_scummvm_differs("movie_mode7", "ScummVM's Blocky16 has no mode 7")
cr_scummvm_differs("movie_mode1s", "ScummVM's Blocky16 has no mode 1")
cr_scummvm_differs("movie_mode7s", "ScummVM's Blocky16 has no mode 7")

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("movie_mode6")
cr_scummvm_differs("movie_mode8")

-- (a memory error in ScummVM under valgrind: on the skip list)
cr_scummvm_differs("movie_mode2", "a memory error in ScummVM under valgrind (uninitialised value or invalid access): on the skip list")

-- (a memory error in ScummVM under valgrind: on the skip list)
cr_scummvm_differs("movie_mode3", "a memory error in ScummVM under valgrind (uninitialised value or invalid access): on the skip list")

-- (a memory error in ScummVM under valgrind: on the skip list)
cr_scummvm_differs("movie_mode4", "a memory error in ScummVM under valgrind (uninitialised value or invalid access): on the skip list")

-- (a memory error in ScummVM under valgrind: on the skip list)
cr_scummvm_differs("movie_mode5", "a memory error in ScummVM under valgrind (uninitialised value or invalid access): on the skip list")
