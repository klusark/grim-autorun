-- GetSectorName(x, y, z) on Jambalaya (gpt): the tourist waypoints of gpt.tourist_waypoints (the game's own use: the tourist script
-- waits until the tourist leaves the waypoint's sector) and a grid of points at two heights. One SN line per point.
ar_log("=== gpt GetSectorName ===")
ar_wait_for_control()
dofile("_jumpscripts.lua")
start_script(jump_script, "250")
local t = 0
while (system.currentSet ~= gpt or cutSceneLevel > 0) and t < 600 do
	break_here()
	t = t + 1
end
ar_wait_for_control()
sn_at = function(label, x, y, z)
	ar_log("SN " .. label .. " " .. x .. " " .. y .. " " .. z .. ": " .. tostring(GetSectorName(x, y, z)))
end
local i = 1
while gpt.tourist_waypoints and gpt.tourist_waypoints[i] do
	local w = gpt.tourist_waypoints[i]
	sn_at("wp" .. i .. "(" .. tostring(w[4]) .. ")", w[1], w[2], w[3])
	if w[4] then
		box_on(w[4])
		sn_at("wp" .. i .. "(" .. w[4] .. " on)", w[1], w[2], w[3])
		box_off(w[4])
		sn_at("wp" .. i .. "(" .. w[4] .. " off)", w[1], w[2], w[3])
	end
	i = i + 1
end
local gp = guybrush:getpos()
sn_at("guybrush", gp.x, gp.y, gp.z)
local y = 0.5
while y < 4 do
	local x = -50
	while x <= 20 do
		local z = -40
		while z <= 15 do
			sn_at("grid", x, y, z)
			z = z + 5
		end
		x = x + 5
	end
	y = y + 2.5
end
sn_at("far", 1000, 0, 1000)
ar_log("SN done")
