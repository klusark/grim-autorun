-- EMI chapter 26: the chase after Ozzie. In his mansion Guybrush tells him he has found Pegnose's booty showcase (a bluff, but Ozzie wants to see
-- his loot), Ozzie walks off to it with his leaky stick: the trail of sawdust through his garden and the forest leads to the lagoon and the
-- hidden passage. Then the passage, the button, the drapes of the booty showroom.
ar_load(25)
ar_log("=== EMI ch26 chase and lagoon ===")
ar_wait_for_control()
ar_do("use", hoj.luc_door)
ar_wait_for_control()
ar_do("use", luc.lum_door2)
ar_wait_for_control()
ar_do("use", lum.oze_door)
ar_wait_for_control()
ar_log("cane " .. tostring(props.ozzies_cane.state))
-- (Ozzie has met Guybrush already, in ch21_zspray: the mansion door only leads in, and Ozzie is talked to)
ar_do("use", oze.ozi_door)
ar_try_wait(function() return ar_set_name() == "ozzie interior" end, 20000)
ar_wait_for_control()
ar_talk(ozi.ozzie)
ar_dlg("ozi1")
sleep_for(1500)
ar_dialog_ready(ozi1, 30000)
ar_log("ozzie dialog node " .. tostring(ozi1.node))
local guard = 0
while ozi1.running and not glob.chasing_ozzie and guard < 15 do
	guard = guard + 1
	ar_dialog_ready(ozi1, 30000)
	local n = ozi1.node
	ar_log("ozzie node " .. tostring(n))
	if n == "gb_intro_node" then
		ar_pick_avail(ozi1, { 100, 110, 120, 130 })
	elseif n == "ozzie_joke_node" then
		ar_pick_avail(ozi1, { 200, 210, 220, 230 })
	elseif n == "main_node" then
		ar_pick_avail(ozi1, { 40, 45 })
	elseif n == "treasure_node" then
		ar_pick_avail(ozi1, { 500, 505, 510, 515, 520, 525, 530 })
	else
		ar_log("unexpected node " .. tostring(n))
		ar_say_exit("ozi1")
	end
	sleep_for(3000)
end
ar_dlg_done("ozi1")
ar_wait_for_control()
ar_log("chasing " .. tostring(glob.chasing_ozzie) .. " hike " .. tostring(glob.ozzie_hike_count))
ar_state("after Ozzie left")
-- after him: out of the mansion, the sawdust trail through the garden, the forest, the path to the lagoon
ar_do("use", ozi.oze_door)
ar_wait_for_control()
ar_state("oze again")
ar_log("chasing " .. tostring(glob.chasing_ozzie) .. " chased_to " .. tostring(glob.chased_ozzie_to))
ar_do("use", oze.for_door)
ar_wait_for_control()
ar_state("forest")
ar_log("chasing " .. tostring(glob.chasing_ozzie) .. " chased_to " .. tostring(glob.chased_ozzie_to))
ar_do("use", for.right_door)
ar_wait_for(function() return ar_set_name() == "lagoon" end, 120000, "the lagoon")
ar_wait_for_control()
ar_state("lag")
ar_log("found_lagoon " .. tostring(glob.found_lagoon))
-- (walking into the passage spot triggers its look-at: the game's own hint that Ozzie went through)
ar_walk_into_door("uch_door")
ar_try_wait(function() return glob.found_lagoon == 2 end, 30000)
ar_wait_for_control()
ar_log("found_lagoon " .. tostring(glob.found_lagoon) .. " set " .. ar_set_name())
ar_do("use", lag.uch_door)
ar_wait_for_control()
ar_state("uch")
ar_do("use", uch.button)
ar_wait_for_control()
ar_log("pulled_drapes=" .. tostring(glob.pulled_drapes))
ar_checkpoint(26)
