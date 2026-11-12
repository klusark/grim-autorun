-- Act 3 chapter 2: the banana picker from the canyon, the bananas on the beach
ar_log("=== ACT3 ch02 bananas ===")
ar_wait_for_control()
ar_do("use", mib.mom_door)
ar_wait_for_control()
a3_go(mom.can_door_left, "canyon")
ar_do("pickUp", can.picker)
ar_do("pickUp", props.ht_note1)
ar_state("picker and note")
ar_do("use", can.mom_door_left)
ar_wait_for_control()
a3_go(mom.mib_door, "monkey beach")
ar_do("pickUp", props.ht_note3)
-- (the picker is used when Timmy is not near: with him within 2.5 of Guybrush at the use point, the game runs him to the bunch for the last
-- use, and then walks Guybrush to the very place Timmy stands, where Guybrush walks into him for good (the original, Nov 11: 300,000
-- collisions in a cutscene). Guybrush goes to the use point first and waits there for Timmy to run off, as a player would)
a3_banana_use = function()
	ar_walk_to(mib.bananabunch.use_pnt_x, mib.bananabunch.use_pnt_y, mib.bananabunch.use_pnt_z)
	if timmy.in_set == system.currentSet and not glob.timmy_following then
		ar_try_wait(function() return proximity(timmy, guybrush) > 3.5 end, 30000)
		ar_log("Timmy at " .. proximity(timmy, guybrush) .. " from Guybrush")
	end
	ar_do("use", mib.bananabunch, props.banana_picker)
end
a3_banana_use()
ar_state("banana 1")
a3_banana_use()
ar_state("banana 2")
a3_banana_use()
ar_state("banana 3")
ar_log("bananas state " .. tostring(props.bananas.state) .. " (LOC3 = " .. tostring(PROP_LOC3) .. ")")
ar_check(props.bananas.state == PROP_LOC3, "the whole bunch of bananas is down")
ar_checkpoint(302)
