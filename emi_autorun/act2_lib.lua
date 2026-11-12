-- Act 2 helpers
AR_TIMEOUT = 60000000

-- Starts a verb whose code runs a conversation inside it (the verb returns when the conversation is over): walks up, presses the key,
-- returns at once; the caller picks the lines (ar_say) and waits for the end (ar_dlg_done). Same as ar_talk for the verb "use" etc.
a2_start = function(verb, obj)
	ar_wait_for_control()
	AR_START_SET = system.currentSet
	AR_CODE = obj[verb]
	ar_log("start: " .. verb .. " " .. tostring(obj.name))
	ar_approach(obj)
	if ar_send_verb(verb, obj, verb .. " " .. tostring(obj.name)) then
		AR_KEYS_USED = AR_KEYS_USED + 1
	end
	return TRUE
end

-- The poker must not hand the Gubernatorial Symbol to every person (Elaine takes it back); A2_POKE_SYMBOL = TRUE allows it
if ar_poke_has_code then
	A2_OLD_HAS_CODE = ar_poke_has_code
	ar_poke_has_code = function(o, item)
		if item == props.gubernatorial_symbol and not A2_POKE_SYMBOL then
			return nil
		end
		return A2_OLD_HAS_CODE(o, item)
	end
end

-- ar_do in a task of its own, for a verb that runs a conversation inside it (an item used on a person): the caller picks the lines
-- (ar_say) and then waits with a2_wait_do(). One at a time.
a2_do_task = function(verb, obj, item)
	A2_DO_DONE = nil
	ar_do(verb, obj, item)
	A2_DO_DONE = TRUE
end

a2_do_async = function(verb, obj, item)
	A2_DO_DONE = nil
	A2_DO_HANDLE = start_script(a2_do_task, verb, obj, item)
end

a2_wait_do = function(max_ms)
	ar_wait_for(function() return A2_DO_DONE end, max_ms or 120000, "the verb to end")
	ar_wait_for_control()
end

-- An inventory item used on its own (eat, drink, wear): in hand, then USE with the item as the hot object (the game's key handler
-- uses the held item on itself when it is the hot object; with nothing offered the key does nothing)
a2_use_held = function(item)
	ar_wait_for_control()
	if not ar_hold(item) then
		return ar_fail("could not take " .. tostring(item.name) .. " in hand")
	end
	ar_log("do: use held " .. tostring(item.name))
	-- (the held item is one of the entries of the game's list: the choice is moved to it with the CHANGE_HOT keys)
	if hot_object ~= item and not ar_cycle_to(item) then
		ar_log("the held " .. tostring(item.name) .. " cannot be chosen: the choice is " .. tostring(hot_object and hot_object.name))
	end
	ar_press("use")
	AR_KEYS_USED = AR_KEYS_USED + 1
	sleep_for(500)
	ar_wait_for(function() return not find_script(Sentence) end, 120000, "the item to be used")
	ar_wait_for_control()
end

-- In place of a fixed sleep in a conversation (the chapters were written with sleep_for(N) before each look at the lines): on as soon as
-- the dialog waits for a choice; the N ms only when the conversation is not running (it ended, or has not begun yet). Guybrush stood
-- through the rest of each sleep (66 s in act2_24 alone).
a2_ready = function(name, ms)
	local waited = 0
	while waited < ms + 30000 do
		local d = getglobal(name)
		if d and d.running and system.buttonHandler == d then
			return TRUE
		end
		if waited >= ms and not (d and d.running) then
			return nil
		end
		sleep_for(100)
		waited = waited + 100
	end
	return nil
end

-- Leaves a conversation: picks the exit line of the node until it has ended
a2_leave = function(name)
	local n = 0
	while getglobal(name) and getglobal(name).running and n < 8 do
		ar_lines(name)
		ar_say_exit(name)
		sleep_for(1500)
		n = n + 1
	end
	ar_dlg_done(name)
end

-- Combines two inventory items the way a player does: the inventory key opens the inventory (which pauses every running script, the
-- run's own too), so a task of its own, started by the game when the inventory has been drawn (Inventory.display is wrapped), does the
-- keys: turn to the first item, USE (it is set aside), turn to the second, USE (the game runs combine_<name>), close. The run waits.
a2_inv_turn_to = function(item)
	local n = 0
	while Inventory.ordered_inventory_table[Inventory.index] ~= item and n < 30 do
		ar_press_key(next(control_map.INVENTORY_NEXT, nil))
		sleep_for(900)
		n = n + 1
	end
	sleep_for(400)
	return Inventory.ordered_inventory_table[Inventory.index] == item
end

a2_inv_driver = function()
	local a = A2_COMB_A
	local b = A2_COMB_B
	ar_log("inventory: driver started for " .. tostring(a and a.name) .. " and " .. tostring(b and b.name))
	sleep_for(1500)
	if not a2_inv_turn_to(a) then
		ar_log("FAIL combine: could not turn to " .. tostring(a.name))
	else
		ar_press("use")
		sleep_for(2500)
		if not a2_inv_turn_to(b) then
			ar_log("FAIL combine: could not turn to " .. tostring(b.name))
		else
			ar_press("use")
			sleep_for(3000)
		end
	end
	-- (the line the combination says, and its cutscene, end before the inventory is closed: keys do nothing meanwhile. On the original
	-- the voice plays in real time while the game runs as fast as it can, and the line lasted all ten tries, 25 game seconds (Nov 11))
	ar_try_wait(function() return not (Inventory.open and (IsMessageGoing() or cutSceneLevel > 0)) end, 120000)
	local n = 0
	while Inventory.open and n < 10 do
		-- (each try logged: the run's own task is paused while the inventory is open, and an inventory that stays open is otherwise silent)
		ar_log("inventory: closing, try " .. n .. ": combine_idx " .. tostring(Inventory.combine_idx) .. " cutscene " .. tostring(cutSceneLevel) .. " message " .. tostring(IsMessageGoing()) .. " holding " .. tostring(manny.is_holding and manny.is_holding.name))
		if Inventory.combine_idx then
			ar_press("inventory")
		else
			ar_press_key(next(control_map.OVERRIDE, nil))
		end
		sleep_for(2500)
		n = n + 1
	end
	ar_log("inventory: driver done, open " .. tostring(Inventory.open))
	A2_COMB_DONE = TRUE
end

-- (a2_inv_driver is started by emi_myst.lua's wrapper of Inventory.display when A2_COMB_START is set: one wrapper for both combinations)

a2_combine = function(a, b)
	ar_wait_for_control()
	ar_put_away()
	ar_log("combine: " .. tostring(a.name) .. " with " .. tostring(b.name))
	A2_COMB_A = a
	A2_COMB_B = b
	A2_COMB_DONE = nil
	A2_COMB_START = TRUE
	ar_press("inventory")
	-- (paused while the inventory is open; this goes on when the driver has closed it)
	sleep_for(500)
	ar_wait_for(function() return A2_COMB_DONE end, 120000, "the combination")
	ar_wait_for_control()
end

-- The rowboat on a map (the actor under the player's control is the set's `control`, Guybrush rides on it): steered to a point with the
-- turn keys and the forward key, as a player does, on a way planned round the trigger strips of the places (AR_WALKER: the walk and the steering are the boat's). Returns TRUE if it arrived (the set may change on the
-- way).
a2_boat_stop = function()
	return cutSceneLevel > 0 or system.currentSet ~= A2_BOAT_SET
end

a2_boat_to = function(ctl, x, y, z, max_ms)
	local startset = system.currentSet
	local w = 0
	while cutSceneLevel > 0 and w < 60000 do
		sleep_for(200)
		w = w + 200
	end
	AR_WALKER = ctl
	AR_AVOID_HOT = TRUE
	-- (the strip of the place that is the goal is not avoided)
	local hid, hname = GetPointSector(x, y, z, HOT)
	AR_HOT_OK = hname
	local bp = ctl:getpos()
	local sid, sname = GetPointSector(bp.x, bp.y, bp.z, HOT)
	AR_HOT_START = sname
	AR_CELLC = { }
	local no_hops = AR_NO_HOPS
	AR_NO_HOPS = TRUE
	-- (a place entered, with the cutscene that comes with it, ends the way)
	A2_BOAT_SET = startset
	ar_walk_to(x, y, z, a2_boat_stop, max_ms or 120000)
	AR_NO_HOPS = no_hops
	AR_AVOID_HOT = nil
	AR_HOT_OK = nil
	AR_HOT_START = nil
	AR_CELLC = { }
	AR_WALKER = nil
	if system.currentSet ~= startset then
		return nil
	end
	local p = ctl:getpos()
	local arrived = abs(p.x - x) + abs(p.z - z) < 2
	ar_log("boat to " .. x .. " " .. z .. ": " .. tostring(arrived) .. " at " .. format("%.1f %.1f", p.x, p.z))
	return arrived
end

-- Picks the first line of the list that the dialog offers now (waiting for it to be ready); returns its number or nil
a2_pick_any = function(name, list)
	local d = ar_dlg(name)
	if not d then
		return nil
	end
	if not ar_dlg_choice(name, "a line of the list") then
		return nil
	end
	local i = 1
	while list[i] do
		if ar_offered_line(name, list[i]) then
			ar_say(name, list[i])
			return list[i]
		end
		i = i + 1
	end
	ar_lines(name)
	return nil
end

-- The plank dive: from the top of the tower walk onto the board (the board is a door sector), wait for the dive's own button handler,
-- then press the moves: 1 up, 2 down, 3 right, 4 left (a list of three), each key down and up
a2_dive_key = function(m)
	local map = control_map.MOVE_FORWARD
	if m == 2 then
		map = control_map.MOVE_BACKWARD
	elseif m == 3 then
		map = control_map.TURN_RIGHT
	elseif m == 4 then
		map = control_map.TURN_LEFT
	end
	return next(map, nil)
end

a2_dive = function(m1, m2, m3)
	-- onto the board: the keys, straight along the plank (the tower's exit sector is under his feet at the start; the way down is the
	-- other end), steered to z -8.3
	local t = 0
	while system.buttonHandler ~= pla.dive_buttonHandler2 and t < 12000 do
		if not ar_steer(-0.12, 29.78, -8.3, 8) then
			ar_step(guybrush)
		end
		break_here()
		t = t + system.frameTime
		if mod(floor(t / 1000), 2) == 0 and t - floor(t / 1000) * 1000 < 20 then
			local p = guybrush:getpos()
			ar_log("dive walk " .. format("%.2f %.2f %.2f", p.x, p.y, p.z))
		end
	end
	ar_drive_stop()
	ar_wait_for(function() return system.buttonHandler == pla.dive_buttonHandler2 end, 60000, "the dive to start")
	local moves = { m1, m2, m3 }
	local i = 1
	while moves[i] do
		local key = a2_dive_key(moves[i])
		ar_press_key(key)
		sleep_for(150)
		ar_release_key(key)
		sleep_for(500)
		i = i + 1
	end
	ar_wait_for(function() return pla.finished_diving end, 60000, "the dive to end")
end

-- ar_obj_pos of emi_lib reads the actor's own position; an actor attached to another one (the manatee on its rotator) has it in the
-- parent's frame (0,0,0): the world position is the real one, which the game's hotlist uses too
A2_OLD_OBJ_POS = A2_OLD_OBJ_POS or ar_obj_pos
ar_obj_pos = function(obj)
	local p = A2_OLD_OBJ_POS(obj)
	if obj.interest_actor and p and p.x == 0 and p.y == 0 and p.z == 0 then
		local w = obj.interest_actor:getworldpos()
		if w and w.x then
			return w
		end
	end
	if (not p or not p.x) and obj.obj_x then
		return { x = obj.obj_x, y = obj.obj_y, z = obj.obj_z }
	end
	return p
end

AR_FINE_Y = TRUE
