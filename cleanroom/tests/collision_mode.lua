-- The collision mode of the actor that moves (ScummVM commit 7240c11, "Do not use the moving actors collision mode, always
-- use sphere"). On the original, Collision_TestActorAgainstOthers (0x4939f0) treats the actor that moves as a sphere
-- whatever its own mode is; only the mode of the other actor counts (0 off, 1 box, 2 sphere). Each test walks a mover
-- with mode m into a wall actor with mode w: the results of one w must be the same for every m.
--
-- The mover walks in at 20 degrees: a move straight into a face of a box gives NaN positions on the original
-- (Collision_BoxSlide turns the slide about a zero axis).

cr_cm_actor = function(name, x, y, yaw)
	local a = LoadActor(name)
	PutActorInSet(a, "cr_flat.set")
	PutActorAt(a, x, y, 0)
	SetActorRot(a, 0, yaw, 0)
	SetActorCostume(a, "cr_box.cos")
	return a
end

cr_cm_case = function(key, m, w, how, scale)
	MakeCurrentSet("cr_flat.set")
	-- (at scale 1 the spheres are 1.9 m across: the mover starts further away)
	local a = cr_cm_actor("cr_cm_mover", 0.2, (scale == 1 and -1.9) or -1.5, 20)
	local b = cr_cm_actor("cr_cm_wall", 0, 0.2, 0)
	SetActorFollowBoxes(a, TRUE)
	SetActorWalkRate(a, 1)
	SetActorCollisionMode(a, m)
	SetActorCollisionMode(b, w)
	SetActorCollisionScale(a, scale or 0.4)
	SetActorCollisionScale(b, scale or 0.4)
	cr_frames(1)
	if how == "to" then
		WalkActorTo(a, -0.3, 1.6, 0)
	end
	local i = 0
	while i < 100 do
		if how == "forward" then
			WalkActorForward(a)
		end
		if mod(i, 20) == 0 then
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

cr_cm_test = function(m, w, how, scale)
	local key = "cm_" .. how .. "_m" .. m .. "_w" .. w
	if scale then
		key = "cm_" .. how .. "_s" .. scale .. "_m" .. m .. "_w" .. w
	end
	cr_test(key, function()
		cr_cm_case(%key, %m, %w, %how, %scale)
	end)
end

-- every mover mode against every wall mode, walking forward and walking to a point behind the wall
local hows = { "forward", "to" }
local h = 1
while hows[h] do
	local w = 0
	while w <= 2 do
		local m = 0
		while m <= 2 do
			cr_cm_test(m, w, hows[h])
			m = m + 1
		end
		w = w + 1
	end
	h = h + 1
end

-- and walking forward at collision scale 1
local w = 0
while w <= 2 do
	local m = 0
	while m <= 2 do
		cr_cm_test(m, w, "forward", 1)
		m = m + 1
	end
	w = w + 1
end
