-- Logging for the investigation of me_gun.wav (SNDLOG lines): every start and stop of any sound named me_gun, the handle
-- the start returns, and, whenever it changes, the play count by name and by handle (the original takes a handle in
-- ImGetParam; ScummVM returns the name as the handle, so there each count is the count by name).
SL_H = {}
SL_N = 0
SL_LAST = ""
SL_is_gun = function(name)
	return type(name) == "string" and strfind(strlower(name), "me_gun", 1, 1)
end
SL_install = function()
	if SL_ORIG_START then
		return
	end
	SL_ORIG_START = ImStartSound
	SL_ORIG_STOP = ImStopSound
	ImStartSound = function(a1, a2, a3)
		local h = SL_ORIG_START(a1, a2, a3)
		if SL_is_gun(a1) then
			SL_N = SL_N + 1
			SL_H[SL_N] = h
			PrintDebug("SNDLOG start #" .. SL_N .. " " .. a1 .. " prio " .. tostring(a2) .. " group " .. tostring(a3) .. " handle " .. tostring(h) .. " count " .. tostring(ImGetParam(a1, IM_SOUND_PLAY_COUNT)))
		end
		return h
	end
	ImStopSound = function(a1)
		if SL_is_gun(a1) then
			PrintDebug("SNDLOG stop " .. a1 .. " count before " .. tostring(ImGetParam(a1, IM_SOUND_PLAY_COUNT)))
		end
		return SL_ORIG_STOP(a1)
	end
	start_script(SL_logger)
end
SL_logger = function()
	while TRUE do
		local s = tostring(ImGetParam("me_gun.wav", IM_SOUND_PLAY_COUNT)) .. " (prio query " .. tostring(ImGetParam("me_gun.wav", IM_SOUND_PRIORITY)) .. ")"
		local i = 1
		while i <= SL_N do
			s = s .. " #" .. i .. "=" .. tostring(ImGetParam(SL_H[i], IM_SOUND_PLAY_COUNT))
			i = i + 1
		end
		if s ~= SL_LAST then
			PrintDebug("SNDLOG state by name " .. s)
			SL_LAST = s
		end
		break_here()
	end
end
-- Chapter 64 (Year 4): the meadow. Salvador's suitcase lets the ticket hop out, Manny plucks it from the flowers
-- and carries it behind the greenhouse, where it vibrates near Salvador's body and flies to it: the body
-- is searched for the trunk key, the key opens the trunk of the car and the gun in it is for the tanks of
-- the water tower, which bury Hector (puzzle state 60). Checkpoint in slot 80.

AR_NEW = TRUE
AR_CONTROL_TIMEOUT = 600000
ar_load(64)
SL_install()
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_do("use", me.suitcase)
ar_wait_for(function() return me.ticket_free end, 120000)
sleep_for(3000)
ar_wait_for_control()
ar_check(me.ticket_free, "the ticket hopped out of the suitcase")
ar_do("pickUp", me.salvador_obj)
ar_wait_for(function() return me.plucked_ticket end, 60000)
sleep_for(2000)
ar_wait_for_control()
ar_check(me.ticket.owner == manny, "Manny holds the ticket")
-- behind the greenhouse: the ticket flies to the body when Manny is close and faces it (a cutscene on the way)
ar_walk_to(-0.69, 2.3, -0.48)
-- (the ticket flies when Manny faces the body)
ar_face(me.sals_body)
sleep_for(2000)
ar_wait_for_control()
ar_check(me.sals_body.touchable, "the ticket found Salvador's body")
ar_do("use", me.sals_body)
ar_wait_for(function() return me.key.owner == manny end, 120000)
sleep_for(2000)
ar_wait_for_control()
ar_check(me.key.owner == manny, "Manny has the trunk key")
ar_walk_to(17.0, -19.55, -7.85)
sleep_for(1000)
ar_do("use", me.car, me.key)
ar_wait_for(function() return me.gun.owner == manny end, 120000)
sleep_for(3000)
ar_wait_for_control()
ar_check(me.gun.owner == manny, "Manny has the gun")
local t = me.tanks
ar_walk_to(t.use_pnt_x, t.use_pnt_y, t.use_pnt_z)
ar_do("use", t, me.gun)
-- (the cutscene waits for the four overlapping shots of me_gun.wav to end; nothing here ends them for it)
ar_wait_for(function() return cur_puzzle_state[60] end, 120000)
sleep_for(3000)
ar_wait_for_control()
ar_check(cur_puzzle_state[60], "the water tower comes down on Hector (puzzle state 60)")
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 64")
ar_checkpoint(65)
