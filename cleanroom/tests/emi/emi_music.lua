-- EMI's music (assets_emi.music: Textures/FullMonkeyMap.imt and MP3 music files of silence, formats.emi_music): states
-- 1 to 110 name two files, A\cr_one.m4b (3 s, no loop) and A\cr_loop.m4b (3 s, a .jmm loop from 2 s back to 0.5 s);
-- odd states are in sync group 1, even ones in 2. ImSetState, ImPushState / ImPopState, ImSelectSet (the music set:
-- 0 Textures/spago, 1 Textures/mego), ImFlushStack, for seconds of the clock (the music plays by real time on both).

-- (n changes of the clock's second)
cr_em_wait = function(n)
	local s = date("%S")
	while n > 0 do
		break_here()
		local t = date("%S")
		if t ~= s then
			s = t
			n = n - 1
		end
	end
end

cr_em_test = function(name, fn)
	cr_test("em_" .. name, function()
		cr_allow_frames(1000000000)
		%fn()
		ImSetState(0)
		ImFlushStack()
		cr_frames(2)
		cr_log("ok", 1)
	end)
end

-- one state, then another of the same sync group, then one of the other group
cr_scummvm_differs("em_states", "ImStateHasEnded / ImStateHasLooped of a state that never played: 128 on the original, 1 on ScummVM")
cr_em_test("states", function()
	ImSetState(1)
	cr_em_wait(2)
	ImSetState(3)
	cr_em_wait(1)
	ImSetState(2)
	cr_em_wait(2)
	cr_log("ended_never_played", ImStateHasEnded(5), ImStateHasLooped(5))
end)

-- a state that loops (cr_loop), for longer than its loop
cr_em_test("loop", function()
	ImSetState(2)
	cr_em_wait(4)
end)

-- the state stack
cr_em_test("stack", function()
	ImSetState(1)
	cr_em_wait(1)
	ImPushState()
	ImSetState(2)
	cr_em_wait(1)
	ImPopState()
	cr_em_wait(1)
	ImPushState()
	ImPushState()
	ImFlushStack()
	cr_em_wait(1)
end)

-- the other music set (Textures/mego), while a state plays, and back
cr_em_test("set", function()
	ImSetState(1)
	cr_em_wait(1)
	ImSelectSet(1)
	cr_em_wait(1)
	ImSelectSet(0)
	cr_em_wait(1)
end)

-- the music's volume while it plays
cr_em_test("volume", function()
	local v = ImGetMusicVol()
	ImSetState(1)
	cr_em_wait(1)
	ImSetMusicVol(20)
	cr_em_wait(1)
	ImSetMusicVol(v or 127)
end)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("em_volume")
