-- To watch: Knuttin town's cheat_front driven into twice (the places found by cf_drive2.lua), with pauses before and after. The first
-- drive comes from the west (the original carries Guybrush across the box to about 21.2 -13.6), the second along the floor's edge.
ar_log("=== cheat_front show ===")
ar_wait_for_control()
dofile("_jumpscripts.lua")
start_script(jump_script, "275")
local t = 0
while (system.currentSet ~= cpt or cutSceneLevel > 0) and t < 600 do
	break_here()
	t = t + 1
end
ar_wait_for_control()
ar_log("CFW starting in 5 s")
sleep_for(5000)

cfw_drive = function(label, tx, tz, yaw)
	local fx = sin(yaw)
	local fz = cos(yaw)
	doorman_disabled = TRUE
	guybrush:setpos(tx - fx * 1.5, 3.25, tz - fz * 1.5)
	guybrush:setrot(0, yaw, 0)
	ar_log("CFW " .. label .. ": in place, walking in 3 s")
	sleep_for(3000)
	doorman_in_hot_box = FALSE
	doorman_disabled = FALSE
	local prev = guybrush:getpos()
	local k = 0
	local done = nil
	while k < 400 and not done do
		guybrush:walk_forward()
		break_here()
		local p = guybrush:getpos()
		local dx = p.x - prev.x
		local dz = p.z - prev.z
		if dx * dx + dz * dz > 0.25 then
			ar_log("CFW " .. label .. format(": jumped from %.2f %.2f to %.2f %.2f", prev.x, prev.z, p.x, p.z))
			done = TRUE
		end
		prev = p
		k = k + 1
	end
	sleep_for(6000)
end

cfw_drive("from the west", 7.1, -8.55, 120)
cfw_drive("along the edge", 7.1, -8.55, 155)
ar_log("CFW done")
sleep_for(8000)
