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
-- The glowing fishies: the baited ScupperWare is used in the hand, as the speed runners do, as soon as one of them swims within 10 of
-- Guybrush (the game's own test, ulg.capture_fishy: the nearest one then comes to the bait, wherever he faces). (The school object's
-- verb is offered only within its range of 6 and while Guybrush faces it: chasing it for that took 50 to 250 s.)
-- Until then he waits where the schools come by: each school (ulg.start_fish, ulg.move_fish) swims from a point of
-- ulg.outskirts_waypoints through one of the four ulg.center_waypoints to another outskirts point, and then the next one starts.
-- (1.43, -15.65) on sector85 is the point of the floor nearest all four centre points (6.6 at most, the fishies' height included), so
-- every school passes within the 8.5 below, and it is 0.5 outside the range of every other object of the lagoon. (Chasing the
-- nearest one instead could end at the floor's north edge with the school out over the open water, out of reach: Nov 26 the strokes
-- ran out at z -19.4, the lagoon stayed dark and unc_path, the way into the cavern, stayed off.)
-- The USE key with the ScupperWare in the hand uses it on the hot object when there is another one (_controls.lua; the held
-- ScupperWare itself is the hot object otherwise): only the school (use_ScupperWare_with_bait_in_it) then catches; the rock beside the
-- place of the dive does not (Nov 26: eight tries from there with a fishy 3 to 8 away, all "I've got a ScupperWare in my hand!").
-- So the walk to the waiting place comes first.
c28_fish = function()
	local best = nil
	local bx = nil
	local bz = nil
	local g = manny:getpos()
	local i = 1
	while ulg and ulg.fish and i <= (ulg.current_fish_count or 0) do
		local p = ulg.fish[i]:getpos()
		local d = sqrt((p.x - g.x) * (p.x - g.x) + (p.y - g.y) * (p.y - g.y) + (p.z - g.z) * (p.z - g.z))
		if not best or d < best then
			best = d
			bx = p.x
			bz = p.z
		end
		i = i + 1
	end
	return best, bx, bz
end
c28_fish_close = function()
	local d = c28_fish()
	return d and d < 8.5
end
c28_fish_ready = function()
	return c28_fish_close() and cutSceneLevel == 0 and (not hot_object or hot_object == props.scupperware or hot_object == ulg.fishschool)
end
C28_TRIES = 0
C28_WAITS = 0
ar_hold(props.scupperware)
ar_walk_to(1.43, nil, -15.65, c28_fish_ready, 20000)
while props.scupperware.state ~= PROP_LOC2 and C28_TRIES < 8 and C28_WAITS < 3 do
	ar_hold(props.scupperware)
	if c28_fish_ready() then
		C28_TRIES = C28_TRIES + 1
		ar_log("fishy try " .. C28_TRIES .. format(", the nearest at %.1f", c28_fish()))
		ar_do("use", props.scupperware)
		sleep_for(1000)
		ar_try_wait(function() return cutSceneLevel == 0 end, 20000)
	else
		C28_WAITS = C28_WAITS + 1
		ar_log("fishy: waiting for the next school")
		ar_try_wait(c28_fish_ready, 240000)
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
