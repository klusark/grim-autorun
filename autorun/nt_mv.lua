AR_NT_TIERS = { move = 1 }
AR_NT_ONLY = "target_meche_obj_still_b_from4"
ar_mv_task = function()
	local k = 0
	while TRUE do
		k = k + 1
		if mod(k, 3) == 0 then
			local p = manny:getpos()
			PrintDebug("MVTRACE " .. k .. format(" %.4f %.4f %.1f", p.x, p.y, manny:getrot().y) .. "\n")
		end
		break_here()
	end
end
start_script(ar_mv_task)
