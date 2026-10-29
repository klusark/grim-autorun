sec_dbg = function()
	while TRUE do
		if FT_FRAME >= 1090 and FT_FRAME <= 1135 then
			local id, name = manny:find_sector_type(WALK)
			local p = manny:getpos()
			PrintDebug("SECDBG " .. FT_FRAME .. " sector " .. tostring(name) .. " id " .. tostring(id) .. format(" %.6f %.6f %.6f", p.x, p.y, p.z) .. "\n")
		end
		break_here()
	end
end
start_script(sec_dbg)
