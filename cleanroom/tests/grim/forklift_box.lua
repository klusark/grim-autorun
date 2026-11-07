-- Repro for ScummVM ab9c9cca (MATH/GRIM: Fix Line2d, "issues with the forklift in GRIM").
--
-- A sphere actor walks forward into a collision BOX that is turned by `yaw` degrees. ScummVM pushes it out along the box
-- edge it hit (Actor::handleCollisionWith -> Segment2d::getPerpendicular -> Segment2d::intersectsLine -> Line2d). With the
-- old Line2d the edge line and its perpendicular came out parallel, intersectsLine() never succeeded, and the walker was
-- always thrown to the nearest corner of the box instead of along the face it hit: it ended up on the wrong side of the
-- wall. The original engine keeps it on the side it came from.
--
-- Only engine builtins are used. Set BX_SET to a flat set with room to walk and BX_COS to any costume with a model (its
-- bounding box is the wall), then call bx_main() from a task (it waits for frames). It prints, for each case:
--     BOXTEST yaw=<wall turn> off=<sideways start> -> <x> <y>   (original: <x> <y>)   PASS|FAIL
-- PASS: the walker stayed on the side it started on (|x| > 0.4, as the original does). Old Line2d: FAIL, fixed: PASS.
-- The original's numbers are for the clean-room data (cr_flat.set, cr_box.cos); with other data only the verdict counts.

BX_SET = BX_SET or "cr_flat.set"
BX_COS = BX_COS or "cr_box.cos"
BX_SCALE = 2                          -- collision scale of the wall box (the bigger, the longer its edges)

-- yaw of the wall, sideways offset of the walker's start, the original's end point
BX_CASES = {
	{ 30, 0.3, 0.8246, -0.1016 },
	{ 60, 0.3, 0.7162, 0.0936 },
	{ 60, -0.3, -0.9257, -0.1589 },
	{ 120, -0.3, -0.7163, 0.0935 },
}

function bx_case(yaw, off)
	MakeCurrentSet(BX_SET)
	local m = LoadActor("bx_mover")
	local w = LoadActor("bx_wall")
	PutActorInSet(m, BX_SET)
	PutActorInSet(w, BX_SET)
	SetActorCostume(m, BX_COS)
	SetActorCostume(w, BX_COS)
	PutActorAt(w, 0, 0.2, 0)
	SetActorRot(w, 0, yaw, 0)
	PutActorAt(m, off, -1.5, 0)           -- the walker goes "forward" (+y) into the wall
	SetActorRot(m, 0, 0, 0)
	SetActorFollowBoxes(m, TRUE)
	SetActorWalkRate(m, 1)
	SetActorCollisionMode(w, 1)           -- box
	SetActorCollisionScale(w, BX_SCALE)
	SetActorCollisionMode(m, 2)           -- sphere
	SetActorCollisionScale(m, 0.4)
	break_here()
	local i = 0
	while i < 100 do
		WalkActorForward(m)
		break_here()
		i = i + 1
	end
	local x, y, z = GetActorPos(m)
	SetActorCollisionMode(w, 0)
	SetActorCollisionMode(m, 0)
	PutActorInSet(m, nil)
	PutActorInSet(w, nil)
	return x, y
end

BX_LOG = BX_LOG or function(yaw, off, x, y, ox, oy, ok)
	local verdict = "FAIL"
	if ok then
		verdict = "PASS"
	end
	PrintDebug(format("BOXTEST yaw=%d off=%.1f -> %.4f %.4f   (original: %.4f %.4f)   %s\n", yaw, off, x, y, ox, oy, verdict))
end

function bx_main()
	local i = 1
	while BX_CASES[i] do
		local c = BX_CASES[i]
		local x, y = bx_case(c[1], c[2])
		local ok = nil
		if c[2] > 0 and x > 0.4 then
			ok = 1
		end
		if c[2] < 0 and x < -0.4 then
			ok = 1
		end
		BX_LOG(c[1], c[2], x, y, c[3], c[4], ok)
		i = i + 1
	end
end
