-- Tricks of the speed runners, each one off unless asked for: run_all.sh and run_chapter.sh add this file when TRICKS= names one (AR_TRICKS["blam"] ...), or when
-- BLAMLEARN=1 asks for the log the spots are made from. A run without them is not changed by a frame.
--
-- blam: typing the four letters b, l, a, m (stopKeyDown, _system.lua) starts est_test: Manny's costume gets est.cos pushed on top, he blows up and comes back, and
-- 3 s later the costume on top of his stack is popped. When the game has pushed a costume of its own on top meanwhile (the search of a jacket, the climb onto a
-- ladder), that one is popped instead: the chore the game waits for is gone with it, the wait ends, and the game's own pop takes est.cos off later. So the word is
-- typed a few frames before the game pushes the costume, and the costume is held for 3 s instead of as long as its animation lasts. The speed runners of the
-- original (54:23, ScummVM) type it many times a minute.
--
-- Where: an anchor is the last thing that happened that the timing of the game's scripts runs from: a verb sent (ar_send_verb), a change of set, the start of a
-- cutscene. Its key is the chapter, the kind, what it was and how many of the same came before in the chapter. A learning run (BLAMLEARN=1) logs each costume
-- pushed onto Manny with the key of its anchor and the frames since it, and each pop; tools/blam_spots.py makes ar_blam_spots.lua from that log: the pushes that are
-- popped again inside a cutscene and are held long enough for the word to save time. A run with TRICKS=blam types the word AR_BLAM_LEAD frames before each.
-- The letters go only to the game's own button handler, and only in a cutscene or when Manny neither holds anything nor looks at anything: then the a (the second
-- pick-up key, ALTHOTKEY_PICKUP) does nothing.

AR_TRICKS = AR_TRICKS or { }
AR_BLAM_SPOTS = AR_BLAM_SPOTS or { }
-- (ar_blam_after.lua: spots where the word is typed that many frames after the push instead of before it)
AR_BLAM_AFTER = AR_BLAM_AFTER or { }
AR_BLAM_LEAD = AR_BLAM_LEAD or 3
AR_TR_COUNT = { }
AR_TR_CH = nil

-- a new anchor; with blam on, the spots that run from it are started
ar_tr_anchor = function(kind, what)
	local ch = tostring(AR_FRAME_CH or AR_CHAPTER)
	if ch ~= AR_TR_CH then
		AR_TR_CH = ch
		AR_TR_COUNT = { }
	end
	local base = ch .. "|" .. kind .. ":" .. tostring(what)
	AR_TR_COUNT[base] = (AR_TR_COUNT[base] or 0) + 1
	AR_TR_KEY = base .. "|" .. AR_TR_COUNT[base]
	AR_TR_FRAME = AR_FRAME
	if AR_TRICKS.blam and AR_BLAM_SPOTS[AR_TR_KEY] then
		local spot = AR_BLAM_SPOTS[AR_TR_KEY]
		if AR_BLAM_AFTER[AR_TR_KEY] then
			start_script(ar_blam_task, AR_FRAME + spot.off + AR_BLAM_AFTER[AR_TR_KEY], spot, AR_TR_KEY, TRUE)
		else
			start_script(ar_blam_task, AR_FRAME + spot.off - (spot.lead or AR_BLAM_LEAD), spot, AR_TR_KEY)
		end
	end
end

-- the word, typed at the first quiet frame from `at` on (the spot's costume is pushed spot.lead frames later: the earlier the word, the sooner its pop comes after the
-- push; with after, it was pushed before, and the word is for the chores the game
-- plays after it: est.cos on top has none of them)
ar_blam_task = function(at, spot, key, after)
	while AR_FRAME < at do
		break_here()
	end
	-- (out of a cutscene the a picks up what Manny looks at, or puts away what he holds: only when there is neither; the b, l and m do something only with control
	-- or alt held. Where it is not quiet yet, every frame up to the one before the push: the cutscene often begins two or three frames before the game pushes
	-- its costume. After the push it is not typed at all: the word would pop the next costume instead)
	local quiet = nil
	local last = at + (spot.lead or AR_BLAM_LEAD) - 1
	if after then
		last = at + 30
	end
	local looking = TRUE
	while looking do
		quiet = system.buttonHandler == SampleButtonHandler and (cutSceneLevel > 0 or (not hot_object and not manny.is_holding))
		if quiet or AR_FRAME >= last then
			looking = nil
		else
			break_here()
		end
	end
	if quiet then
		ar_log("BLAM for " .. tostring(spot.cos) .. " (" .. tostring(key) .. ", held " .. tostring(spot.held) .. " frames in the learning run" .. (after and (", " .. tostring(AR_BLAM_AFTER[key]) .. " frames after its push") or "") .. ")")
		AR_BLAM_N = (AR_BLAM_N or 0) + 1
		ar_press_key(BKEY)
		ar_press_key(LKEY)
		ar_press_key(AKEY)
		ar_press_key(MKEY)
	else
		ar_log("BLAM not typed for " .. tostring(spot.cos) .. " (" .. tostring(key) .. "): cut scene level " .. tostring(cutSceneLevel) .. ", the handler is " .. (system.buttonHandler == SampleButtonHandler and "the game's" or "another") .. ", looking at " .. tostring(hot_object and hot_object.name) .. ", holding " .. tostring(manny.is_holding and manny.is_holding.name))
	end
end

-- the anchors: a verb sent
AR_TR_SEND = ar_send_verb
ar_send_verb = function(verb, noun1, label)
	ar_tr_anchor("verb", tostring(verb) .. " " .. tostring(noun1 and noun1.name))
	return AR_TR_SEND(verb, noun1, label)
end

-- a change of set and the start of a cutscene, looked at every frame
ar_tr_watch = function()
	local set = system.currentSet
	local cut = cutSceneLevel
	while TRUE do
		if system.currentSet ~= set then
			set = system.currentSet
			ar_tr_anchor("set", set and set.name)
		end
		if cutSceneLevel > 0 and cut <= 0 then
			ar_tr_anchor("cut", system.currentSet and system.currentSet.name)
		end
		cut = cutSceneLevel
		break_here()
	end
end
AR_TR_WATCH = start_script(ar_tr_watch)

-- the learning log: each costume pushed onto Manny and popped off him
if AR_BLAM_LEARN then
	AR_TR_PUSH = Actor.push_costume
	Actor.push_costume = function(a, c)
		if a == manny then
			ar_log("TRK push " .. tostring(c) .. " key " .. tostring(AR_TR_KEY) .. " off " .. tostring(AR_FRAME - (AR_TR_FRAME or AR_FRAME)) .. " cut " .. tostring(cutSceneLevel) .. " frame " .. tostring(AR_FRAME))
		end
		return AR_TR_PUSH(a, c)
	end
	AR_TR_POP = Actor.pop_costume
	Actor.pop_costume = function(a)
		if a == manny then
			ar_log("TRK pop " .. tostring(GetActorCostume(a.hActor)) .. " cut " .. tostring(cutSceneLevel) .. " frame " .. tostring(AR_FRAME))
		end
		return AR_TR_POP(a)
	end
end

-- menu: a movie of a cutscene that has no override (the Lola torn from the pier, the Pearl sub, the end of the world, ...) is stopped the way the speed
-- runners do it, through the game's menu: the menu key, "View Cutscenes" (main_menu item 7), the first cutscene of the list, which cutscene_menu.view_cutscene
-- starts with StopMovie() (the movie of the game is the one that stops), the override key for the cutscene that starts, and the override key twice back to the
-- game. The cutscene that waited for its movie goes on. The menu pauses every task but the one that pressed its key (pause_scripts), this one, which drives it.
-- AR_MENU_AFTER: frames of the movie before the menu (so that a movie of a frame or two is left alone); AR_MENU_SKIP["chapter|set"] = TRUE leaves a movie alone
AR_MENU_AFTER = AR_MENU_AFTER or 6
AR_MENU_SKIP = AR_MENU_SKIP or { }

-- waits a frame at a time for cond, at most n frames; TRUE when it came
ar_menu_wait = function(cond, n)
	local k = 0
	while not cond() and k < n do
		break_here()
		k = k + 1
		-- (the frame counter of the run is a task the menu pauses too: the frames of the menu are counted here, a player's clock runs on through it)
		if game_pauser.is_paused then
			AR_FRAME = AR_FRAME + 1
			AR_MENU_FRAMES = (AR_MENU_FRAMES or 0) + 1
		end
	end
	return cond()
end

-- out of any menu and back to the game: the override key until the game is no longer paused (at most 10 presses)
ar_menu_back = function()
	local k = 0
	while game_pauser.is_paused and k < 10 do
		-- (the next press as soon as the handler of the keys has changed: the cutscene menu gives way to the main menu at once, the main menu to the
		-- game a frame or two later)
		AR_MENU_H = system.buttonHandler
		ar_press_key(ar_real_key("OVERRIDE"))
		ar_menu_wait(function() return not game_pauser.is_paused or system.buttonHandler ~= AR_MENU_H end, 20)
		k = k + 1
	end
	if game_pauser.is_paused then
		ar_log("MENU the game did not come back from the menu")
	end
end

ar_menu_stop_movie = function(where)
	ar_log("MENU stopping the movie in " .. where)
	AR_MENU_N = (AR_MENU_N or 0) + 1
	ar_press_key(ar_real_key("MENU"))
	if not ar_menu_wait(function() return main_menu.is_active and main_menu.menu end, 30) then
		ar_log("MENU the main menu did not open")
		return
	end
	-- (View &Cutscenes: its hot key, the letter c, as the engine hands a typed letter to the menu's characterHandler. The arrow keys move the menu in a script
	-- of their own while the key is held, a frame and 500 ms at a time)
	if system.characterHandler and system.characterHandler.characterHandler then
		system.characterHandler:characterHandler("c")
	end
	if not ar_menu_wait(function() return cutscene_menu.is_active and cutscene_menu.menu end, 30) then
		ar_log("MENU the cutscene menu did not open (main menu " .. tostring(main_menu.is_active) .. ", cutscene menu " .. tostring(cutscene_menu.is_active) .. ", handler is main menu " .. tostring(system.buttonHandler == main_menu) .. "), back to the game")
		ar_menu_back()
		return
	end
	-- (the first cutscene of the list: the Home key puts the cursor there at once)
	ar_press_key(ar_real_key("PAGE_HOME"))
	ar_log("MENU cutscene menu item " .. tostring(cutscene_menu.menu.cur_item))
	ar_press_key(ar_real_key("DIALOG_CHOOSE"))
	-- (the chosen cutscene starts after view_cutscene stopped the game's movie: its key is the override)
	if ar_menu_wait(function() return system.buttonHandler == cutscene_menu_view_button_handler end, 60) then
		ar_menu_wait(function() return IsMoviePlaying() end, 30)
		ar_press_key(ar_real_key("OVERRIDE"))
		ar_menu_wait(function() return system.buttonHandler == cutscene_menu end, 120)
	else
		ar_log("MENU the cutscene did not start")
	end
	-- back: the cutscene menu to the main menu, the main menu to the game
	ar_menu_back()
end

ar_menu_watch = function()
	local f0 = nil
	while TRUE do
		local m = cutSceneLevel > 0 and IsMoviePlaying and IsMoviePlaying() and not (system.override and system.override.is_active) and not game_pauser.is_paused and system.buttonHandler == SampleButtonHandler
		if m then
			f0 = f0 or AR_FRAME
		else
			f0 = nil
		end
		if f0 and AR_FRAME - f0 >= AR_MENU_AFTER then
			local where = tostring(AR_FRAME_CH or AR_CHAPTER) .. "|" .. tostring(system.currentSet and system.currentSet.name)
			if not AR_MENU_SKIP[where] then
				local m0 = AR_FRAME
				ar_menu_stop_movie(where)
				ar_log("MENU done in " .. (AR_FRAME - m0) .. " frames, the movie had played " .. AR_MENU_AFTER .. ", playing now " .. tostring(IsMoviePlaying()))
			end
			f0 = nil
			-- (one movie a time: wait for this one to be over before the next is looked at)
			ar_menu_wait(function() return not IsMoviePlaying() end, 600)
		end
		break_here()
	end
end
if AR_TRICKS.menu then
	AR_MENU_WATCH = start_script(ar_menu_watch)
end
