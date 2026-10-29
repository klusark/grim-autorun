-- Probe (PROBE lines): the walk of ch17 across dd to the door of bw (ar_go), Manny every 5 frames, and the actors of the set
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
ar_load(16)
dump_actors = function()
	local k, v = nextvar(nil)
	while k do
		if type(v) == "table" and v.hActor and v.currentSet == dd then
			local p = v:getpos()
			PrintDebug("PROBE actor " .. k .. format(" %.3f %.3f %.3f", p.x, p.y, p.z) .. "\n")
		end
		k, v = nextvar(k)
	end
end
dump_actors()
logger = function()
	local f = 0
	while AR_KEEP_GOING do
		break_here()
		f = f + 1
		if mod(f, 5) == 0 then
			local p = manny:getpos()
			local r = manny:getrot()
			PrintDebug("PROBE m " .. f .. format(" %.4f %.4f %.4f yaw %.3f", p.x, p.y, p.z, r.y) .. "\n")
		end
	end
end
start_script(logger)
ar_go(dd.bw_door, bw)
dump_actors()
AR_KEEP_GOING = nil
ar_finish()
