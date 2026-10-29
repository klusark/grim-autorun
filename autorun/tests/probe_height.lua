-- Probe: how far off the plane of a sector a point still counts as in it (IsPointInSector by name), flat and on a stair.
ar_wait_for_control()
ar_fx_make_sets()
EP_Z = { 0, 1e-6, 1e-5, 2e-5, 1e-4, 1e-3, 4e-3, 6e-3, 1e-2, 1.5e-2, 2e-2, 5e-2, 0.1 }
ep_hprobe = function(setname, sector, x, y, z0, label)
	local set = getglobal(setname)
	set:switch_to_set("noenter")
	break_here()
	manny:put_in_set(set)
	break_here()
	local line = "HEIGHTPROBE " .. setname .. " " .. sector .. " " .. label .. ":"
	local i = 1
	while EP_Z[i] do
		local up = IsPointInSector(x, y, z0 + EP_Z[i], sector)
		local down = IsPointInSector(x, y, z0 - EP_Z[i], sector)
		line = line .. " " .. (up and 1 or 0) .. (down and 1 or 0)
		i = i + 1
	end
	PrintDebug(line .. "\n")
end
ep_hprobe("t_flat", "floor", 0, 0, 0, "flat, above/below")
ep_hprobe("t_stair", "stair_b", 0, 0.5, 0.3, "stair slope 0.6, above/below")
ep_hprobe("t_stair", "hi_b", 0, 2, 0.6, "flat upper floor")
PrintDebug("HEIGHTPROBE offsets: 0 1e-6 1e-5 2e-5 1e-4 1e-3 4e-3 6e-3 1e-2 1.5e-2 2e-2 5e-2 0.1\n")
ar_finish()
