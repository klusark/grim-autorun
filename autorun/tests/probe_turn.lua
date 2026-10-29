-- Probe: Manny's turn rate where the turn tier measures it. TESTSETS=1 EXTRA="nav_cases.lua ar_fixture.lua ar_nt_lib.lua" sh run_chapter.sh tests/probe_turn.lua 100
ar_wait_for_control()
ar_fx_make_sets()
local show = function(tag)
	PrintDebug("TURNPROBE " .. tag .. " rate=" .. tostring(GetActorTurnRate(manny.hActor)) .. " walk=" .. tostring(GetActorWalkRate(manny.hActor)) .. " set=" .. tostring(system.currentSet.name) .. " running=" .. tostring(manny.is_running) .. "\n")
end
show("start")
manny:set_run(FALSE)
show("after set_run(FALSE)")
ar_nt_place({ id = "probe", set = "t_flat", from = { 0, 0, 0 }, yaw = 0 })
show("placed in t_flat")
local y0 = manny:getrot().y
local k = 0
while k < 30 do
	TurnActor(manny.hActor, 1)
	break_here()
	k = k + 1
end
break_here()
local d = manny:getrot().y - y0
d = d - 360 * floor(d / 360 + 0.5)
show("after 30 turns: " .. format("%.3f degrees, %.3f a frame, frame %d ms", d, d / 30, system.frameTime))
manny:set_turn_rate(85)
show("after set_turn_rate(85)")
y0 = manny:getrot().y
k = 0
while k < 30 do
	TurnActor(manny.hActor, 1)
	break_here()
	k = k + 1
end
break_here()
d = manny:getrot().y - y0
d = d - 360 * floor(d / 360 + 0.5)
show("again: " .. format("%.3f degrees, %.3f a frame", d, d / 30))
ar_finish()
