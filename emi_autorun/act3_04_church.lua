-- Act 3 chapter 4: the Church of LeChuck: the priest, the shields (cymbals) with the banana picker, the lava ride and the milk bottle
ar_log("=== ACT3 ch04 church ===")
ar_wait_for_control()
a3_to_map()
a3_go(mom.col_door, "field of lava")
ar_do("use", lav.col_door)
ar_wait_for_control()
a3_dialog("lp1", { [56] = 1, [57] = 1, [58] = 1 })
-- (into the ghost's trigger box, a diagonal strip of the floor about x -1.2..0.4, z -4..-1: walking on into it brings the priest)
ar_walk_to(-0.4, 0, -3.6, function() return glob.met_priest end)
ar_wait_for(function() return glob.met_priest end, 60000, "priest")
a3_dlg_done("lp1")
ar_do("use", props.cymbals, props.banana_picker)
ar_put_away()
-- the ride: the bottle shows at one node of the flume (which one depends on the puzzle the game picked); the boats there are bumper
-- cars: a bump can send Guybrush round again, or out at the end without the bottle, then the priest is asked for another ride
local rides = 0
while props.milk_bottle.state == PROP_INITIAL and rides < 8 do
	rides = rides + 1
	if rides == 1 then
		a3_dialog_lines("lp1", { 56, 57 })
	else
		a3_dialog_lines("lp1", { 58 })
	end
	a3_talk(col.priest_obj, "lp1")
	a3_wait(a3_riding, 200000, "the ride")
	ar_log("RIDING puzzle " .. tostring(glob.flume_puzzle) .. ", ride " .. rides)
	local bot = start_script(a3_ride_bot)
	A3_RIDE_ABORT = nil
	AR_KEEP_GOING = TRUE
	a3_wait(function() return a3_bottle_hot() or not a3_riding() end, 200000, "the bottle or the end of the ride")
	AR_KEEP_GOING = FALSE
	if not a3_bottle_hot() and a3_riding() then
		ar_log("no luck with the bumper boats this ride, leaving by the end of the flume")
		A3_RIDE_ABORT = TRUE
		AR_FAILED = FALSE
	end
	if a3_bottle_hot() then
		ar_log("bottle is hot")
		ar_do("use", props.milk_bottle, props.banana_picker)
	else
		ar_log("ride over without the bottle")
	end
	a3_wait(function() return not a3_riding() end, 600000, "the end of the ride")
	ar_wait_for_control()
	stop_script(bot)
end
ar_state("after ride")
ar_check(props.milk_bottle.state ~= PROP_INITIAL, "the milk bottle")
ar_checkpoint(304)
