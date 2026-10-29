-- Probe (PROBE lines): Manny in dd where the walk of ch17 gets stuck (5.1889 -2.4139, yaw 668.96), steered to the next point (5.85 -1.44) as the autorun does
-- (ar_steer, walk_forward), every frame
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
ar_load(16)
manny:setpos(5.1889, -2.4139, 0)
manny:setrot(0, 308.9576, 0)
break_here()
break_here()
f = 0
while f < 240 do
	local turning = ar_steer(5.85, -1.44, 0, 8)
	if abs(AR_STEER_D or 0) < 40 then
		manny:walk_forward()
	end
	break_here()
	f = f + 1
	local p = manny:getpos()
	local r = manny:getrot()
	PrintDebug("PROBE c " .. f .. format(" %.4f %.4f %.4f yaw %.3f d %.2f", p.x, p.y, p.z, r.y, AR_STEER_D or 0) .. "\n")
end
AR_KEEP_GOING = nil
ar_finish()
