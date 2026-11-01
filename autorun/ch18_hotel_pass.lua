-- Chapter 18: the gold flake liqueur from the casino bar, then across the town to the Hotel
-- Hatchet's elevator, and past Raoul, who lets him through now that Glottis is gambling inside. Checkpoint in slot 34.

ar_load(17)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(cn.ci_door, ci)
ar_do("pickUp", ci.liqueur)
ar_wait_for(function() return ci.liqueur.owner == manny end, 30000)
ar_check(ci.liqueur.owner == manny, "Manny has the liqueur")
ar_go(ci.cc_door, cc)
ar_go(cc.ce_door, ce)
ar_go(ce.ev_door, ev)
ar_go(ev.be_door, bw)
ar_go(bw.hb_door, hb)
ar_go(hb.xb_door, xb)
-- the extend-o-bridge is pulled out first
ar_do("use", xb.bridge)
ar_wait_for(function() return xb.bridge.extended end, 60000)
ar_wait_for_control()
ar_go(xb.tx_door, tx)
ar_go(tx.ts_door, ts)
ar_go(ts.tb_door, tb)
-- the first visit shows the track in a cutscene, which ends in the track window
ar_wait_for_control()
if system.currentSet == tw then
	ar_go(tw.tb_door, tb)
end
-- (Glottis is gambling in the high roller lounge since chapter 17: Raoul lets Manny through without the pass)
ar_go(tb.hh_door, hh, -0.3, 0.0, 0)
ar_wait_for_control()
ar_hh_elevator()
ar_go(hh.hl_door, hl)
ar_wait_for(function() return system.currentSet == hl end, 120000)
ar_wait_for_control()
ar_state("in the high roller lounge")
ar_checkpoint(18)
