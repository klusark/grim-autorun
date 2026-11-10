-- The rest of actor.cpp's corners in Grim (prefix amc_):
-- * the collisions of a walk that needs a path (cr_ell: from ell_a to ell_c round the corner, through ell_b): each point
--   the path goes through is moved off the sphere of every other actor in the set (Actor::handleCollisionTo,
--   getTangentPos), whatever the other's collision mode is (off: not moved), with or without a costume;
-- * the small error paths: a colormap on an actor without a costume, a costume put on over another, an actor drawn into
--   the clean buffer (ActorToClean) and put in a set again, the shadow's "valid" flag and a shadow point under the plane
--   (seen through cr_snap(key, "dark")).

AMC_ELL = "cr_ell.set"

amc_put = function(name, set, x, y)
	local a = LoadActor(name)
	PutActorInSet(a, set)
	PutActorAt(a, x, y, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorFollowBoxes(a, TRUE)
	return a
end

amc_moving = function()
	return not IsActorMoving(AMC_W)
end

-- the walker (sphere or box) walks from (x0, y0) to (x1, y1); the other actor stands at (ox, oy) with collision mode omode
-- and costume ocos (nil: none)
amc_path_case = function(key, wmode, omode, ocos, ox, oy, x0, y0, x1, y1)
	MakeCurrentSet(AMC_ELL)
	local w = amc_put("amc_walker", AMC_ELL, x0, y0)
	AMC_W = w
	SetActorCostume(w, "cr_box.cos")
	SetActorWalkRate(w, 1)
	SetActorCollisionMode(w, wmode)
	SetActorCollisionScale(w, 0.3)
	local o = amc_put("amc_other", AMC_ELL, ox, oy)
	if ocos then
		SetActorCostume(o, ocos)
	end
	SetActorCollisionMode(o, omode)
	SetActorCollisionScale(o, 0.3)
	cr_frames(1)
	WalkActorTo(w, x1, y1, 0)
	local i = 0
	while i < 5 do
		cr_frames(20)
		cr_pos(key .. "_f" .. (i + 1) * 20, w)
		i = i + 1
	end
	local f = cr_until(amc_moving, 200)
	cr_log(key .. "_frames", f)
	cr_pos(key .. "_end", w)
	cr_pos(key .. "_other", o)
	SetActorCollisionMode(w, 0)
	SetActorCollisionMode(o, 0)
	SetActorCollisionScale(w, 1)
	SetActorCollisionScale(o, 1)
	SetActorCostume(w, nil)
	SetActorCostume(o, nil)
	PutActorInSet(w, nil)
	PutActorInSet(o, nil)
end

-- the other actor beside the first leg of the path (from (-1, -1) to the corner): the leg passes through its sphere
cr_scummvm_differs("amc_path_sphere", "the walker does not go round the other actor's sphere (moveTo, as cm_to_m2_w2)") cr_test("amc_path_sphere", function()
	amc_path_case("sphere", 2, 2, "cr_box.cos", -0.55, -0.35, -1, -1, 1, 1)
end)

-- the same with a box walker and a box obstacle (the mode of the other only says whether it counts)
cr_scummvm_differs("amc_path_box", "the path round the corner differs (as path_corner)") cr_test("amc_path_box", function()
	amc_path_case("box", 1, 1, "cr_box.cos", -0.55, -0.35, -1, -1, 1, 1)
end)

-- the other actor's collisions off: the path is not moved
cr_scummvm_differs("amc_path_other_off", "the path round the corner differs (as path_corner)") cr_test("amc_path_other_off", function()
	amc_path_case("off", 2, 0, "cr_box.cos", -0.55, -0.35, -1, -1, 1, 1)
end)

-- the other actor without a costume (no sphere)
cr_scummvm_differs("amc_path_other_nocos", "the path round the corner differs (as path_corner)") cr_test("amc_path_other_nocos", function()
	amc_path_case("nocos", 2, 2, nil, -0.55, -0.35, -1, -1, 1, 1)
end)

-- the other actor far from the path (in ell_b's far corner)
cr_scummvm_differs("amc_path_far", "the path round the corner differs (as path_corner)") cr_test("amc_path_far", function()
	amc_path_case("far", 2, 2, "cr_box.cos", 1.7, -1.7, -1.5, -0.5, 1, 1.5)
end)

-- the way back, from ell_c to ell_a, past the other actor near the corner in ell_b
cr_scummvm_differs("amc_path_back", "the path round the corner and the collision differ") cr_test("amc_path_back", function()
	amc_path_case("back", 2, 2, "cr_box.cos", 0.5, -0.5, 1.5, 1.5, -1.5, -1)
end)

-- starting on the edge between ell_a and ell_b, to either side: the first point of the path is where the walker stands
cr_scummvm_differs("amc_path_on_edge", "from the edge the original goes by the corner first") cr_test("amc_path_on_edge", function()
	amc_path_case("to_b", 2, 2, "cr_box.cos", 1, 1, 0, -1, 1, -1)
	amc_path_case("to_a", 2, 2, "cr_box.cos", 1, 1, 0, -1, -1, -1)
end)

-- SetActorColormap on an actor that has no costume
cr_test("amc_colormap_nocos", function()
	local a = cr_actor("cr_flat.set")
	cr_log("ret", SetActorColormap(a, "cr_pal.cmp"))
	cr_log("costume", GetActorCostume(a))
	cr_log("depth", GetActorCostumeDepth(a))
	PutActorInSet(a, nil)
end)

-- SetActorCostume over a costume: the top one is replaced, not pushed
cr_scummvm_differs("amc_costume_replace", "pushCostume refuses a costume already in the stack (actor.cpp:1364)") cr_test("amc_costume_replace", function()
	local a = cr_actor("cr_flat.set")
	SetActorCostume(a, "cr_box.cos")
	cr_log("first", GetActorCostume(a), GetActorCostumeDepth(a))
	cr_log("ret", SetActorCostume(a, "cr_luav.cos"))
	cr_log("second", GetActorCostume(a), GetActorCostumeDepth(a))
	PushActorCostume(a, "cr_box.cos")
	cr_log("pushed", GetActorCostume(a), GetActorCostumeDepth(a))
	SetActorCostume(a, "cr_luav.cos")
	cr_log("replaced_top", GetActorCostume(a), GetActorCostumeDepth(a))
	cr_log("pop", PopActorCostume(a))
	cr_log("after_pop", GetActorCostume(a), GetActorCostumeDepth(a))
	SetActorCostume(a, nil)
	cr_log("cleared", GetActorCostume(a), GetActorCostumeDepth(a))
	PutActorInSet(a, nil)
end)

-- an actor drawn into the clean buffer (ActorToClean), taken out of the set and put back: seen on the screen (cr_open
-- draws the white box of cr_dbox.cos)
cr_scummvm_differs("amc_clean_put", "no clean buffer: what ActorToClean drew does not stay") cr_test("amc_clean_put", function()
	MakeCurrentSet("cr_open.set")
	local a = amc_put("amc_clean", "cr_open.set", 0, 0)
	SetActorCostume(a, "cr_dbox.cos")
	cr_frames(2)
	cr_snap("drawn")
	ActorToClean(a)
	cr_frames(2)
	cr_snap("clean")
	PutActorInSet(a, nil)
	cr_frames(2)
	cr_snap("out")
	PutActorAt(a, 1, 1, 0)
	PutActorInSet(a, "cr_open.set")
	cr_frames(2)
	cr_snap("back")
	cr_pos("pos", a)
	PutActorInSet(a, nil)
	cr_frames(2)
	cr_snap("out_again")
	SetActorCostume(a, nil)
	cr_frames(1)
end)

-- the shadows of shadow.lua (cr_dbox.cos on cr_open's plane shadow1), with SetActorShadowValid(a, 1) and with the shadow
-- point under the plane
amc_shadow = function(key, x, y, z, valid)
	MakeCurrentSet("cr_open.set")
	local a = amc_put("amc_shadower", "cr_open.set", 0, 0)
	SetActorCostume(a, "cr_dbox.cos")
	cr_frames(2)
	SetActiveShadow(a, 0)
	SetActorShadowPoint(a, x, y, z)
	SetActorShadowPlane(a, "shadow1")
	AddShadowPlane(a, "shadow1")
	if valid then
		SetActorShadowValid(a, valid)
	end
	ActivateActorShadow(a, TRUE, 0)
	cr_frames(3)
	cr_snap(key .. "_dark", "dark")
	KillActorShadows(a)
	cr_frames(2)
	SetActorCostume(a, nil)
	PutActorInSet(a, nil)
end

cr_test("amc_shadow_valid", function()
	amc_shadow("valid1", -4, 0, 3, 1)
end)

cr_test("amc_shadow_valid0", function()
	amc_shadow("valid0", -4, 0, 3, 0)
end)

cr_test("amc_shadow_below", function()
	amc_shadow("below", -4, 0, -3)
end)
