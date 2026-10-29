-- Chapter 22: the cat stables. The can opener on the shelf, then the scythe finds the metal
-- detector in the litter (sound guides Manny to the buried spot). Checkpoint in slot 38.

ar_load(21)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(sl.gt_door, gt)
ar_go(gt.tb_door, tb)
-- the first visit from this side shows the track in a cutscene, which ends in the track window
ar_wait_for_control()
ar_wait_for(function() return tb.seen_intro and not find_script(tb.show_room) end, 120000)
ar_wait_for_control()
if system.currentSet == tw then
	ar_go(tw.tb_door, tb)
end
ar_go(tb.ts_door, ts)
ar_go(ts.kh_door, kh)
ar_go(kh.ks_door, ks)
ar_wait_for_control()
ar_describe()
ar_do("pickUp", ks.opener)
ar_check(ks.opener.owner == manny, "Manny has the can opener")
-- (the dig for the detector is watched to its end: skipped, it does not hand the detector over)
AR_NO_SKIP = TRUE
ar_do("use", ks.litter2, mo.scythe)
ar_wait_for(function() return sl.detector.retrieved end, 120000)
ar_wait_for(function() return sl.detector.owner == manny end, 60000)
AR_NO_SKIP = nil
ar_wait_for_control()
ar_check(sl.detector.owner == manny, "Manny has the metal detector")
ar_state("end of chapter 22")
ar_checkpoint(22)
