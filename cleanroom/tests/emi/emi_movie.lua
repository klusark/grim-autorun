-- EMI's movies: Bink of our own (assets_emi.loose_files, formats.bik: BIKi with fill blocks and no sound, 160 x 120 at 15
-- frames a second), Movies/cr_white.m4b (90 white frames, 6 s) and Movies/cr_steps.m4b (5 frames, grey to white).
-- StartMovie(name, ...), IsMoviePlaying, StopMovie, PauseMovie. A movie plays by real time on both engines: the tests wait
-- for seconds of the clock (date), as tests/grim/movie.lua. (The original's EMI has no screenshot in the clean room: only
-- what the Lua sees is compared.)

-- (n changes of the clock's second: between n - 1 and n seconds)
cr_emi_wait_s = function(n)
	local s = date("%S")
	while n > 0 do
		break_here()
		local t = date("%S")
		if t ~= s then
			s = t
			n = n - 1
			-- (a line that is not a result, each second: run.py takes a log that stops for CR_STALL seconds for a hang)
			PrintDebug("wait\n")
		end
	end
end

-- (until the movie stops, at most about n seconds; whether it stopped)
cr_emi_movie_wait = function(n)
	local s = date("%S")
	while n > 0 and IsMoviePlaying() do
		break_here()
		local t = date("%S")
		if t ~= s then
			s = t
			n = n - 1
			-- (a line that is not a result, each second: run.py takes a log that stops for CR_STALL seconds for a hang)
			PrintDebug("wait\n")
		end
	end
	return not IsMoviePlaying()
end

cr_emi_movie_test = function(name, fn)
	cr_test("emi_movie_" .. name, function()
		cr_allow_frames(1000000000)
		%fn()
		StopMovie()
		cr_frames(2)
	end)
end

-- a movie: at once, while it plays, whether it ends
cr_emi_movie_test("play", function()
	cr_log("start", StartMovie("cr_white"))
	cr_log("playing_at_once", IsMoviePlaying())
	cr_emi_wait_s(2)
	cr_log("playing", IsMoviePlaying())
	cr_log("ended", cr_emi_movie_wait(10))
	cr_frames(3)
	cr_log("after", IsMoviePlaying())
end)

-- the name with its extension
cr_emi_movie_test("extension", function()
	cr_log("start", StartMovie("cr_steps.m4b"))
	cr_log("ended", cr_emi_movie_wait(5))
end)

-- a short one ends
cr_emi_movie_test("short", function()
	cr_log("start", StartMovie("cr_steps"))
	cr_log("ended", cr_emi_movie_wait(5))
end)

-- (StopMovie while a movie plays crashes the original: an access violation at 0x422711, in its movie player, after
-- StopMovie (0x418550) paused the Bink and deleted the player. Not tested; the movies here stop by themselves.)

-- PauseMovie for longer than the movie: still playing? Then on again: does it end?
cr_emi_movie_test("pause", function()
	StartMovie("cr_steps")
	PauseMovie(TRUE)
	cr_emi_wait_s(3)
	cr_log("paused_playing", IsMoviePlaying())
	PauseMovie(nil)
	cr_log("ended", cr_emi_movie_wait(5))
end)

-- one that is not there, and one started while another plays
cr_emi_movie_test("missing", function()
	cr_log("missing", StartMovie("no_such"))
	cr_log("playing", IsMoviePlaying())
	StartMovie("cr_white")
	cr_emi_wait_s(1)
	cr_log("second", StartMovie("cr_steps"))
	cr_log("ended", cr_emi_movie_wait(10))
end)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("emi_movie_extension")
