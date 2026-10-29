-- Probe (PROBE lines): ActorPuckOrient (FUN_00490f50). Manny is oriented to the sector (puck on) on the flat floor of mo, and on the tilted sector of bs
-- (the case slide_wall_right), with angles set by SetActorRot that do not match the sector, then left to settle and made to walk; the three angles
-- frame by frame. Both engines: EXTRA="nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua
-- rules_known.lua" sh run_chapter.sh tests/probe_puck.lua 300
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
puck_show = function(tag, k)
	local p = manny:getpos()
	local r = manny:getrot()
	PrintDebug("PROBE " .. tag .. " " .. k .. format(" pos %.6f %.6f %.6f rot %.6f %.6f %.6f", p.x, p.y, p.z, r.x, r.y, r.z) .. "\n")
end
puck_case = function(tag, c, rot, walk, frames, nopuck)
	ar_nt_place(c)
	AR_WALK = TRUE
	manny:set_run(FALSE)
	sleep_for(2500)
	manny:setpos(c.from[1], c.from[2], c.from[3])
	if nopuck then
		ActorPuckOrient(manny.hActor, FALSE)
	else
		ActorPuckOrient(manny.hActor, TRUE)
	end
	manny:setrot(rot[1], rot[2], rot[3])
	puck_show(tag, 0)
	local k = 0
	while k < frames do
		if walk then
			manny:walk_forward()
		end
		break_here()
		k = k + 1
		puck_show(tag, k)
	end
	ActorPuckOrient(manny.hActor, FALSE)
	AR_WALK = nil
end
flat = { id = "pf", set = "mo", from = { 1.41, 0.04, 0 } }
tilt = { id = "pt", set = "bs", from = { -6.80, 26.40, 11.85 } }
puck_case("np_p40", flat, { 40, 90, 20 }, nil, 12, TRUE)
puck_case("np_walk", flat, { 40, 90, 20 }, TRUE, 12, TRUE)
puck_case("np_tilt", tilt, { 35, 20, -20 }, nil, 6, TRUE)
puck_case("flat_p40", flat, { 40, 90, 0 }, nil, 40)
puck_case("flat_r30", flat, { 0, 90, 30 }, nil, 40)
puck_case("flat_pr", flat, { -25, 200, 50 }, nil, 40)
puck_case("flat_walk", flat, { 20, 45, 0 }, TRUE, 30)
puck_case("tilt_0", tilt, { 0, 160, 0 }, nil, 40)
puck_case("tilt_p", tilt, { 35, 20, -20 }, nil, 40)
puck_case("tilt_walk", tilt, { 0, 160, 0 }, TRUE, 40)
AR_KEEP_GOING = nil
ar_finish()
