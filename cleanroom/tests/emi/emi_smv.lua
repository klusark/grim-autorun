-- EMI's movies with the SMUSH header of the game's own movies in front of the Bink data (assets_emi_extra_smv.py): the
-- movie's subtitles, text with every byte xor 0xd2 (the offset of the Bink data, BEGINDATA, first and last frame and text
-- id per subtitle, ENDOFDATA, as the game's movies have it). Movies/smv_sub.m4b: 45 white frames (3 s), a subtitle on frames 0-15 and one on 20-40;
-- Movies/smv_latesub.m4b: one subtitle after the last frame (never shown). StartMovie(name, subtitles): with 1 the subtitles are shown.
-- (The original's EMI has no screenshot in the clean room: what the Lua sees is compared. StopMovie while a movie plays
-- crashes the original (emi_movie.lua): the movies stop by themselves.)

-- (n changes of the clock's second: between n - 1 and n seconds)
emi_smv_wait_s = function(n)
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
emi_smv_wait_end = function(n)
	local s = date("%S")
	while n > 0 and IsMoviePlaying() do
		break_here()
		local t = date("%S")
		if t ~= s then
			s = t
			n = n - 1
			PrintDebug("wait\n")
		end
	end
	return not IsMoviePlaying()
end

emi_smv_test = function(name, fn)
	cr_test("emi_smv_" .. name, function()
		cr_allow_frames(1000000000)
		%fn()
		emi_smv_wait_end(10)
		cr_frames(2)
	end)
end

-- with the subtitles shown: at once, after 1-2 s (the second subtitle), whether it ends
emi_smv_test("sub", function()
	cr_log("start", StartMovie("smv_sub", 1))
	cr_log("playing_at_once", IsMoviePlaying())
	emi_smv_wait_s(2)
	cr_log("playing", IsMoviePlaying())
	cr_log("ended", emi_smv_wait_end(10))
	cr_frames(3)
	cr_log("after", IsMoviePlaying())
end)

-- the same without them
emi_smv_test("sub_hidden", function()
	cr_log("start", StartMovie("smv_sub"))
	cr_log("playing_at_once", IsMoviePlaying())
	cr_log("ended", emi_smv_wait_end(10))
end)

-- a subtitle after the movie's last frame
emi_smv_test("latesub", function()
	cr_log("start", StartMovie("smv_latesub", 1))
	cr_log("playing_at_once", IsMoviePlaying())
	cr_log("ended", emi_smv_wait_end(10))
end)
