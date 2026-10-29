AR_NT_IDS = { lobby_long = 1 }
AR_NT_MODE = "walk"
ar_wtrace = function()
	while TRUE do
		local p = manny:getpos()
		PrintDebug("WTRACE " .. format("%.4f %.4f", p.x, p.y) .. "\n")
		break_here()
	end
end
start_script(ar_wtrace)
