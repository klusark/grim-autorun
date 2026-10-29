-- Probe for the tracer (GRIMTRACE_BP=4a8610): steps of Manny in dd at an interior point of sect_32 (4.5 -2.7), of $ect_32 (5.5 -2.2), and at the shared edge (5.1889 -2.4139)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
ar_load(16)
manny:follow_boxes()
pq_pts = { { 4.5, -2.7, 308 }, { 5.5, -2.2, 308 }, { 5.1889, -2.4139, 308.9576 }, { 4.5, -2.7, 308 }, { 5.5, -2.2, 308 } }
pq_i = 1
while pq_pts[pq_i] do
	manny:setpos(pq_pts[pq_i][1], pq_pts[pq_i][2], 0)
	manny:setrot(0, pq_pts[pq_i][3], 0)
	local pq_f = 0
	while pq_f < 6 do
		break_here()
		manny:walk_forward()
		pq_f = pq_f + 1
	end
	local pq_p = manny:getpos()
	PrintDebug("PROBE t " .. pq_i .. format(" %.4f %.4f", pq_p.x, pq_p.y) .. "\n")
	pq_i = pq_i + 1
end
AR_KEEP_GOING = nil
ar_finish()
