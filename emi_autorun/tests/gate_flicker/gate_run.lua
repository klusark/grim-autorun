AR_CONTINUE = TRUE
AR_TIMEOUT = 36000000
-- ScummVM #11785 (future Guybrush flickers as he comes through the gate): each frame in the Mysts o' Tyme, the sort order and the
-- sector under mot.raft2 and mot.guybrush2, logged when they change (GW), with a frame counter.
GW_F = 0
gw_watch = function()
	local last = ""
	while TRUE do
		GW_F = GW_F + 1
		if system.currentSet == mot and mot.raft2 and mot.raft2.hActor and mot.guybrush2 and mot.guybrush2.hActor then
			local p = mot.raft2:getpos()
			local s = GetSectorName(p.x, p.y, p.z)
			local cur = "raft2 " .. tostring(GetActorSortOrder(mot.raft2.hActor)) .. " " .. tostring(s) .. " guy2 " .. tostring(GetActorSortOrder(mot.guybrush2.hActor)) .. " gate " .. tostring(mot.opened_gate)
			if cur ~= last then
				ar_log("GW " .. GW_F .. " " .. cur .. " at " .. p.x .. " " .. p.z)
				last = cur
			end
		end
		break_here()
	end
end
start_script(gw_watch)
ar_log("=== file ch01_wed.lua ===")
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

ar_log("=== file ch02_scu.lua ===")
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
ar_do("use", mel.lua_door)
ar_wait_for_control()
ar_check(ar_set_name() == "SCUMM Bar", "in the SCUMM bar")
ar_do("lookAt", scu.balloon_obj)
-- (the conversation starts as the walk ends: the verb is only sent and the dialog is followed, whether the cutscene level is up yet or not)
ar_approach(scu.george_obj)
ar_send_verb("use", scu.george_obj, "the dart player")
ar_say("dart1", 60)
ar_say("dart1", 230)
ar_wait_for(ar_drunk_fell, 40000, "the drunk falls")
ar_say_exit("dart1")
ar_dlg_done("dart1")
ar_do("pickUp", scu.pretzbowl)
ar_check(props.pretzbowl.state == PROP_INV, "the pretzel bowl is Guybrush's")

ar_log("=== file ch03_navigator.lua ===")
-- EMI chapter 3: Melee, the SCUMM Bar: Mr. Cheese, the navigator, by insult arm wrestling
ar_log("=== EMI ch03 navigator ===")
ar_wait_for_control()
ar_try_attempt = 0
ar_arm_wrestle_pick = function()
	-- one step of the contest: the dialog is at its offense node (pick an insult) or a defense node (pick the comeback that answers)
	local d = iaw
	if d.node == "offense_node" then
		-- (an insult that is on the screen now, else the first unused one: the list slides and ar_pick scrolls to it)
		local k = 1
		local any = nil
		while k <= d.insult_count do
			if d[k] and not d[k].off then
				if ar_line_shown(d, d[k]) then
					return k
				end
				if not any then
					any = k
				end
			end
			k = k + 1
		end
		return any
	elseif d.node == "defense_node" then
		local k, v = next(d, nil)
		while k do
			if type(k) == "number" and type(v) == "table" and v.defense_node and not v.off and v.text == d.guycomebacks[d.correct_response] then
				return k
			end
			k, v = next(d, k)
		end
	elseif d.node == "easy_defense_node" then
		local k = d.lame_insult_comeback_offset + 1
		return k
	end
	return nil
end
ar_do("use", scu.navigator_obj)
ar_dlg("nv1")
sleep_for(1500)
ar_say("nv1", 70)
sleep_for(800)
ar_say("nv1", 120)
sleep_for(800)
ar_say("nv1", 200)
sleep_for(800)
ar_say("nv1", 300)
sleep_for(800)
ar_say("nv1", 82)
sleep_for(800)
ar_say("nv1", 76)
sleep_for(800)
ar_say("nv1", 600)
ar_iaw_running = function() return getglobal("iaw") and iaw.running end
-- the contest
ar_wait_for(ar_iaw_running, 90000, "the arm wrestling to start")
local guard = 0
while iaw.running and guard < 200 do
	ar_dialog_ready(iaw, 20000)
	-- (the node changes when the navigator has spoken, the list on the screen a moment later: wait until the lines shown are those of the node)
	local settle = 0
	while iaw.running and settle < 4000 and not (iaw.current_choices and iaw.current_choices[1] and iaw.current_choices[1][iaw.node]) do
		sleep_for(100)
		settle = settle + 100
	end
	local n = ar_arm_wrestle_pick()
	if n then
		ar_pick(iaw, n)
	else
		ar_log("arm wrestling: nothing to pick in node " .. tostring(iaw.node))
		sleep_for(500)
	end
	sleep_for(300)
	guard = guard + 1
end
ar_dlg_done("iaw")
ar_log("arm wrestling over, got_navigator=" .. tostring(glob.got_navigator))
ar_check(glob.got_navigator, "Mr. Cheese is the navigator")

ar_log("=== file ch04_innertube.lua ===")
-- EMI chapter 4: the inner tube from the harbor
ar_log("=== EMI ch04 inner tube ===")
ar_wait_for_control()
ar_do("use", scu.mel_door)
ar_wait_for_control()
ar_mel_patio_down()
ar_do("use", mel.mem_rdoor)
ar_wait_for_control()
ar_do("use", mem.shi_door)
ar_wait_for_control()
ar_check(ar_set_name() == "shipyards", "in the shipyards")
ar_do("pickUp", props.innertube)
ar_check(props.innertube.state == PROP_INV, "the inner tube is Guybrush's")

ar_log("=== file ch05_catapult.lua ===")
ar_catapult_broken = function() return glob.broke_catapult end
-- EMI chapter 5: the catapult at the mansion: pretzels for Tony, the inner tube on the cactus, then the controls (Tony recalibrates to the
-- cactus and the boulder comes back at his catapult)
ar_log("=== EMI ch05 catapult ===")
ar_wait_for_control()
ar_do("use", shi.mem_door)
ar_wait_for_control()
ar_do("use", mem.gme_door)
ar_wait_for_control()
ar_check(ar_set_name() == "gov mansion exterior", "at the mansion")
ar_do("use", gme.puz_cactus, props.innertube)
ar_wait_for_control()
ar_check(props.innertube.state == PROP_FINAL, "the inner tube is on the cactus")
ar_do("use", gme.tony, props.pretzbowl)
ar_wait_for_control()
ar_do("use", gme.cp_controls)
ar_wait_for_control()
ar_wait_for(ar_catapult_broken, 120000, "the catapult breaks")
ar_wait_for_control()
ar_check(glob.broke_catapult, "the catapult is broken")

ar_log("=== file ch06_elaine.lua ===")
ar_has_symbol = function() return props.gubernatorial_symbol.state == PROP_INV end
ar_cushy_signed = function() return glob.signed_cushy end
-- EMI chapter 6: the mansion: Elaine gives the Gubernatorial Symbol; the cushy contract form is signed
ar_log("=== EMI ch06 Elaine ===")
ar_wait_for_control()
ar_do("use", gme.gmi_door)
ar_wait_for_control()
ar_check(ar_set_name() == "governors mansion interior", "inside the mansion")
ar_talk(gmi.elaine)
ar_dlg("el1")
sleep_for(1500)
ar_say("el1", 90)
sleep_for(800)
if ar_offered_line("el1", 420) then
	ar_say("el1", 420)
else
	ar_say("el1", 410)
end
sleep_for(1500)
ar_wait_for(ar_has_symbol, 40000, "the symbol")
ar_say_exit("el1")
ar_dlg_done("el1")
ar_check(props.gubernatorial_symbol.state == PROP_INV, "the Gubernatorial Symbol is Guybrush's")
ar_do("pickUp", gmi.cushycontract)
ar_check(props.cushycontract.state == PROP_INV, "the government paper is Guybrush's")
ar_look_item(props.cushycontract)
ar_check(glob.found_cushy, "the paper has been read")
ar_do("use", gmi.elaine, props.cushycontract)
ar_wait_for(ar_cushy_signed, 60000, "the contract to be signed")
ar_wait_for_control()
ar_check(glob.signed_cushy, "the cushy contract is signed")

ar_log("=== file ch07_crew.lua ===")
ar_knows_contracts = function() return glob.knows_to_get_contracts end
-- EMI chapter 7: Melee town: Carla and Otis, the signed cushy contract: the crew
ar_log("=== EMI ch07 crew ===")
ar_wait_for_control()
ar_do("use", gmi.gme_door)
ar_wait_for_control()
ar_do("use", gme.mem_door)
ar_wait_for_control()
ar_do("use", mem.mel_door)
ar_wait_for_control()
ar_check(ar_set_name() == "melee town", "in Melee town")
ar_talk(mel.carlaotis_obj)
ar_dlg("carlo")
sleep_for(1500)
AR_EXH_REPEAT = 3
ar_exhaust("carlo", ar_knows_contracts, 80)
AR_EXH_REPEAT = nil
ar_log("knows_to_get_contracts=" .. tostring(glob.knows_to_get_contracts))
if getglobal("carlo") and carlo.running then
	ar_say_exit("carlo")
end
ar_dlg_done("carlo")
ar_check(glob.knows_to_get_contracts, "Carla and Otis want a signed contract")
ar_do("use", mel.carlaotis_obj, props.cushycontract)
ar_wait_for_control()
ar_check(glob.got_crew, "the crew is complete")

ar_log("=== file ch08_ship.lua ===")
-- EMI chapter 8: the harbor: the Gubernatorial Symbol gets the ship; the crew sails
ar_log("=== EMI ch08 ship ===")
ar_wait_for_control()
ar_do("use", mel.mem_rdoor)
ar_wait_for_control()
ar_do("use", mem.shi_door)
ar_wait_for_control()
ar_check(ar_set_name() == "shipyards", "in the shipyards")
ar_do("use", shi.mistress, props.gubernatorial_symbol)
ar_wait_for_control()
ar_check(glob.got_ship, "the ship is Guybrush's")
ar_log("set now " .. ar_set_name() .. " act " .. tostring(glob.curr_act))
sleep_for(5000)
ar_wait_for_control()
ar_log("set later " .. ar_set_name() .. " act " .. tostring(glob.curr_act))
ar_checkpoint(8)

ar_log("=== file ch09_lucre.lua ===")
-- EMI chapter 9: Lucre Island: the law offices (letter from the arrival)
ar_load(8)
ar_log("=== EMI ch09 law offices ===")
ar_wait_for_control()
ar_do("use", luc.law_door)
ar_wait_for_control()
ar_check(ar_set_name() == "law firm interior", "in the law offices")
ar_checkpoint(9)

ar_log("=== file ch10_lawyers.lua ===")
-- EMI chapter 10: the lawyers: Marley's letter read, then everything the lawyers have to say
ar_load(9)
ar_log("=== EMI ch10 lawyers ===")
ar_wait_for_control()
ar_look_item(props.herman_letter or Inventory.ordered_inventory_table[1])
ar_put_away()
ar_talk(law.lawyers_obj)
ar_dlg("dlg_law")
sleep_for(1500)
AR_EXH_REPEAT = 2
ar_exhaust("dlg_law", nil, 40)
AR_EXH_REPEAT = nil
if getglobal("dlg_law") and dlg_law.running then
	ar_say_exit("dlg_law")
end
ar_dlg_done("dlg_law")
ar_log("flags: read=" .. tostring(glob.guybrush_read_marley_letter) .. " deed=" .. tostring(glob.dlaw_talked_deed) .. " bank=" .. tostring(glob.dlaw_talked_bank))
ar_checkpoint(10)

ar_log("=== file ch11_bank.lua ===")
-- EMI chapter 11: the bank
ar_load(10)
ar_log("=== EMI ch11 bank ===")
ar_wait_for_control()
ar_do("use", law.luc_door)
ar_wait_for_control()
ar_do("use", luc.ban_door)
ar_wait_for_control()
ar_state("bank")
ar_checkpoint(11)

ar_log("=== file ch12_bankpoke.lua ===")
-- EMI chapter 12: the bank: the teller, all her topics, the safe deposit box under the name Marley, the letter and the Gubernatorial Symbol:
-- the robbery
ar_load(11)
ar_log("=== EMI ch12 bank poke ===")
ar_wait_for_control()
ar_do("pickUp", props.scupperware)
ar_wait_for_control()
ar_put_away()
ar_talk(ban.teller_obj)
ar_dlg("bt1")
sleep_for(1500)
ar_exhaust("bt1", nil, 30)
if getglobal("bt1") and bt1.running then
	ar_say_exit("bt1")
end
ar_dlg_done("bt1")
ar_wait_for(function() return glob.bank_robbed end, 60000, "the robbery")
ar_wait_for_control()
ar_check(props.scupperware.state == PROP_INV, "the ScupperWare from the flyer in hand")
ar_check(glob.bank_robbed, "the bank is robbed")
ar_checkpoint(12)

ar_log("=== file ch13_vault.lua ===")
-- EMI chapter 13: the bank vault: grog from the safe, the sword in the hinge then the crack, the sponges, the grog on them: the door bulges open
ar_load(12)
ar_log("=== EMI ch13 vault ===")
ar_wait_for_control()
ar_check(ar_set_name() == "bank vault", "in the vault")
ar_do("lookAt", vau.open_safe)
ar_wait_for_control()
ar_do("pickUp", props.music_box)
ar_wait_for_control()
ar_do("pickUp", props.grog_bottle)
ar_do("pickUp", props.old_sword)
ar_do("pickUp", props.hanky)
ar_do("pickUp", props.sponge_small)
ar_do("pickUp", props.sponge_medium)
ar_do("pickUp", props.sponge_large)
ar_log("inventory: " .. ar_inventory())
ar_do("use", vau.bottom_hinge, props.old_sword)
ar_wait_for_control()
ar_do("use", vau.door_crack, props.old_sword)
ar_wait_for_control()
ar_do("use", vau.door_crack, props.sponge_small)
ar_do("use", vau.door_crack, props.sponge_medium)
ar_do("use", vau.door_crack, props.sponge_large)
ar_log("sponges stuffed " .. tostring(glob.vau_sponges_stuffed))
ar_do("use", vau.door_crack, props.grog_bottle)
ar_wait_for_control()
ar_log("door open=" .. tostring(glob.vau_door_open) .. " set=" .. ar_set_name())
ar_checkpoint(13)

ar_log("=== file ch14_hoj.lua ===")
-- EMI chapter 14: the Hall o' Justice, explored by the poker
ar_load(13)
ar_log("=== EMI ch14 hoj ===")
ar_wait_for_control()
ar_state("hoj")
ar_survey()
ar_poke_room(5)
ar_state("end")
ar_checkpoint(14)

ar_log("=== file ch15_out.lua ===")
-- EMI chapter 15: out of the Hall o' Justice
ar_load(14)
ar_log("=== EMI ch15 out ===")
ar_wait_for_control()
ar_do("use", hoj.luc_door)
ar_wait_for_control()
ar_state("out")
ar_checkpoint(15)

ar_log("=== file ch16_cane.lua ===")
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

ar_log("=== file ch17_spritzer.lua ===")
-- EMI chapter 17: Lucre town: the empty spritzer bottle, water from the fountain, the smell of Pegnose's hanky (what the perfume has to smell like)
ar_load(16)
ar_log("=== EMI ch17 spritzer ===")
ar_wait_for_control()
ar_do("pickUp", luc.spritzer_pile)
ar_check(props.spritzer.state == PROP_INV, "the spritzer bottle is Guybrush's")
ar_do("use", luc.fountain, props.spritzer)
ar_wait_for_control()
ar_check(glob.water_in, "there is water in the spritzer")
ar_look_item(props.hanky)
ar_put_away()
ar_log("hanky smell " .. tostring(glob.hanky_smell))
ar_checkpoint(17)

ar_log("=== file ch18_bait_wood.lua ===")
-- EMI chapter 18: bait from the bait shop and wood shavings from the House o' Sticks into the spritzer
ar_load(17)
ar_log("=== EMI ch18 bait and wood ===")
ar_wait_for_control()
ar_do("use", luc.bas_door)
ar_wait_for_control()
ar_do("use", bas.free_bait_box, props.spritzer)
ar_wait_for_control()
ar_check(glob.bait_in, "bait in the spritzer")
ar_do("use", bas.luc_door)
ar_wait_for_control()
ar_do("use", luc.hos_door)
ar_wait_for_control()
ar_do("use", hos.sawdust_inv, props.spritzer)
ar_wait_for_control()
ar_check(glob.wood_in, "wood in the spritzer")
ar_checkpoint(18)

ar_log("=== file ch19_flower_swamp.lua ===")
-- EMI chapter 19: the flower at Ozzie's mansion and the swamp water: the spritzer holds all five (water, wood, bait, flowers, swamp)
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
ar_survey()
ar_checkpoint(19)

ar_log("=== file ch20_swamp.lua ===")
-- EMI chapter 20: the swamp water into the spritzer (the puddle at Mysts o' Tyme)
ar_load(19)
ar_log("=== EMI ch20 swamp water ===")
ar_wait_for_control()
ar_do("use", oze.for_door)
ar_wait_for_control()
ar_state("after oze door")
ar_do("use", lum.mot_door)
ar_wait_for_control()
ar_state("swamp")
ar_do("use", mot.puddle, props.spritzer)
ar_wait_for_control()
ar_check(glob.swamp_in, "swamp water in the spritzer")
ar_log("spritzer: wood=" .. tostring(glob.wood_in) .. " flowers=" .. tostring(glob.flowers_in) .. " bait=" .. tostring(glob.bait_in) .. " swamp=" .. tostring(glob.swamp_in) .. " water=" .. tostring(glob.water_in))
ar_checkpoint(20)

ar_log("=== file ch21_files.lua ===")
ar_has_pegnose_name = function() return glob.gbpegnose_name end
-- EMI chapter 21: Deadeye Dave: the perfume tells him whose smell it is (Pegnose's customer name), the dials of the file system are set to the
-- combination of that name, the file ("directions" through the swamp) is retrieved
ar_load(20)
ar_log("=== EMI ch21 files ===")
ar_wait_for_control()
ar_do("use", mot.lum_door)
ar_wait_for_control()
ar_do("use", lum.luc_door)
ar_wait_for_control()
ar_do("use", luc.pop_door)
ar_wait_for_control()
ar_check(ar_set_name() == "place o prosthetics", "in the Palace o' Prostheses")
ar_do("use", pop.deadeye_obj, props.hanky)
ar_wait_for_control()
ar_do("use", pop.deadeye_obj, props.spritzer)
ar_wait_for(ar_has_pegnose_name, 60000, "Deadeye to name the smell")
ar_wait_for_control()
ar_log("the name: " .. tostring(glob.gbpegnose_name) .. " know_mysts=" .. tostring(glob.know_mysts))
ar_checkpoint(21)

ar_log("=== file ch21_zspray.lua ===")
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

ar_log("=== file ch22_dials.lua ===")
ar_has_directions = function() return props.pegnose_map.state == PROP_INV end
-- EMI chapter 22: the dials of Deadeye's file retrieval system: Pegnose's file ("directions") is retrieved with the combination the game keeps
ar_load(121)
ar_log("=== EMI ch22 dials ===")
ar_dial_press = function(name)
	ar_press_key(ar_real_key(name))
	ar_release_key(ar_real_key(name))
	sleep_for(700)
	ar_try_wait(ar_dial_idle, 30000)
end
ar_dial_idle = function()
	return not find_script(pop.file_controls.buttonDelay) and not find_script(pop.file_controls.roll_roller) and not pop.arm_moving
end
ar_in_file_controls = function()
	return system.buttonHandler == pop.file_controls.buttonHandler
end
ar_wait_for_control()
ar_dial_target = { glob.pegnose_first_i, glob.pegnose_mid_i, glob.pegnose_last_i }
ar_log("combination " .. tostring(ar_dial_target[1]) .. tostring(ar_dial_target[2]) .. tostring(ar_dial_target[3]))
-- (the verb runs until the dials are left, and Guybrush is out of the set meanwhile: started, not waited for)
ar_put_away()
AR_START_SET = system.currentSet
AR_CODE = pop.file_controls.use
ar_approach(pop.file_controls)
ar_send_verb("use", pop.file_controls, "use the file controls")
ar_try_wait(ar_in_file_controls, 30000)
ar_log("in controls: " .. tostring(ar_in_file_controls()) .. " handler=" .. tostring(system.buttonHandler) .. " cut=" .. tostring(cutSceneLevel) .. " target=" .. tostring(pop.file_controls.current_target) .. " key=" .. tostring(ar_real_key("TURN_RIGHT")))
sleep_for(500)
ar_dial_i = 1
while ar_dial_i <= 3 do
	local guard = 0
	while pop.file_controls.current_target ~= ar_dial_i and guard < 8 do
		ar_dial_press("TURN_RIGHT")
		guard = guard + 1
	end
	guard = 0
	while pop["fc_roll" .. ar_dial_i].value ~= ar_dial_target[ar_dial_i] and guard < 8 do
		ar_dial_press("USE")
		guard = guard + 1
	end
	ar_log("dial " .. ar_dial_i .. " = " .. tostring(pop["fc_roll" .. ar_dial_i].value))
	ar_dial_i = ar_dial_i + 1
end
ar_dial_press("MOVE_BACKWARD")
ar_log("target now " .. tostring(pop.file_controls.current_target))
ar_press_key(ar_real_key("USE"))
ar_wait_for(ar_has_directions, 60000, "the directions")
-- (reading the map: a "press any key" screen; the skipper does not always see it in a long chain)
ar_pak = 0
while ar_pak < 30 and (system.press_any_key or cutSceneLevel > 0) do
	if system.press_any_key then
		ar_log("pressing a key for the map")
		ar_press_key(ar_real_key("USE"))
		ar_release_key(ar_real_key("USE"))
	end
	sleep_for(700)
	ar_pak = ar_pak + 1
end
ar_wait_for_control()
ar_check(props.pegnose_map.state == PROP_INV, "Pegnose's directions are Guybrush's")
ar_checkpoint(22)

ar_log("=== file ch23_clock.lua ===")
-- EMI chapter 23: the chess clock of the two chess players in Lucre town (needed for the raft in Mysts o' Tyme). Santiago (ms) is made to
-- drop the piece he holds ("Where?" lines while he holds it: glob.chess_guys_status == 1), Castaneda (sc) falls for Brittany ("Hi, Brittany"
-- while he holds his piece: status == 3, after ms told us of the crush); the two start a fight and the clock is free.
ar_load(22)
ar_log("=== EMI ch23 clock ===")
ar_wait_for_control()
ar_do("use", pop.luc_door)
ar_wait_for_control()
ar_state("luc")
ar_chess_pick = function(name, cough, line, want_status)
	-- opens the dialog, coughs, waits for the moment (the chess monitor puts the status up while the player holds a piece), asks the line
	ar_wait_for_control()
	local obj = luc.ms_obj
	if name == "sc1" then
		obj = luc.sc_obj
	end
	ar_talk(obj)
	ar_dlg(name)
	sleep_for(1500)
	local d = getglobal(name)
	ar_dialog_ready(d, 20000)
	ar_pick(d, cough)
	sleep_for(1500)
	if want_status then
		local waited = 0
		while glob.chess_guys_status ~= want_status and waited < 120000 do
			sleep_for(200)
			waited = waited + 200
		end
		ar_log("the moment: status " .. tostring(glob.chess_guys_status) .. " after " .. waited .. " ms")
	end
	ar_dialog_ready(d, 20000)
	ar_pick(d, line)
end
-- 1. Santiago drops his piece
ar_chess_pick("ms1", 10, 140, 1)
sleep_for(4000)
if getglobal("ms1") and ms1.running then
	ar_say_exit("ms1")
end
ar_dlg_done("ms1")
ar_log("status after ms: " .. tostring(glob.chess_guys_status))
ar_state("after ms")
-- 2. Castaneda looks away once (so that Santiago tells of his crush), Santiago tells it
ar_chess_pick("sc1", 10, 140, nil)
sleep_for(3000)
if getglobal("sc1") and sc1.running then
	ar_say_exit("sc1")
end
ar_dlg_done("sc1")
ar_log("sc status " .. tostring(glob.chess_guys_sc_status))
ar_chess_pick("ms1", 10, 150, nil)
sleep_for(3000)
if getglobal("ms1") and ms1.running then
	ar_say_exit("ms1")
end
ar_dlg_done("ms1")
ar_log("crush known " .. tostring(glob.know_brittany_crush) .. " sc status " .. tostring(glob.chess_guys_sc_status))
-- 3. Brittany!, while Castaneda holds his piece
a23_n = 0
while glob.chess_guys_status <= 3 and a23_n < 5 do
	a23_n = a23_n + 1
	ar_chess_pick("sc1", 10, 145, 3)
	sleep_for(8000)
	if getglobal("sc1") and sc1.running then
		ar_say_exit("sc1")
	end
	ar_dlg_done("sc1")
	ar_log("chess status " .. tostring(glob.chess_guys_status) .. " try " .. a23_n)
	ar_try_wait(function() return glob.chess_guys_status > 3 end, 20000)
end
ar_wait_for(function() return glob.chess_guys_status > 3 end, 60000, "the chess fight")
sleep_for(8000)
ar_log("clock state " .. tostring(props.clock.state) .. " touchable " .. tostring(props.clock.touchable))
local tries = 0
while props.clock.state ~= PROP_INV and tries < 4 do
	tries = tries + 1
	ar_do("pickUp", props.clock)
	sleep_for(1500)
	ar_wait_for_control()
	ar_log("clock pickup try " .. tries .. " state " .. tostring(props.clock.state))
end
ar_wait_for_control()
ar_log("clock state after " .. tostring(props.clock.state))
ar_check(props.clock.state == PROP_INV, "the chess clock in hand")
-- the duck that waddles about the town (it goes through the window at Pegnose Pete's)
local dtries = 0
while props.duck.state ~= PROP_INV and dtries < 5 do
	dtries = dtries + 1
	-- (the duck waddles on while Guybrush walks to where it was: he follows it, as a player does, until it is within reach (range 3))
	local dlegs = 0
	local dnear = function()
		local d = ar_obj_pos(props.duck)
		local g = manny:getpos()
		return d.x and sqrt((d.x - g.x) * (d.x - g.x) + (d.z - g.z) * (d.z - g.z)) < 2.4
	end
	while not dnear() and dlegs < 6 do
		dlegs = dlegs + 1
		local d = ar_obj_pos(props.duck)
		ar_log(format("duck at %.2f %.2f, following it (leg %d)", d.x, d.z, dlegs))
		ar_walk_to(d.x, d.y, d.z, dnear, 6000)
	end
	ar_do("pickUp", props.duck)
	sleep_for(1500)
	ar_wait_for_control()
	ar_log("duck pickup try " .. dtries .. " state " .. tostring(props.duck.state))
end
ar_check(props.duck.state == PROP_INV, "the duck in hand")
ar_checkpoint(23)

ar_log("=== file ch24_raft.lua ===")
-- EMI chapter 24: Mysts o' Tyme: the clock on the raft, on the raft, the map (Pegnose's directions) followed screen by screen
ar_load(23)
ar_log("=== EMI ch24 raft ===")
ar_wait_for_control()
ar_do("use", luc.lum_door2)
ar_wait_for_control()
ar_do("use", lum.mot_door)
ar_wait_for_control()
ar_state("mot")
ar_log("map: steps " .. tostring(glob.map_steps) .. " start " .. tostring(glob.map_start_index))
ar_i = glob.map_start_index
while ar_i ~= 0 and ar_i do
	local m = glob.map[ar_i]
	ar_log("MAP [" .. ar_i .. "] setup " .. m.setup .. " dir " .. m.direction .. " time " .. m.mins .. ":" .. m.secs .. " next " .. m.next)
	ar_i = m.next
end
ar_do("use", mot.raft_obj, props.clock)
ar_wait_for_control()
ar_log("clock on raft: " .. tostring(props.clock.state))
ar_do("use", mot.raft_obj)
ar_wait_for(function() return mot.guybrush_on_raft end, 60000, "on the raft")
ar_wait_for_control()
ar_log("on raft; raft at " .. tostring(swampraft:getpos().x) .. " " .. tostring(swampraft:getpos().z) .. " setup " .. tostring(mot.cur_setup_id))
-- the first screens of the map, up to the gate
ar_node = glob.map[glob.map_start_index]
ar_k = 0
while ar_node and ar_node.next ~= 0 and ar_k < 3 do
	ar_log("MAP STEP " .. (ar_k + 1) .. ": screen " .. tostring(mot.cur_setup_id) .. " should be " .. tostring(ar_node.setup) .. " exit " .. tostring(ar_node.direction))
	ar_raft_exit(ar_node.direction)
	ar_k = ar_k + 1
	ar_log("now screen " .. tostring(mot.cur_setup_id) .. " map_step " .. tostring(mot.map_step))
	ar_node = mot.this_map_thing
end
-- the gate: the future Guybrush on the other side brings the key
ar_wait_for(function() return mot.other_gb_at_center end, 60000, "the other Guybrush at the gate")
ar_state("gate")
start_script(ar_raft_exit, "gate_trigger")
ar_dlg("mot0")
sleep_for(1500)
ar_dialog_ready(mot0, 30000)
ar_pick(mot0, 10)
ar_dlg_done("mot0")
ar_log("question " .. tostring(mot.question) .. " response " .. tostring(mot.response) .. " give " .. tostring(mot.give[1]) .. tostring(mot.give[2]) .. tostring(mot.give[3]))
ar_state("after the gifts")
-- ask the future Guybrush the number he is thinking of (the proof that he is me), then open the gate for him with the key
ar_do("use", mot.guybrush2_obj)
ar_wait_for_control()
ar_log("guessed number " .. tostring(mot.guessed_num))
ar_do("use", mot.gate_obj, mot.key)
ar_wait_for(function() return mot.opened_gate end, 120000, "the gate open")
ar_wait_for_control()
ar_log("gate opened " .. tostring(mot.opened_gate) .. " step " .. tostring(mot.map_step) .. " screen " .. tostring(mot.cur_setup_id) .. " got " .. tostring(mot.got[1]) .. tostring(mot.got[2]) .. tostring(mot.got[3]))
ar_state("after the gate")
-- on along the map to the other side of the gate (where I am the future Guybrush)
-- (a wrong exit sends the raft to a random screen, three of them back to the start of the map: the steps of the map are not
-- taken again, the run fails, and the restart from the checkpoint before has the same map)
local ar_exits = 0
while mot.map_step < 6 do
	ar_exits = ar_exits + 1
	ar_check(ar_exits <= 8 and mot.map_step >= 3, "on the map after the gate (step " .. tostring(mot.map_step) .. ")")
	local m = mot.this_map_thing
	ar_log("MAP STEP " .. (mot.map_step + 1) .. ": screen " .. tostring(mot.cur_setup_id) .. " should be " .. tostring(m.setup) .. " exit " .. tostring(m.direction))
	ar_raft_exit(m.direction)
	ar_log("now screen " .. tostring(mot.cur_setup_id) .. " map_step " .. tostring(mot.map_step))
end
ar_wait_for(function() return mot.other_gb_at_center end, 60000, "the other Guybrush at the gate")
ar_state("the other side of the gate")
ar_log("screen " .. tostring(mot.cur_setup_id) .. " question " .. tostring(mot.question) .. " response " .. tostring(mot.response) .. " give " .. tostring(mot.give[1]) .. tostring(mot.give[2]) .. tostring(mot.give[3]) .. " guess " .. tostring(mot.guessed_num) .. " give_step " .. tostring(mot.give_step) .. " gave_key " .. tostring(mot.gave_key))
-- the future Guybrush's part: the key (and the answer to the question he asked), the two things in the order they came, the number
AR_NO_SKIP = nil
ar_dname = "mot" .. mot.question
-- (the raft is steered up to the other Guybrush, the USE key with the raft at rest puts the pole down, and then the key is given with the verb)
AR_RAFT_STOP = nil
start_script(ar_raft_walk, 400.3, 0.5)
ar_wait_for(function() return AR_RAFT_STOP or ar_hot_is(mot.guybrush2_obj) end, 40000, "the raft next to the other Guybrush")
-- (stopped there, and the pole put down as soon as the raft is at rest: it sat 4 s by the other Guybrush)
AR_RAFT_STOP = TRUE
ar_raft_at_rest(3000)
ar_press("use")
ar_wait_for(function() return mot.pole_down end, 30000, "the pole down")
ar_wait_for_control()
ar_inv_hold(mot.key)
ar_do_bg("use", mot.guybrush2_obj, mot.key)
ar_dlg(ar_dname)
sleep_for(1500)
ar_dialog_ready(getglobal(ar_dname), 30000)
ar_pick(getglobal(ar_dname), 10 * mot.response)
ar_dlg_done(ar_dname)
ar_log("gave key: give_step " .. tostring(mot.give_step) .. " screwed_up " .. tostring(mot.screwed_up))
ar_do("use", mot.guybrush2_obj, mot.get_item[mot.give[1]])
ar_wait_for_control()
ar_do_bg("use", mot.guybrush2_obj, mot.get_item[mot.give[2]])
ar_log("gave two: give_step " .. tostring(mot.give_step))
ar_dlg("mot4")
sleep_for(1500)
ar_dialog_ready(mot4, 30000)
ar_pick(mot4, mot.guessed_num)
ar_dlg_done("mot4")
ar_wait_for(function() return mot.opened_gate end, 120000, "the gate")
ar_wait_for_control()
ar_state("through the gate")
ar_log("screen " .. tostring(mot.cur_setup_id) .. " step " .. tostring(mot.map_step) .. " gave " .. tostring(mot.gave[1]) .. tostring(mot.gave[2]) .. tostring(mot.gave[3]))
ar_wait_for(function() return mot.map_step >= 7 or mot.cur_setup_id ~= 5 end, 180000, "the raft out of the gate screen")
ar_wait_for_control()
ar_state("after the gate screen")
ar_log("screen " .. tostring(mot.cur_setup_id) .. " step " .. tostring(mot.map_step) .. " gave " .. tostring(mot.gave[1]) .. tostring(mot.gave[2]) .. tostring(mot.gave[3]) .. " vortex " .. tostring(mot.vortex_on))
-- the last screen of the map: out to the right, to Pegnose Pete's hideout
ar_in_pph = function() return ar_set_name() == "pegnose petes hideout" and cutSceneLevel == 0 end
-- (the screen can change again after the gate while the raft is carried on: the way out is taken from the screen the raft is on now)
ch24_n = 0
while not ar_in_pph() and ch24_n < 5 do
	ch24_n = ch24_n + 1
	ar_wait_for_control()
	sleep_for(2000)
	ar_log("exit try " .. ch24_n .. ": screen " .. tostring(mot.cur_setup_id) .. " step " .. tostring(mot.map_step))
	ar_raft_exit(mot.this_map_thing.direction)
	ar_try_wait(ar_in_pph, 20000)
end
ar_wait_for(ar_in_pph, 180000, "Pegnose Pete's hideout")
ar_wait_for_control()
ar_state("pph")
ar_log("knows_ozzie_framed " .. tostring(glob.guybrush_knows_ozzie_framed) .. " been_to_pegnoses " .. tostring(glob.been_to_pegnoses))
ar_checkpoint(24)

ar_log("GW done")
