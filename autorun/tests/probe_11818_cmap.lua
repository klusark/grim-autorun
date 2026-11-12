-- Bug #11818 probe: each costume that shares Manny's chowthund model is pushed and popped; with a reload log in Model::reload
-- (warning of _fname + cmap) the model must stay m_chow.cmp throughout. Without the fix siberian.cmp / charlie.cmp stay after the pop.
start_script(function()
	th:switch_to_set()
	manny:put_in_set(th)
	manny:setpos(0.217875004, -0.0647829995, 2.1559999)
	manny:default("fancy")
	sleep_for(500)
	PrintWarning("P11818 set " .. system.currentSet.setFile .. " " .. manny:get_costume())
	local list = { "mcc_snowblow.cos", "mcc_coffee.cos", "mcc_knock_on_door.cos", "mccthund_ladder_generic.cos", "mccthund_react.cos", "mcc_theater.cos" }
	local i = 1
	while list[i] do
		manny:push_costume(list[i])
		PrintWarning("P11818 pushed " .. list[i])
		sleep_for(300)
		manny:pop_costume()
		PrintWarning("P11818 popped " .. list[i])
		sleep_for(300)
		i = i + 1
	end
	PrintWarning("P11818 END")
end)
