-- Chapter 13: the end of Year 1 in the real game. Outside the Rubamat Manny walks to the edge,
-- slips and falls into the sea; Velasco fishes him out and the next year's story starts.
-- Checkpoint in slot 29.

ar_load(12)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_JUMPED = FALSE
ar_walk_to(6.6, 0.5, -1.99, function() return re.plunged end)
ar_wait_for(function() return re.plunged end, 60000)
ar_check(re.plunged, "Manny has slipped off the edge")
-- Velasco fishes Manny out; Manny shivers until he presses a key
ar_wait_for(function() return system.buttonHandler == shiver_button_handler end, 600000)
ar_wait_for_control()
ar_press("use")
ar_wait_for(function() return system.buttonHandler == SampleButtonHandler end, 60000)
ar_wait_for_control()
ar_state("up again")

-- into the Rubamat to Celso, who has a photo for Manny after the right questions
ar_go(re.ri_door, ri)
ar_do("use", ri.celso_obj)
ar_wait_for(function() return ce1 end, 60000)
ar_pick(ce1, 110)
ar_pick(ce1, 120)
ar_pick(ce1, 135)
ar_wait_for(function() return ri.photo.owner == manny end, 120000)
ar_check(ri.photo.owner == manny, "Manny has the photo")
ar_pick_exit(ce1)
ar_wait_for_control()

-- the photo to Velasco, who gives the logbook
ar_go(ri.re_door, re)
ar_do("use", re.velasco_obj, ri.photo)
ar_wait_for(function() return ve1 and system.buttonHandler == ve1 end, 120000)
ar_pick(ve1, 90)
ar_wait_for(function() return re.logbook.owner == manny end, 120000)
ar_check(re.logbook.owner == manny, "Manny has the logbook")
ar_pick_exit(ve1)
ar_wait_for_control()

-- the logbook to Celso: Manny gets the job, and the next year begins
ar_go(re.ri_door, ri)
AR_NO_SKIP = TRUE
ar_do("use", ri.celso_obj, re.logbook)
ar_wait_for(function() return system.currentSet == cb end, 600000)
ar_wait_for_control()
AR_NO_SKIP = nil
ar_state("end of chapter 13")
ar_checkpoint(13)
