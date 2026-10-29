A3_PD = 0
a3_pac_watch = function()
	local last = ""
	while TRUE do
		local s = ""
		local r = next(pac.rocks, nil)
		while r do
			local p = r:getpos()
			s = s .. format("[%s %.1f,%.1f]", tostring(r.node and r.node.name), p.x, p.y)
			r = next(pac.rocks, r)
		end
		if s ~= last then
			ar_log("PAC t=" .. A3_PD .. " " .. s)
			last = s
		end
		sleep_for(250)
		A3_PD = A3_PD + 250
	end
end
