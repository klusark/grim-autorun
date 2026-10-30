-- Chapter 38: the sunken Lola. Walking the ring of the wreck brings Chepito, the lamplighter, who
-- circles Manny. When he passes close, Manny turns to him and stops him with a talk; after the
-- talk he dangles his lantern as bait, Manny grabs it (and Chepito) and hands him to Glottis
-- (left or right key): the Pearl cutscene. Checkpoint in slot 54.

ar_load(37)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- the ring of the wreck: Glottis comments, then Chepito appears
ar_walk_to(0.55, -3.65, 0)
ar_wait_for_control()
ar_walk_to(-0.1, -4.35, 0)

-- turns Manny to an object's actor, step by step as the stick does, and has the game offer it
local face = function(obj)
	local io = obj.interest_actor
	local p = io:getpos()
	local n = 0
	while TurnActorTo(manny.hActor, p.x, p.y, p.z) and n < 100 do
		break_here()
		n = n + 1
	end
	return ar_gaze_at(obj)
end

local done = nil
local w = 0
while not done and w < 6000 do
	local io = su.moving_chepito_obj.interest_actor
	if su.moving_chepito_obj.touchable and io and proximity(io) < 1.45 then
		if face(su.moving_chepito_obj) then
			ar_press("use")
			done = TRUE
		end
	end
	sleep_for(50)
	w = w + 1
end
ar_check(done, "Manny stopped Chepito")
ar_wait_for(function() return cp1 and system.buttonHandler == cp1 end, 60000)
ar_check(cp1 and system.buttonHandler == cp1, "Chepito talks")
ar_pick_exit(cp1)
-- the lines Chepito says while he is held are the time the player has to give him to Glottis: they are not skipped (AR_SAYING keeps the line skipper off)
AR_SAYING = TRUE

-- the bait
done = nil
w = 0
while not done and w < 6000 do
	if su.lantern.touchable and face(su.lantern) then
		ar_press("pickUp")
		done = TRUE
	end
	sleep_for(50)
	w = w + 1
end
ar_check(done, "Manny grabbed the lantern")
ar_wait_for(function() return system.buttonHandler == suButtonHandler end, 120000)
ar_check(system.buttonHandler == suButtonHandler, "Manny holds Chepito")
ar_key_down("TURN_RIGHT")
sleep_for(150)
ar_key_up("TURN_RIGHT")
ar_wait_for(function() return system.currentSet == ps end, 600000)
AR_SAYING = nil
ar_wait_for(function() return ps.octo_here and not find_script(cut_scene.thepearl) end, 900000)
ar_wait_for_control()
local pp = manny:getpos()
ar_log("POS_AFTER " .. pp.x .. " " .. pp.y)
ar_state("end of chapter 38")
ar_checkpoint(38)
