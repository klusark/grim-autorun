-- ScummVM #11849 (after a set change the set's first setup is drawn for a moment before the right one): logs, each frame, the set and
-- its current setup when either changes, with a frame counter (SW). Put in front of chapters by run_test.sh.
SW_F = 0
sw_watch = function()
	local last = ""
	while TRUE do
		SW_F = SW_F + 1
		local s = system.currentSet
		local name = "nil"
		local setup = -1
		if s then
			name = tostring(s.setFile)
			setup = s:current_setup()
		end
		local cur = name .. " " .. tostring(setup)
		if cur ~= last then
			ar_log("SW " .. SW_F .. " " .. cur)
			last = cur
		end
		break_here()
	end
end
start_script(sw_watch)
