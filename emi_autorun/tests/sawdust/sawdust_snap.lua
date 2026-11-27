-- ScummVM #11870: the sawdust piles of Ozzie's trail in Lucre's forest are turned at weird angles. From the game's jump to the dust
-- trail (165), the cane state that makes for.enter lay out the 11 piles (fx/sawdust.cos, "single_pile"), into the forest, wide
-- setup; logs SNAP READY and holds 25 s for a window capture (tests/kitchen_lever/cap.ps1).
ar_log("=== sawdust_snap ===")
ar_wait_for_control()
dofile("_jumpscripts.lua")
start_script(jump_script, "165")
ar_wait_for(function() return system.currentSet == hos end, 30000, "the House of Sticks")
ar_wait_for_control()
sleep_for(1000)
props.ozzies_cane.state = PROP_LOC2
switch_to_set("for")
ar_wait_for(function() return system.currentSet == for end, 30000, "the forest")
guybrush:put_in_set(for)
guybrush:setpos(4.4, 0, 1.2)
guybrush:setrot(0, 180, 0)
for:current_setup(for_wide)
sleep_for(3000)
ar_log("SAWDUST SNAP READY")
sleep_for(25000)
ar_log("=== sawdust_snap done ===")
