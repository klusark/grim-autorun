-- Act 2 chapter 12: Planet Threepwood: the menu, a caricature of Guybrush, a Mega Monkey Meal on a coupon (the Monkey Mug arrives), the
-- caricature with the mug, glue, the logo mug wrapped = a fake Monkey Mug, the switch
-- TRICKS=mug (the speed runners' "mug skip"): the real mug is taken without a fake one. Seated, the stool's button handler sends the waitress
-- for the mug only on the inventory, pick up and out keys (plt.stool.buttonHandler); a number key passes on to the game's own handler, which
-- puts the held mug away for the item bound to that key (inventory_hot_key_pressed). When Guybrush gets up she takes the mug she thinks is
-- still on the table; the real one stays in the inventory, and Act 2's pieces need nothing more of it (props.ultimate_insult.check_components).
-- Then the meal is ordered here on the manatee's coupon, and act2_13 does nothing (no caricature, no second meal; act2_08 and act2_10 leave
-- out the logo mug and Stan's coupon)
ar_load(211)
ar_log("=== ACT2 ch12 plt ===")
ar_wait_for_control()
ar_put_away()
ar_do("use", mig.gpt_door)
ar_wait_for_control()
ar_do("use", gpt.plt_door)
ar_wait_for_control()
ar_check(ar_set_name() == "Planet Threepwood", "in Planet Threepwood")
if not (AR_TRICKS and AR_TRICKS.mug) then
	ar_survey()
	ar_do("lookAt", plt.specials)
	ar_wait_for_control()
	ar_check(glob.plt_saw_menu, "the menu")
	-- a caricature of Guybrush
	ar_talk(plt.artist_obj)
	ar_dlg("ar1")
	a2_ready("ar1", 3000)
	ar_lines("ar1")
	ar_say("ar1", 70)
	a2_ready("ar1", 1500)
	ar_say("ar1", 72)
	a2_ready("ar1", 6000)
	ar_lines("ar1")
	ar_say("ar1", 200)
	a2_ready("ar1", 3000)
	ar_lines("ar1")
	ar_say("ar1", 300)
	a2_ready("ar1", 3000)
	ar_lines("ar1")
	ar_say("ar1", 400)
	ar_dlg_done("ar1")
	ar_check(props.guycaricature.state == PROP_INV, "caricature of Guybrush")
else
	ar_do("lookAt", plt.specials)
	ar_wait_for_control()
	ar_check(glob.plt_saw_menu, "the menu")
	-- (the brochure gets its number key now: while the real mug is held the inventory key would bring the waitress)
	ar_hold(props.brochure)
	ar_put_away()
	-- (the waitress walks a circuit: try again when she was out of reach)
	AR_KEEP_GOING = TRUE
	A2_PLT_TRIES = 0
	while not (getglobal("tw1") and tw1.running) and A2_PLT_TRIES < 12 do
		AR_FAILED = FALSE
		ar_talk(plt.pt_waitress_obj)
		sleep_for(4000)
		A2_PLT_TRIES = A2_PLT_TRIES + 1
	end
	AR_KEEP_GOING = FALSE
	AR_FAILED = FALSE
	ar_dlg("tw1")
	a2_ready("tw1", 3000)
	ar_lines("tw1")
	ar_say("tw1", 70)
	a2_ready("tw1", 3000)
	ar_lines("tw1")
	ar_say("tw1", 200)
	a2_ready("tw1", 3000)
	ar_lines("tw1")
	ar_say("tw1", 300)
	a2_ready("tw1", 3000)
	ar_lines("tw1")
	ar_say("tw1", 420)
	ar_wait_for(function() return plt.sitting end, 120000, "Guybrush to sit down with the mug on the table")
	ar_dlg_done("tw1")
	ar_wait_for_control()
	ar_state("seated")
	ar_do("pickUp", plt.monkeymug)
	ar_wait_for_control()
	ar_check(props.monkeymug.state == PROP_INV, "the Monkey Mug picked up")
	ar_hold(props.brochure)
	ar_check(manny.is_holding == props.brochure and Inventory.unordered_inventory_table[props.monkeymug], "the mug put away by the brochure's key")
	ar_put_away()
	-- (the game offers the stool, "Get up from", through its own forced_hotlist during the mug scene)
	ar_do("use", plt.stool)
	ar_wait_for_control()
	ar_check(props.monkeymug.state ~= PROP_INITIAL and Inventory.unordered_inventory_table[props.monkeymug], "the real Monkey Mug kept")
end
ar_state("end")
ar_checkpoint(212)
