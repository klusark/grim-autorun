-- Frame time: PerSecond(1000) is the frame time in ms; around set changes, chores and the first frames of a task  -- games: grim emi

cr_dt_trace = function(n)
	local s = ""
	local i = 0
	while i < n do
		s = s .. tostring(PerSecond(1000)) .. " "
		break_here()
		i = i + 1
	end
	return s
end

cr_t_frame_time = function()
	cr_log("steady", cr_dt_trace(8))
	-- (no EMI sets yet: a set that does not exist crashes the original Monkey4.exe)
	if CR_GAME == "emi" then
		return
	end
	MakeCurrentSet("cr_flat.set")
	cr_log("after_same_set", cr_dt_trace(4))
	MakeCurrentSet("cr_edge.set")
	cr_log("after_other_set", cr_dt_trace(4))
	MakeCurrentSet("cr_flat.set")
	cr_log("after_back", cr_dt_trace(4))
end
cr_test("frame_time", cr_t_frame_time)

cr_t_sleep_for = function()
	local f = 0
	CR_SLEPT = nil
	start_script(cr_t_sleeper)
	while not CR_SLEPT and f < 100 do
		break_here()
		f = f + 1
	end
	cr_log("sleep_100ms_frames", f)
end
cr_t_sleeper = function()
	sleep_for(100)
	CR_SLEPT = TRUE
end
cr_scummvm_differs("sleep_for", nil, "grim") cr_scummvm_differs("sleep_for", nil, "emi") cr_test("sleep_for", cr_t_sleep_for)
