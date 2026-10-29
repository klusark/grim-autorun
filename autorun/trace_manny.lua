-- Prints Manny's position, heading and the sector under him every 6 frames: EXTRA=trace_manny.lua sh run_chapter.sh chNN.lua   ("MANNYTRACE x y z yaw sector constrained")
ar_mt_task = function()
	local k = 0
	while TRUE do
		k = k + 1
		if mod(k, 6) == 0 then
			local p = manny:getpos()
			local id, name = GetActorSector(manny.hActor, 4096)
			PrintDebug("MANNYTRACE " .. k .. format(" %.4f %.4f %.4f %.1f ", p.x, p.y, p.z, manny:getrot().y) .. tostring(name) .. "\n")
		end
		break_here()
	end
end
start_script(ar_mt_task)
