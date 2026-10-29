-- Act 3 chapter 8: Monkey Kombat practice: the wild monkeys of the jungle (a bot answers every phrase with a stance that beats the
-- monkey's) until the level is 4
ar_log("=== ACT3 ch08 kombat practice ===")
ar_wait_for_control()
local bot = start_script(a3_kombat_bot)
A3_STAY_JUN = TRUE
local tries = 0
while glob.monkey_kombat_level < 4 and tries < 30 do
	tries = tries + 1
	if ar_set_name() ~= A3_SET_JUN then
		if mod(tries, 2) == 1 then
			a3_goto("monkey town")
		else
			a3_goto("monkey head")
		end
	end
	if ar_set_name() == A3_SET_JUN then
		-- (the set tables are built while the set is entered: the name is there before the monkey object is)
		ar_try_wait(function() return jun and jun.MImonkey_obj and cutSceneLevel == 0 end, 15000)
	end
	if ar_set_name() == A3_SET_JUN and jun and jun.MImonkey_obj then
		ar_log("a monkey in the jungle, try " .. tries .. ", level " .. glob.monkey_kombat_level)
		AR_KEEP_GOING = TRUE
		ar_do("use", jun.MImonkey_obj)
		AR_KEEP_GOING = FALSE
		ar_wait_for(function() return mk == nil end, 300000, "the fight to end")
		ar_wait_for_control()
		ar_log("kombat level " .. tostring(glob.monkey_kombat_level))
		-- the jungle is left by its way back to the map
		a3_to_map()
	end
end
A3_STAY_JUN = nil
stop_script(bot)
ar_check(glob.monkey_kombat_level >= 4, "Monkey Kombat level 4")
ar_checkpoint(308)
