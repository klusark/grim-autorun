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
