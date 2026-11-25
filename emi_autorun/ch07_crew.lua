ar_knows_contracts = function() return glob.knows_to_get_contracts end
-- EMI chapter 7: Melee town: Carla and Otis, the signed cushy contract: the crew
ar_log("=== EMI ch07 crew ===")
ar_wait_for_control()
ar_do("use", gmi.gme_door)
ar_wait_for_control()
ar_do("use", gme.mem_door)
ar_wait_for_control()
ar_do("use", mem.mel_door)
ar_wait_for_control()
ar_check(ar_set_name() == "melee town", "in Melee town")
ar_talk(mel.carlaotis_obj)
ar_dlg("carlo")
sleep_for(1500)
-- (the way to the contracts: the crew asked for (100: they look familiar), recognised (330: the cruise to Monkey Island, which opens
-- 116), asked again for old time's sake (116), bribed with cushy government jobs (235: knows_to_get_contracts))
ar_route("carlo", { 100, 330, 116, 235 })
if not ar_knows_contracts() then
	AR_EXH_REPEAT = 3
	ar_exhaust("carlo", ar_knows_contracts, 80)
	AR_EXH_REPEAT = nil
end
ar_log("knows_to_get_contracts=" .. tostring(glob.knows_to_get_contracts))
if getglobal("carlo") and carlo.running then
	ar_say_exit("carlo")
end
ar_dlg_done("carlo")
ar_check(glob.knows_to_get_contracts, "Carla and Otis want a signed contract")
ar_do("use", mel.carlaotis_obj, props.cushycontract)
ar_wait_for_control()
ar_check(glob.got_crew, "the crew is complete")
