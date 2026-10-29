-- Chapter 17: Charlie at the casino table gives the ticket printer and, since Velasco told about
-- the union card, the V.I.P. pass. Checkpoint in slot 33.

ar_load(16)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(dd.bw_door, bw)
ar_go(bw.ev_door, ev, -2.49, -2.35, 0.2)
ar_go(ev.ce_door, ce, -0.5, -0.85, 0.05)
ar_go(ce.cc_door, cc)
ar_go(cc.ci_door, ci)
PrintDebug("PROBE arrived " .. format("%.4f %.4f", manny:getpos().x, manny:getpos().y) .. "\n")
pq_way = { { 0.59, 1.72 }, { -0.12, 1.72 } }
manny:setpos(0.9, 1.5, -1.4)
pq_k = 1
pq_f = 0
while pq_way[pq_k] and pq_f < 600 do
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
		if mod(pq_f, 6) == 0 then
			local r = manny:getrot()
			PrintDebug("PROBE w " .. pq_f .. " k " .. pq_k .. format(" %.4f %.4f %.4f yaw %.2f", pq_p.x, pq_p.y, pq_p.z, r.y) .. "\n")
		end
	end
end
PrintDebug("PROBE end " .. pq_f .. " k " .. pq_k .. "\n")
ar_finish()
