-- Probe: how far outside an edge a point still counts as in the sector (IsPointInSector with the sector's name), edges of different length and direction.
ar_wait_for_control()
ar_fx_make_sets()
EP_OFFS = { 0, 1e-6, 2e-6, 5e-6, 8e-6, 1e-5, 1.5e-5, 2e-5, 3e-5, 4e-5, 6e-5, 1e-4, 1e-3 }
ep_probe = function(setname, sector, label, ox, oy, nx, ny, z)
	local set = getglobal(setname)
	set:switch_to_set("noenter")
	break_here()
	manny:put_in_set(set)
	break_here()
	local line = "EDGEPROBE " .. setname .. " " .. sector .. " " .. label .. ":"
	local i = 1
	while EP_OFFS[i] do
		local id, name = IsPointInSector(ox + nx * EP_OFFS[i], oy + ny * EP_OFFS[i], z, sector)
		if name then
			line = line .. " 1"
		else
			line = line .. " 0"
		end
		i = i + 1
	end
	PrintDebug(line .. "\n")
end
-- (the point starts on the edge and moves along the outward normal)
ep_probe("t_edge", "e_gap", "bottom edge, length 4, outward -y", 0, 2.00002, 0, -1, 0)
ep_probe("t_edge", "e_left", "right edge x=0, length 4, outward +x", 0, 0, 1, 0, 0)
ep_probe("t_edge", "e_right", "left edge x=0, length 4, outward -x", 0, 0, -1, 0, 0)
ep_probe("t_edge", "e_left", "left wall x=-2, length 4, outward -x", -2, 0, -1, 0, 0)
ep_probe("t_sliver", "sl3", "sliver left edge x=-1, length 2, outward -x", -1, 0, -1, 0, 0)
ep_probe("t_sliver", "narrow", "narrow top edge y=1.025, length 2, outward +y", -2, 1.025, 0, 1, 0)
ep_probe("t_edge", "e_wedge", "slanted edge (4,0)-(2,2), outward (+.707,+.707)", 3, 1, 0.70710678, 0.70710678, 0)
ep_probe("t_flat", "floor", "wall y=2, length 4, outward +y", 0, 2, 0, 1, 0)
PrintDebug("EDGEPROBE offsets: 0 1e-6 2e-6 5e-6 8e-6 1e-5 1.5e-5 2e-5 3e-5 4e-5 6e-5 1e-4 1e-3\n")
ar_finish()
