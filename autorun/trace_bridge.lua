-- EXTRA=trace_bridge.lua: a line for every frame Manny is on the extend-o-bridge (set xb): the frame number counted here, the frame length, his position and yaw,
-- the walk sector the engine finds for him, the camera setup and whether he is in a cutscene; and a line for every call of a walkOut of the set.
-- Compare the TR lines of a simulated run and a real-time one (tools: trace_cmp.py): the first line that differs says where they part.
AR_TR_N = 0
AR_TR_MAX = AR_TR_MAX or 4000
AR_TR_WRAPPED = nil

ar_tr_wrap = function()
	if AR_TR_WRAPPED then
		return
	end
	AR_TR_WRAPPED = TRUE
	local k, v = next(xb, nil)
	while k do
		if type(v) == "table" and v.walkOut and not v.tr_wrapped then
			v.tr_wrapped = TRUE
			v.tr_name = k
			v.tr_orig = v.walkOut
			v.walkOut = function(self)
				local p = manny:getpos()
				ar_log(format("TR %d walkOut %s at %.3f %.3f %.3f", AR_TR_N, tostring(self.tr_name), p.x, p.y, p.z))
				return self.tr_orig(self)
			end
		end
		k, v = next(xb, k)
	end
end

ar_trace = function()
	while TRUE do
		break_here()
		if system.currentSet == xb and AR_TR_N < AR_TR_MAX then
			ar_tr_wrap()
			AR_TR_N = AR_TR_N + 1
			local p = manny:getpos()
			local r = manny:getrot()
			local id, sname = GetPointSector(p.x, p.y, p.z)
			ar_log(format("TR %d ft=%d pos %.3f %.3f %.3f yaw %.2f sector %s cam %s cut %d", AR_TR_N, system.frameTime, p.x, p.y, p.z, r.y, tostring(sname), tostring(system.currentSet:current_setup()), cutSceneLevel))
		end
	end
end
AR_TR_TASK = start_script(ar_trace)
