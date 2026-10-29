-- Probe (PROBE lines): the walk sector of Manny at points of dd near the corner of the ch17 walk, and the angles after SetActorRot there
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
ar_load(16)
manny:follow_boxes()
pts = { { 5.1889, -2.4139 }, { 5.0, -2.5 }, { 5.3, -2.35 }, { 5.5, -2.2 }, { 4.5, -2.7 }, { 5.1889, -2.4139 } }
i = 1
while pts[i] do
	manny:setpos(pts[i][1], pts[i][2], 0)
	break_here()
	local id, name = manny:find_sector_type(WALK)
	manny:setrot(0, 668.9576, 0)
	break_here()
	break_here()
	id, name = manny:find_sector_type(WALK)
	local r = manny:getrot()
	local p = manny:getpos()
	PrintDebug("PROBE s " .. i .. format(" %.4f %.4f %.4f", p.x, p.y, p.z) .. " sector " .. tostring(name) .. " id " .. tostring(id) .. format(" yaw %.3f", r.y) .. "\n")
	i = i + 1
end
AR_KEEP_GOING = nil
ar_finish()
