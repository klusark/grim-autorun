-- Chapter 42: Meche's ashtray room. Twisting the ashtray while Meche flicks her ash sets her stockings
-- alight; they are thrown into the wastebasket and Manny takes the remains. Checkpoint in slot 58.

ar_load(41)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(mn.ea_door, ea)
ar_go(ea.fh_door, fh)
ar_go(fh.vd_door, vd)
ar_go(vd.ar_door, ar)
ar_wait_for_control()
ar_wait_for(function() return ar.greeted and not find_script(ar.greet_manny) and cutSceneLevel == 0 end, 300000)
ar_wait_for_control()
-- The stockings burn when Meche's loop (ar.meche_idle) picks the flick while ashtray.twisted is true, 296 to 474 frames after the verb is pressed. Her pick is a draw of
-- pick_one_of(meche_ash_idles, TRUE) from the game's random numbers (a shuffle bag: each of her four idles once before any repeats), and those are predictable
-- (ar_rng.lua): the bag is in masterTable, each idle has its length, a background script draws one number every frame and a pick takes the numbers after it. So
-- Manny stands where the animation puts him, the picks are worked out, and the verb is pressed at the first frame at which the flick falls inside the twist.
-- Every pick that then happens is compared with the one worked out; the first that differs ends this and the verb is tried the old way, again and again.
-- In real time the frames are not the fixed 60 a second the lengths are worked out for: then it is the old way at once.
AR_MA_L = { [0] = 633, [1] = 1667, [2] = 1366, [3] = 3383 }
AR_MA_TW0 = 296
AR_MA_TW1 = 474
AR_MA_MARGIN = 12

-- milliseconds of frame k of the 60 a second clock of a simulated run (the frame counts here are too large to multiply by 50 in a float: k / 3 and k mod 3). The 16, 17,
-- 17 ms of the frames repeat every three, and where they fall against the frame counter of the autorun depends on how many frames went before: AR_MA_OFF (0 to 2) is the
-- phase, found from the picks that are seen (ar_ma_calibrate)
AR_MA_OFF = 1
ar_ma_ms = function(k)
	local a = k + AR_MA_OFF
	return floor(a / 3) * 50 + floor(mod(a, 3) * 50 / 3)
end

-- the frame at which an idle that was picked at frame f is over and the next pick is made
ar_ma_end = function(f, chore)
	local m = f + 1
	local t0 = ar_ma_ms(f)
	while ar_ma_ms(m) - t0 < AR_MA_L[chore] do
		m = m + 1
	end
	return m
end

-- The phase for ar_ma_end, from the frame times the tracker has seen: the tracker's picks, stamped in its own place in the order of the frame, follow the 16, 17, 17 ms
-- pattern of the frames one phase on (found from 60 picks in a run of the whole game and in the chapter by itself: 2 and 0 for the pattern, 0 and 1 for the picks).
-- TRUE when there is a phase and a pick has been seen
ar_ma_calibrate = function()
	if not AR_MA_PF then
		return nil
	end
	local ft = ar_ma_ftphase()
	if not ft then
		return nil
	end
	AR_MA_OFF = mod(ft + 1, 3)
	AR_MA_OFFS = { AR_MA_OFF }
	return TRUE
end

-- the phase of the 16, 17, 17 ms pattern as the tracker sees it: the one for which the differences of ar_ma_ms are the frame times of the last 12 frames; nil if none or two
ar_ma_ftphase = function()
	local found = nil
	local count = 0
	local off = 0
	while off <= 2 do
		AR_MA_OFF = off
		local ok = TRUE
		local j = 0
		while j < 12 do
			local e = AR_MA_FTR[j]
			if not e or ar_ma_ms(e.f) - ar_ma_ms(e.f - 1) ~= e.t then
				ok = nil
			end
			j = j + 1
		end
		if ok then
			count = count + 1
			found = off
		end
		off = off + 1
	end
	if count == 1 then
		return found
	end
	return nil
end

-- a tracker: the frame and the idle of the last pick (the bag of masterTable gets one more mark with each)
ar_ma_track = function()
	local prev = nil
	while TRUE do
		break_here()
		AR_MA_FTR[mod(AR_FRAME, 12)] = { f = AR_FRAME, t = system.frameTime }
		if system.currentSet == ar and meche_ash_idles and masterTable and masterTable[meche_ash_idles] then
			local b = masterTable[meche_ash_idles]
			local cur = { }
			local i = 1
			while b[i] do
				cur[i] = b[i].marker and 1 or 0
				i = i + 1
			end
			if prev then
				-- (a full bag is cleared before the pick: the marks are then those of the pick alone)
				local base = { }
				local full = 1
				i = 1
				while prev[i] do
					if prev[i] == 0 then
						full = nil
					end
					i = i + 1
				end
				i = 1
				while prev[i] do
					if full then
						base[i] = 0
					else
						base[i] = prev[i]
					end
					i = i + 1
				end
				local found = nil
				local changed = nil
				i = 1
				while cur[i] do
					if cur[i] ~= prev[i] then
						changed = TRUE
					end
					if cur[i] == 1 and base[i] == 0 and not found then
						found = i
					end
					i = i + 1
				end
				if changed and found then
					AR_MA_PF = AR_FRAME
					AR_MA_PC = b[found].value
					AR_MA_N = (AR_MA_N or 0) + 1
					-- the pick that was worked out for this frame, if there was one
					if AR_MA_PRED and AR_MA_PRED[AR_MA_PI] then
						local pr = AR_MA_PRED[AR_MA_PI]
						if pr.f == AR_FRAME and pr.c == b[found].value then
							AR_MA_PI = AR_MA_PI + 1
							AR_MA_HIT = (AR_MA_HIT or 0) + 1
						else
							AR_MA_MISS = TRUE
							ar_log("MA pick differs: frame " .. AR_FRAME .. " idle " .. tostring(b[found].value) .. ", worked out: frame " .. pr.f .. " idle " .. pr.c)
						end
					end
				end
			end
			prev = cur
		end
	end
end

-- the picks from the next frame on, worked out from the bag, the last pick and the numbers to come (xs, from ar_rng_peek), for a verb pressed at frame fv:
-- Manny's own draw in the animation, the pick of the sound of the cigarette, comes 180 frames after the verb and takes a number of the picks after it
ar_ma_sim = function(xs, fv, last)
	local b = masterTable[meche_ash_idles]
	local bag = { }
	local val = { }
	local i = 1
	while b[i] do
		bag[i] = b[i].marker and 1 or 0
		val[i] = b[i].value
		i = i + 1
	end
	local count = i - 1
	local idx = 1
	local f = AR_FRAME
	local npf = ar_ma_end(AR_MA_PF, AR_MA_PC)
	local picks = { }
	local n = 0
	while f < last do
		f = f + 1
		idx = idx + 1
		if fv and f == fv + 180 then
			idx = idx + 1
		end
		if f == npf then
			local all = 1
			i = 1
			while i <= count do
				if bag[i] == 0 then
					all = nil
				end
				i = i + 1
			end
			if all then
				i = 1
				while i <= count do
					bag[i] = 0
					i = i + 1
				end
			end
			local got = nil
			while not got do
				local r = ar_rng_value(xs[idx], nil)
				idx = idx + 1
				local k = 1 + floor((count - 1 + 0.999899983) * r)
				if bag[k] == 0 then
					bag[k] = 1
					got = k
				end
			end
			n = n + 1
			picks[n] = { f = f, c = val[got] }
			npf = ar_ma_end(f, val[got])
		end
	end
	return picks
end

-- the pick of the flick inside the twist for a verb at frame fv among the picks, or nil
ar_ma_hit = function(picks, fv)
	local lo = fv + AR_MA_TW0 + AR_MA_MARGIN
	local hi = fv + AR_MA_TW1 - AR_MA_MARGIN
	local i = 1
	while picks[i] do
		if picks[i].c == 2 and picks[i].f >= lo and picks[i].f <= hi then
			return picks[i]
		end
		i = i + 1
	end
	return nil
end

-- frames to wait before the verb so that a flick falls inside the twist, with the picks worked out for it; or nil. The same picks have to come out for every phase of the
-- frame pattern that fits what was seen
ar_ma_plan = function()
	local xs = ar_rng_peek(2400)
	local d = 0
	while d <= 700 do
		local fv = AR_FRAME + d
		local ref = nil
		local first = nil
		local ok = TRUE
		local o = 1
		while AR_MA_OFFS[o] and ok do
			AR_MA_OFF = AR_MA_OFFS[o]
			local picks = ar_ma_sim(xs, fv, fv + AR_MA_TW1 + 2)
			local hit = ar_ma_hit(picks, fv)
			if not hit then
				ok = nil
			elseif not ref then
				ref = picks
				first = hit
			else
				local i = 1
				while ref[i] or picks[i] do
					if not ref[i] or not picks[i] or ref[i].f ~= picks[i].f or ref[i].c ~= picks[i].c then
						ok = nil
					end
					i = i + 1
				end
			end
			o = o + 1
		end
		if ok and ref then
			AR_MA_OFF = AR_MA_OFFS[1]
			return d, first.f, ref
		end
		d = d + 1
	end
	return nil
end

local tries = 0
if not AR_NOTIMEOUT and AR_RNG_BAD == 0 then
	AR_MA_FTR = { }
	start_script(ar_ma_track)
	-- where ashtray_fun walks Manny to and turns him: the verb then does not walk him (the steps of a walk draw numbers of their own)
	ar_walk_to(-0.126024, -0.168297, 0)
	ar_face_yaw(63.2788)
	sleep_for(100)
	ar_wait_for_control()
	-- a pick has to be seen (at most 200 frames) and 12 frames of the pattern
	local calibrated = nil
	local waited = 0
	while not calibrated and waited < 12000 do
		calibrated = ar_ma_calibrate()
		if not calibrated then
			sleep_for(100)
			waited = waited + 100
		end
	end
	local d, pf, picks = nil, nil, nil
	if calibrated then
		d, pf, picks = ar_ma_plan()
	else
		ar_log("MA the phase of the frame pattern is not known: the old way")
	end
	ar_log("MA wait " .. tostring(d) .. " frames for a flick at frame " .. tostring(pf))
	if d then
		AR_MA_PRED = picks
		AR_MA_FLICK = pf
		AR_MA_PI = 1
		AR_MA_MISS = nil
		local target = AR_FRAME + d
		while AR_FRAME < target and not AR_MA_MISS do
			break_here()
		end
		if not AR_MA_MISS then
			ar_gaze_at(ar.ashtray)
			ar_press("use")
			ar_log("MA verb pressed at frame " .. AR_FRAME .. ", the flick worked out for frame " .. tostring(pf))
			ar_wait_for(function() return ar.stockings_tossed or AR_MA_MISS or AR_FRAME > AR_MA_FLICK + 700 end, 60000, "the stockings or a different pick")
			ar_wait_for_control()
		end
	end
	AR_MA_PRED = nil
	stop_script(ar_ma_track)
end
while not ar.stockings_tossed and tries < 40 do
	ar_do("use", ar.ashtray)
	ar_wait_for_control()
	sleep_for(1500)
	tries = tries + 1
end
ar_check(ar.stockings_tossed, "Meche's stockings went up in flames")
ar_wait_for(function() return not find_script(cut_scene.leg) and cutSceneLevel == 0 end, 300000)
ar_wait_for_control()
ar_do("lookAt", ar.wastebasket)
ar_wait_for(function() return ar.stockings.owner == manny end, 120000)
ar_wait_for_control()
ar_check(ar.stockings.owner == manny, "Manny has the stockings")
ar_state("end of chapter 42")
ar_checkpoint(42)
