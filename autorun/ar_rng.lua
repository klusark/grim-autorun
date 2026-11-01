-- The game's random numbers, followed and predicted.
--
-- random() of the engine is the C library's rand(), seeded by the game's own randomseed(5) at boot. On this build rand() is Microsoft's generator:
--     state = state * 214013 + 2531011 (mod 2^32), the number is bits 16..30 of the state (0..32767), and random() is (number mod 32767) / 32767.
-- A Lua number is a float (exact for integers up to 2^24 only), so the state is kept in four limbs of 8 bits and the products stay small.
--
-- Every draw of the game goes through the Lua function random, so the wrapper below sees them all: it steps a shadow of the state once for each, checks the number the
-- engine gave against the one the shadow expects (AR_RNG_BAD counts the differences), and ar_rng_peek(k) gives the next k numbers without taking them.
-- The wrapper reseeds the generator with 5 when it is installed (the state is then known; the game does the same at boot), and again after a save is loaded
-- (the state of rand is not in a save, the limbs below are: ar_rng_resync).

AR_RNG_N = AR_RNG_N or 0
AR_RNG_BAD = AR_RNG_BAD or 0

-- one step of the generator on four limbs, least significant first
ar_rng_step = function(b0, b1, b2, b3)
	-- 214013 = 3 * 65536 + 67 * 256 + 253, 2531011 = 38 * 65536 + 158 * 256 + 195
	local c0 = b0 * 253 + 195
	local c1 = b0 * 67 + b1 * 253 + 158
	local c2 = b0 * 3 + b1 * 67 + b2 * 253 + 38
	local c3 = b1 * 3 + b2 * 67 + b3 * 253
	local n0 = mod(c0, 256)
	c1 = c1 + floor(c0 / 256)
	local n1 = mod(c1, 256)
	c2 = c2 + floor(c1 / 256)
	local n2 = mod(c2, 256)
	c3 = c3 + floor(c2 / 256)
	local n3 = mod(c3, 256)
	return n0, n1, n2, n3
end

-- the number of a state, 0..32767
ar_rng_out = function(b2, b3)
	return b2 + mod(b3, 128) * 256
end

-- the value that random(a) gives for a number of the generator
ar_rng_value = function(x, a)
	local e = mod(x, 32767) / 32767
	if a and a ~= 0 then
		e = floor(e * a) + 1
	end
	return e
end

ar_rng_seed = function(s)
	AR_R0 = mod(s, 256)
	AR_R1 = mod(floor(s / 256), 256)
	AR_R2 = mod(floor(s / 65536), 256)
	AR_R3 = 0
end

-- the next k numbers (0..32767) of the generator, the state left as it is
ar_rng_peek = function(k)
	local list = { }
	local b0, b1, b2, b3 = AR_R0, AR_R1, AR_R2, AR_R3
	local i = 1
	while i <= k do
		b0, b1, b2, b3 = ar_rng_step(b0, b1, b2, b3)
		list[i] = ar_rng_out(b2, b3)
		i = i + 1
	end
	return list
end

-- the generator and its shadow brought to a known state (5, as at boot)
ar_rng_resync = function()
	AR_RNG_OLDSEED(5)
	ar_rng_seed(5)
	AR_RNG_BAD = 0
	AR_RNG_N = 0
end

if not AR_RNG_HOOKED then
	AR_RNG_HOOKED = TRUE
	AR_RNG_OLD = random
	AR_RNG_OLDSEED = randomseed
	random = function(a)
		AR_R0, AR_R1, AR_R2, AR_R3 = ar_rng_step(AR_R0, AR_R1, AR_R2, AR_R3)
		local x = ar_rng_out(AR_R2, AR_R3)
		local r
		if a == nil then
			r = AR_RNG_OLD()
		else
			r = AR_RNG_OLD(a)
		end
		AR_RNG_N = AR_RNG_N + 1
		if abs(r - ar_rng_value(x, a)) > 0.0001 then
			AR_RNG_BAD = AR_RNG_BAD + 1
			if AR_RNG_BAD <= 5 then
				ar_log("RNG shadow differs at draw " .. AR_RNG_N .. ": engine " .. tostring(r) .. ", shadow " .. tostring(ar_rng_value(x, a)))
			end
		end
		if AR_RNG_TRACE then
			ar_log("RNG " .. AR_RNG_N .. " " .. x)
		end
		return r
	end
	randomseed = function(s)
		AR_RNG_OLDSEED(s)
		ar_rng_seed(s)
	end
end
-- (every time this file is run: after a save is loaded it is run again, with the limbs of the save and the state of rand of the game as it was)
ar_rng_resync()

-- Every chapter starts from the same state of the generator (5, as at boot): a change of timing in one chapter no longer changes the random events of all the chapters
-- after it (idles, the picks of the sounds, Meche's, Toto's walks), which made every comparison of two runs carry the noise of the chapters that came later. Hooked once.
if not AR_RNG_CHAPTER_HOOKED and ar_frame_chapter then
	AR_RNG_CHAPTER_HOOKED = TRUE
	AR_RNG_FRAME_CHAPTER = ar_frame_chapter
	ar_frame_chapter = function(name)
		AR_RNG_FRAME_CHAPTER(name)
		ar_rng_resync()
	end
end
