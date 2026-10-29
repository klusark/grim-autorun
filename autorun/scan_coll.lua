ar_load(19)
local set = getglobal("re")
set:switch_to_set()
ar_wait_for_control()
velasco:default()
velasco:put_in_set(set)
velasco:push_costume("velasco_idles.cos")
velasco:setpos(0.633072972, -3.98850989, -3.4000001)
velasco:setrot(0, 140.009003, 0)
velasco:set_collision_mode(COLLISION_BOX, 1)
manny:put_in_set(set)
manny:set_collision_mode(COLLISION_SPHERE)
SetActorCollisionScale(manny.hActor, 0.349999994)
local y = 0
while y < 360 do
	manny:setpos(0.585, -4.258, -3.4)
	manny:setrot(0, y, 0, TRUE)
	break_here()
	break_here()
	local k = 0
	while k < 120 do
		manny:walk_forward()
		break_here()
		k = k + 1
	end
	local p = manny:getpos()
	PrintDebug("SCAN yaw " .. y .. format(" -> %.3f %.3f", p.x, p.y) .. "\n")
	y = y + 30
end
PrintDebug("SCAN done\n")
AR_FAILED = nil
