-- Chapter 23: the morgue. The metal detector is for the coroner Membrillo; while he sweeps the
-- other corpse the sailor's dog tags go on the first one, he finds them: a vacancy is made
-- (cut_scene.idcorpse). Checkpoint in slot 39.

ar_load(22)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(ks.kh_door, kh)
ar_go(kh.ts_door, ts)
ar_go(ts.tx_door, tx)
ar_go(tx.xb_door, xb)
ar_go(xb.hb_door, hb)
ar_go(hb.bw_door, bw)
ar_go(bw.ev_door, ev, -2.49, -2.35, 0.2)
ar_go(ev.pc_door, pc)
ar_wait_for_control()
ar_describe()
ar_go(pc.mg_door, mg)
ar_wait_for_control()
ar_state("in the morgue")
-- the coroner is given the metal detector and sweeps the other corpse
ar_do("use", mg.membrillo_obj, sl.detector)
ar_wait_for(function() return membrillo.detecting end, 120000)
ar_wait_for_control()
ar_check(membrillo.detecting, "Membrillo has the detector")
-- the tags go on the first corpse; the detector finds them
ar_do("use", mg.corpse_1, si.dog_tags)
ar_wait_for(function() return made_vacancy end, 300000)
ar_check(made_vacancy, "a vacancy is made")
ar_wait_for(function() return system.currentSet ~= mg and cutSceneLevel == 0 end, 300000)
ar_wait_for_control()
ar_state("end of chapter 23")
ar_checkpoint(23)
