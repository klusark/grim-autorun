-- Probe: a walk along a planned path in the garage with several points, to compare the position and the frame of the walker at every step with the
-- original (the tracer on Walker_WalkSectors; WALKSEC lines of the debug channel "actors" on ScummVM).
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
pw_case = { id = "pw", set = "ga", from = { 15.3, 3.0, 0 } }
ar_nt_place(pw_case)
PutActorAt(manny.hActor, 15.3, 3.0, 0)
manny:setrot(0, 90, 0)
break_here()
break_here()
WalkActorTo(manny.hActor, 1.4, 9.9, 0)
local n = 0
while n < 700 and manny:is_moving() do
	break_here()
	n = n + 1
end
PrintDebug("PATHWALK frames " .. n .. "\n")
AR_KEEP_GOING = nil
ar_finish()
