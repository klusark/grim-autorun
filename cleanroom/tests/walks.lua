-- Walks: rates, the states of a walking actor, a walk changed half way, a turn before the walk

-- (frames until the global actor CR_A stops, and where; the actor states every 10 frames)
cr_walk_follow = function(key, max)
	local f = 0
	local s = ""
	while IsActorMoving(CR_A) and f < max do
		if mod(f, 10) == 0 then
			s = s .. tostring(IsActorMoving(CR_A)) .. "/" .. tostring(IsActorTurning(CR_A)) .. "/" .. tostring(IsActorResting(CR_A)) .. " "
		end
		break_here()
		f = f + 1
	end
	cr_log(key .. "_states", s)
	cr_log(key .. "_frames", f)
	cr_pos(key .. "_end", CR_A)
	local p, y, r = GetActorRot(CR_A)
	cr_log(key .. "_yaw", y)
end

cr_t_walk_rates = function()
	local rates = { 0.5, 2, 4 }
	local i = 1
	while i <= 3 do
		cr_actor_global("cr_flat.set")
		SetActorWalkRate(CR_A, rates[i])
		cr_frames(1)
		WalkActorTo(CR_A, 1, 1.5, 0)
		break_here()
		cr_walk_follow("rate" .. i, 400)
		i = i + 1
	end
end
cr_test("walk_rates", cr_t_walk_rates)

-- (the target changes after 20 frames)
cr_t_walk_retarget = function()
	cr_actor_global("cr_flat.set")
	SetActorWalkRate(CR_A, 1)
	cr_frames(1)
	WalkActorTo(CR_A, 1.5, 0, 0)
	cr_frames(20)
	cr_pos("at_20", CR_A)
	WalkActorTo(CR_A, -1, 1.5, 0)
	break_here()
	cr_walk_follow("retarget", 300)
end
cr_test("walk_retarget", cr_t_walk_retarget)

-- (a walk behind the actor: it has to turn round first; with a slow turn rate)
cr_t_walk_behind = function()
	cr_actor_global("cr_flat.set")
	SetActorWalkRate(CR_A, 1)
	SetActorTurnRate(CR_A, 60)
	SetActorRot(CR_A, 0, 0, 0)
	cr_frames(1)
	WalkActorTo(CR_A, 0, -1.5, 0)
	break_here()
	cr_walk_follow("behind", 300)
end
cr_test("walk_behind", cr_t_walk_behind)

-- (the walk is stopped by putting the actor somewhere else)
cr_t_walk_interrupted = function()
	cr_actor_global("cr_flat.set")
	SetActorWalkRate(CR_A, 1)
	cr_frames(1)
	WalkActorTo(CR_A, 1.5, 1.5, 0)
	cr_frames(10)
	PutActorAt(CR_A, -1, -1, 0)
	cr_log("moving_after_put", IsActorMoving(CR_A))
	break_here()
	cr_log("moving_next", IsActorMoving(CR_A))
	cr_frames(10)
	cr_pos("after_10", CR_A)
end
cr_test("walk_interrupted", cr_t_walk_interrupted)
