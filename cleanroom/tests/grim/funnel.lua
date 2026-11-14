-- Funnel sectors (cr_funnel.set, assets.py): type 0x1100. WalkPlane_SetType (0x4a6790) keeps it for a sector of 4 corners
-- and works out its long axis; a funnel of 3 corners becomes a walk sector (0x1000). Actors walk into and through them.

cr_t_funnel_types = function()
	MakeCurrentSet("cr_funnel.set")
	cr_frames(1)
	cr_point("floor", 0, -1, 0)
	cr_point("rect", 0, 1, 0)
	cr_point("trap", 3, -1, 0)
	cr_point("tri", -1.8, -2.2, 0)
	cr_point("outside", 0, 3, 0)
	cr_log("rect_active", IsSectorActive("fn_rect"))
end
cr_test("funnel_types", cr_t_funnel_types)

cr_fn_walk = function(key, x0, y0, x1, y1, rate)
	local a = cr_actor_global("cr_funnel.set")
	SetActorWalkRate(a, rate or 2)
	PutActorAt(a, x0, y0, 0)
	cr_frames(1)
	cr_log(key .. "_start_sector", GetActorSector(a, 4096))
	WalkActorTo(a, x1, y1, 0)
	break_here()
	local i = 0
	while i < 4 do
		cr_frames(5)
		cr_pos(key .. "_f" .. (i + 1) * 5, a)
		i = i + 1
	end
	local f = cr_until(cr_not_moving_a, 300)
	cr_log(key .. "_frames", f)
	cr_pos(key .. "_end", a)
	cr_log(key .. "_sector", GetActorSector(a, 4096))
	local p, y, r = GetActorRot(a)
	cr_log(key .. "_rot", p, y, r)
end

-- from the floor straight into the funnel, along it, across it, and out again
cr_t_funnel_walk_in = function()
	cr_fn_walk("in", 0, -1, 0, 1.5)
end
cr_test("funnel_walk_in", cr_t_funnel_walk_in)

cr_t_funnel_walk_slanted = function()
	cr_fn_walk("slanted", -1.5, -1, 0.3, 1.8)
end
cr_test("funnel_walk_slanted", cr_t_funnel_walk_slanted)

cr_t_funnel_walk_out = function()
	cr_fn_walk("out", 0, 1.5, 1.5, -1)
end
cr_test("funnel_walk_out", cr_t_funnel_walk_out)

cr_t_funnel_walk_across = function()
	cr_fn_walk("across", -0.4, 1, 0.4, 1.2)
end
cr_test("funnel_walk_across", cr_t_funnel_walk_across)

-- past its far end (outside every sector): where the actor stops
cr_t_funnel_walk_past = function()
	cr_fn_walk("past", 0, 0.5, 0, 3)
end
cr_test("funnel_walk_past", cr_t_funnel_walk_past)

-- the trapezoid: into its narrow end
cr_t_funnel_walk_trap = function()
	cr_fn_walk("trap", 1, -1, 3.4, -1)
end
cr_test("funnel_walk_trap", cr_t_funnel_walk_trap)

-- the triangle (a walk sector now)
cr_t_funnel_walk_tri = function()
	cr_fn_walk("tri", -1, -1, -1.8, -2.2)
end
cr_test("funnel_walk_tri", cr_t_funnel_walk_tri)

-- with the funnel off
cr_t_funnel_off = function()
	MakeCurrentSet("cr_funnel.set")
	MakeSectorActive("fn_rect", FALSE)
	cr_fn_walk("off", 0, -1, 0, 1.5)
	MakeSectorActive("fn_rect", TRUE)
end
cr_test("funnel_off", cr_t_funnel_off)

-- walking with the keys (WalkActorForward in a direction) into the funnel at an angle
cr_t_funnel_forward = function()
	local a = cr_actor_global("cr_funnel.set")
	PutActorAt(a, 0.3, -0.5, 0)
	SetActorRot(a, 0, 20, 0)
	cr_frames(1)
	local i = 0
	while i < 40 do
		WalkActorForward(a)
		break_here()
		i = i + 1
		if mod(i, 10) == 0 then
			cr_pos("fwd_f" .. i, a)
			cr_log("fwd_sector_f" .. i, GetActorSector(a, 4096))
		end
	end
	local p, y, r = GetActorRot(a)
	cr_log("fwd_rot", p, y, r)
end
cr_test("funnel_forward", cr_t_funnel_forward)
