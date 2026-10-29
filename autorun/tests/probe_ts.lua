-- Probe: the sector answers along the track stairs (ts.set, stairs_29_c from (-0.2,-0.15,0.55) to (0.895,-0.15,0)): the plane z at x is 0.55 * (0.895 - x) / 1.095
ar_wait_for_control()
local set = ts
set:switch_to_set("noenter")
break_here()
manny:put_in_set(set)
break_here()
local xs = { 0.1, 0.3, 0.5, 0.6, 0.61, 0.7, 0.8, 0.89 }
local dz = { 0, 0.003, 0.006, 0.009, 0.012 }
local i = 1
while xs[i] do
	local line = "TSPROBE x=" .. xs[i] .. ":"
	local j = 1
	while dz[j] do
		local z = 0.55 * (0.895 - xs[i]) / 1.095 + dz[j]
		local id, name = IsPointInSector(xs[i], -0.17, z, "")
		line = line .. " " .. tostring(name)
		j = j + 1
	end
	PrintDebug(line .. "\n")
	i = i + 1
end
ar_finish()
