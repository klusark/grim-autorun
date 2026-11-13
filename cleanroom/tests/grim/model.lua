-- An actor with a model (cr_box.cos: cr_box.3do, no faces; a body box 0.4 x 0.3 x 1.8 m, nodes root body head arm, and the
-- Lua Variable CR_LV as component 1 with the chores of cr_luav.cos)

cr_box_actor = function(name, x, y)
	local a = LoadActor(name)
	PutActorInSet(a, "cr_flat.set")
	PutActorAt(a, x, y, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, "cr_box.cos")
	return a
end

cr_t_model_costume = function()
	MakeCurrentSet("cr_flat.set")
	local a = cr_box_actor("cr_boxer", 0, 0)
	cr_log("costume", GetActorCostume(a))
	CR_LV = 0
	cr_frames(1)
	PlayActorChore(a, 0, "cr_box.cos")
	local f = 0
	local s = ""
	while f < 80 and IsActorChoring(a, 0, FALSE, "cr_box.cos") do
		s = s .. tostring(CR_LV) .. " "
		break_here()
		f = f + 1
	end
	cr_log("keys_trace", s)
	cr_log("keys_frames", f)
	cr_log("keys_last", CR_LV)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("model_costume") cr_test("model_costume", cr_t_model_costume)

cr_node = function(key, a, n)
	local x, y, z = GetActorNodeLocation(a, n)
	cr_log(key, x, y, z)
end

cr_t_model_nodes = function()
	MakeCurrentSet("cr_flat.set")
	local a = cr_box_actor("cr_noder", 0.5, -0.5)
	cr_frames(1)
	cr_node("root", a, 0)
	cr_node("head", a, 2)
	cr_node("arm", a, 3)
	SetActorRot(a, 0, 90, 0)
	cr_frames(1)
	cr_node("head_yaw90", a, 2)
	cr_node("arm_yaw90", a, 3)
	SetActorRot(a, 20, 45, 10)
	cr_frames(1)
	cr_node("arm_tilted", a, 3)
	cr_log("rect", GetActorRect(a))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("model_nodes") cr_test("model_nodes", cr_t_model_nodes)

-- (a walks forward into b; collision as boxes (1) and as spheres (2), the size from the model)
cr_collide_case = function(key, mode, scale)
	MakeCurrentSet("cr_flat.set")
	local a = cr_box_actor("cr_mover", 0, -1)
	local b = cr_box_actor("cr_wall", 0.1, 0.5)
	SetActorFollowBoxes(a, TRUE)
	SetActorWalkRate(a, 1)
	SetActorCollisionMode(a, mode)
	SetActorCollisionMode(b, mode)
	if scale then
		SetActorCollisionScale(a, scale)
		SetActorCollisionScale(b, scale)
	end
	cr_frames(1)
	local i = 0
	while i < 90 do
		WalkActorForward(a)
		if mod(i, 15) == 0 then
			cr_pos(key .. "_f" .. i, a)
		end
		break_here()
		i = i + 1
	end
	cr_pos(key .. "_end", a)
	cr_pos(key .. "_other", b)
	SetActorCollisionMode(a, 0)
	SetActorCollisionMode(b, 0)
	PutActorInSet(a, nil)
	PutActorInSet(b, nil)
end

cr_t_model_collide = function()
	cr_collide_case("box", 1, nil)
	cr_collide_case("sphere", 2, nil)
	cr_collide_case("sphere_half", 2, 0.5)
end
cr_scummvm_differs("model_collide") cr_test("model_collide", cr_t_model_collide)
