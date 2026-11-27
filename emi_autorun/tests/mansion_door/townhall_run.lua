-- ScummVM #11820: Guybrush seen through the closed Melee town hall (tower) door while Elaine talks to him (mel.mel_door4 before the
-- catapult breaks). ch01, ch02 to Melee town, DR READY, 12 s, the door, held for a window capture.
AR_CONTINUE = TRUE
ar_log("=== file ch01_wed ===")
ar_in_mdo = function() return ar_set_name() ~= "wedding ship" and cutSceneLevel == 0 end
ar_log("=== EMI ch01 wedding ship ===")
ar_wait_for_control()
ar_do("use", wed.brazier)
ar_state("after brazier")
ar_do("pickUp", wed.coalpile)
ar_state("after coal")
ar_do("use", wed.cannon, props.hotcoal)
ar_wait_for(ar_in_mdo, 60000, "set mdo")
ar_state("end")

ar_drunk_fell = function() return glob.drunk_fell end
-- EMI chapter 2: Melee, the SCUMM Bar: pop the balloon with the darts, the drunk falls, take the pretzel bowl
ar_log("=== EMI ch02 SCUMM bar ===")
ar_wait_for_control()
-- (the end of the walk is the edge of the door's box: whether the box is entered by it depends on the last hair of the floor test)
ar_walk_to(52, 0, -46)
ar_wait_for_control()
if system.currentSet == gme then
	ar_do("use", gme.mem_door)
	ar_wait_for_control()
end
ar_do("use", mem.mel_door)
ar_wait_for_control()
ar_check(ar_set_name() == "melee town", "in Melee town")
ar_wait_for_control()
ar_log("DR READY")
sleep_for(12000)
ar_log("DR USE")
ar_do("use", mel.mel_door4)
sleep_for(25000)
ar_log("DR done")
