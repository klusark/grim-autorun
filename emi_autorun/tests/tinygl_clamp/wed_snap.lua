-- ScummVM #11862 (dark lines in the EMI intro with TinyGL: the renderer never clamps textures): the wedding ship at the start of a
-- new game, held for a window capture (run with --renderer=software and =opengl to compare).
ar_log("=== wed_snap ===")
ar_wait_for_control()
sleep_for(2000)
ar_log("TC READY")
sleep_for(20000)
ar_log("=== wed_snap done ===")
