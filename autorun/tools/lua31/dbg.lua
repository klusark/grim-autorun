ar_nt_unit({ id = "sh", set = "sh", from = { 0.61, -0.05, 0.39 }, door = "te_door", off = { "glottis_gone", "bw_up1", "bw_up2", "bw_up3" } })
local set, nav = ar_nt_place({ set = "sh", from = { 0.61, -0.05, 0.39 } })
local i = 1
while nav.n[i] do
	local p = nav.p[i]
	local near = nil
	local k = 1
	while p[k] do if abs(p[k]) < 2.5 and abs(p[k + 1]) < 2.5 then near = TRUE end k = k + 3 end
	if near then
		local s = nav.n[i] .. ":"
		k = 1
		while p[k] do s = s .. format(" (%.2f,%.2f,%.2f)", p[k], p[k + 1], p[k + 2]); k = k + 3 end
		PrintDebug(s .. "\n")
	end
	i = i + 1
end
i = 1
while nav.hn[i] do
	local p = nav.hp[i]
	local s = "HOT " .. nav.hn[i] .. ":"
	local k = 1
	while p[k] do s = s .. format(" (%.2f,%.2f,%.2f)", p[k], p[k + 1], p[k + 2]); k = k + 3 end
	PrintDebug(s .. "\n")
	i = i + 1
end
