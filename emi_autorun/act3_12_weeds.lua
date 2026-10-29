-- Act 3 chapter 12: the second ride of the lava flume: with the rock in the lava ditch the flume has a branch that ends on the ledge in the
-- lava field (the boat stops at the boulder). There the weeds in the ditch are whipped with the weed whipper (the lava drains into the
-- ground) and the lone palm tree is kicked down: it makes the bridge over the stream, the way from the field's east door to its hill.
ar_log("=== ACT3 ch12 weeds ===")
ar_wait_for_control()
a3_to_map()
a3_go(mom.col_door, "field of lava")
ar_do("use", lav.col_door)
ar_wait_for_control()
a3_rides = 0
while ar_set_name() ~= "field of lava" and a3_rides < 8 do
	a3_rides = a3_rides + 1
	a3_dialog_lines("lp1", { 58 })
	a3_talk(col.priest_obj, "lp1")
	a3_wait(a3_riding, 200000, "the ride")
	ar_log("RIDING to the lava field, puzzle " .. tostring(glob.flume_puzzle) .. ", ride " .. a3_rides)
	A3_RIDE_TARGET = "lavfield"
	a3_bot = start_script(a3_ride_bot)
	AR_KEEP_GOING = TRUE
	-- (the boat is Guybrush's ride until it stops at the ledge: then lav.guyboat is set)
	a3_wait(function() return not a3_riding() or lav.guyboat end, 600000, "the end of the ride")
	AR_KEEP_GOING = FALSE
	AR_FAILED = FALSE
	ar_wait_for_control()
	stop_script(a3_bot)
	A3_RIDE_TARGET = nil
end
ar_check(ar_set_name() == "field of lava", "the ride ended in the lava field")
ar_state("on the ledge")
ar_do("use", lav.weeds, props.weed_whipper)
ar_wait_for_control()
ar_state("weeds whipped")
ar_check(glob.lava_filled, "the lava is drained")
if not glob.knocked_lav_tree then
	ar_do("use", lav.tree)
	ar_wait_for_control()
end
ar_check(glob.knocked_lav_tree, "the palm tree is down")
ar_checkpoint(312)
