-- Probe: sector names of the temp factory hub around the arrival point (FHMAP lines, one per row of y)
ar_wait_for_control()
fh:switch_to_set()
break_here()
manny:put_in_set(fh)
break_here()
local y = -2.70
while y > -3.0 do
	local line = format("FHMAP %.3f ", y)
	local x = -1.20
	while x < -0.70 do
		manny:setpos(x, y, -1.28)
		local id, name = manny:find_sector_type(WALK)
		if name then
			line = line .. strsub(name, 1, 3) .. " "
		else
			line = line .. "--- "
		end
		x = x + 0.025
	end
	PrintDebug(line .. "\n")
	y = y - 0.02
end
