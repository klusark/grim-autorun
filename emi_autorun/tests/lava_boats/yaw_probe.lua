-- ScummVM #11824 probe: the lava ride's boats are set up facing GetActorYawToPoint(next) - 90, and after a bump turned with
-- TurnActorTo (Actor.turn_toward_entity) to the next point. Compares the two on an actor in the first set, for 8 directions.
ar_log("=== yaw_probe ===")
ar_wait_for_control()
YP = Actor:create(nil, nil, nil, "yaw probe")
YP:set_wear_chore("props/lava_boat.cos")
YP:put_in_set(system.currentSet)
YP:ignore_boxes()
YP:set_turn_rate(720)
local p = guybrush:getpos()
YP:setpos(p.x, p.y, p.z)
local dirs = { { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 } }
local i = 1
while dirs[i] do
	local tx = p.x + dirs[i][1] * 3
	local tz = p.z + dirs[i][2] * 3
	YP:setrot(0, 0, 0)
	local yaw = GetActorYawToPoint(YP.hActor, tx, p.y, tz)
	local n = 0
	while TurnActorTo(YP.hActor, tx, p.y, tz) and n < 400 do
		break_here()
		n = n + 1
	end
	local r = YP:getrot()
	ar_log("YP dir " .. dirs[i][1] .. " " .. dirs[i][2] .. " yawToPoint " .. yaw .. " turnTo " .. r.y)
	i = i + 1
end
ar_log("=== yaw_probe done ===")
