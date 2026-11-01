-- EXTRA=dump_xb.lua: the sectors of the extend-o-bridge as the planner has them (walk sectors, then hot ones), one line each, when Manny first stands in it
ar_dump_xb = function()
	while system.currentSet ~= xb do
		break_here()
	end
	local nav = ar_nav_of(system.currentSet)
	local i = 1
	while nav.n[i] do
		local p = nav.p[i]
		local s = ""
		local j = 1
		while p[j] do
			s = s .. format("(%.2f %.2f %.2f)", p[j], p[j + 1], p[j + 2])
			j = j + 3
		end
		ar_log("XBSEC walk " .. tostring(nav.n[i]) .. " type " .. tostring(nav.t[i]) .. " " .. s)
		i = i + 1
	end
	i = 1
	while nav.hn[i] do
		local p = nav.hp[i]
		local s = ""
		local j = 1
		while p[j] do
			s = s .. format("(%.2f %.2f %.2f)", p[j], p[j + 1], p[j + 2])
			j = j + 3
		end
		ar_log("XBSEC hot " .. tostring(nav.hn[i]) .. " " .. s)
		i = i + 1
	end
	-- the links of the world: from the floor at (px py) over the step in at (ex ey) to the floor at (lx ly)
	local w = ar_w(nav)
	local fk, list = next(w.lk, nil)
	while fk do
		local n = 1
		while list[n] do
			local l = list[n]
			ar_log(format("XBLINK %s from %.2f %.2f %.2f step %.2f %.2f to %.2f %.2f %.2f cost %.2f", tostring(l.kind), l.px, l.py, l.pz, l.ex, l.ey, l.lx, l.ly, l.lz, l.cost))
			n = n + 1
		end
		fk, list = next(w.lk, fk)
	end
end
start_script(ar_dump_xb)

-- AR_XB_DROP_SOUTH = TRUE: the link over the south edge of ws_sd_box is taken out of the world, to see what the plan is without it
ar_xb_drop = function()
	while system.currentSet ~= xb do
		break_here()
	end
	break_here()
	local nav = ar_nav_of(system.currentSet)
	local w = ar_w(nav)
	local fk, list = next(w.lk, nil)
	while fk do
		local n = 1
		while list[n] do
			local l = list[n]
			if l.kind == "c" and l.ex > 39.8 and l.ey < -14.0 then
				ar_log("XBDROP the link over the south edge at " .. format("%.2f %.2f", l.ex, l.ey))
				list[n] = list[ar_nav_len(list)]
				list[ar_nav_len(list)] = nil
				n = n - 1
			end
			n = n + 1
		end
		fk, list = next(w.lk, fk)
	end
end
if AR_XB_DROP_SOUTH then
	start_script(ar_xb_drop)
end
