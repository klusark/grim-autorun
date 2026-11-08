-- EMI's costumes (assets_emi.costumes: formats.cosb, sklb, meshb, animb). cr_lv.cos has Lua Variable tracks only (CR_LV);
-- cr_ebox.cos a skeleton, a mesh on it and an animation. A chore is played by name: PlayActorChore(actor, name, costume,
-- looping, fade) gives its handle (IsChorePlaying, IsChoreLooping). The original's EMI has no picture of the screen in
-- the clean room: what is seen is CR_LV and what the chore builtins give.

-- (Monkey4.exe has no SetActorCostume: PlayActorChore puts the costume it names on the actor)
cr_ec_actor = function()
	local a = cr_ea_actor("cr_flat.set")
	CR_LV = 0
	return a
end

-- (CR_LV and IsChorePlaying every frame, n frames, as one string)
cr_ec_trace = function(c, n)
	local s = ""
	local f = 0
	while f < n do
		s = s .. tostring(CR_LV) .. "/" .. tostring(IsChorePlaying(c)) .. " "
		break_here()
		f = f + 1
	end
	return s
end

cr_scummvm_differs("ec_load", "a chore handle is a number on the original, userdata on ScummVM; a missing chore gives 2 against nil")
cr_test("ec_load", function()
	local a = cr_ec_actor()
	local c = PlayActorChore(a, "keys", "cr_lv.cos")
	cr_log("handle", type(c), IsChoreValid(c), IsChorePlaying(c), IsChoreLooping(c))
	cr_log("missing", PlayActorChore(a, "no_such_chore", "cr_lv.cos"))
	StopActorChores(a)
	PutActorInSet(a, nil)
end)

-- the keys of a chore, frame by frame (1 s: about 60 frames of 17 ms)
cr_test("ec_keys", function()
	local a = cr_ec_actor()
	local c = PlayActorChore(a, "keys", "cr_lv.cos")
	cr_log("trace", cr_ec_trace(c, 70))
	cr_log("after", CR_LV, IsChorePlaying(c))
	StopActorChores(a)
	PutActorInSet(a, nil)
end)

-- a chore shorter than a frame
cr_test("ec_short", function()
	local a = cr_ec_actor()
	local c = PlayActorChore(a, "short", "cr_lv.cos")
	cr_log("trace", cr_ec_trace(c, 6))
	StopActorChores(a)
	PutActorInSet(a, nil)
end)

-- looping (the fourth argument), then stopped
cr_test("ec_loop", function()
	local a = cr_ec_actor()
	local c = PlayActorChore(a, "loop", "cr_lv.cos", 1)
	cr_log("looping", IsChoreLooping(c))
	cr_log("trace", cr_ec_trace(c, 45))
	StopChore(c)
	cr_frames(1)
	cr_log("stopped", CR_LV, IsChorePlaying(c))
	StopActorChores(a)
	PutActorInSet(a, nil)
end)

-- a chore of length 1000 (no end)
cr_test("ec_endless", function()
	local a = cr_ec_actor()
	local c = PlayActorChore(a, "endless", "cr_lv.cos")
	cr_frames(90)
	cr_log("after_90", CR_LV, IsChorePlaying(c))
	StopActorChores(a)
	cr_frames(1)
	cr_log("stopped", IsChorePlaying(c))
	PutActorInSet(a, nil)
end)

-- what the actor plays (GetActorChores) while two chores run
cr_test("ec_actor_chores", function()
	local a = cr_ec_actor()
	PlayActorChore(a, "endless", "cr_lv.cos")
	PlayActorChore(a, "keys", "cr_lv.cos")
	cr_frames(2)
	local t = GetActorChores(a)
	cr_log("chores", type(t))
	StopActorChores(a)
	PutActorInSet(a, nil)
end)

-- the skeleton, mesh and animation costume: worn, then the lift
cr_scummvm_differs("ec_box", "a chore handle is a number on the original, userdata on ScummVM")
cr_test("ec_box", function()
	local a = cr_ec_actor()
	local w = PlayActorChore(a, "wear_default", "cr_ebox.cos")
	cr_frames(2)
	cr_log("wear", type(w), IsChorePlaying(w))
	local c = PlayActorChore(a, "lift", "cr_ebox.cos")
	cr_log("trace", cr_ec_trace(c, 70))
	cr_log("after", CR_LV, IsChorePlaying(c), IsChorePlaying(w))
	StopActorChores(a)
	PutActorInSet(a, nil)
end)
