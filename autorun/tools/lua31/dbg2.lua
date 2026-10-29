local set, nav = ar_nt_place({ set = "td", from = { 0.67, -2.62, -0.02 }, off = { "sigh_box" } })
local w = ar_w(nav)
local si = nil
local i = 1
while nav.n[i] do if nav.n[i] == "stair1" then si = i end i = i + 1 end
local p = nav.p[si]
local n = nav.pn[si]
local cx, cy = ar_nav_centre(nav, si)
local e = 0
while e < n do
	local ax, ay, az = ar_corner(p, n, e)
	local bx, by = ar_corner(p, n, e + 1)
	local nx, ny = ar_w_inward(ax, ay, bx, by, cx, cy)
	local f = 0.5
	local X = ax + (bx - ax) * f + nx * 0.04
	local Y = ay + (by - ay) * f + ny * 0.04
	local s = ar_nav_find(nav, X, Y, az)
	local dx, dy
	if s then
		dx, dy = ar_w_cons_dir(nav, s, X, Y, nx, ny)
		if dx then dx, dy = ar_w_cons_dir(nav, s, X, Y, dx, dy) end
	end
	PrintDebug(format("edge %d at %.2f,%.2f normal %.2f,%.2f sector %s dir %s %s\n", e, X, Y, nx, ny, tostring(s and nav.n[s]), tostring(dx), tostring(dy)))
	if dx then
		local before = AR_W_LINKS
		ar_w_cons_link(nav, w, X, Y, ar_nav_z(nav, s, X, Y), dx, dy)
	end
	e = e + 1
end
local x, y, z = 0.61, -2.74, ar_nav_z(nav, si, 0.61, -2.74)
local dx, dy = 0.738752, -0.673978
local t = 0
local qx, qy, qz = x, y, z
local ok = TRUE
while ok and t < 15 and ar_w_in_cons(nav, w, qx, qy) do
	t = t + 0.01
	qx = x + dx * t
	qy = y + dy * t
	local s = ar_nav_find(nav, qx, qy, qz)
	if not s or abs(ar_nav_z(nav, s, qx, qy) - qz) > 0.35 then
		ok = nil
		PrintDebug(format("stopped at t %.2f %.2f,%.2f sector %s\n", t, qx, qy, tostring(s)))
	else
		qz = ar_nav_z(nav, s, qx, qy)
	end
end
PrintDebug(format("end t %.2f at %.3f %.3f %.3f ok %s\n", t, qx, qy, qz, tostring(ok)))
local more = 0.1
while more >= 0 do
	local fk = ar_w_floor_at(nav, w, qx + dx * more, qy + dy * more, qz)
	PrintDebug(format("more %.2f floor %s\n", more, tostring(fk)))
	more = more - 0.03
end
