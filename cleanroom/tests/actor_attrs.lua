-- Actor attributes: setters and getters, costume stacks, chores of an actor, head and looking, walking variants

-- (a builtin by name: nil and a "missing" value when the engine has none, so that the gap is a difference, not an error)
cr_nothing = function()
end

cr_fn = function(name)
	local f = getglobal(name)
	if type(f) ~= "function" and type(f) ~= "cfunction" then
		cr_log("missing_" .. name, 1)
		return nil
	end
	return f
end

-- (an actor in cr_flat with the model costume, following the boxes)
cr_attr_actor = function(name)
	MakeCurrentSet("cr_flat.set")
	local a = LoadActor(name)
	PutActorInSet(a, "cr_flat.set")
	PutActorAt(a, 0, 0, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorFollowBoxes(a, TRUE)
	SetActorCostume(a, "cr_box.cos")
	return a
end

cr_t_attr_scale = function()
	local a = cr_attr_actor("cr_attr1")
	SetActorScale(a, 2)
	local f = cr_fn("GetActorScale")
	if f then
		cr_log("scale", f(a))
	end
	SetActorScale(a, 0.5)
	if f then
		cr_log("scale_half", f(a))
	end
	SetActorTimeScale(a, 0.5)
	cr_log("timescale", GetActorTimeScale(a))
	SetActorTimeScale(a, 1)
	cr_log("timescale_back", GetActorTimeScale(a))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("attr_scale") cr_test("attr_scale", cr_t_attr_scale)

cr_t_attr_rot_parts = function()
	local a = cr_attr_actor("cr_attr2")
	SetActorPitch(a, 15)
	local p, y, r = GetActorRot(a)
	cr_log("pitch", p, y, r)
	SetActorRoll(a, -10)
	p, y, r = GetActorRot(a)
	cr_log("roll", p, y, r)
	SetActorPitch(a, 400)
	p, y, r = GetActorRot(a)
	cr_log("pitch_wrap", p, y, r)
	PutActorInSet(a, nil)
end
cr_test("attr_rot_parts", cr_t_attr_rot_parts)

cr_t_attr_rates = function()
	local a = cr_attr_actor("cr_attr3")
	SetActorTurnRate(a, 123)
	local f = cr_fn("GetActorTurnRate")
	if f then
		cr_log("turn_rate", f(a))
	end
	SetActorLookRate(a, 77)
	cr_log("look_rate", GetActorLookRate(a))
	SetActorWalkRate(a, -1)
	cr_log("walk_rate_negative", GetActorWalkRate(a))
	SetActorWalkRate(a, 0)
	cr_log("walk_rate_zero", GetActorWalkRate(a))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("attr_rates") cr_test("attr_rates", cr_t_attr_rates)

cr_t_attr_talk_color = function()
	local a = cr_attr_actor("cr_attr4")
	cr_log("default", type(GetActorTalkColor(a)))
	SetActorTalkColor(a, MakeColor(10, 20, 30))
	local r, g, b = GetColorComponents(GetActorTalkColor(a))
	cr_log("set", r, g, b)
	PutActorInSet(a, nil)
end
cr_test("attr_talk_color", cr_t_attr_talk_color)

cr_t_attr_constrain = function()
	local a = cr_attr_actor("cr_attr5")
	local f = cr_fn("GetActorConstrain")
	if f then
		cr_log("default", f(a))
	end
	SetActorConstrain(a, TRUE)
	if f then
		cr_log("on", f(a))
	end
	SetActorConstrain(a, FALSE)
	if f then
		cr_log("off", f(a))
	end
	PutActorInSet(a, nil)
end
cr_test("attr_constrain", cr_t_attr_constrain)

cr_t_costume_stack = function()
	local a = cr_attr_actor("cr_attr6")
	cr_log("depth1", GetActorCostumeDepth(a))
	PushActorCostume(a, "cr_luav.cos")
	cr_log("depth2", GetActorCostumeDepth(a))
	cr_log("top", GetActorCostume(a))
	cr_log("by_index0", GetActorCostume(a, 0), GetActorCostume(a, 1))
	cr_log("pop", PopActorCostume(a))
	cr_log("depth_after_pop", GetActorCostumeDepth(a))
	cr_log("top_after_pop", GetActorCostume(a))
	cr_log("pop_last", PopActorCostume(a))
	cr_log("pop_empty", PopActorCostume(a))
	cr_log("depth_empty", GetActorCostumeDepth(a))
	cr_log("load", type(LoadCostume("cr_luav.cos")), type(LoadCostume("no_such.cos")))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("costume_stack") cr_test("costume_stack", cr_t_costume_stack)

cr_t_actor_chores = function()
	local a = cr_attr_actor("cr_attr7")
	PlayActorChore(a, 0, "cr_box.cos")
	PlayActorChoreLooping(a, 2, "cr_box.cos")
	cr_frames(2)
	local f = cr_fn("GetActorChores")
	if f then
		local t = f(a)
		cr_log("chores_type", type(t))
	end
	local g = cr_fn("GetActorLoopingChores")
	if g then
		cr_log("looping_type", type(g(a)))
	end
	cr_log("choring_any", IsActorChoring(a, nil, FALSE, "cr_box.cos"))
	cr_log("choring_excl_loop", IsActorChoring(a, nil, TRUE, "cr_box.cos"))
	SetActorChoreLooping(a, 2, FALSE, "cr_box.cos")
	cr_frames(20)
	cr_log("loop_off_after_20", IsActorChoring(a, 2, FALSE, "cr_box.cos"))
	StopActorChore(a, nil, "cr_box.cos")
	cr_log("stopped_all", IsActorChoring(a, nil, FALSE, "cr_box.cos"))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("actor_chores") cr_test("actor_chores", cr_t_actor_chores)

cr_t_chore_fade = function()
	local a = cr_attr_actor("cr_attr8")
	CR_LV = 0
	FadeInChore(a, "cr_box.cos", 0, 200)
	cr_frames(3)
	cr_log("fade_in_choring", IsActorChoring(a, 0, FALSE, "cr_box.cos"), CR_LV)
	FadeOutChore(a, "cr_box.cos", 0, 100)
	cr_frames(10)
	cr_log("fade_out_choring", IsActorChoring(a, 0, FALSE, "cr_box.cos"), CR_LV)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("chore_fade") cr_test("chore_fade", cr_t_chore_fade)

-- (the walk chore is chore 2 of cr_box.cos, the looping one: CR_LV follows it while the actor walks)
cr_t_walk_chore = function()
	local a = cr_attr_actor("cr_attr9")
	SetActorWalkChore(a, 2, "cr_box.cos")
	SetActorRestChore(a, 1, "cr_box.cos")
	SetActorWalkRate(a, 1)
	CR_LV = 0
	cr_frames(2)
	cr_log("resting", CR_LV, IsActorResting(a))
	WalkActorTo(a, 1, 0, 0)
	local s = ""
	local i = 0
	while i < 70 do
		s = s .. tostring(CR_LV) .. " "
		break_here()
		i = i + 1
	end
	cr_log("trace", s)
	cr_log("after", CR_LV, IsActorMoving(a), IsActorResting(a))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("walk_chore") cr_test("walk_chore", cr_t_walk_chore)

-- (the zero-length chore as the rest chore: this hung the original)
cr_t_rest_chore_zero = function()
	local a = cr_attr_actor("cr_attr19")
	SetActorRestChore(a, 3, "cr_box.cos")
	cr_frames(3)
	cr_log("resting", IsActorResting(a))
	PutActorInSet(a, nil)
end
cr_test("rest_chore_zero", cr_t_rest_chore_zero)

cr_t_turn_chores = function()
	local a = cr_attr_actor("cr_attr10")
	SetActorTurnChores(a, 0, 1, "cr_box.cos")
	SetActorTurnRate(a, 60)
	CR_LV = 0
	cr_frames(1)
	local s = ""
	local i = 0
	while i < 20 do
		TurnActor(a, 1)
		s = s .. tostring(CR_LV) .. " "
		break_here()
		i = i + 1
	end
	cr_log("left_trace", s)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("turn_chores") cr_test("turn_chores", cr_t_turn_chores)

-- (the head: joints 1 2 2 of cr_box.3do (body, head, head); the head looks at a point)
cr_t_head_look = function()
	local a = cr_attr_actor("cr_attr11")
	SetActorHead(a, 1, 2, 2, 30, 30, 80)
	SetActorLookRate(a, 200)
	ActorLookAt(a, 1, 1, 1.7, 200)
	CR_LOOKING = cr_fn("IsActorLooking") or cr_nothing
	cr_log("looking_at_once", CR_LOOKING(a))
	cr_frames(10)
	cr_log("looking_after_10", CR_LOOKING(a))
	ActorLookAt(a, nil)
	cr_frames(10)
	cr_log("looking_released", CR_LOOKING(a))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("head_look") cr_test("head_look", cr_t_head_look)

cr_t_visibility = function()
	local a = cr_attr_actor("cr_attr12")
	SetActorVisibility(a, FALSE)
	cr_frames(1)
	local t = GetVisibleThings()
	cr_log("visible_things_type", type(t))
	SetActorVisibility(a, TRUE)
	SetActorReflection(a, 80)
	SetActorFrustrumCull(a, TRUE)
	ActorPuckOrient(a, TRUE)
	SetActorWalkDominate(a, TRUE)
	cr_frames(1)
	cr_pos("after_flags", a)
	ActorPuckOrient(a, FALSE)
	SetActorWalkDominate(a, nil)
	PutActorInSet(a, nil)
end
cr_test("visibility", cr_t_visibility)

cr_t_put_at_interest = function()
	local a = cr_attr_actor("cr_attr13")
	PutActorAt(a, 1, 1, 0)
	PutActorAtInterest(a)
	cr_pos("at_interest", a)
	local f = cr_fn("PutActorAtOrigin")
	if f then
		PutActorAt(a, 1, 1, 0)
		f(a)
		cr_pos("at_origin", a)
	end
	PutActorInSet(a, nil)
end
cr_scummvm_differs("put_at_interest") cr_test("put_at_interest", cr_t_put_at_interest)

cr_t_drive = function()
	local a = cr_attr_actor("cr_attr14")
	SetActorWalkRate(a, 1)
	SetActorTurnRate(a, 90)
	cr_frames(1)
	local i = 0
	while i < 40 do
		DriveActorTo(a, 1, 1, 0)
		if mod(i, 10) == 0 then
			cr_pos("f" .. i, a)
		end
		break_here()
		i = i + 1
	end
	cr_pos("end", a)
	local p, y, r = GetActorRot(a)
	cr_log("end_yaw", y)
	PutActorInSet(a, nil)
end
cr_test("drive", cr_t_drive)

cr_t_walk_avoiding = function()
	local a = cr_attr_actor("cr_attr15")
	local b = cr_attr_actor("cr_attr16")
	PutActorAt(b, 0.5, 0.5, 0)
	SetActorWalkRate(a, 1)
	cr_frames(1)
	WalkActorToAvoiding(a, b, 1, 1, 0)
	cr_frames(60)
	cr_pos("after_60", a)
	PutActorInSet(a, nil)
	PutActorInSet(b, nil)
end
cr_scummvm_differs("walk_avoiding") cr_test("walk_avoiding", cr_t_walk_avoiding)

cr_t_selected_actor = function()
	local a = cr_attr_actor("cr_attr17")
	SetSelectedActor(a)
	cr_frames(1)
	cr_log("ok", 1)
	ShutUpActor(a)
	cr_log("message_going", IsMessageGoing())
	PutActorInSet(a, nil)
end
cr_test("selected_actor", cr_t_selected_actor)

cr_t_clip = function()
	local a = cr_attr_actor("cr_attr18")
	SetActorClipPlane(a, 1, 0, 0, 0.5, 0, 0)
	SetActorClipActive(a, TRUE)
	cr_frames(1)
	SetActorClipActive(a, FALSE)
	SetActorInvClipNode(a, 2)
	cr_frames(1)
	cr_log("ok", 1)
	PutActorInSet(a, nil)
end
cr_test("clip", cr_t_clip)
