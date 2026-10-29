-- Chapter 45: the vault door. The chisel drills into the door jam (the safe busts open its jam), then
-- the wheel is turned until the four tumblers stand in line, the scythe is wedged into them and the
-- handle opens the door on the outer vault. Checkpoint in slot 61.

-- The vault safe (vd.lua): four tumblers behind a wheel. Tumbler 1 turns with the wheel, tumbler k+1 is
-- picked up when tumbler k passes its lock value (its own angle + pin as it stood when the wheel last
-- changed direction) and then turns with the others. A change of direction drops tumblers 2-4 where they
-- are. All four have to stand within 248..290 degrees. So the tumblers are put in place from the last
-- to the first: the chain up to tumbler k is picked up, turned until tumbler k stands in the middle of
-- the window, then the direction changes and the next shorter chain is turned. The wheel is turned with
-- the real keys: held until the tumbler is near, then single taps (a tap is 5 degrees).

AR_WLO = 248
AR_WHI = 290
AR_WMID_LO = 261
AR_WMID_HI = 277

safe_pos = function(x)
	x = mod(x, 360)
	if x < 0 then
		x = x + 360
	end
	return x
end

safe_in = function(r, lo, hi)
	return r >= lo and r <= hi
end

-- steps of direction d (+1 right, -1 left) until the angle is in lo..hi
safe_steps = function(r, d, lo, hi)
	if safe_in(r, lo, hi) then
		return 0
	end
	if d > 0 then
		return safe_pos(lo - r)
	end
	return safe_pos(r - hi)
end

safe_collides = function(k, d, n)
	if k >= 4 then
		return nil
	end
	local T = vd.safe_door.tumblers
	local lv = safe_pos(T[k + 1].rot + T[k + 1].lock_pin)
	local delta = safe_pos((lv - T[k].rot) * d)
	return delta >= 1 and delta <= n
end

safe_key = function(d)
	if d > 0 then
		return "TURN_RIGHT"
	end
	return "TURN_LEFT"
end

safe_tap = function(d)
	ar_key_down(safe_key(d))
	break_here()
	ar_key_up(safe_key(d))
	ar_wait_for_control()
end

-- puts tumbler k in the middle of the window; returns TRUE when it stands there and the later
-- tumblers have not been moved
safe_place = function(k, lastdir)
	local T = vd.safe_door.tumblers
	local r = T[k].rot
	if safe_in(r, AR_WMID_LO, AR_WMID_HI) and not T[k].lock then
		return TRUE, lastdir
	end
	local dr = safe_steps(r, 1, AR_WMID_LO, AR_WMID_HI)
	local dl = safe_steps(r, -1, AR_WMID_LO, AR_WMID_HI)
	local cr = safe_collides(k, 1, dr + 20)
	local cl = safe_collides(k, -1, dl + 20)
	local d = 1
	if not cr and (cl or dr <= dl) then
		d = 1
	elseif not cl then
		d = -1
	end
	ar_log("safe: tumbler " .. k .. " at " .. r .. " goes " .. d .. " (" .. dr .. "/" .. dl .. " steps, hits next " .. tostring(cr) .. "/" .. tostring(cl) .. ")")
	-- the session must start with a change of direction, which drops the tumblers of the last one
	if d == lastdir then
		safe_tap(-d)
	end
	-- (a stale lock of tumbler k+1 means the last session left it picked up)
	local frames = 0
	local done = nil
	while not done and frames < 6000 do
		local rk = T[k].rot
		local engaged = (k == 1) or T[k].lock
		local n = safe_steps(rk, d, AR_WMID_LO, AR_WMID_HI)
		if engaged and n == 0 then
			done = TRUE
		elseif engaged and n <= 60 then
			safe_tap(d)
		else
			ar_key_down(safe_key(d))
			break_here()
			ar_key_up(safe_key(d))
			ar_wait_for_control()
		end
		if k < 4 and T[k + 1].lock then
			-- picked up: not wanted
			ar_log("safe: tumbler " .. (k + 1) .. " was picked up by mistake")
			return nil, d
		end
		frames = frames + 1
	end
	return done, d
end

-- cracks the safe from the wheel (the handler vd.buttonHandler is on); returns TRUE when all stand in the
-- window
ar_crack_safe = function()
	local T = vd.safe_door.tumblers
	local lastdir = 0
	local k = 4
	local fails = 0
	while k >= 1 and fails < 30 do
		local ok, d = safe_place(k, lastdir)
		lastdir = d
		if ok then
			k = k - 1
		else
			fails = fails + 1
		end
	end
	local i = 1
	local all = TRUE
	while i <= 4 do
		if not safe_in(T[i].rot, AR_WLO, AR_WHI) then
			all = nil
		end
		i = i + 1
	end
	ar_log("safe: tumblers at " .. T[1].rot .. " " .. T[2].rot .. " " .. T[3].rot .. " " .. T[4].rot .. " aligned=" .. tostring(vd.tumblers.alligned))
	return all
end

ar_load(44)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(dr.ar_door, ar)
ar_go(ar.vd_door, vd)
ar_wait_for_control()
ar_do("use", vd.door_jam, mn.chisel)
ar_wait_for(function() return vd.door_busted end, 300000)
ar_wait_for_control()
ar_check(vd.door_busted, "the door jam is drilled")
ar_do("use", vd.wheel)
ar_wait_for(function() return system.buttonHandler == vd.buttonHandler end, 60000)
ar_check(system.buttonHandler == vd.buttonHandler, "Manny holds the wheel")
ar_crack_safe()
ar_check(vd.tumblers.alligned, "the tumblers are in line")
-- off the wheel, the scythe into the tumblers, and the handle
ar_key_down("MOVE_BACKWARD")
break_here()
ar_key_up("MOVE_BACKWARD")
ar_wait_for(function() return system.buttonHandler == SampleButtonHandler end, 60000)
ar_wait_for_control()
ar_do("use", vd.tumblers, mo.scythe)
ar_wait_for(function() return vd.tumblers.secured end, 60000)
ar_wait_for_control()
ar_check(vd.tumblers.secured, "the scythe holds the tumblers")
ar_do("use", vd.handle)
ar_wait_for(function() return vd.door_open end, 300000)
ar_wait_for_control()
ar_check(vd.door_open, "the vault door is open")
ar_state("end of chapter 45")
ar_checkpoint(45)
