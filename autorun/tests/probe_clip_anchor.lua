-- Probe (frames through DumpFrame, DUMPDIR=<dir>; the original through tools/framecap.py): Manny in the porthole scenes dp and op (the clip plane of their enter
-- scripts, a near-vertical plane at y = 0.01) moved across the plane along y, the plane on (as the script sets it) and off again at the same places
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
probe_wait = function(n)
	local k = 0
	while k < n do
		k = k + 1
		break_here()
	end
end
probe_anchor = function(case, x, ys, cx, cy)
	ar_nt_place(case)
	probe_wait(150)
	SetActorClipPlane(manny.hActor, 0, 1, 0.02, cx, cy, 0)
	SetActorClipActive(manny.hActor, TRUE)
	local p = manny:getpos()
	ar_log("PROBE " .. case.id .. " pos " .. format("%.4f %.4f %.4f", p.x, p.y, p.z))
	ar_frame(case.id .. "_start")
	probe_wait(40)
	local i = 1
	while ys[i] do
		manny:setpos(x, ys[i], 0)
		probe_wait(6)
		local q = manny:getpos()
		ar_log("PROBE at " .. format("%.3f %.3f %.3f", q.x, q.y, q.z) .. " asked y " .. ys[i])
		ar_frame(case.id .. "_y" .. format("%03d", floor(ys[i] * 100 + 100.5)))
		probe_wait(40)
		i = i + 1
	end
	SetActorClipActive(manny.hActor, FALSE)
	i = 1
	while ys[i] do
		manny:setpos(x, ys[i], 0)
		probe_wait(6)
		local q = manny:getpos()
		ar_log("PROBE at " .. format("%.3f %.3f %.3f", q.x, q.y, q.z) .. " asked y " .. ys[i])
		ar_frame(case.id .. "_off_y" .. format("%03d", floor(ys[i] * 100 + 100.5)))
		probe_wait(40)
		i = i + 1
	end
end
probe_anchor({ id = "dp", set = "dp" }, -0.03, { 0.30, 0.15, 0.05, 0.0, -0.05, -0.15 }, -0.03, 0.0107)
probe_anchor({ id = "op", set = "op" }, 0.012, { 0.30, 0.15, 0.05, 0.0, -0.05, -0.15 }, 0.0122, 0.0168)
AR_KEEP_GOING = nil
ar_finish()
