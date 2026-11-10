-- EMI chapter 23: the chess clock of the two chess players in Lucre town (needed for the raft in Mysts o' Tyme). Santiago (ms) is made to
-- drop the piece he holds ("Where?" lines while he holds it: glob.chess_guys_status == 1), Castaneda (sc) falls for Brittany ("Hi, Brittany"
-- while he holds his piece: status == 3, after ms told us of the crush); the two start a fight and the clock is free.
ar_load(22)
ar_log("=== EMI ch23 clock ===")
ar_wait_for_control()
ar_do("use", pop.luc_door)
ar_wait_for_control()
ar_state("luc")
ar_chess_pick = function(name, cough, line, want_status)
	-- opens the dialog, coughs, waits for the moment (the chess monitor puts the status up while the player holds a piece), asks the line
	ar_wait_for_control()
	local obj = luc.ms_obj
	if name == "sc1" then
		obj = luc.sc_obj
	end
	ar_talk(obj)
	ar_dlg(name)
	sleep_for(1500)
	local d = getglobal(name)
	ar_dialog_ready(d, 20000)
	ar_pick(d, cough)
	sleep_for(1500)
	if want_status then
		local waited = 0
		while glob.chess_guys_status ~= want_status and waited < 120000 do
			sleep_for(200)
			waited = waited + 200
		end
		ar_log("the moment: status " .. tostring(glob.chess_guys_status) .. " after " .. waited .. " ms")
	end
	ar_dialog_ready(d, 20000)
	ar_pick(d, line)
end
-- 1. Santiago drops his piece
ar_chess_pick("ms1", 10, 140, 1)
sleep_for(4000)
if getglobal("ms1") and ms1.running then
	ar_say_exit("ms1")
end
ar_dlg_done("ms1")
ar_log("status after ms: " .. tostring(glob.chess_guys_status))
ar_state("after ms")
-- 2. Castaneda looks away once (so that Santiago tells of his crush), Santiago tells it
ar_chess_pick("sc1", 10, 140, nil)
sleep_for(3000)
if getglobal("sc1") and sc1.running then
	ar_say_exit("sc1")
end
ar_dlg_done("sc1")
ar_log("sc status " .. tostring(glob.chess_guys_sc_status))
ar_chess_pick("ms1", 10, 150, nil)
sleep_for(3000)
if getglobal("ms1") and ms1.running then
	ar_say_exit("ms1")
end
ar_dlg_done("ms1")
ar_log("crush known " .. tostring(glob.know_brittany_crush) .. " sc status " .. tostring(glob.chess_guys_sc_status))
-- 3. Brittany!, while Castaneda holds his piece
a23_n = 0
while glob.chess_guys_status <= 3 and a23_n < 5 do
	a23_n = a23_n + 1
	ar_chess_pick("sc1", 10, 145, 3)
	sleep_for(8000)
	if getglobal("sc1") and sc1.running then
		ar_say_exit("sc1")
	end
	ar_dlg_done("sc1")
	ar_log("chess status " .. tostring(glob.chess_guys_status) .. " try " .. a23_n)
	ar_try_wait(function() return glob.chess_guys_status > 3 end, 20000)
end
ar_wait_for(function() return glob.chess_guys_status > 3 end, 60000, "the chess fight")
sleep_for(8000)
ar_log("clock state " .. tostring(props.clock.state) .. " touchable " .. tostring(props.clock.touchable))
local tries = 0
while props.clock.state ~= PROP_INV and tries < 4 do
	tries = tries + 1
	ar_do("pickUp", props.clock)
	sleep_for(1500)
	ar_wait_for_control()
	ar_log("clock pickup try " .. tries .. " state " .. tostring(props.clock.state))
end
ar_wait_for_control()
ar_log("clock state after " .. tostring(props.clock.state))
ar_check(props.clock.state == PROP_INV, "the chess clock in hand")
-- the duck that waddles about the town (it goes through the window at Pegnose Pete's)
local dtries = 0
while props.duck.state ~= PROP_INV and dtries < 5 do
	dtries = dtries + 1
	-- (the duck waddles on while Guybrush walks to where it was: he follows it, as a player does, until it is within reach (range 3))
	local dlegs = 0
	local dnear = function()
		local d = ar_obj_pos(props.duck)
		local g = manny:getpos()
		return d.x and sqrt((d.x - g.x) * (d.x - g.x) + (d.z - g.z) * (d.z - g.z)) < 2.4
	end
	while not dnear() and dlegs < 6 do
		dlegs = dlegs + 1
		local d = ar_obj_pos(props.duck)
		ar_log(format("duck at %.2f %.2f, following it (leg %d)", d.x, d.z, dlegs))
		ar_walk_to(d.x, d.y, d.z, dnear, 6000)
	end
	ar_do("pickUp", props.duck)
	sleep_for(1500)
	ar_wait_for_control()
	ar_log("duck pickup try " .. dtries .. " state " .. tostring(props.duck.state))
end
ar_check(props.duck.state == PROP_INV, "the duck in hand")
ar_checkpoint(23)
