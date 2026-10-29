-- Chapter 65 (Year 4): the end. Manny opens the greenhouse door (the hothouse blows up with Hector in it), the last cutscene
-- (byebye) and the credits play, and the game ends. The run ends with the credits ("done with credits").

AR_NEW = TRUE
AR_CONTROL_TIMEOUT = 900000
ar_load(65)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
local d = me.door
ar_walk_to(d.use_pnt_x, d.use_pnt_y + 0.5, d.use_pnt_z)
-- (the use point of the door is just out of its range, 0.604 of 0.6: Manny stays where he is, close to it, and faces it)
ar_face(d)
ar_wait_turn()
ar_face_precise(d, 3)
sleep_for(800)
AR_NO_WALK_APPROACH = TRUE
-- (the last movie is played, not skipped: the skip would take Manny straight to the credits and out of the game, before the
-- run has seen them begin)
AR_NO_SKIP = TRUE
ar_do("use", d, me.gun)
AR_NO_WALK_APPROACH = nil
-- the hothouse blows up, the last movie plays (the actors stand still while it does), then the credits begin: that is the end,
-- there is no need to sit through them
ar_wait_for(function() return find_script(cut_scene.end_credits) end, 900000, "the credits to begin")
ar_check(find_script(cut_scene.end_credits), "the last cutscene is over, the credits begin")
ar_state("THE END, the credits are rolling")
AR_CREDITS_REACHED = TRUE
