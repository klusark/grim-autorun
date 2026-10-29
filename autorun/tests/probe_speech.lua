-- Probe (PROBE lines): how many frames a spoken line lasts, to be run on both engines (the voices must be on: NOMUTE=1 on ScummVM). Manny says some lines of
-- the first chapter one after the other, each alone, in the office; the frames are counted from the call of say_line to the first frame in which IsMessageGoing
-- is false. The original gives the lengths of the voices plus a tail; the lengths of the files are the ones of ScummVM's own run (the sound ends in its log).
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
probe_say = function(id)
	local n = 0
	manny:say_line(id)
	break_here()
	while IsMessageGoing() and n < 2000 do
		n = n + 1
		break_here()
	end
	PrintDebug("PROBE " .. id .. " frames " .. n .. "\n")
	-- (a pause between the lines, the same on both)
	local k = 0
	while k < 60 do
		k = k + 1
		break_here()
	end
end
probe_say("/moma025/")
probe_say("/momc026/")
probe_say("/moma027/")
probe_say("/moma028/")
probe_say("/moma025/")
AR_KEEP_GOING = nil
ar_finish()
