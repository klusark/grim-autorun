-- ScummVM bug 11813: Manny can walk into Toto when he is on the phone in set si. Toto stands off the floor there, 7 cm
-- from the edges of drill_box1 and drill_box2, and both are spheres (scales 0.3 and 0.35). The original pushes every actor
-- that moved out of the other actors' spheres once a frame (Collision_UpdateMovedActors 0x4939a0), path walks included,
-- whatever the mover's own mode; ScummVM pushed only walks with the keys (walkForward), so a WalkActorTo went through the
-- other actor. The walks forward along and into the edge (cle_slide*, cle_head_on, cle_steep) were a first guess at the
-- cause: ScummVM master keeps out of the sphere there too.
-- cle_edge.set (assets_extra_cle.py): the floor is x < 0; the wall actor is a sphere (cr_box.cos, scale 0.2: radius 0.187,
-- both 0.374 m) standing at (wx, wy). The mover walks forward from (x0, y0) facing yaw for n frames, or to (x1, y1) with
-- WalkActorTo. Logged: whether it stayed 0.33 m or more from the wall actor, the closest it came (squared, in cm^2 / 10,
-- rounded) and where it ended (cm).

cr_cle_pos = function(key, a)
	local x, y, z = GetActorPos(a)
	cr_log(key, floor(x * 100 + 0.5), floor(y * 100 + 0.5))
end

cr_cle_actor = function(name, x, y, yaw)
	local a = LoadActor(name)
	PutActorInSet(a, "cle_edge.set")
	PutActorAt(a, x, y, 0)
	SetActorRot(a, 0, yaw, 0)
	SetActorCostume(a, "cr_box.cos")
	return a
end

cr_cle_case = function(key, wx, wy, x0, y0, yaw, n, x1, y1, ma, mb)
	MakeCurrentSet("cle_edge.set")
	local a = cr_cle_actor("cr_cle_mover", x0, y0, yaw)
	local b = cr_cle_actor("cr_cle_wall", wx, wy, 0)
	SetActorFollowBoxes(a, TRUE)
	SetActorWalkRate(a, 1)
	SetActorCollisionMode(a, 2)
	SetActorCollisionMode(b, 2)
	SetActorCollisionScale(a, 0.2)
	SetActorCollisionScale(b, 0.2)
	if ma then
		SetActorCollisionMode(a, ma)
	end
	if mb then
		SetActorCollisionMode(b, mb)
	end
	cr_frames(1)
	if x1 then
		WalkActorTo(a, x1, y1, 0)
	end
	local best = 1000
	local i = 0
	while i < n do
		if not x1 then
			WalkActorForward(a)
		end
		break_here()
		local x, y, z = GetActorPos(a)
		local d2 = (x - wx) * (x - wx) + (y - wy) * (y - wy)
		if d2 < best then
			best = d2
		end
		i = i + 1
	end
	cr_log(key .. "_kept_out", best >= 0.33 * 0.33)
	cr_log(key .. "_closest", floor(best * 1000 + 0.5))
	cr_cle_pos(key .. "_end", a)
	if x1 then
		cr_log(key .. "_moving", IsActorMoving(a))
	end
	SetActorCollisionMode(a, 0)
	SetActorCollisionMode(b, 0)
	PutActorInSet(a, nil)
	PutActorInSet(b, nil)
end

-- along the edge: the mover meets the edge at 20 degrees and slides north along it into the wall actor, 15 cm off the floor
cr_test("cle_slide", function()
	cr_cle_case("cle_slide", 0.15, 0.5, -0.3, -1.5, -20, 150)
end)
-- the same from the north, walking south
cr_test("cle_slide_south", function()
	cr_cle_case("cle_slide_south", 0.15, -0.5, -0.3, 1.5, 200, 150)
end)
-- the wall actor 7 cm off the floor, as Toto
cr_test("cle_slide_near", function()
	cr_cle_case("cle_slide_near", 0.07, 0.5, -0.3, -1.5, -20, 150)
end)
-- straight into the edge, at the wall actor: the walker stops on the edge (the angle is over the reflection angle)
cr_test("cle_head_on", function()
	cr_cle_case("cle_head_on", 0.15, 0.5, -1, 0.5, -90, 90)
end)
-- straight into the edge, at 60 degrees
cr_test("cle_steep", function()
	cr_cle_case("cle_steep", 0.15, 0.5, -1, -0.1, -60, 90)
end)
-- the wall actor on the floor, walked into without an edge (this worked already)
cr_test("cle_on_floor", function()
	cr_cle_case("cle_on_floor", -0.5, 0.5, -0.5, -1.5, 0, 150)
end)
-- WalkActorTo (ScummVM's path walks tested no collision at all): past the wall actor along the edge, long enough to
-- arrive, as in set si when Manny walks to something near Toto
cr_test("cle_walkto", function()
	cr_cle_case("cle_walkto", 0.15, 0.5, -0.3, -1.5, 0, 300, -0.02, 1.5)
end)
-- to a point inside the wall actor's sphere
cr_test("cle_walkto_into", function()
	cr_cle_case("cle_walkto_into", 0.15, 0.5, -0.3, -1.5, 0, 300, -0.05, 0.5)
end)
-- the mover's collision mode off: the original still pushes a moved actor out (it is a sphere whatever its mode)
cr_test("cle_walkto_mover_off", function()
	cr_cle_case("cle_walkto_mover_off", 0.15, 0.5, -0.3, -1.5, 0, 300, -0.02, 1.5, 0)
end)
-- the wall actor's mode off: no collision
cr_test("cle_walkto_wall_off", function()
	cr_cle_case("cle_walkto_wall_off", 0.15, 0.5, -0.3, -1.5, 0, 300, -0.02, 1.5, 2, 0)
end)
-- the wall actor on the floor, right on the way
cr_test("cle_walkto_floor", function()
	cr_cle_case("cle_walkto_floor", -0.5, 0.5, -0.5, -1.5, 0, 300, -0.5, 1.5)
end)
-- the wall actor on the floor, just off the way
cr_test("cle_walkto_graze", function()
	cr_cle_case("cle_walkto_graze", -0.5, 0.5, -0.8, -1.5, 0, 300, -0.8, 1.5)
end)

-- ScummVM master: the slide along an edge ends a few cm further on (the edge rules differ, as walk_* and collision_side_*)
cr_scummvm_differs("cle_slide", "the slide along the edge ends 3 cm further on")
cr_scummvm_differs("cle_slide_south", "the slide along the edge ends 3 cm further on")
cr_scummvm_differs("cle_slide_near", "the slide along the edge ends 6 cm further on")
-- ScummVM master (bug 11813): a path walk is not pushed out of other actors' spheres
cr_scummvm_differs("cle_walkto", "the path walk goes into the wall actor's sphere")
cr_scummvm_differs("cle_walkto_into", "the path walk goes into the wall actor's sphere")
cr_scummvm_differs("cle_walkto_mover_off", "the path walk goes into the wall actor's sphere")
cr_scummvm_differs("cle_walkto_floor", "the path walk goes through the wall actor")
cr_scummvm_differs("cle_walkto_graze", "the path walk goes into the wall actor's sphere")
