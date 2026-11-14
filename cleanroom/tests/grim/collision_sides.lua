-- Box collisions from every side (Collision_BoxSlide): collision_mode.lua's mover (a sphere whatever its mode) walks into a
-- wall actor in box mode (1) from the left, the right, behind and in front, at an angle (a move straight into a face gives
-- NaN positions on the original), into a turned box, and into its corner. cr_cm_actor is collision_mode.lua's.

cr_cs_case = function(key, x0, y0, x1, y1, wall_yaw, scale)
	MakeCurrentSet("cr_flat.set")
	local a = cr_cm_actor("cr_cs_mover", x0, y0, 0)
	local b = cr_cm_actor("cr_cs_wall", 0, 0, wall_yaw or 0)
	SetActorFollowBoxes(a, TRUE)
	SetActorWalkRate(a, 1)
	SetActorCollisionMode(a, 2)
	SetActorCollisionMode(b, 1)
	SetActorCollisionScale(a, scale or 0.4)
	SetActorCollisionScale(b, scale or 0.4)
	cr_frames(1)
	WalkActorTo(a, x1, y1, 0)
	local i = 0
	while i < 90 do
		if mod(i, 15) == 0 then
			cr_pos(key .. "_f" .. i, a)
		end
		break_here()
		i = i + 1
	end
	cr_pos(key .. "_end", a)
	cr_log(key .. "_walking", IsActorMoving(a))
	SetActorCollisionMode(a, 0)
	SetActorCollisionMode(b, 0)
	PutActorInSet(a, nil)
	PutActorInSet(b, nil)
end

local cases = {
	{ "from_left", -1.5, 0.2, 1.5, -0.3 },
	{ "from_right", 1.5, -0.2, -1.5, 0.3 },
	{ "from_behind", -0.2, 1.5, 0.3, -1.5 },
	{ "from_front", 0.2, -1.5, -0.3, 1.5 },
	{ "corner", -1.2, -1.2, 1.3, 1.1 },
	{ "graze_right", 1.5, 0.45, -1.5, 0.35 },
}
local i = 1
while cases[i] do
	cr_test("collision_side_" .. cases[i][1], function()
		local c = %cases[%i]
		cr_cs_case(c[1], c[2], c[3], c[4], c[5])
	end)
	cr_test("collision_side_" .. cases[i][1] .. "_turned", function()
		local c = %cases[%i]
		cr_cs_case(c[1], c[2], c[3], c[4], c[5], 35)
	end)
	i = i + 1
end

-- a larger box (scale 1) and a mover already inside it
cr_test("collision_side_big", function()
	cr_cs_case("big", -2.5, 0.3, 2.5, -0.2, 0, 1)
end)
cr_test("collision_side_inside", function()
	cr_cs_case("inside", 0.05, 0.02, 1.5, 0.4)
end)
