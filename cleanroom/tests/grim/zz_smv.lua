-- Movies put together chunk by chunk (assets_extra_smv.py): sound in stereo, in the track form of the Wave chunk, IMA4,
-- more sound than the player's ring holds; ANNO chunks between frames, chunks in a frame the player does not know, an
-- unknown chunk between frames, a file cut short; frames without sound and sound without frames (the player slows down,
-- speeds up and skips late frames); the Blocky16 buffer swap 2 and BOMP data with raw runs. 160 x 120 at (100, 50) but
-- the Blocky16 ones (640 x 480 at 0, 0); 15 frames a second. Seen as movie.lua sees its movies: IsMoviePlaying while the
-- frames of game time go on (movie.lua's cr_wait_s / cr_movie_wait), and cr_snap (the box of the white pixels).

-- (n seconds of game time)
smv_wait_s = function(n)
	cr_wait_s(n)
end

-- (until the movie stops, at most n seconds of game time; whether it stopped)
smv_wait_end = function(n)
	return cr_movie_wait(n)
end

smv_test = function(name, fn)
	cr_test("smv_" .. name, function()
		cr_allow_frames(1000000000)
		MakeCurrentSet("cr_flat.set")
		cr_frames(2)
		%fn()
		StopMovie()
		cr_frames(3)
	end)
end

-- a 3 s movie in a window: at once, after 1-2 s (with the picture), whether it ends
smv_plays = function(file)
	cr_log("start", StartMovie(file, nil, 100, 50))
	cr_log("playing_at_once", IsMoviePlaying())
	smv_wait_s(2)
	cr_log("playing", IsMoviePlaying())
	cr_snap("snap")
	cr_log("ended", smv_wait_end(10))
end

-- sound in stereo (the VIMA block's first byte with bit 7 set: two channels)
smv_test("stereo", function()
	smv_plays("smv_stereo.snm")
end)

-- the same fullscreen
smv_test("stereo_fullscreen", function()
	cr_log("start", StartFullscreenMovie("smv_stereo.snm"))
	smv_wait_s(2)
	cr_log("playing", IsMoviePlaying(), IsFullscreenMoviePlaying())
	cr_log("ended", smv_wait_end(10))
end)

-- the Wave chunks in their track form (a count of -1, the track, the count): track 7, then track 8 from frame 22 (a new
-- stream)
smv_test("track", function()
	smv_plays("smv_track.snm")
end)

-- VIMA in its IMA4 form
smv_test("ima4", function()
	smv_plays("smv_ima4.snm")
end)

-- VIMA with escapes (samples stored as they are) and changes past the 16-bit range
smv_test("vima", function()
	smv_plays("smv_vima.snm")
end)

-- 6 s of frames with 90 s of sound: the sound's ring overflows (the movie ends with its frames)
smv_test("flood", function()
	smv_plays("smv_flood.snm")
end)

-- a first frame with 11 s of sound (nearly the whole ring before the sound starts)
smv_test("big", function()
	smv_plays("smv_big.snm")
end)

-- the header's total size of the sound only 5 frames' worth
smv_test("short", function()
	smv_plays("smv_short.snm")
end)

-- ANNO chunks between the frames
smv_test("anno", function()
	smv_plays("smv_anno.snm")
end)

-- chunks in the frames the player does not know: TRES and ZZZZ
smv_test("extra", function()
	smv_plays("smv_extra.snm")
end)

-- FOBJ, IACT and PSAD in the frames (the chunks of the older SMUSH games)
smv_test("old", function()
	smv_plays("smv_old.snm")
end)

-- frames without sound (the header says there is sound)
smv_test("nowave", function()
	smv_plays("smv_nowave.snm")
end)

-- an unknown chunk between frames 15 and 16 of 90 (6 s): does the movie stop there (after 1 s)?
smv_test("badtop", function()
	cr_log("start", StartMovie("smv_badtop.snm", nil, 100, 50))
	cr_log("playing_at_once", IsMoviePlaying())
	smv_wait_s(3)
	cr_log("playing_2s", IsMoviePlaying())
	cr_log("ended", smv_wait_end(10))
end)

-- the same looped: stopped, or started again?
smv_test("badtop_loop", function()
	cr_log("start", StartMovie("smv_badtop.snm", TRUE, 100, 50))
	smv_wait_s(3)
	cr_log("playing_2s", IsMoviePlaying())
	StopMovie()
	cr_frames(3)
	cr_log("stopped", IsMoviePlaying())
end)

-- 90 frames, the file cut in the middle of frame 20 (1.3 s): the original goes on playing (waiting for the rest of the
-- frame, it seems) until StopMovie; ScummVM ends the movie there
cr_scummvm_differs("smv_cut", "a file cut short in a frame: the original's movie goes on playing until StopMovie; ScummVM's SmushAnimator::readBlock gives -2 on the short read and SmushAnimPlay ends the movie")
smv_test("cut", function()
	cr_log("start", StartMovie("smv_cut.snm", nil, 100, 50))
	cr_log("playing_at_once", IsMoviePlaying())
	smv_wait_s(3)
	cr_log("playing_2s", IsMoviePlaying())
	cr_log("ended", smv_wait_end(10))
end)

-- SHDR's frame count more than the file has (90, the file 20: 1.3 s), and less (15: 1 s, the file 90: 6 s)
smv_test("fewer", function()
	cr_log("start", StartMovie("smv_fewer.snm", nil, 100, 50))
	smv_wait_s(3)
	cr_log("playing_2s", IsMoviePlaying())
	cr_log("ended", smv_wait_end(10))
end)
smv_test("more", function()
	cr_log("start", StartMovie("smv_more.snm", nil, 100, 50))
	smv_wait_s(3)
	cr_log("playing_2s", IsMoviePlaying())
	cr_log("ended", smv_wait_end(10))
end)

-- the frames behind the sound: 10 grey ones without sound, 30 of sound only, 60 that copy a white delta buffer (the
-- frames skipped when late), 15 white ones: what is on the screen after 3-4 s (the copies, or the grey of before if they
-- were skipped), and whether it ends
smv_test("late", function()
	cr_log("start", StartMovie("smv_late.snm", nil, 100, 50))
	smv_wait_s(4)
	cr_log("playing", IsMoviePlaying())
	cr_snap("snap")
	cr_log("ended", smv_wait_end(15))
end)

-- the Blocky16 ones, 640 x 480 at 0, 0: after 1-2 s, the box of the white pixels and how many there are
smv_blocky = function(file)
	cr_log("start", StartMovie(file, nil, 0, 0))
	smv_wait_s(2)
	cr_log("playing", IsMoviePlaying())
	cr_snap("snap", "count")
end

-- the buffer swap 2 (delta buffer 1 becomes 0, the frame becomes 1): then copies of buffer 0 (mode 4: frame X, white at
-- 80, 80) or of buffer 1 (mode 3: frame Y, white at 240, 160)
smv_test("swap4", function()
	smv_blocky("smv_swap4.snm")
end)
smv_test("swap3", function()
	smv_blocky("smv_swap3.snm")
end)

-- BOMP data with raw runs: every third pixel of the top half white, in mode 8 (the colour table) and mode 5 (16-bit)
smv_test("bomp8", function()
	smv_blocky("smv_bomp8.snm")
end)
smv_test("bomp5", function()
	smv_blocky("smv_bomp5.snm")
end)

-- (the shader and software renderers count 48 white pixels fewer in the BOMP frames than the original and OpenGL)
cr_scummvm_differs("smv_bomp8", "the shader and software renderers count 48 white pixels fewer")
cr_scummvm_differs("smv_bomp5", "the shader and software renderers count 48 white pixels fewer")

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("smv_stereo")
