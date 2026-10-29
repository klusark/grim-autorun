-- Chapter 36: Rubacava's end. In the cafe office the roulette panel steers the casino's tables;
-- when Bogen's table is the spinning one, switching its magnet off breaks the house.
-- Checkpoint in slot 52 (the next year starts).

ar_load(35)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(lm.hb_door, hb)
ar_go(hb.bw_door, bw)
ar_go(bw.ev_door, ev, -2.49, -2.35, 0.2)
ar_go(ev.ce_door, ce, -0.5, -0.85, 0.05)
ar_go(ce.cc_door, cc)
sleep_for(2000)
ar_wait_for_control()
ar_go(cc.cf_door, cf)
ar_wait_for_control()
ar_check(cn.bogens_in_the_house_again, "Bogen is back in the casino")
ar_do("use", cf.panel)
ar_wait_for(function() return system.buttonHandler == roulettePanelButtonHandler end, 60000)
ar_check(system.buttonHandler == roulettePanelButtonHandler, "the roulette panel is open")
local waited = 0
while not (current_roulette_table == bogen_table and current_roulette_table.rate > 0 and current_roulette_table.magnet ~= nil) and waited < 600000 do
	sleep_for(50)
	waited = waited + 50
end
ar_log("Bogen's table: " .. tostring(current_roulette_table == bogen_table))
ar_press("use")
ar_wait_for(function() return find_script(cut_scene.byeruba) end, 60000)
ar_log("byeruba started")
ar_wait_for(function() return not find_script(cut_scene.byeruba) and cutSceneLevel == 0 end, 900000)
ar_wait_for_control()
ar_state("end of chapter 36")
ar_checkpoint(36)
