-- Knuttin town (cpt), cheat_front: first a sweep of where the game itself says Guybrush is in cheat_front (GetActorSector HOT, after
-- setpos, which keeps him on the floor), then drives into the first place found: Guybrush steps forward frame by frame
-- (walk_forward, the step the autorun takes when the keys do not reach him) with Doorman running, and the frame he jumps is logged.
-- Lines: CFS (sweep), CFD (drive). The same script on ScummVM master, ScummVM with the fix and Monkey4.exe.

ar_log("=== cheat_front drive 2 ===")
ar_wait_for_control()
dofile("_jumpscripts.lua")
start_script(jump_script, "275")
local t = 0
while (system.currentSet ~= cpt or cutSceneLevel > 0) and t < 600 do
	break_here()
	t = t + 1
end
ar_wait_for_control()
sleep_for(1000)

-- the sweep: x 6.6..8.0, z -8.2..-9.8, 5 cm apart; doorman off meanwhile (no frame passes between a setpos and the look)
doorman_disabled = TRUE
CFS_N = 0
CFS_X = nil
CFS_Z = nil
local x = 6.6
while x <= 8.0 do
	local z = -8.2
	while z >= -9.8 do
		guybrush:setpos(x, 3.25, z)
		local id, name = GetActorSector(guybrush.hActor, HOT)
		if name == "cheat_front" then
			local p = guybrush:getpos()
			CFS_N = CFS_N + 1
			if not CFS_X then
				CFS_X = p.x
				CFS_Z = p.z
			end
			if CFS_N <= 12 then
				ar_log("CFS in cheat_front at" .. format(" %.3f %.3f (asked %.2f %.2f)", p.x, p.z, x, z))
			end
		end
		z = z - 0.05
	end
	x = x + 0.05
	break_here()
end
ar_log("CFS points in cheat_front: " .. CFS_N)
doorman_disabled = FALSE

-- a drive: from a point 1.5 m behind the target along the yaw, walk_forward each frame for up to 3 s
cfd_drive = function(label, tx, tz, yaw)
	local fx = sin(yaw)
	local fz = cos(yaw)
	doorman_disabled = TRUE
	guybrush:setpos(tx - fx * 1.5, 3.25, tz - fz * 1.5)
	guybrush:setrot(0, yaw, 0)
	sleep_for(300)
	doorman_in_hot_box = FALSE
	doorman_disabled = FALSE
	local prev = guybrush:getpos()
	local prevhot = nil
	local k = 0
	local done = nil
	ar_log("CFD " .. label .. format(" start %.3f %.3f yaw %d", prev.x, prev.z, yaw))
	while k < 180 and not done do
		guybrush:walk_forward()
		break_here()
		local p = guybrush:getpos()
		local dx = p.x - prev.x
		local dz = p.z - prev.z
		if dx * dx + dz * dz > 0.25 then
			ar_log("CFD " .. label .. format(" jump from %.3f %.3f", prev.x, prev.z) .. " in " .. tostring(prevhot) .. format(" to %.3f %.3f %.3f", p.x, p.y, p.z) .. " step " .. k)
			done = TRUE
		end
		local hi, hn = GetActorSector(guybrush.hActor, HOT)
		if hn ~= prevhot then
			ar_log("CFD " .. label .. " step " .. k .. " hot " .. tostring(hn) .. format(" %.3f %.3f", p.x, p.z))
		end
		prevhot = hn
		prev = p
		k = k + 1
	end
	local q = guybrush:getpos()
	ar_log("CFD " .. label .. format(" end %.3f %.3f", q.x, q.z) .. " jumped " .. tostring(done))
end

if CFS_X then
	cfd_drive("along_edge", CFS_X, CFS_Z, 155)
	cfd_drive("from_north", CFS_X, CFS_Z, 180)
	cfd_drive("from_west", CFS_X, CFS_Z, 120)
end
-- and cheat_front2 for comparison (the same in every engine: its name is its own)
cfd_drive("front2", 7.4, -10.2, 155)
ar_log("CFD done")
