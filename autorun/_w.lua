start_script(function()
	local p0 = manny:getpos()
	local n = 0
	while n < 20 do
		manny:walk_forward()
		break_here()
		n = n + 1
	end
	local q = manny:getpos()
	PrintDebug("ORL fwd " .. format("%.2f to %.2f", p0.x, q.x))
end)
