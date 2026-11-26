-- EMI chapter 19: the flower at Ozzie's mansion and the swamp water: the spritzer holds all five (water, wood, bait, flowers, swamp)
-- Then, in the same trip (as the speed runners do; it was ch21_zspray's second trip to the mansion), Ozzie's second cane: in his mansion
-- he is met, then his stuffed animals are sprayed with the Eau de LeChuck of ch17 until he breaks his cane in anger and goes to order a
-- new one (ozi.spray_cologne: ozzie_gone_to_hos, the cane back in the shop for ch21_zspray's termites)
ar_load(18)
ar_log("=== EMI ch19 flower and swamp ===")
ar_wait_for_control()
ar_do("use", hos.luc_door)
ar_wait_for_control()
ar_do("use", luc.hot_out_door)
ar_wait_for_control()
ar_do("use", lum.oze_door)
ar_wait_for_control()
ar_state("oze")
ar_do("use", props.flower, props.spritzer)
ar_wait_for_control()
ar_check(glob.flowers_in, "flowers in the spritzer")
-- a door, until the set it leads to is there (the verb comes back before the change of set)
c19_door = function(door, setname)
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
-- the mansion: Ozzie meets Guybrush the first time (ozi.force_meeting, a conversation); it is left at its main node
-- (the verb is only sent: it runs until the conversation is over)
ar_put_away()
ar_approach(oze.ozi_door)
ar_send_verb("use", oze.ozi_door, "the mansion door")
ar_dlg("ozi1")
sleep_for(1500)
C19_N = 0
while ozi1.running and C19_N < 12 do
	C19_N = C19_N + 1
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
-- the stuffed animals sprayed with Eau de LeChuck, one after the other, until Ozzie breaks his cane over it and goes to order a new one
C19_ANIMALS = { ozi.croc, ozi.wombat, ozi.platypus, ozi.koala, ozi.dingo1, ozi.kangaroo, ozi.dingo2, ozi.platypus2, ozi.ostrich_head }
C19_I = 0
while not glob.ozzie_gone_to_hos and C19_I < 18 do
	C19_I = C19_I + 1
	if ar_set_name() ~= "ozzie interior" then
		ar_log("thrown out: back in")
		if ar_set_name() ~= "ozzie exterior" then
			c19_door(lum.oze_door, "ozzie exterior")
		end
		ar_approach(oze.ozi_door)
		ar_send_verb("use", oze.ozi_door, "the mansion door")
		ar_try_wait(function() return ar_set_name() == "ozzie interior" end, 20000)
		ar_wait_for_control()
	end
	C19_A = C19_ANIMALS[mod(C19_I - 1, 9) + 1]
	ar_do("use", C19_A, props.cologne)
	ar_wait_for_control()
	sleep_for(1500)
	ar_wait_for_control()
	ar_log("sprayed " .. tostring(C19_A.name) .. ": breaks " .. tostring(glob.ozzie_break_count) .. " gone " .. tostring(glob.ozzie_gone_to_hos) .. " cane " .. tostring(props.ozzies_cane.state) .. " set " .. ar_set_name())
end
ar_check(glob.ozzie_gone_to_hos, "Ozzie has gone to order a new cane")
-- (ch20 goes on from the garden)
c19_door(ozi.oze_door, "ozzie exterior")
ar_survey()
ar_checkpoint(19)
