-- Act 4 helpers for the end of the whole game (Ozzie's tower and the last Monkey Kombat; run_single.sh). The chapters 01-25 that played
-- Monkey Island from the game's jump scripts, with a patched island map, are in act4_standalone/ (not part of the player-input-only run).
AR_TIMEOUT = 60000000   -- the whole act in one run takes more than the 30 minutes of game time that the watchdog of the library allows

-- Start of a chapter after ar_load: the Lua globals of the run are part of the save
ar_a4_begin = function(name)
	AR_BIG_SET = nil
	ar_log("=== ACT4 " .. name .. " === in " .. tostring(ar_set_name()))
	ar_wait_for_control()
end


-- A verb whose script does not give control back before the caller goes on (like ar_talk: the switch of the tower starts the final
-- fight, a cutscene that ends with the credits): walks up and presses the verb, returns at once.
ar_a4_start = function(verb, obj, item)
	ar_wait_for_control()
	AR_START_SET = system.currentSet
	if item then
		AR_CODE = obj[verb .. "_" .. trim_header(item.system_name or item.string_name)]
		if not ar_hold(item) then
			return ar_fail("could not take " .. tostring(item.name) .. " in hand")
		end
	else
		AR_CODE = obj[verb]
		-- (a held item makes the verb a use of that item)
		if manny.is_holding then
			ar_put_away()
		end
	end
	ar_log("start: " .. verb .. " " .. tostring(obj.name) .. (item and (" with " .. tostring(item.name)) or ""))
	ar_approach(obj)
	if item and manny.is_holding ~= item then
		ar_hold(item)
	end
	if ar_send_verb(verb, obj, verb .. " " .. tostring(obj.name)) then
		AR_KEYS_USED = AR_KEYS_USED + 1
	end
	return TRUE
end

-- Monkey Kombat (monkey_kombat2.lua). The keys of a move word: 1 forward, 2 right, 3 backward, 4 left (the game's kombat_buttonHandler).
-- A stance is changed by saying the three words glob.mk_phrase_table[from][to]; the same word three times keeps the stance. The stance of
-- the monkey is mk.current_monkey_stance; one of the two that beat it is the one to move to (what_beats_me), in the last fight
-- (mk.level 6) the contest cannot be won on damage (the monkey's health stops at half): three draws on Guybrush's own turns end it
-- (do_kombat: guybrush_stalls >= 3), so there the stance to move to is the monkey's own.
ar_a4_kkey = function(n)
	if n == 1 then
		return next(control_map.MOVE_FORWARD, nil)
	elseif n == 2 then
		return next(control_map.TURN_RIGHT, nil)
	elseif n == 3 then
		return next(control_map.MOVE_BACKWARD, nil)
	end
	return next(control_map.TURN_LEFT, nil)
end

ar_a4_kword = function(i)
	-- the i-th word is said when the game has taken it (cur_button moves on after the word is spoken)
	local key = ar_a4_kkey(AR_A4_WORD[i])
	ar_press_key(key)
	sleep_for(60)
	ar_release_key(key)
	AR_A4_I = i
	ar_try_wait(ar_a4_kword_taken, 20000)
end

ar_a4_kword_taken = function()
	return not mk or mk.quitting or mk.no_press_buttons or mk.cur_button > AR_A4_I
end

ar_a4_kturn_ready = function()
	return mk and not mk.quitting and not mk.monkey_turn and not mk.no_input and not mk.no_press_buttons and mk.cur_button == 1 and system.buttonHandler == mk.kombat_buttonHandler
end

ar_a4_kombat_target = function()
	local m = mk.current_monkey_stance
	if mk.level == 6 then
		return m
	end
	-- (a stance that beats the monkey's: what_beats_me)
	local b = mk.what_beats_me[m]
	local g = mk.current_guybrush_stance
	if g == b[1] or g == b[2] then
		return g
	end
	return b[1]
end

ar_a4_kombat_diag = function()
	if not mk then return end
	ar_log(format("KOMBAT STALL: monkey_turn=%s no_input=%s no_press=%s cur_button=%s last_button=%s quitting=%s cs=%d msg=%s choose=%s check=%s watch=%s guyhealth=%.1f monhealth=%.1f gstance=%s mstance=%s handler=%s", tostring(mk.monkey_turn), tostring(mk.no_input), tostring(mk.no_press_buttons), tostring(mk.cur_button), tostring(mk.last_button), tostring(mk.quitting), cutSceneLevel, tostring(IsMessageGoing()), tostring(find_script(mk.choose_monkey_move)), tostring(find_script(mk.check_guybrush_move)), tostring(find_script(mk.watch_for_buttons)), mk.guybrush_health, mk.monkey_health, tostring(mk.current_guybrush_stance), tostring(mk.current_monkey_stance), tostring(system.buttonHandler == mk.kombat_buttonHandler)))
end

ar_a4_kombat = function()
	local rounds = 0
	local stall = 0
	ar_try_wait(ar_a4_kturn_ready, 60000)
	while mk and not mk.quitting and rounds < 80 do
		stall = stall + 1
		if stall == 150 or stall == 600 or stall == 2000 then
			ar_a4_kombat_diag()
		end
		if ar_a4_kturn_ready() then
			stall = 0
			local g = mk.current_guybrush_stance
			local t = ar_a4_kombat_target()
			if g == t then
				AR_A4_WORD = { 1, 1, 1 }
			else
				AR_A4_WORD = glob.mk_phrase_table[g][t]
			end
			rounds = rounds + 1
			ar_log(format("kombat round %d: guybrush stance %d, monkey stance %d -> %d, words %d %d %d, health %.1f / %.1f, stalls %d", rounds, g, mk.current_monkey_stance, t, AR_A4_WORD[1], AR_A4_WORD[2], AR_A4_WORD[3], mk.guybrush_health, mk.monkey_health, mk.guybrush_stalls))
			ar_a4_kword(1)
			ar_a4_kword(2)
			ar_a4_kword(3)
		end
		sleep_for(200)
	end
	ar_log("kombat over after " .. rounds .. " rounds")
end

ar_a4_credits_up = function()
	return credits_menu and credits_menu.is_active
end
ar_a4_credits = function(ms)
	ar_log("waiting for the credits")
	ar_try_wait(ar_a4_credits_up, ms)
	ar_log("credits menu=" .. tostring(credits_menu) .. " active=" .. tostring(credits_menu and credits_menu.is_active))
end

ar_a4_credits_over = function()
	return not credits_menu or not credits_menu.is_active
end

-- Monkey Island map: a wild monkey that touches Guybrush throws him into the jungle (set jun) for a kombat encounter that is never
-- needed; the way back is the door "Monkey Island" there (mom.encounter_return puts him where he was). A do on the map is repeated
