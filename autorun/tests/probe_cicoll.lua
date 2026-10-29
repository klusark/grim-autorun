-- Probe (PROBE lines): the actors of ci that collide (AR_COLL), as ch17 finds them
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
ar_nt_place({ id = "ciw", set = "ci", from = { 0.238, 0.559, 0 } })
sleep_for(1500)
pq_h, pq_mode = next(AR_COLL, nil)
while pq_h do
	local x, y, z = GetActorPos(pq_h)
	PrintDebug("PROBE coll " .. tostring(pq_h) .. " mode " .. tostring(pq_mode) .. " " .. tostring(GetActorName and GetActorName(pq_h)) .. format(" %.3f %.3f %.3f", x or 0, y or 0, z or 0) .. "\n")
	pq_h, pq_mode = next(AR_COLL, pq_h)
end
AR_KEEP_GOING = nil
ar_finish()
