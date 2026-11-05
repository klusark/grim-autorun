-- Edge cases: the original's watchdog for scripts that never yield, text files, script control with odd arguments,
-- a model actor at the walls, a walk rate changed while walking

-- (the original kills a script that runs "a really long time" without break_here; how many loop steps are allowed)
cr_long_loop = function(n)
	local i = 0
	local x = 0
	while i < n do
		x = x + 1
		i = i + 1
	end
	return x
end

cr_t_loop_100k = function()
	cr_log("done", cr_long_loop(100000))
end
cr_test("loop_100k", cr_t_loop_100k)

cr_t_loop_1m = function()
	cr_log("done", cr_long_loop(1000000))
end
cr_test("loop_1m", cr_t_loop_1m)

cr_t_loop_5m = function()
	cr_log("done", cr_long_loop(5000000))
end
cr_test("loop_5m", cr_t_loop_5m)

-- (cr_lines.txt is in the game folder: 3 lines)
cr_t_text_file = function()
	cr_log("count", TextFileGetLineCount("cr_lines.txt"))
	cr_log("line0", TextFileGetLine("cr_lines.txt", 0))
	cr_log("line_at_6", TextFileGetLine("cr_lines.txt", 6))
	cr_log("missing_count", TextFileGetLineCount("cr_no_such.txt"))
	cr_log("missing_line", TextFileGetLine("cr_no_such.txt", 0))
end
cr_test("text_file", cr_t_text_file)

cr_t_script_odd = function()
	cr_log("find_nil", find_script(nil))
	cr_log("find_number", find_script(123456))
	cr_log("find_fn_not_running", find_script(cr_t_script_odd_never))
	local id = start_script(cr_t_script_odd_wait)
	cr_log("find_fn_running", find_script(cr_t_script_odd_wait) ~= nil)
	stop_script(id)
	stop_script(123456)
	cr_log("identify_bad", identify_script(123456))
	cr_log("after", 1)
end
cr_t_script_odd_never = function()
end
cr_t_script_odd_wait = function()
	while TRUE do
		break_here()
	end
end
cr_test("script_odd", cr_t_script_odd)

-- (an actor with the model costume walks forward into the outer wall of cr_flat, collision mode off and box)
cr_model_wall = function(key, mode)
	MakeCurrentSet("cr_flat.set")
	local a = LoadActor("cr_waller" .. key)
	PutActorInSet(a, "cr_flat.set")
	PutActorAt(a, 1, 0, 0)
	SetActorRot(a, 0, 290, 0)
	SetActorFollowBoxes(a, TRUE)
	SetActorCostume(a, "cr_box.cos")
	SetActorCollisionMode(a, mode)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	local i = 0
	while i < 60 do
		WalkActorForward(a)
		if mod(i, 15) == 0 then
			cr_pos(key .. "_f" .. i, a)
		end
		break_here()
		i = i + 1
	end
	cr_pos(key .. "_end", a)
	SetActorCollisionMode(a, 0)
	PutActorInSet(a, nil)
end

cr_t_model_wall = function()
	cr_model_wall("off", 0)
	cr_model_wall("box", 1)
end
cr_test("model_wall", cr_t_model_wall)

cr_t_walk_rate_change = function()
	cr_actor_global("cr_flat.set")
	SetActorWalkRate(CR_A, 1)
	cr_frames(1)
	WalkActorTo(CR_A, 1.8, 0, 0)
	cr_frames(20)
	cr_pos("at_20", CR_A)
	SetActorWalkRate(CR_A, 3)
	cr_frames(10)
	cr_pos("at_30", CR_A)
	SetActorWalkRate(CR_A, 0)
	cr_frames(10)
	cr_pos("at_40_rate0", CR_A)
	cr_log("moving_rate0", IsActorMoving(CR_A))
	SetActorWalkRate(CR_A, 1)
	cr_frames(60)
	cr_pos("end", CR_A)
end
cr_test("walk_rate_change", cr_t_walk_rate_change)
