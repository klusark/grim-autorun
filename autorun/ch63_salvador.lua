-- Chapter 63 (Year 4): the meadow again, Manny healed. By the car the camera changes to the close-up of Salvador's head when
-- Manny steps on to the platform by it, and Manny talks to it: Salvador says goodbye and sprouts a flower
-- while Olivia runs off. Checkpoint in slot 79.

AR_NEW = TRUE
AR_CONTROL_TIMEOUT = 600000
ar_load(63)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_walk_to(17.0, -19.55, -7.85)
sleep_for(1000)
ar_walk_to(17.5, -19.85, -7.82, function() return me:current_setup() == me_salcu end)
sleep_for(2500)
ar_wait_for_control()
ar_check(me:current_setup() == me_salcu, "the camera shows Salvador's head close up")
ar_do("use", me.salvador_obj)
ar_wait_for(function() return salvador.sprouted end, 300000)
sleep_for(5000)
ar_wait_for_control()
ar_check(salvador.sprouted, "Salvador has said goodbye")
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 63")
ar_checkpoint(64)
