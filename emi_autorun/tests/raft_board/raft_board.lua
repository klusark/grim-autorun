-- ScummVM #11819: Guybrush lies tilted when he gets on the raft at the Mysts o' Tyme (mot.get_on_raft: flyto onto it, turn to a
-- point, walk_forward with the boxes off). From the game's jump to Lucre (150) into mot beside the raft, "use" on the raft: logs
-- Guybrush's rotation every few frames during the boarding and the largest pitch (x) and roll (z).
ar_log("=== raft_board ===")
ar_wait_for_control()
dofile("_jumpscripts.lua")
start_script(jump_script, "150")
ar_wait_for(function() return system.currentSet == luc end, 30000, "Lucre")
ar_wait_for_control()
sleep_for(1000)
switch_to_set("mot")
ar_wait_for(function() return system.currentSet == mot end, 30000, "the Mysts o' Tyme")
guybrush:put_in_set(mot)
guybrush:setpos(-0.6, 0, -4.9)
guybrush:setrot(0, 349, 0)
ar_wait_for_control()
sleep_for(1500)
RB_ON = TRUE
RB_MX = 0
RB_MZ = 0
rb_angle = function(a)
	while a > 180 do a = a - 360 end
	while a < -180 do a = a + 360 end
	if a < 0 then a = -a end
	return a
end
rb_watch = function()
	local f = 0
	while RB_ON do
		local r = guybrush:getrot()
		local p = guybrush:getpos()
		local x = rb_angle(r.x)
		local z = rb_angle(r.z)
		if x > RB_MX then RB_MX = x end
		if z > RB_MZ then RB_MZ = z end
		f = f + 1
		if mod(f, 5) == 0 and cutSceneLevel > 0 then
			ar_log("RBR " .. r.x .. " " .. r.y .. " " .. r.z .. " at " .. p.x .. " " .. p.y .. " " .. p.z)
		end
		break_here()
	end
end
start_script(rb_watch)
ar_log("RB READY")
sleep_for(12000)
ar_log("RB USE")
ar_send_verb("use", mot.raft_obj, "the raft")
ar_wait_for(function() return mot.guybrush_on_raft end, 30000, "Guybrush on the raft")
ar_wait_for_control()
sleep_for(1000)
RB_ON = nil
ar_log("RB largest pitch " .. RB_MX .. " roll " .. RB_MZ)
sleep_for(15000)
