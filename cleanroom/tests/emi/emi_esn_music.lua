-- EMI's music (prefix esn; assets_emi.music and assets_emi_extra_esn.py): a state past the table, the music's position,
-- a state that loops, the music set changed while a state fades out and while one is on the stack, and (ScummVM's second
-- table, Textures/FullMonkeyMap1.imt: states 111 to 113, which Monkey4.exe does not read) a change of state within a
-- sync group, a start past the end of a looping file and a loop whose end is past the end of its file. The music plays by
-- real time on both engines: the tests wait for changes of the clock's second and log what does not depend on how far
-- the music got.

esn_mtest = function(name, fn)
	cr_test("esn_m_" .. name, function()
		cr_allow_frames(1000000000)
		%fn()
		ImSetState(0)
		ImFlushStack()
		cr_frames(2)
		cr_log("ok", 1)
	end)
end

-- a state past the end of the table (126 states), then one that is there, then past the end again
esn_mtest("high", function()
	ImSetState(200)
	cr_frames(2)
	ImSetState(1)
	esn_wait(1)
	ImSetState(200)
	esn_wait(1)
	ImSetState(1)
	esn_wait(1)
end)

-- the position of the music while a state plays
esn_mtest("msecs", function()
	ImSetState(1)
	esn_wait(1)
	local ms = ImGetMillisecondPosition(1)
	cr_log("type", type(ms))
	cr_unstable("ms")
	cr_log("ms", ms)
end)

-- a state that loops (cr_loop: from 2 s back to 0.5 s), long after its loop
cr_scummvm_differs("esn_m_looped", "ImStateHasLooped of a looping state: 1 on ScummVM, nil on the original (whose music does not seem to play here: ImGetMillisecondPosition is -1)") esn_mtest("looped", function()
	ImSetState(2)
	esn_wait(4)
	local l = ImStateHasLooped(2)
	local e = ImStateHasEnded(2)
	cr_log("looped", l)
	cr_log("ended", e)
end)

-- the music set changed while the state before fades out
esn_mtest("set_fading", function()
	ImSetState(1)
	esn_wait(1)
	ImSetState(2)
	cr_frames(2)
	ImSelectSet(1)
	cr_frames(2)
	ImSelectSet(0)
	esn_wait(1)
end)

-- the music set changed while a state is on the stack (faded out and paused there), then the state popped
esn_mtest("set_stack", function()
	ImSetState(1)
	esn_wait(1)
	ImPushState()
	esn_wait(3)
	ImSelectSet(1)
	cr_frames(2)
	ImPopState()
	esn_wait(1)
	ImSelectSet(0)
	cr_frames(2)
end)

-- states of ScummVM's second table: 111 in sync group 1 after state 1 (starts where state 1 was)
esn_mtest("sync", function()
	ImSetState(1)
	esn_wait(1)
	ImSetState(111)
	esn_wait(1)
end)

-- 112 (0.5 s, a loop) after state 1 (sync group 1: started where state 1 was, past its end)
esn_mtest("past_end", function()
	ImSetState(1)
	esn_wait(1)
	ImSetState(112)
	esn_wait(1)
end)

-- 113 (a loop past the end of its file) until the file ends, then state 1. (Without state 1 after it, ScummVM's next Save
-- crashes: the mixer deletes the looping stream at its end, and MP3Track::getPos (mp3track.cpp:211) reads it, a division
-- by zero in Audio::Timestamp::msecs from EMISound::saveTrack, emisound.cpp:1035)
esn_mtest("over_end", function()
	ImSetState(113)
	esn_wait(3)
	ImSetState(1)
	esn_wait(1)
end)

-- 114 (no file) after 2
esn_mtest("no_file", function()
	ImSetState(2)
	esn_wait(1)
	ImSetState(114)
	esn_wait(1)
end)
