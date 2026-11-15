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
