-- Frame trace of the whole game (FT lines): every frame, the game time (the sum of the frame times), the set, the cutscene level and, for Manny and every
-- other actor that is in the set, the position and the angles. Run on both engines (EXTRALIB=ftrace_lib.lua for build_original.sh, EXTRA for the ScummVM
-- scripts) and compared by tools/ftrace_cmp.py. Lines are short: FT <t> <set> <cut> <actor> x y z yaw ...
FT_T = 0
FT_FRAME = 0
FT_CHAPTER = "?"
FT_ACTORS = nil
ft_chapter = function(name)
	FT_CHAPTER = name
	PrintDebug("FTCHAPTER " .. name .. " " .. FT_FRAME .. "\n")
end
ft_run = function()
	while TRUE do
		local s = system.currentSet
		local line = "FT " .. FT_FRAME .. " " .. format("%d", FT_T) .. " " .. tostring(s and s.name) .. " c" .. cutSceneLevel
		local p = manny:getpos()
		local r = manny:getrot()
		line = line .. format(" M %.4f %.4f %.4f %.3f %.3f %.3f", p.x, p.y, p.z, r.x, r.y, r.z)
		PrintDebug(line .. "\n")
		FT_FRAME = FT_FRAME + 1
		FT_T = FT_T + system.frameTime
		break_here()
	end
end
start_script(ft_run)
