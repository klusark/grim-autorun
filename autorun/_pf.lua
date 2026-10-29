ar_pf = function()
	local lx, ly, lyaw = 1000, 1000, 1000
	local f = 0
	while TRUE do
		f = f + 1
		if system.currentSet == sg then
			local p = bonewagon:getpos()
			local yaw = bonewagon:getrot().y
			if abs(p.x - lx) + abs(p.y - ly) > 0.0001 or abs(yaw - lyaw) > 0.01 then
				PrintDebug("PF " .. f .. " " .. format("%.3f %.3f yaw %.2f", p.x, p.y, yaw) .. " rate=" .. tostring(bonewagon.walk_rate) .. " ft=" .. tostring(system.frameTime))
				lx, ly, lyaw = p.x, p.y, yaw
			end
		end
		break_here()
	end
end
start_script(ar_pf)
