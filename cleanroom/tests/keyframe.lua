-- Keyframe animation (cr_kbox.cos: the drawn box of draw.lua with cr_slide.key, which slides the body node 1 m to +x and
-- turns it 90 degrees over 2 s, 30 frames at 15 a second; markers at frames 10 and 20). The chores start the keyframe in
-- each of its modes (chores 0 to 5 of cr_kbox.cos: slide_once, slide_loop, slide_hold, slide_fade, slide_stop, slide_late) (the key values of a keyframe component: 0 once, 1 looping, 2 pause at the end, 3 fade at the end,
-- 4 stop). Seen through the location of the body node and of its child, the head (GetActorNodeLocation: world positions for
-- a text model on the original) and through cr_snap.

cr_kf_actor = function()
	MakeCurrentSet("cr_open.set")
	local a = LoadActor("cr_kf_a")
	PutActorInSet(a, "cr_open.set")
	PutActorAt(a, -1, 0, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, "cr_kbox.cos")
	cr_frames(2)
	return a
end

cr_kf_nodes = function(key, a)
	local x, y, z = GetActorNodeLocation(a, 1)
	cr_log(key .. "_body", x, y, z)
	x, y, z = GetActorNodeLocation(a, 2)
	cr_log(key .. "_head", x, y, z)
end

-- (the nodes every `step` frames for `n` steps, and whether the chore still plays)
cr_kf_watch = function(key, a, chore, n, step)
	local i = 0
	while i < n do
		cr_kf_nodes(key .. "_" .. i * step, a)
		cr_log(key .. "_" .. i * step .. "_playing", IsActorChoring(a, chore, FALSE, "cr_kbox.cos"))
		cr_frames(step)
		i = i + 1
	end
end

cr_kf_test = function(name, fn)
	cr_test("kf_" .. name, function()
		local a = cr_kf_actor()
		%fn(%name, a)
		StopActorChore(a)
		PutActorInSet(a, nil)
	end)
end

cr_kf_test("rest", function(k, a)
	cr_kf_nodes(k, a)
	cr_snap(k .. "_box")
end)

cr_kf_test("once", function(k, a)
	PlayActorChore(a, 0, "cr_kbox.cos")
	cr_kf_watch(k, a, 0, 8, 20)
	cr_snap(k .. "_box")
end)

cr_kf_test("loop", function(k, a)
	PlayActorChore(a, 1, "cr_kbox.cos")
	cr_kf_watch(k, a, 1, 9, 20)
end)

cr_kf_test("looping_chore", function(k, a)
	PlayActorChoreLooping(a, 0, "cr_kbox.cos")
	cr_kf_watch(k, a, 0, 9, 20)
end)

cr_kf_test("hold", function(k, a)
	PlayActorChore(a, 2, "cr_kbox.cos")
	cr_kf_watch(k, a, 2, 8, 20)
	cr_snap(k .. "_box")
end)

cr_kf_test("fade_end", function(k, a)
	PlayActorChore(a, 3, "cr_kbox.cos")
	cr_kf_watch(k, a, 3, 8, 20)
end)

cr_kf_test("stopped", function(k, a)
	PlayActorChore(a, 1, "cr_kbox.cos")
	cr_frames(40)
	PlayActorChore(a, 4, "cr_kbox.cos")
	cr_kf_watch(k, a, 4, 4, 10)
end)

cr_kf_test("stop_chore", function(k, a)
	PlayActorChore(a, 1, "cr_kbox.cos")
	cr_frames(40)
	StopActorChore(a, 1, "cr_kbox.cos")
	cr_kf_watch(k, a, 1, 4, 10)
end)

cr_kf_test("complete", function(k, a)
	PlayActorChore(a, 0, "cr_kbox.cos")
	cr_frames(10)
	CompleteActorChore(a, 0, "cr_kbox.cos")
	cr_kf_watch(k, a, 0, 4, 10)
end)

cr_kf_test("late", function(k, a)
	CR_LV = nil
	PlayActorChore(a, 5, "cr_kbox.cos")
	local i = 0
	while i < 8 do
		cr_log(k .. "_lv_" .. i * 20, CR_LV)
		cr_kf_nodes(k .. "_" .. i * 20, a)
		cr_frames(20)
		i = i + 1
	end
end)

cr_kf_test("fade_in", function(k, a)
	FadeInChore(a, "cr_kbox.cos", 1, 1000)
	cr_kf_watch(k, a, 1, 6, 15)
end)

cr_kf_test("fade_out", function(k, a)
	PlayActorChore(a, 1, "cr_kbox.cos")
	cr_frames(30)
	FadeOutChore(a, "cr_kbox.cos", 1, 1000)
	cr_kf_watch(k, a, 1, 6, 15)
end)

cr_kf_test("time_scale", function(k, a)
	SetActorTimeScale(a, 2)
	PlayActorChore(a, 0, "cr_kbox.cos")
	cr_kf_watch(k, a, 0, 5, 15)
	SetActorTimeScale(a, 1)
end)

cr_kf_test("chores", function(k, a)
	PlayActorChore(a, 1, "cr_kbox.cos")
	cr_frames(5)
	cr_log(k .. "_list", type(GetActorChores(a)))
	cr_log(k .. "_any", IsActorChoring(a))
	cr_log(k .. "_other", IsActorChoring(a, 0, FALSE, "cr_kbox.cos"))
end)

-- the markers of the keyframe: the engine calls system.costumeMarkerHandler(system, actor, marker)
cr_kf_test("markers", function(k, a)
	cr_log(k .. "_system", type(system))
	if type(system) ~= "table" then
		system = { }
	end
	CR_MARKS = ""
	system.costumeMarkerHandler = function(self, actor, marker)
		CR_MARKS = CR_MARKS .. " " .. tostring(marker)
	end
	PlayActorChore(a, 0, "cr_kbox.cos")
	cr_frames(150)
	cr_log(k .. "_seen", CR_MARKS)
	system.costumeMarkerHandler = nil
end)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("kf_chores")
cr_scummvm_differs("kf_complete")
cr_scummvm_differs("kf_fade_end")
cr_scummvm_differs("kf_fade_in")
cr_scummvm_differs("kf_fade_out")
cr_scummvm_differs("kf_hold")
cr_scummvm_differs("kf_late")
cr_scummvm_differs("kf_loop")
cr_scummvm_differs("kf_looping_chore")
cr_scummvm_differs("kf_once")
cr_scummvm_differs("kf_rest")
cr_scummvm_differs("kf_stop_chore")
cr_scummvm_differs("kf_stopped")
cr_scummvm_differs("kf_time_scale")
