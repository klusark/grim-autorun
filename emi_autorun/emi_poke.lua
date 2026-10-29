-- The poker: an adventure game bot for exploring a set. It looks at, picks up, talks to and uses everything the set offers and every
-- inventory item on every object, until a whole pass changes nothing (inventory, the game's flags, the set); then the doors. What it
-- changes goes to the log (POKE lines), the chapter that solves the room is written by hand from them. EMI-only (Lua 3.1: no closures).

AR_POKE_SEEN = AR_POKE_SEEN or { }

-- A string that changes when the game moves on: the inventory and every flag of glob that is true
ar_poke_state = function()
	local s = ar_set_name() .. "|" .. ar_inventory() .. "|"
	local k, v = next(glob, nil)
	local n = 0
	while k do
		if v and type(v) ~= "table" and type(v) ~= "function" then
			s = s .. tostring(k) .. "=" .. tostring(v) .. ","
		end
		k, v = next(glob, k)
	end
	return s
end

-- the objects of the set worth trying: touchable, with a name, not a door, not the actor of a person we cannot reach
-- (AR_POKE_SKIP: substrings of names of objects the poker leaves alone, e.g. the bank window that leaves the bank)
ar_poke_skipped = function(v)
	local i = 1
	while AR_POKE_SKIP and AR_POKE_SKIP[i] do
		if strfind(tostring(v.name), AR_POKE_SKIP[i], 1, 1) then
			return TRUE
		end
		i = i + 1
	end
	return nil
end

ar_poke_objects = function()
	local list = { }
	local n = 0
	local s = system.currentSet
	local k, v = next(s, nil)
	while k do
		if type(v) == "table" and v.interest_actor and v.name and v.touchable and not v.walkOut and not v.doorAct and (v.range or 0) > 0 and not ar_poke_skipped(v) then
			-- (an object that appears under two names in the set is tried once)
			local dup = nil
			local i = 1
			while i <= n do
				if list[i] == v then
					dup = TRUE
				end
				i = i + 1
			end
			if not dup then
				n = n + 1
				list[n] = v
			end
		end
		k, v = next(s, k)
	end
	return list, n
end

ar_poke_doors = function()
	local list = { }
	local n = 0
	local s = system.currentSet
	local k, v = next(s, nil)
	while k do
		if type(v) == "table" and v.interest_actor and v.walkOut and v.name then
			local dup = nil
			local i = 1
			while i <= n do
				if list[i] == v or list[i].name == v.name then
					dup = TRUE
				end
				i = i + 1
			end
			if not dup then
				n = n + 1
				list[n] = v
			end
		end
		k, v = next(s, k)
	end
	return list, n
end

ar_poke_inventory = function()
	local list = { }
	local n = 0
	local item = next(Inventory.unordered_inventory_table, nil)
	while item do
		if item.owner == manny then
			n = n + 1
			list[n] = item
		end
		item = next(Inventory.unordered_inventory_table, item)
	end
	return list, n
end

-- one try: log what it changed
ar_poke_try = function(verb, obj, item)
	local before = ar_poke_state()
	local startset = system.currentSet
	AR_FAILED = FALSE
	AR_KEEP_GOING = TRUE
	local label = verb .. " " .. tostring(obj.name)
	if item then
		label = label .. " WITH " .. tostring(item.name)
	end
	ar_log("POKE try " .. label)
	AR_POKE_TALKED = (verb == "talk")
	if verb == "talk" then
		ar_talk(obj)
		ar_dlg_idle_wait()
	else
		ar_do(verb, obj, item)
	end
	ar_wait_for_control()
	AR_FAILED = FALSE
	local after = ar_poke_state()
	if after ~= before then
		ar_log("POKE CHANGED by " .. label .. ": " .. ar_poke_diff(before, after))
		return TRUE
	end
	return nil
end

-- what is new in b against a (inventory and flags), short
ar_poke_diff = function(a, b)
	local out = ""
	local i = 1
	local bs = b .. ","
	-- the flag entries of b that a does not hold
	local pos = 1
	while pos <= strlen(bs) do
		local e = strfind(bs, ",", pos, TRUE)
		if not e then
			pos = strlen(bs) + 1
		else
			local part = strsub(bs, pos, e - 1)
			if part ~= "" and not strfind(a, part, 1, TRUE) then
				out = out .. part .. "; "
			end
			pos = e + 1
		end
	end
	return out
end

-- A conversation, whoever started it (a talk, or a use that talks): asks everything and leaves. A task of its own, so that the verb that
-- started it (which runs until the conversation is over) can wait for it.
ar_poke_run_dialog = function(d)
	local guard = 0
	local last = nil
	local same = 0
	while d.running and guard < 60 and same < 3 do
		ar_dialog_ready(d, 20000)
		local best = nil
		local used = AR_POKE_USED[d] or { }
		AR_POKE_USED[d] = used
		local kk, vv = next(d, nil)
		while kk do
			if type(kk) == "number" and type(vv) == "table" and vv.text and vv[d.node] and not vv.off and (used[kk] or 0) < 2 and (not best or kk < best) then
				best = kk
			end
			kk, vv = next(d, kk)
		end
		if not best then
			ar_pick_exit(d)
			guard = 999
		else
			used[best] = (used[best] or 0) + 1
			-- (a conversation that offers the same line again and again is left)
			if best == last then
				same = same + 1
			else
				same = 0
			end
			last = best
			ar_pick(d, best)
			sleep_for(600)
		end
		guard = guard + 1
	end
	if d.running then
		ar_pick_exit(d)
	end
	AR_POKE_USED = { }
end
AR_POKE_USED = { }

ar_poke_dialog_watch = function()
	while TRUE do
		local d = system.buttonHandler
		if type(d) == "table" and d.running and d.node then
			ar_poke_run_dialog(d)
		end
		sleep_for(200)
	end
end

ar_in_dialog = function()
	local d = system.buttonHandler
	return type(d) == "table" and d.running
end

ar_dlg_idle_wait = function()
	sleep_for(1000)
	ar_wait_for(ar_not_in_dialog, 180000, "the conversation to end")
	ar_wait_for_control()
end

ar_not_in_dialog = function()
	return not ar_in_dialog()
end

ar_poke_has_code = function(o, item)
	local name = item.system_name or trim_header(tostring(item.string_name))
	local code = o[gsub("use_" .. name, " ", "_")]
	return code or o.use_anything
end

-- one pass over the set: returns true when it changed something
ar_poke_pass = function()
	local changed = nil
	local objs, no = ar_poke_objects()
	local items, ni = ar_poke_inventory()
	local startset = system.currentSet
	-- the items are looked at once (reading a letter sets what a conversation asks for)
	local li = 1
	while li <= ni do
		local key = "item|" .. tostring(items[li].name)
		if not AR_POKE_SEEN[key] then
			AR_POKE_SEEN[key] = TRUE
			local before = ar_poke_state()
			ar_log("POKE try look at the item " .. tostring(items[li].name))
			ar_look_item(items[li])
			local after = ar_poke_state()
			if after ~= before then
				ar_log("POKE CHANGED by looking at " .. tostring(items[li].name) .. ": " .. ar_poke_diff(before, after))
				changed = TRUE
			end
			ar_put_away()
		end
		li = li + 1
	end
	local i = 1
	while i <= no and system.currentSet == startset do
		local o = objs[i]
		if not AR_POKE_SEEN[ar_set_name() .. "|look|" .. tostring(o.name)] then
			AR_POKE_SEEN[ar_set_name() .. "|look|" .. tostring(o.name)] = TRUE
			if ar_poke_try("lookAt", o) then changed = TRUE end
		end
		if o.pickUp and o.pickUp ~= Object.pickUp and ar_poke_try("pickUp", o) then changed = TRUE end
		if o.talkTo and ar_poke_try("talk", o) then changed = TRUE end
		if o.use and o.use ~= Object.use and not o.talkTo and ar_poke_try("use", o) then changed = TRUE end
		items, ni = ar_poke_inventory()
		local j = 1
		while j <= ni and system.currentSet == startset do
			local key = ar_set_name() .. "|" .. tostring(o.name) .. "|" .. tostring(items[j].name)
			-- (only pairs the game has code for: its code is use_<item> of the object, or use_anything; the rest only answers with a
			-- default line)
			-- (a pair that changed nothing is not tried again until something else changed)
			if ar_poke_has_code(o, items[j]) and AR_POKE_SEEN[key] ~= ar_poke_state() then
				if ar_poke_try("use", o, items[j]) then
					changed = TRUE
				end
				AR_POKE_SEEN[key] = ar_poke_state()
			end
			j = j + 1
		end
		i = i + 1
	end
	return changed
end

-- the whole room: passes until nothing changes
ar_poke_room = function(max_passes)
	local p = 1
	local more = TRUE
	ar_log("POKE room " .. ar_set_name())
	AR_KEEP_GOING = TRUE
	if not AR_POKE_WATCH or not find_script(AR_POKE_WATCH) then
		AR_POKE_WATCH = start_script(ar_poke_dialog_watch)
	end
	local startset = system.currentSet
	while more and p <= (max_passes or 6) and system.currentSet == startset do
		more = ar_poke_pass()
		p = p + 1
	end
	AR_KEEP_GOING = FALSE
	if AR_POKE_WATCH then
		stop_script(AR_POKE_WATCH)
	end
	ar_close_dialogs()
	ar_log("POKE room done " .. ar_set_name() .. " inventory " .. ar_inventory())
end

-- A conversation that the last poke left open (a talk that the poker started at the end of its round) is left by the exit line of its node
ar_close_dialogs = function()
	local n = 0
	-- the conversation of a talk is not open yet when the poke returns (Guybrush is still walking up to the person): wait for it to start, or
	-- it opens later and blocks the next chapter
	if AR_POKE_TALKED then
		ar_try_wait(function() return Dialog.current_dlg and Dialog.current_dlg.running end, 6000)
		AR_POKE_TALKED = FALSE
	end
	while Dialog.current_dlg and Dialog.current_dlg.running and n < 12 do
		local d = Dialog.current_dlg
		ar_dialog_ready(d, 20000)
		if d.running then
			ar_pick_exit(d)
		end
		sleep_for(1500)
		n = n + 1
	end
	ar_wait_for_control()
end
