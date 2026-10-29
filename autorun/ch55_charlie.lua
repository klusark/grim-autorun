-- Chapter 55 (Year 4): the Le Mans lobby (ly), reached from the theater sewer now Manny looks like a
-- Thunderboy. The unicycle man (Charlie's agent) is talked to twice, Meche twice (she gives Manny her sheet),
-- the sheet is thrown over Chowchilla Charlie at his slot machine, and while he struggles the agent is asked
-- again: he climbs into Charlie's machine for the jackpot and Charlie is taken away by Meche
-- (puzzle state 56). Checkpoint in slot 71.

AR_NEW = TRUE
AR_CONTROL_TIMEOUT = 300000
ar_load(55)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(th.te_door, te)
ar_wait_for_control()
ar_climb(nil, nil, 40000)
ar_wait_for_control()
ar_go(te.ly_door, ly)
ar_wait_for_control()
ar_do_retry("use", ly.unicycle_man, nil, 12, 1.35, 0.05, 0)
ar_wait_for_control()
ar_do_retry("use", ly.unicycle_man, nil, 12, 1.35, 0.05, 0)
ar_wait_for_control()
ar_check(ly.agent_talk_count >= 2, "talked to the agent twice")
ar_do("use", ly.meche_obj)
-- (the talk is a script of its own, which is still going when the verb is over)
ar_wait_for(function() return not find_script(ly.talk_clothes_with_meche) end, 90000, "the talk with Meche")
ar_wait_for_control()
-- (Meche goes to Charlie after the first talk and cannot be spoken to until she is back)
AR_IDLE_MAX = 90000
ar_wait_for(function() return ly.meche_obj.touchable end, 90000, "Meche to be back")
AR_IDLE_MAX = nil
ar_do("use", ly.meche_obj)
ar_wait_for(function() return not find_script(ly.talk_clothes_with_meche) end, 90000, "the talk with Meche")
ar_wait_for_control()
ar_check(manny.is_holding == ly.sheet, "Manny holds Meche's sheet")
-- the agent rides about; Manny waits until he is close, as the sheet has to be followed by talking to him quickly
ar_wait_for(function() return proximity(manny.hActor, unicycle_man.hActor) < 1.4 end, 60000)
ar_do("use", ly.charlie_obj, ly.sheet)
ar_log("t after throw start " .. tostring(AR_NOW))
ar_wait_for(function() return ly.charlie_on_floor end, 60000)
ar_wait_for_control()
ar_check(ly.charlie_on_floor, "Charlie is under the sheet")
ar_log("t=" .. tostring(AR_NOW) .. " before the last talk: on floor " .. tostring(ly.charlie_on_floor) .. " agent talks " .. tostring(ly.agent_talk_count) .. " meche talks " .. tostring(ly.meche_talk_count))
-- he rides about, his use point is where he used to be: Manny runs up to him, quickly, there are 25 seconds
do
	local um = unicycle_man:getpos()
	local mp = manny:getpos()
	local dx = mp.x - um.x
	local dy = mp.y - um.y
	local dl = sqrt(dx * dx + dy * dy)
	manny:set_run(TRUE)
	ar_walk_stick(um.x + dx / dl * 0.5, um.y + dy / dl * 0.5, mp.z, nil, 6000)
end
local tries = 0
while tries < 25 and not ar_gaze_at(ly.unicycle_man) do
	ar_turn_to_point(unicycle_man:getpos().x, unicycle_man:getpos().y, manny:getpos().z)
	sleep_for(300)
	local um2 = unicycle_man:getpos()
	local mp2 = manny:getpos()
	if point_proximity(um2.x, um2.y, um2.z) > 0.6 then
		ar_walk_stick(um2.x + (mp2.x - um2.x) * 0.4, um2.y + (mp2.y - um2.y) * 0.4, mp2.z, nil, 800)
	end
	tries = tries + 1
end
ar_log("gazing at the agent after " .. tries .. " tries")
ar_press("use")
sleep_for(1000)
ar_log("t=" .. tostring(AR_NOW) .. " after the last talk: on floor " .. tostring(ly.charlie_on_floor) .. " agent talks " .. tostring(ly.agent_talk_count))
ar_wait_for(function() return cur_puzzle_state[56] end, 300000)
ar_wait_for_control()
ar_check(cur_puzzle_state[56], "Charlie is gone (puzzle state 56)")
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 55")
ar_checkpoint(56)
