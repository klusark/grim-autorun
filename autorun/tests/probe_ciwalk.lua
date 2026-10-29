-- Probe (PROBE lines): Manny in ci walking the way of ch17 to the door (0.24 0.56) ... (1.23 1.24) (0.59 1.72) (-0.12 1.72), steered as the autorun does
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
ar_nt_place({ id = "ciw", set = "ci", from = { 0.238, 0.559, 0 } })
sleep_for(1500)
pq_way = { { 0.44, 0.28 }, { 1.31, 0.20 }, { 3.39, 0.20 }, { 3.47, 0.44 }, { 3.32, 0.61 }, { 2.52, 0.76 }, { 2.04, 1.00 }, { 1.23, 1.24 }, { 0.59, 1.72 }, { -0.12, 1.72 } }
pq_k = 1
pq_f = 0
while pq_way[pq_k] and pq_f < 2400 do
	local tx = pq_way[pq_k][1]
	local ty = pq_way[pq_k][2]
	local pq_p = manny:getpos()
	if sqrt((pq_p.x - tx) * (pq_p.x - tx) + (pq_p.y - ty) * (pq_p.y - ty)) < 0.06 then
		pq_k = pq_k + 1
	else
		ar_steer(tx, ty, pq_p.z, 8)
		if abs(AR_STEER_D or 0) < 40 then
			manny:walk_forward()
		end
		break_here()
		pq_f = pq_f + 1
		if mod(pq_f, 20) == 0 then
			local r = manny:getrot()
			PrintDebug("PROBE w " .. pq_f .. " k " .. pq_k .. format(" %.4f %.4f yaw %.2f", pq_p.x, pq_p.y, r.y) .. "\n")
		end
	end
end
PrintDebug("PROBE end " .. pq_f .. " k " .. pq_k .. "\n")
AR_KEEP_GOING = nil
ar_finish()
