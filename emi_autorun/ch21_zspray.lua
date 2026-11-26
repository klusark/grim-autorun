-- EMI chapter 21z (after ch21_files, before ch22): Ozzie's second cane, which he ordered when his stuffed animals were sprayed (ch19). The
-- termite hand on that cane in the House o' Sticks: the termites gnaw it, Ozzie takes the leaky stick (the sawdust trail through the
-- forest, ch26). Ends in the Palace o' Prostheses, where ch22 goes on.
ar_load(21)
ar_log("=== EMI ch21z spray ===")
ar_wait_for_control()
-- a door, until the set it leads to is there (the verb comes back before the change of set)
a2z_door = function(door, setname)
	local n = 0
	while ar_set_name() ~= setname and n < 3 do
		n = n + 1
		ar_do("use", door)
		ar_try_wait(function() return ar_set_name() == %setname end, 15000)
		ar_log("door try " .. n .. ": " .. ar_set_name())
		ar_wait_for_control()
	end
	ar_check(ar_set_name() == setname, "in " .. setname)
end
ar_log("ozzie: met " .. tostring(glob.met_ozzie) .. " gone " .. tostring(glob.ozzie_gone_to_hos) .. " cane " .. tostring(props.ozzies_cane.state))
-- (ozzie_gone_to_hos is cleared when the garden is entered again, ch20: the cane in the shop is what counts)
ar_check(props.ozzies_cane.state == PROP_INITIAL, "Ozzie's new cane is in the House o' Sticks (ch19)")
a2z_door(pop.luc_door, "Lucre Island Town")
a2z_door(luc.hos_door, "house o sticks")
ar_log("in hos: cane " .. tostring(props.ozzies_cane.state) .. " hand " .. tostring(props.prosthetic_hand.state))
AR_NO_SKIP = TRUE
ar_do("use", hos.ozzies_cane, props.prosthetic_hand)
ar_wait_for(function() return props.ozzies_cane.state == PROP_LOC2 end, 120000, "Ozzie takes the gnawed cane")
ar_wait_for_control()
AR_NO_SKIP = nil
ar_log("cane " .. tostring(props.ozzies_cane.state))
ar_check(props.ozzies_cane.state == PROP_LOC2, "Ozzie has the gnawed cane")
ar_state("after the cane")
a2z_door(hos.luc_door, "Lucre Island Town")
a2z_door(luc.pop_door, "place o prosthetics")
ar_checkpoint(121)
