-- EMI chapter 16: the music box plays for Deadeye (he does not hear the thief), the wooden prosthetic hand, the termites of the bait shop's circus
-- onto it. Then the House o' Sticks: Ozzie broke his cane at the bank, and when the framed Guybrush leaves the shop Ozzie comes in for the new one
-- Freddie has made him (hos:ozzie_takes_stick); the carving leaves the wood shavings on the floor, for the perfume (ch18). That cane is an ordinary
-- one: the gnawed one comes in ch21_zspray, when the sprayed animals in his mansion make Ozzie break this one too and order another.
ar_load(15)
ar_log("=== EMI ch16 cane ===")
ar_wait_for_control()
ar_log("cane " .. tostring(props.ozzies_cane.state) .. " saw_take " .. tostring(glob.saw_ozzie_take_stick) .. " framed " .. tostring(glob.guybrush_framed))
ar_do("use", luc.pop_door)
ar_wait_for_control()
ar_do("use", pop.deadeye_obj, props.music_box)
ar_wait_for_control()
ar_log("music box on " .. tostring(props.music_box.on) .. " state " .. tostring(props.music_box.state))
ar_do("use", pop.limbbasket)
ar_wait_for_control()
-- (the close-up of the basket gives the hand its range; pop.wait_for_move ends it the moment Guybrush's place or rotation changes, and
-- in some states he is still turning to the basket when the short cutscene ends: once he stands still, the basket again)
local ar_tries = 0
while pop:current_setup() ~= pop_basket and ar_tries < 3 do
	ar_tries = ar_tries + 1
	ar_settled()
	sleep_for(500)
	ar_log("the close-up of the basket ended at once, again (" .. ar_tries .. ")")
	ar_do("use", pop.limbbasket)
	ar_wait_for_control()
end
ar_log("camera setup " .. tostring(pop:current_setup()) .. " hand range " .. tostring(pop.pros_hand.range))
ar_do("pickUp", props.prosthetic_hand)
ar_wait_for_control()
ar_log("hand state " .. tostring(props.prosthetic_hand.state))
ar_do("use", pop.luc_door)
ar_wait_for_control()
ar_do("use", luc.bas_door)
ar_wait_for_control()
ar_state("bas")
AR_NO_SKIP = TRUE
ar_do("use", bas.termite_circus, props.prosthetic_hand)
ar_wait_for_control()
AR_NO_SKIP = nil
ar_log("hand state after the termites " .. tostring(props.prosthetic_hand.state))
ar_do("use", bas.luc_door)
ar_wait_for_control()
ar_do("use", luc.hos_door)
ar_wait_for_control()
ar_state("hos")
ar_log("in hos: cane " .. tostring(props.ozzies_cane.state) .. " saw_take " .. tostring(glob.saw_ozzie_take_stick))
ar_do("use", hos.luc_door)
ar_wait_for(function() return glob.saw_ozzie_take_stick end, 60000, "Ozzie comes in for his new cane")
ar_wait_for_control()
ar_log("cane " .. tostring(props.ozzies_cane.state) .. " sawdust " .. tostring(props.sawdust and props.sawdust.state))
ar_check(props.sawdust.state ~= PROP_INITIAL, "the wood shavings on the floor of the House o' Sticks")
ar_check(props.prosthetic_hand.state == PROP_LOC1, "the termites on the hand")
ar_state("luc again")
ar_checkpoint(16)
