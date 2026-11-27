-- ScummVM #11847 (the animated sea in set shi looks clamped instead of repeated with TinyGL): the game's jump 120 (Melee harbour,
-- shi), held for a window capture (run with --renderer=software and =opengl to compare).
ar_log("=== shi_snap ===")
ar_wait_for_control()
dofile("_jumpscripts.lua")
start_script(jump_script, "120")
ar_wait_for(function() return system.currentSet == shi end, 30000, "the harbour")
ar_wait_for_control()
sleep_for(3000)
ar_log("TC READY")
sleep_for(20000)
ar_log("=== shi_snap done ===")
