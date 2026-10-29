start_script(function()
	while TRUE do
		local p = manny:getpos()
		local id, nm = manny:find_sector_name("")
		PrintDebug("LG " .. system.currentSet.name .. " " .. format("%.2f %.2f", p.x, p.y) .. " sec=" .. tostring(nm) .. " mv=" .. tostring(manny:is_moving()) .. " cut=" .. cutSceneLevel)
		sleep_for(500)
	end
end)
