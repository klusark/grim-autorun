-- Act 2 chapter 19: Knuttin's rock field: the parrot whistle calls the parrots, the weak grog makes one drunk, "Two plus two?" tells which one
-- is the liar; the other is asked at every rock whether the bronze hat is under it
ar_load(218)
ar_log("=== ACT2 ch19 parrots ===")
ar_wait_for_control()
ar_put_away()
-- into the rock field
ar_walk_to(45, 3.43, 30)
sleep_for(3000)
ar_wait_for_control()
ar_check(kab.current_loc, "in the rock field")
a2_use_held(props.whistle)
ar_put_away()
-- the left-hand parrot gets the grog (any one of them)
ar_do("use", kab.huggin_obj, props.lamegrog)
ar_wait_for_control()
ar_put_away()
ar_check(huggin.drunk, "one parrot is drunk")
ar_talk(kab.huggin_obj)
ar_dlg("pr1")
a2_ready("pr1", 3000)
a2_pick_any("pr1", { 70 })
a2_leave("pr1")
ar_check(kab.parrot_tagged, "the parrots can be told apart")
-- the truthful parrot, from its answer to "Two plus two?" (Four = truth)
a2_truthful = function()
	if huggin.liar then
		return kab.kissin_obj
	end
	return kab.huggin_obj
end
-- the cell door objects by column
a2_kab_east = function(x) if x == 1 then return kab.east_1 elseif x == 2 then return kab.east else return kab.east_2 end end
a2_kab_ns = function(x, up) if up then if x == 1 then return kab.ns_1 else return kab.ns_2 end else if x == 2 then return kab.ns_1 else return kab.ns_2 end end end
a2_kab_ask = function()
	-- the parrots at this rock (the whistle calls them)
	if not glob.kab_parrot_loc or glob.kab_parrot_loc.x ~= kab.current_loc.x or glob.kab_parrot_loc.y ~= kab.current_loc.y then
		a2_use_held(props.whistle)
		ar_put_away()
	end
	ar_talk(a2_truthful())
	ar_dlg("pr1")
	a2_ready("pr1", 3000)
	local k = a2_pick_any("pr1", { 90 })
	a2_ready("pr1", 2500)
	a2_leave("pr1")
	ar_wait_for_control()
	return glob.kab_found_hat
end
-- the cells of the field are places of ONE set: the door's wait for a new set ends when the cell has changed (it waited 20 s a step)
AR_DOOR_STAYS = function()
	return cutSceneLevel == 0 and kab.current_loc and (kab.current_loc.x ~= A2_KAB_X or kab.current_loc.y ~= A2_KAB_Y)
end
a2_kab_do = function(door)
	A2_KAB_X = kab.current_loc.x
	A2_KAB_Y = kab.current_loc.y
	ar_do("use", door)
end
local tries = 0
local dirx = 0
-- the field is entered in the middle of its first row: that row is done first in full (west end, back through the middle to the east end),
-- then the rows above are done in a serpentine from the east end (the hat of a run can be under any of the 36 rocks)
a2_kab_step = function(door)
	a2_kab_do(door)
	ar_wait_for_control()
	sleep_for(1500)
end
-- The cell of the hat is in the state of the game (glob.kab_hat_loc): the way there is walked at once and the truthful parrot is asked at that
-- rock; the search below is only the fallback (when the state is not there, or the answer there was not the hat)
a2_kab_goto = function(tx, ty)
	local guard = 0
	while kab.current_loc.y < ty and guard < 12 do
		guard = guard + 1
		a2_kab_step(a2_kab_east(kab.current_loc.x))
	end
	while kab.current_loc.x ~= tx and guard < 24 do
		guard = guard + 1
		a2_kab_step(a2_kab_ns(kab.current_loc.x, kab.current_loc.x < tx))
	end
end
if glob.kab_hat_loc and glob.kab_hat_loc.x then
	ar_log("the hat is in cell " .. glob.kab_hat_loc.x .. "," .. glob.kab_hat_loc.y)
	a2_kab_goto(glob.kab_hat_loc.x, glob.kab_hat_loc.y)
	ar_log("cell " .. kab.current_loc.x .. "," .. kab.current_loc.y)
	a2_kab_ask()
end
if not glob.kab_found_hat and kab.current_loc.x == 2 and kab.current_loc.y == 1 then
	ar_log("cell 2,1")
	if not a2_kab_ask() then
		a2_kab_step(a2_kab_ns(2, false))
		ar_log("cell " .. kab.current_loc.x .. "," .. kab.current_loc.y)
		if not a2_kab_ask() then
			a2_kab_step(a2_kab_ns(1, true))
			a2_kab_step(a2_kab_ns(2, true))
			ar_log("cell " .. kab.current_loc.x .. "," .. kab.current_loc.y)
			if not a2_kab_ask() then
				a2_kab_step(a2_kab_east(3))
				dirx = -1
			end
		end
	end
end
while not glob.kab_found_hat and tries < 60 do
	local x = kab.current_loc.x
	local y = kab.current_loc.y
	ar_log("cell " .. x .. "," .. y)
	if not a2_kab_ask() then
	-- the next cell: the serpentine through the columns, one column further east when a row is done
	x = kab.current_loc.x
	y = kab.current_loc.y
	if dirx == 0 then
		-- the first row starts in the middle: first to column 1, then back through 2 to 3
		dirx = -1
	end
	local nx = x + dirx
	if nx < 1 or nx > 3 then
		a2_kab_do(a2_kab_east(x))
		dirx = -dirx
	else
		a2_kab_do(a2_kab_ns(x, dirx > 0))
	end
	ar_wait_for_control()
	sleep_for(1500)
	if kab.current_loc.x == x and kab.current_loc.y == y then
		-- (the door sector itself: east is at the north edge of the column)
		ar_log("the step did not change the cell, walking into the door sector")
		if nx < 1 or nx > 3 then
			local ex = 33
			if x == 2 then ex = 38.3 elseif x == 3 then ex = 41.0 end
			ar_walk_to(ex, 3.43, 14.8)
		end
		sleep_for(2000)
		ar_wait_for_control()
		if kab.current_loc.x == x and kab.current_loc.y == y then
			tries = tries + 10
		end
	end
	end
	tries = tries + 1
end
ar_log("found hat: " .. tostring(glob.kab_found_hat) .. " at " .. tostring(glob.kab_hat_loc.x) .. "," .. tostring(glob.kab_hat_loc.y))
ar_check(glob.kab_found_hat, "the rock with the bronze hat")
AR_DOOR_STAYS = nil
ar_state("end")
ar_checkpoint(219)
