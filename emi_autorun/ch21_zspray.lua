-- EMI chapter 21z (after ch21_files, before ch22): Ozzie's second cane. A bottle of Eau de LeChuck from the perfume stand in Lucre town; in
-- his mansion Ozzie is met, then his stuffed animals are sprayed until he breaks his cane in anger and goes to order a new one
-- (ozi.spray_cologne: ozzie_gone_to_hos, the cane back in the shop). The termite hand on that cane in the House o' Sticks: the termites gnaw
-- it, Ozzie takes the leaky stick (the sawdust trail through the forest, ch26). Ends in the Palace o' Prostheses, where ch22 goes on.
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
ar_log("ozzie: met " .. tostring(glob.met_ozzie) .. " home " .. tostring(glob.ozzie_home) .. " cane " .. tostring(props.ozzies_cane.state))
a2z_door(pop.luc_door, "Lucre Island Town")
ar_do("pickUp", luc.cologne)
ar_wait_for_control()
ar_check(props.cologne.state ~= PROP_INITIAL, "the bottle of Eau de LeChuck")
ar_put_away()
ar_log("cologne state " .. tostring(props.cologne.state) .. " cutscene " .. tostring(cutSceneLevel))
ar_walk_to(-3.95, 3.67, -196.14)
ar_log("at the square " .. ar_set_name())
a2z_door(luc.lum_door2, "lucre island map")
a2z_door(lum.oze_door, "ozzie exterior")
ar_state("oze")
-- the mansion: Ozzie meets Guybrush the first time (ozi.force_meeting, a conversation); it is left at its main node
-- (the verb is only sent: it runs until the conversation is over)
ar_approach(oze.ozi_door)
ar_send_verb("use", oze.ozi_door, "the mansion door")
ar_dlg("ozi1")
sleep_for(1500)
a2z_n = 0
while ozi1.running and a2z_n < 12 do
	a2z_n = a2z_n + 1
	ar_dialog_ready(ozi1, 30000)
	ar_log("ozzie node " .. tostring(ozi1.node))
	if ozi1.node == "gb_intro_node" then
		ar_pick_avail(ozi1, { 100, 110, 120, 130 })
	elseif ozi1.node == "ozzie_joke_node" then
		ar_pick_avail(ozi1, { 200, 210, 220, 230 })
	else
		ar_say_exit("ozi1")
	end
	sleep_for(3000)
end
ar_dlg_done("ozi1")
ar_wait_for_control()
ar_state("ozi")
ar_log("ozzie: met " .. tostring(glob.met_ozzie) .. " home " .. tostring(glob.ozzie_home) .. " cane " .. tostring(props.ozzies_cane.state))
-- the stuffed animals sprayed with Eau de LeChuck, one after the other, until Ozzie breaks his cane over it and goes to order a new one
a2z_animals = { ozi.croc, ozi.wombat, ozi.platypus, ozi.koala, ozi.dingo1, ozi.kangaroo, ozi.dingo2, ozi.platypus2, ozi.ostrich_head }
a2z_i = 0
while not glob.ozzie_gone_to_hos and a2z_i < 18 do
	a2z_i = a2z_i + 1
	if ar_set_name() ~= "ozzie interior" then
		ar_log("thrown out: back in")
		if ar_set_name() ~= "ozzie exterior" then
			a2z_door(lum.oze_door, "ozzie exterior")
		end
		ar_approach(oze.ozi_door)
		ar_send_verb("use", oze.ozi_door, "the mansion door")
		ar_try_wait(function() return ar_set_name() == "ozzie interior" end, 20000)
		ar_wait_for_control()
	end
	a2z_a = a2z_animals[mod(a2z_i - 1, 9) + 1]
	ar_do("use", a2z_a, props.cologne)
	ar_wait_for_control()
	sleep_for(1500)
	ar_wait_for_control()
	ar_log("sprayed " .. tostring(a2z_a.name) .. ": breaks " .. tostring(glob.ozzie_break_count) .. " gone " .. tostring(glob.ozzie_gone_to_hos) .. " cane " .. tostring(props.ozzies_cane.state) .. " set " .. ar_set_name())
end
ar_check(glob.ozzie_gone_to_hos, "Ozzie has gone to order a new cane")
-- back to the House o' Sticks
a2z_door(ozi.oze_door, "ozzie exterior")
-- (the garden's forest path comes out on the island map)
ar_do("use", oze.for_door)
ar_try_wait(function() return ar_set_name() == "lucre island map" end, 20000)
ar_wait_for_control()
a2z_door(lum.luc_door, "Lucre Island Town")
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
