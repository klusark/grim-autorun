-- Chores of a costume without a model (cr_luav.cos: one Lua Variable component; CR_LV is set when a key is reached)
-- Chores: 0 keys (1000 ms; keys 0 100 250 1000), 1 short (50 ms), 2 loop (300 ms; keys 0 150), 3 zero (0 ms)

cr_costume_actor = function()
	MakeCurrentSet("cr_flat.set")
	local a = LoadActor("cr_chorer")
	PutActorInSet(a, "cr_flat.set")
	PutActorAt(a, 0, 0, 0)
	SetActorCostume(a, "cr_luav.cos")
	CR_LV = 0
	return a
end

-- (CR_LV and IsActorChoring every frame while the chore plays, at most max frames)
cr_follow_chore = function(a, chore, max, key)
	local f = 0
	local s = ""
	while f < max and IsActorChoring(a, chore, FALSE, "cr_luav.cos") do
		s = s .. tostring(CR_LV) .. "/" .. tostring(PerSecond(1000)) .. " "
		break_here()
		f = f + 1
	end
	cr_log(key .. "_trace", s)
	cr_log(key .. "_frames", f)
	cr_log(key .. "_last", CR_LV)
end

cr_t_chore_keys = function()
	local a = cr_costume_actor()
	cr_log("costume", GetActorCostume(a))
	cr_frames(1)
	PlayActorChore(a, 0, "cr_luav.cos")
	cr_log("at_once", CR_LV, IsActorChoring(a, 0, FALSE, "cr_luav.cos"))
	cr_follow_chore(a, 0, 120, "keys")
end
cr_test("chore_keys", cr_t_chore_keys)

cr_t_chore_short = function()
	local a = cr_costume_actor()
	cr_frames(1)
	PlayActorChore(a, 1, "cr_luav.cos")
	cr_follow_chore(a, 1, 30, "short")
	PlayActorChore(a, 3, "cr_luav.cos")
	cr_log("zero_at_once", CR_LV, IsActorChoring(a, 3, FALSE, "cr_luav.cos"))
	cr_follow_chore(a, 3, 30, "zero")
end
cr_test("chore_short", cr_t_chore_short)

cr_t_chore_loop = function()
	local a = cr_costume_actor()
	cr_frames(1)
	PlayActorChoreLooping(a, 2, "cr_luav.cos")
	local f = 0
	local s = ""
	while f < 45 do
		s = s .. tostring(CR_LV) .. " "
		break_here()
		f = f + 1
	end
	cr_log("trace", s)
	cr_log("choring", IsActorChoring(a, 2, FALSE, "cr_luav.cos"))
	StopActorChore(a, 2, "cr_luav.cos")
	cr_log("after_stop", IsActorChoring(a, 2, FALSE, "cr_luav.cos"))
	CR_LV = 0
	PlayActorChore(a, 0, "cr_luav.cos")
	cr_frames(2)
	CompleteActorChore(a, 0, "cr_luav.cos")
	cr_log("completed", CR_LV, IsActorChoring(a, 0, FALSE, "cr_luav.cos"))
	cr_frames(1)
	cr_log("completed_next", CR_LV, IsActorChoring(a, 0, FALSE, "cr_luav.cos"))
end
cr_test("chore_loop", cr_t_chore_loop)
