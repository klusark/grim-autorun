local set, nav = ar_nt_place({ set = "td", from = { 0.67, -2.62, -0.02 }, off = { "sigh_box" } })
local w = ar_w(nav)
local k, list = next(w.lk, nil)
while k do
	local i = 1
	while list[i] do
		local l = list[i]
		PrintDebug(format("link %s from (%.2f,%.2f,%.2f) step (%.2f,%.2f) to (%.2f,%.2f,%.2f)\n", l.kind, l.px, l.py, l.pz, l.ex, l.ey, l.lx, l.ly, l.lz))
		i = i + 1
	end
	k, list = next(w.lk, k)
end
