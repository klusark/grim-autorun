-- Movies of our own (assets.py, formats.snm: gzipped SMUSH with raw Blocky16 frames and silent VIMA sound, 160 x 120 at
-- 15 frames a second): cr_white.snm, 90 white frames (6 s), and cr_steps.snm, 5 frames from grey to white.
-- StartMovie(name, looping, x, y), StartFullscreenMovie(name), IsMoviePlaying, IsFullscreenMoviePlaying, PauseMovie,
-- StopMovie, GetSmushLength. What is on the screen is seen through cr_snap (the box of the bright pixels: the movie's white
-- on cr_flat). The tests wait in frames of 17 ms (game time), not for seconds of the clock: on the original, grimlaunch's
-- smushtime and imusetime patches play movies and sound by game time (`CR_GRIMLAUNCH="--with smushtime,imusetime"`).

-- (the frames of n seconds of game time, frames of 17 ms)
cr_s_frames = function(n)
	return floor(n * 1000 / 17 + 0.5)
end

-- (n seconds of game time; at most max frames)
cr_wait_s = function(n, max)
	local f = cr_s_frames(n)
	if max and max < f then
		f = max
	end
	cr_frames(f)
end

-- (until the movie stops, at most n seconds of game time; whether it stopped)
cr_movie_wait = function(n)
	local f = cr_s_frames(n)
	while f > 0 and IsMoviePlaying() do
		break_here()
		f = f - 1
	end
	return not IsMoviePlaying()
end

cr_movie_test = function(name, fn)
	cr_test("movie_" .. name, function()
		-- (seconds of waiting: many frames)
		cr_allow_frames(1000000000)
		MakeCurrentSet("cr_flat.set")
		cr_frames(2)
		%fn()
		StopMovie()
		cr_frames(2)
	end)
end

-- a movie in a window: at once, while it plays, whether it ends, after
cr_movie_test("play", function()
	cr_log("start", StartMovie("cr_white.snm", nil, 100, 50))
	cr_log("playing_at_once", IsMoviePlaying(), IsFullscreenMoviePlaying())
	cr_wait_s(2)
	cr_log("playing", IsMoviePlaying(), IsFullscreenMoviePlaying())
	cr_snap("snap")
	cr_log("ended", cr_movie_wait(10))
	cr_frames(3)
	cr_snap("after_snap")
end)

-- where it is drawn: another place, the edge of the screen, and no place (nil)
cr_movie_test("place", function()
	StartMovie("cr_white.snm", nil, 400, 300)
	cr_wait_s(2)
	cr_snap("at_400_300")
	StopMovie()
	cr_frames(3)
	StartMovie("cr_white.snm", nil, 560, 420)
	cr_wait_s(2)
	cr_snap("past_the_edge")
	StopMovie()
	cr_frames(3)
	StartMovie("cr_white.snm")
	cr_wait_s(2)
	cr_snap("no_place")
end)

-- fullscreen
cr_movie_test("fullscreen", function()
	cr_log("start", StartFullscreenMovie("cr_white.snm"))
	cr_wait_s(2)
	cr_log("playing", IsMoviePlaying(), IsFullscreenMoviePlaying())
	cr_snap("snap")
	StopMovie()
	cr_frames(3)
	cr_log("stopped", IsMoviePlaying(), IsFullscreenMoviePlaying())
end)

-- PauseMovie for longer than the movie, with TRUE (the game's pause menu, _options.lua) and with nil (FALSE, its resume):
-- still there after? Then the other one, and does it end? (The original's Lua_PauseMovie pauses when the argument is nil:
-- Movie_SetPaused(lua_isnil(arg)), the other way round from the scripts)
cr_scummvm_differs("movie_pause", "PauseMovie's argument the other way round: the original pauses with nil (FALSE) and goes on with TRUE; ScummVM pauses with TRUE, as the game's scripts mean it")
cr_movie_test("pause", function()
	StartMovie("cr_white.snm", nil, 100, 50)
	cr_wait_s(2)
	PauseMovie(TRUE)
	cr_wait_s(8)
	cr_log("true_playing", IsMoviePlaying())
	cr_snap("true_snap")
	PauseMovie(FALSE)
	cr_wait_s(1)
	cr_log("true_then_false", IsMoviePlaying())
	StopMovie()
	cr_frames(3)
	StartMovie("cr_white.snm", nil, 100, 50)
	cr_wait_s(2)
	PauseMovie(nil)
	cr_wait_s(8)
	cr_log("nil_playing", IsMoviePlaying())
	cr_snap("nil_snap")
	PauseMovie(TRUE)
	cr_wait_s(1)
	cr_log("nil_then_true", IsMoviePlaying())
	cr_log("ended", cr_movie_wait(10))
end)

-- looping: still playing after many times its length, until StopMovie
cr_movie_test("loop", function()
	StartMovie("cr_steps.snm", TRUE, 100, 50)
	cr_wait_s(3)
	cr_log("looping", IsMoviePlaying())
	StopMovie()
	cr_frames(3)
	cr_log("stopped", IsMoviePlaying())
end)

-- a movie that is not looped ends: the short one
cr_movie_test("short", function()
	StartMovie("cr_steps.snm", nil, 100, 50)
	cr_log("ended", cr_movie_wait(5))
end)

-- a movie started while another plays, and one that is not there while one plays
cr_scummvm_differs("movie_replace", "the original redraws only what changed: the last frame of the first movie stays on the screen; ScummVM draws the whole screen")
cr_movie_test("replace", function()
	StartMovie("cr_white.snm", nil, 100, 50)
	cr_wait_s(1)
	cr_log("second", StartMovie("cr_white.snm", nil, 300, 200))
	cr_wait_s(2)
	cr_log("playing", IsMoviePlaying())
	cr_snap("snap")
	cr_log("missing", StartMovie("no_such.snm", nil, 0, 0))
	cr_frames(3)
	cr_log("after_missing", IsMoviePlaying())
end)

-- GetSmushLength (the original only)
cr_scummvm_differs("movie_length", "no GetSmushLength on ScummVM")
cr_movie_test("length", function()
	local f = cr_fn("GetSmushLength")
	if f then
		cr_log("white", f("cr_white.snm"))
		cr_log("steps", f("cr_steps.snm"))
		cr_log("missing", f("no_such.snm"))
	end
end)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("movie_place")
