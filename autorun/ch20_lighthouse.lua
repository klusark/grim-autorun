-- Chapter 20: from the Blue Casket kitchen to the lighthouse: the skeleton key (chapter 19) opens its door; at the top Manny finds Lola (cutscene) and gets the card.
-- Checkpoint in slot 36.

ar_load(19)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(bk.bi_door, bi)
ar_go(bi.be_door, be)
ar_go(be.bw_door, bw)
ar_go(bw.dd_door, dd)
ar_wait_for_control()
ar_go(dd.lx_door, lx)
ar_wait_for_control()
ar_describe()
-- the pier ends in a sector that carries Manny to the foot of the lighthouse (lx.teleport)
ar_walk_to(-4.9, -12.1, 0, function() return manny:getpos().y > -8 end, 40000)
ar_wait_for_control()
ar_do("use", lx.lighthouse_door, sl.key)
ar_wait_for(function() return lx.lighthouse_door:is_open() or not sl.key.owner == manny end, 60000)
ar_wait_for_control()
ar_check(lx.lighthouse_door:is_open(), "the lighthouse door is open")
-- up the stairs to the lamp: Lola's cutscene, and Manny gets the card
local d = lx.lighthouse_door
ar_walk_to(d.use_pnt_x, d.use_pnt_y, d.use_pnt_z, function() return lx.seen_lola end)
ar_walk_to(d.obj_x, d.obj_y, d.use_pnt_z, function() return lx.seen_lola end)
ar_wait_for(function() return lx.seen_lola end, 600000)
ar_wait_for(function() return cutSceneLevel == 0 and not find_script(cut_scene.loladies) end, 600000)
ar_wait_for_control()
ar_state("after Lola")
ar_check(lx.lengua.owner == manny, "Manny has the card")
ar_checkpoint(20)
