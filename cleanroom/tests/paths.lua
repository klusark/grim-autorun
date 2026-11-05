-- Walks that need a path (cr_ell: the floors ell_a (-2..0, -2..0), ell_b (0..2, -2..0) and ell_c (0..2, 0..2), an L): the
-- straight line from ell_a to ell_c leaves the floor, so the walk goes round the corner through ell_b.

cr_path_case = function(key, x0, y0, x1, y1, frames)
	local a = cr_actor_global("cr_ell.set")
	SetActorWalkRate(a, 2)
	PutActorAt(a, x0, y0, 0)
	cr_frames(1)
	WalkActorTo(a, x1, y1, 0)
	local i = 0
	while i < (frames or 6) do
		cr_frames(10)
		cr_pos(key .. "_f" .. (i + 1) * 10, a)
		i = i + 1
	end
	local f = cr_until(cr_not_moving_a, 300)
	cr_log(key .. "_frames", f)
	cr_pos(key .. "_end", a)
	cr_log(key .. "_sector", GetActorSector(a, 4096))
	PutActorInSet(a, nil)
end

cr_t_path_corner = function()
	cr_path_case("a_to_c", -1.5, -0.5, 1, 1.5)
end
cr_test("path_corner", cr_t_path_corner)

cr_t_path_back = function()
	cr_path_case("c_to_a", 1.5, 1.5, -1.5, -1)
end
cr_test("path_back", cr_t_path_back)

cr_t_path_same = function()
	cr_path_case("a_to_b", -1.5, -1, 1.5, -1)
end
cr_test("path_same_row", cr_t_path_same)

-- to a point off the floor (in the empty quarter) and far outside
cr_t_path_off = function()
	cr_path_case("to_hole", -1.5, -1.5, -1, 1)
	cr_path_case("to_far", 1, 1, 5, 5)
end
cr_test("path_off_floor", cr_t_path_off)

-- walking forward into the empty quarter and along the edge of the floor
cr_t_path_forward = function()
	local a = cr_actor("cr_ell.set")
	SetActorWalkRate(a, 1)
	PutActorAt(a, -1, -0.5, 0)
	SetActorRot(a, 0, 0, 0)
	cr_frames(1)
	local i = 0
	while i < 90 do
		WalkActorForward(a)
		if mod(i, 15) == 0 then
			cr_pos("fwd_f" .. i, a)
		end
		break_here()
		i = i + 1
	end
	cr_pos("fwd_end", a)
	cr_log("fwd_sector", GetActorSector(a, 4096))
	SetActorRot(a, 0, 45, 0)
	i = 0
	while i < 60 do
		WalkActorForward(a)
		break_here()
		i = i + 1
	end
	cr_pos("fwd45_end", a)
	PutActorInSet(a, nil)
end
cr_test("path_forward", cr_t_path_forward)
