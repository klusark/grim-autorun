-- TurnActorTo stepping: a fresh actor at Guybrush's place, turn rate 360, set to yaw 0 and turned with TurnActorTo toward points
-- at yaw 90, -90, 170, -170 and 30 (one call a frame). TT lines: each call's result and the yaw the frame after it, then the
-- yaw over the next 40 frames whenever it changes.
ar_log("=== turn_probe ===")
ar_wait_for_control()
TP = Actor:create(nil, nil, nil, "turn probe")
TP:set_wear_chore("props/lava_boat.cos")
TP:put_in_set(system.currentSet)
TP:ignore_boxes()
TP:set_turn_rate(360)
local p = guybrush:getpos()
TP:setpos(p.x, p.y, p.z)
local targets = { 90, -90, 170, -170, 30 }
local i = 1
while targets[i] do
	local tx = p.x + sin(targets[i]) * 3
	local tz = p.z + cos(targets[i]) * 3
	TP:setrot(0, 0, 0)
	break_here()
	break_here()
	local r0 = TP:getrot()
	ar_log("TT target " .. targets[i] .. " start yaw " .. r0.y .. " yawToPoint " .. GetActorYawToPoint(TP.hActor, tx, p.y, tz))
	local n = 0
	local res = TRUE
	while res and n < 60 do
		res = TurnActorTo(TP.hActor, tx, p.y, tz)
		break_here()
		n = n + 1
		local r = TP:getrot()
		ar_log("TT target " .. targets[i] .. " call " .. n .. " " .. tostring(res) .. " yaw " .. r.y)
	end
	local last = nil
	local k = 1
	while k <= 40 do
		break_here()
		local r = TP:getrot()
		if r.y ~= last then
			ar_log("TT target " .. targets[i] .. " after " .. k .. " yaw " .. r.y)
			last = r.y
		end
		k = k + 1
	end
	i = i + 1
end
ar_log("TT done")
