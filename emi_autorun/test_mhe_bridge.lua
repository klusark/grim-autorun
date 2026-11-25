-- Meathook's rope bridge (mhe): the forward key held, no steering, from each end of the bridge and from a few slants. The bridge is
-- the narrow run of walk quads sector66/63/64/62/60/61/67 (x about 11..14, z 44.9..58.7), bending a little west on the way north; the
-- island is z > 59. The same script runs on ScummVM (run_emi.sh) and on the original (run_orig.sh): it starts from a new game and
-- switches to the set, so no checkpoint is needed. A measurement, not a playthrough.
--   sh run_emi.sh test_mhe_bridge.lua 300      sh run_orig.sh test_mhe_bridge.lua 600
-- Result: "BRIDGE <case> t=<ms>" lines with the position, yaw and floor every 200 ms, and "BRIDGE <case> end ..." with the time.

-- the forward key held for at most ms, logging every 200 ms; done(p) ends it early
ar_br_hold = function(label, ms, zstop, north)
	local t = 0
	local p = manny:getpos()
	ar_key_down("MOVE_FORWARD")
	local going = TRUE
	while going do
		p = manny:getpos()
		ar_log("BRIDGE " .. label .. format(" t=%d %.3f %.3f %.3f yaw %.1f", t, p.x, p.y, p.z, manny:getrot().y))
		if north and p.z > zstop then
			going = FALSE
		elseif not north and p.z < zstop then
			going = FALSE
		elseif t >= ms then
			going = FALSE
		else
			sleep_for(200)
			t = t + 200
		end
	end
	ar_key_up("MOVE_FORWARD")
	sleep_for(300)
	p = manny:getpos()
	local reached = "no"
	if north and p.z > zstop then
		reached = "yes"
	elseif not north and p.z < zstop then
		reached = "yes"
	end
	ar_log("BRIDGE " .. label .. " running " .. tostring(manny.is_running))
	ar_log("BRIDGE " .. label .. " end reached " .. reached .. format(" t=%d %.3f %.3f %.3f yaw %.1f", t, p.x, p.y, p.z, manny:getrot().y))
end

-- put on the bridge at x, y, z facing the point (fx, fz) turned by turn degrees, then the forward key held
ar_br_case = function(label, x, y, z, fx, fz, turn, ms, zstop, north)
	if ar_set_name() ~= "Meathook Exterior" then
		ar_log("BRIDGE " .. label .. " skipped: not in mhe")
		return
	end
	manny:setpos(x, y, z)
	sleep_for(200)
	manny:setrot(0, ar_want_yaw(fx, fz) + turn, 0)
	manny:set_run(FALSE)
	sleep_for(300)
	ar_br_hold(label, ms, zstop, north)
end

-- (walking, not running: the library's watcher otherwise switches the run on whenever he moves)
AR_WALK = TRUE
ar_log("=== mhe bridge ===")
ar_wait_for_control()
-- (on the bridge before the switch: his wedding ship position is in mhe's exit box to the map)
manny:setpos(13.0, 39.19, 45.5)
switch_to_set("mhe")
ar_wait_for_control()
sleep_for(500)
ar_check(ar_set_name() == "Meathook Exterior", "in mhe")

-- north, from the south end (sector66) towards the middle of sector64's far edge
ar_br_case("north_straight", 13.0, 39.19, 45.5, 13.2, 48.4, 0, 12000, 59.2, TRUE)
ar_br_case("north_left20", 13.0, 39.19, 45.5, 13.2, 48.4, -20, 12000, 59.2, TRUE)
ar_br_case("north_right20", 13.0, 39.19, 45.5, 13.2, 48.4, 20, 12000, 59.2, TRUE)
-- north from the middle of sector62, facing up the bridge (on ScummVM it ends at the west half of sector67's north edge)
ar_br_case("north_mid", 12.95, 38.8, 49.8, 12.5, 52.1, 0, 10000, 59.2, TRUE)
-- south, from the north end (sector67) down the bridge, stopped on sector66 before the exit box to the map
ar_br_case("south_straight", 11.7, 39.1, 58.0, 12.1, 54.4, 0, 12000, 46.2, FALSE)
ar_br_case("south_left20", 11.7, 39.1, 58.0, 12.1, 54.4, -20, 12000, 46.2, FALSE)
ar_br_case("south_right20", 11.7, 39.1, 58.0, 12.1, 54.4, 20, 12000, 46.2, FALSE)
ar_log("BRIDGE done")
