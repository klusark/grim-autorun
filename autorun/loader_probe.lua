ar_probe_set = function(file, setname)
	local sf = ar_sf_load(file)
	local nav = AR_NAV[setname]
	local hot = ar_nav_hotnav(nav)
	local bad = 0
	local checked = 0
	local i = 1
	while sf.n[i] do
		local found = nil
		local k = 1
		while nav.n[k] and not found do
			if nav.n[k] == sf.n[i] then found = nav.p[k] end
			k = k + 1
		end
		k = 1
		while hot.n[k] and not found do
			if hot.n[k] == sf.n[i] then found = hot.p[k] end
			k = k + 1
		end
		if found then
			checked = checked + 1
			local p = sf.p[i]
			local m = 1
			while found[m] or p[m] do
				if not found[m] or not p[m] or abs(found[m] - p[m]) > 0.01 then
					bad = bad + 1
					PrintDebug("SETFILE   differs: " .. sf.n[i] .. " at " .. m .. " file " .. tostring(p[m]) .. " data " .. tostring(found[m]) .. "\n")
					m = 100000
				end
				m = m + 1
			end
		end
		i = i + 1
	end
	PrintDebug("SETFILE " .. file .. ": " .. sf.lines .. " lines, " .. sf.count .. " sectors, " .. checked .. " found in the data, " .. bad .. " differ\n")
end
ar_probe_set("ha.set", "Hallway")
ar_probe_set("ga.set", "Garage")
ar_probe_set("si.set", "Scrimshaw Interior")
ar_probe_set("os.set", "office steps")
PrintDebug("SETFILE DONE\n")
