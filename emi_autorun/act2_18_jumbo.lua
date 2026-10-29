-- Act 2 chapter 18: Knuttin's beach: the big pirate and his two parrots
ar_load(217)
ar_log("=== ACT2 ch18 jumbo ===")
ar_wait_for_control()
ar_put_away()
ar_do("use", cpt.kab_door)
ar_wait_for(function() return system.currentSet == kab end, 60000, "the beach")
sleep_for(3000)
ar_wait_for_control()
ar_state("on the beach")
ar_talk(kab.jumbo_obj)
ar_dlg("jm1")
sleep_for(4000)
ar_lines("jm1")
local seq = { 50, 60, 62, 200, 80, 70, 90, 95, 100, 105, 120, 125, 127 }
local i = 1
while seq[i] do
	sleep_for(5000)
	local k = a2_pick_any("jm1", { seq[i] })
	ar_log("picked " .. tostring(k) .. " for " .. seq[i])
	i = i + 1
end
sleep_for(8000)
ar_lines("jm1")
a2_leave("jm1")
ar_wait_for_control()
ar_log("kab_talked_hat=" .. tostring(glob.kab_talked_hat) .. " heard_truth_about_tiny=" .. tostring(glob.heard_truth_about_tiny) .. " disc_parrots=" .. tostring(glob.kab_disc_parrots))
ar_check(glob.kab_talked_hat, "knows the hat is under a boulder")
ar_checkpoint(218)
