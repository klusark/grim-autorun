-- Knuttin town (cpt): Guybrush driven with the walk keys into the cheat box cheat_front. Its walkable part is a sliver of about 0.04 m2
-- (x 7.03..7.48, z -8.50..-9.23) between the east edge of sector156 and the edge cheat_front shares with cheat_front2. Doorman then
-- calls teleport_out_of_hot_box -> GetSectorOppositeEdge(guybrush, "cheat_front"): ScummVM master looked the name up as a part of a
-- name and took cheat_front2 (it comes first in the set), Monkey4.exe takes the exact name. Each drive starts on the floor's east
-- edge north of the boxes; the frame Guybrush jumps by more than half a metre is logged with the hot box he was in.
-- Lines: CF <drive> ... (both engines print the same keys)

ar_log("=== cheat_front drive ===")
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
ar_log("CF set " .. tostring(system.currentSet and system.currentSet.setFile))

-- the frame-by-frame watch: CF_PREV the place in the frame before, CF_HOT the hot box then
CF_JUMPED = nil
cf_watch = function()
	local p = guybrush:getpos()
	if CF_PREV then
		local dx = p.x - CF_PREV.x
		local dz = p.z - CF_PREV.z
		if dx * dx + dz * dz > 0.25 and not CF_JUMPED then
			CF_JUMPED = TRUE
			ar_log("CF " .. CF_DRIVE .. format(" jump from %.3f %.3f %.3f", CF_PREV.x, CF_PREV.y, CF_PREV.z) .. " in " .. tostring(CF_HOT) ..
				format(" to %.3f %.3f %.3f", p.x, p.y, p.z) .. " setup " .. tostring(cpt:current_setup()))
		end
	end
	local id, name = GetActorSector(guybrush.hActor, HOT)
	CF_HOT = name
	CF_PREV = p
	return CF_JUMPED
end

cf_drive = function(label, sx, sz, yaw, tx, tz, ms)
	CF_DRIVE = label
	CF_JUMPED = nil
	CF_PREV = nil
	ar_drive_stop()
	guybrush:setpos(sx, 3.25, sz)
	guybrush:setrot(0, yaw, 0)
	sleep_for(500)
	doorman_in_hot_box = FALSE
	local p = guybrush:getpos()
	ar_log("CF " .. label .. format(" start %.3f %.3f %.3f", p.x, p.y, p.z))
	ar_walk_direct(tx, 3.25, tz, cf_watch, ms)
	ar_drive_stop()
	sleep_for(1000)
	p = guybrush:getpos()
	ar_log("CF " .. label .. format(" end %.3f %.3f %.3f", p.x, p.y, p.z) .. " jumped " .. tostring(CF_JUMPED) .. " setup " .. tostring(cpt:current_setup()))
end

-- (a walk from where the jump puts him, to see that the keys move him here)
local p0 = guybrush:getpos()
ar_walk_direct(p0.x - 2, p0.y, p0.z, nil, 4000)
local p1 = guybrush:getpos()
ar_log("CF walk test" .. format(" from %.3f %.3f to %.3f %.3f", p0.x, p0.z, p1.x, p1.z))

-- A: straight along the edge (the line through the sliver)
cf_drive("A", 4.3, -2.6, 155, 10.0, -14.6, 6000)
-- B: aimed a little east of the edge, so that he walks along it
cf_drive("B", 4.3, -2.6, 155, 10.6, -14.2, 6000)
-- C: the same from a little further west
cf_drive("C", 4.1, -2.4, 155, 11.0, -13.6, 6000)
ar_log("CF done")
