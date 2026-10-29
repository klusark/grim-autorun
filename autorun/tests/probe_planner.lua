-- Probe (PLAN lines): the path of the planner for many pairs of points in the garage (ga), to be run on both engines. On ScummVM the path is in the WALKTO lines of
-- the debug channel "actors"; on the original the points are read from the arguments of FUN_004917e0 with the tracer (tools/plan_cmp.py).
--   ScummVM:  DEBUGFLAGS=scripts,actors EXTRA="nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua rules_known.lua" sh run_chapter.sh tests/probe_planner.lua 600
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
plan_case = { id = "plan", set = "ga", from = { 15.3, 3.0, 0 } }
ar_nt_place(plan_case)
MakeSectorActive("ga_elevator_psg", TRUE)
plan_pts = {
	{ 15.3, 3.0 }, { 10.0, 4.0 }, { 7.0, 9.5 }, { 15.7, -0.3 }, { 15.8, 0.05 }, { 15.77, 0.22 }, { 1.4, 9.9 }, { 17.3, 6.0 }, { 14.5, 8.0 }, { 3.7, 9.2 }, { 0.7, 8.5 },
}
plan_i = 1
plan_n = 0
while plan_pts[plan_i] do
	plan_j = 1
	while plan_pts[plan_j] do
		if plan_i ~= plan_j then
			plan_n = plan_n + 1
			PrintDebug("PLAN " .. plan_n .. " from " .. plan_pts[plan_i][1] .. " " .. plan_pts[plan_i][2] .. " to " .. plan_pts[plan_j][1] .. " " .. plan_pts[plan_j][2] .. "\n")
			PutActorAt(manny.hActor, plan_pts[plan_i][1], plan_pts[plan_i][2], 0)
			WalkActorTo(manny.hActor, plan_pts[plan_j][1], plan_pts[plan_j][2], 0)
			break_here()
			break_here()
		end
		plan_j = plan_j + 1
	end
	plan_i = plan_i + 1
end
PrintDebug("PLANDONE\n")
AR_KEEP_GOING = nil
ar_finish()
