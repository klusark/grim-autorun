-- EMI chapter 28: dive, catch the glowing fishy in the ScupperWare, the cavern, the loot and the tiny screw that drops out of it
ar_load(27)
ar_log("=== EMI ch28 booty ===")
ar_wait_for_control()
-- (from the hideout of ch26 out by its ladder to the lagoon; or, when ch27 fetched the bait, from the bait shop)
if ar_set_name() == "bait shop" then
	ar_do("use", bas.luc_door)
	ar_wait_for_control()
	ar_do("use", luc.lum_door2)
	ar_wait_for_control()
	ar_do("use", lum.lag_door)
	ar_wait_for_control()
else
	ar_do("use", uch.ladder)
	ar_wait_for_control()
end
ar_do("use", lag.deepwater)
ar_wait_for(function() return ar_set_name() == "underwater lagoon" end, 20000, "the dive")
sleep_for(2500)
ar_wait_for_control()
ar_state("ulg")
local tries = 0
while props.scupperware.state ~= PROP_LOC2 and tries < 8 do
	tries = tries + 1
	ar_log("fishy try " .. tries)
	-- (the ScupperWare is in the hand before the fishies come by: they are only in reach for a moment)
	ar_hold(props.scupperware)
	-- (the school swims about: the verb is given the moment the game offers it, with the ScupperWare in hand; walking up to it by the
	-- verb sends Guybrush after a school that has moved on)
	ar_chase_offered(ulg.fishschool, 90000)
	AR_CODE = props.scupperware.use
	AR_KEEP_GOING = TRUE
	ar_send_verb("use", ulg.fishschool, "the fishies")
	AR_KEEP_GOING = FALSE
	AR_FAILED = FALSE
	sleep_for(1000)
	ar_try_wait(function() return cutSceneLevel == 0 end, 20000)
	if props.scupperware.state ~= PROP_LOC2 then
		ar_do("use", props.scupperware)
		sleep_for(1000)
		ar_try_wait(function() return cutSceneLevel == 0 end, 20000)
		sleep_for(2000)
	end
end
ar_log("scupperware state " .. tostring(props.scupperware.state))
ar_try_wait(function() return cutSceneLevel == 0 end, 30000)
sleep_for(1500)
-- (the cavern is entered by swimming into its mouth, the door sector in the west of the lagoon. Where the fish chase ended can be a
-- spot the walker does not leave in the way planned (held up where two edges meet): then a player turns a little and swims a stroke,
-- a little further round each time)
local cave_tries = 0
while ar_set_name() ~= "underground cavern" and cave_tries < 4 do
	cave_tries = cave_tries + 1
	ar_walk_into_door("unc_door")
	if ar_set_name() ~= "underground cavern" then
		local cp = manny:getpos()
		ar_log("cavern: walk " .. cave_tries .. " ended at " .. format("%.2f %.2f", cp.x, cp.z) .. ", a turn and a stroke")
		ar_key_down("TURN_LEFT")
		sleep_for(300 * cave_tries)
		ar_key_up("TURN_LEFT")
		ar_key_down("MOVE_FORWARD")
		sleep_for(1500)
		ar_key_up("MOVE_FORWARD")
	end
end
ar_wait_for(function() return ar_set_name() == "underground cavern" end, 30000, "the cavern")
sleep_for(1500)
-- (the entrance cutscene is skipped by the skipper with Escape, as a player does; the game gives the control back)
ar_wait_for_control()
ar_state("unc")
ar_survey()
AR_NO_SKIP = TRUE -- the pickup cutscene sets recovered_loot at its end; its skip does not
ar_do("use", unc.booty)
ar_wait_for_control()
AR_NO_SKIP = nil
-- (the tiny screw drops out of the loot as it is taken: picked up now, while Guybrush is in the cavern; it used to be a second dive in
-- ch31, with a second fish chase. Its pickup plays the Elaine movie (ela2) when Pegnose is caught and his nose is not found yet: here,
-- out of ch30's no-skip window, where it ran its whole length)
ar_do("use", unc.screw)
ar_wait_for_control()
ar_check(props.nosescrew.state == PROP_INV, "the screw in hand")
ar_log("recovered_loot=" .. tostring(glob.recovered_loot))
ar_checkpoint(28)
