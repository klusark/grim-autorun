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
pq_h, pq_mode = next(AR_COLL, nil)
while pq_h do
	local x, y, z = GetActorPos(pq_h)
	local nm = "?"
	local gk, gv = nextvar(nil)
	while gk do
		if type(gv) == "table" and gv.hActor == pq_h then
			nm = gk .. " set " .. tostring(gv.currentSet and gv.currentSet.setFile)
		end
		gk, gv = nextvar(gk)
	end
	PrintDebug("PROBE coll " .. tostring(GetActorCostume(pq_h)) .. " " .. nm .. " " .. tostring(pq_h) .. " mode " .. tostring(pq_mode) .. format(" %.3f %.3f %.3f", x or 0, y or 0, z or 0) .. "\n")
	pq_h, pq_mode = next(AR_COLL, pq_h)
end
ar_finish()
