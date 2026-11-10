-- EMI chapter 24: Mysts o' Tyme: the clock on the raft, on the raft, the map (Pegnose's directions) followed screen by screen
ar_load(23)
ar_log("=== EMI ch24 raft ===")
ar_wait_for_control()
ar_do("use", luc.lum_door2)
ar_wait_for_control()
ar_do("use", lum.mot_door)
ar_wait_for_control()
ar_state("mot")
ar_log("map: steps " .. tostring(glob.map_steps) .. " start " .. tostring(glob.map_start_index))
ar_i = glob.map_start_index
while ar_i ~= 0 and ar_i do
	local m = glob.map[ar_i]
	ar_log("MAP [" .. ar_i .. "] setup " .. m.setup .. " dir " .. m.direction .. " time " .. m.mins .. ":" .. m.secs .. " next " .. m.next)
	ar_i = m.next
end
ar_do("use", mot.raft_obj, props.clock)
ar_wait_for_control()
ar_log("clock on raft: " .. tostring(props.clock.state))
ar_do("use", mot.raft_obj)
ar_wait_for(function() return mot.guybrush_on_raft end, 60000, "on the raft")
ar_wait_for_control()
ar_log("on raft; raft at " .. tostring(swampraft:getpos().x) .. " " .. tostring(swampraft:getpos().z) .. " setup " .. tostring(mot.cur_setup_id))
-- the first screens of the map, up to the gate
ar_node = glob.map[glob.map_start_index]
ar_k = 0
while ar_node and ar_node.next ~= 0 and ar_k < 3 do
	ar_log("MAP STEP " .. (ar_k + 1) .. ": screen " .. tostring(mot.cur_setup_id) .. " should be " .. tostring(ar_node.setup) .. " exit " .. tostring(ar_node.direction))
	ar_raft_exit(ar_node.direction)
	ar_k = ar_k + 1
	ar_log("now screen " .. tostring(mot.cur_setup_id) .. " map_step " .. tostring(mot.map_step))
	ar_node = mot.this_map_thing
end
-- the gate: the future Guybrush on the other side brings the key
ar_wait_for(function() return mot.other_gb_at_center end, 60000, "the other Guybrush at the gate")
ar_state("gate")
start_script(ar_raft_exit, "gate_trigger")
ar_dlg("mot0")
sleep_for(1500)
ar_dialog_ready(mot0, 30000)
ar_pick(mot0, 10)
ar_dlg_done("mot0")
ar_log("question " .. tostring(mot.question) .. " response " .. tostring(mot.response) .. " give " .. tostring(mot.give[1]) .. tostring(mot.give[2]) .. tostring(mot.give[3]))
ar_state("after the gifts")
-- ask the future Guybrush the number he is thinking of (the proof that he is me), then open the gate for him with the key
ar_do("use", mot.guybrush2_obj)
ar_wait_for_control()
ar_log("guessed number " .. tostring(mot.guessed_num))
ar_do("use", mot.gate_obj, mot.key)
ar_wait_for(function() return mot.opened_gate end, 120000, "the gate open")
ar_wait_for_control()
ar_log("gate opened " .. tostring(mot.opened_gate) .. " step " .. tostring(mot.map_step) .. " screen " .. tostring(mot.cur_setup_id) .. " got " .. tostring(mot.got[1]) .. tostring(mot.got[2]) .. tostring(mot.got[3]))
ar_state("after the gate")
-- on along the map to the other side of the gate (where I am the future Guybrush)
-- (a wrong exit sends the raft to a random screen, three of them back to the start of the map: the steps of the map are not
-- taken again, the run fails, and the restart from the checkpoint before has the same map)
local ar_exits = 0
while mot.map_step < 6 do
	ar_exits = ar_exits + 1
	ar_check(ar_exits <= 8 and mot.map_step >= 3, "on the map after the gate (step " .. tostring(mot.map_step) .. ")")
	local m = mot.this_map_thing
	ar_log("MAP STEP " .. (mot.map_step + 1) .. ": screen " .. tostring(mot.cur_setup_id) .. " should be " .. tostring(m.setup) .. " exit " .. tostring(m.direction))
	ar_raft_exit(m.direction)
	ar_log("now screen " .. tostring(mot.cur_setup_id) .. " map_step " .. tostring(mot.map_step))
end
ar_wait_for(function() return mot.other_gb_at_center end, 60000, "the other Guybrush at the gate")
ar_state("the other side of the gate")
ar_log("screen " .. tostring(mot.cur_setup_id) .. " question " .. tostring(mot.question) .. " response " .. tostring(mot.response) .. " give " .. tostring(mot.give[1]) .. tostring(mot.give[2]) .. tostring(mot.give[3]) .. " guess " .. tostring(mot.guessed_num) .. " give_step " .. tostring(mot.give_step) .. " gave_key " .. tostring(mot.gave_key))
-- the future Guybrush's part: the key (and the answer to the question he asked), the two things in the order they came, the number
AR_NO_SKIP = nil
ar_dname = "mot" .. mot.question
-- (the raft is steered up to the other Guybrush, the USE key with the raft at rest puts the pole down, and then the key is given with the verb)
AR_RAFT_STOP = nil
start_script(ar_raft_walk, 400.3, 0.5)
ar_wait_for(function() return AR_RAFT_STOP or ar_hot_is(mot.guybrush2_obj) end, 40000, "the raft next to the other Guybrush")
sleep_for(3000)
AR_RAFT_STOP = TRUE
sleep_for(1000)
ar_press("use")
ar_wait_for(function() return mot.pole_down end, 30000, "the pole down")
ar_wait_for_control()
ar_inv_hold(mot.key)
ar_do_bg("use", mot.guybrush2_obj, mot.key)
ar_dlg(ar_dname)
sleep_for(1500)
ar_dialog_ready(getglobal(ar_dname), 30000)
ar_pick(getglobal(ar_dname), 10 * mot.response)
ar_dlg_done(ar_dname)
ar_log("gave key: give_step " .. tostring(mot.give_step) .. " screwed_up " .. tostring(mot.screwed_up))
ar_do("use", mot.guybrush2_obj, mot.get_item[mot.give[1]])
ar_wait_for_control()
ar_do_bg("use", mot.guybrush2_obj, mot.get_item[mot.give[2]])
ar_log("gave two: give_step " .. tostring(mot.give_step))
ar_dlg("mot4")
sleep_for(1500)
ar_dialog_ready(mot4, 30000)
ar_pick(mot4, mot.guessed_num)
ar_dlg_done("mot4")
ar_wait_for(function() return mot.opened_gate end, 120000, "the gate")
ar_wait_for_control()
ar_state("through the gate")
ar_log("screen " .. tostring(mot.cur_setup_id) .. " step " .. tostring(mot.map_step) .. " gave " .. tostring(mot.gave[1]) .. tostring(mot.gave[2]) .. tostring(mot.gave[3]))
ar_wait_for(function() return mot.map_step >= 7 or mot.cur_setup_id ~= 5 end, 180000, "the raft out of the gate screen")
ar_wait_for_control()
ar_state("after the gate screen")
ar_log("screen " .. tostring(mot.cur_setup_id) .. " step " .. tostring(mot.map_step) .. " gave " .. tostring(mot.gave[1]) .. tostring(mot.gave[2]) .. tostring(mot.gave[3]) .. " vortex " .. tostring(mot.vortex_on))
-- the last screen of the map: out to the right, to Pegnose Pete's hideout
ar_in_pph = function() return ar_set_name() == "pegnose petes hideout" and cutSceneLevel == 0 end
-- (the screen can change again after the gate while the raft is carried on: the way out is taken from the screen the raft is on now)
ch24_n = 0
while not ar_in_pph() and ch24_n < 5 do
	ch24_n = ch24_n + 1
	ar_wait_for_control()
	sleep_for(2000)
	ar_log("exit try " .. ch24_n .. ": screen " .. tostring(mot.cur_setup_id) .. " step " .. tostring(mot.map_step))
	ar_raft_exit(mot.this_map_thing.direction)
	ar_try_wait(ar_in_pph, 20000)
end
ar_wait_for(ar_in_pph, 180000, "Pegnose Pete's hideout")
ar_wait_for_control()
ar_state("pph")
ar_log("knows_ozzie_framed " .. tostring(glob.guybrush_knows_ozzie_framed) .. " been_to_pegnoses " .. tostring(glob.been_to_pegnoses))
ar_checkpoint(24)
