ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
probe_wait = function(n)
	local k = 0
	while k < n do
		k = k + 1
		break_here()
	end
end
ar_nt_place({ id = "mo", set = "mo" })
probe_wait(30)
ImStartSound("keyboard.imu!", 127, 1)
probe_wait(10)
ar_log("CSND after bang start: plain count " .. ImGetParam("keyboard.imu", IM_SOUND_PLAY_COUNT) .. " vol " .. ImGetParam("keyboard.imu", IM_SOUND_VOL) .. " pan " .. ImGetParam("keyboard.imu", IM_SOUND_PAN))
ar_log("CSND after bang start: bang pan " .. ImGetParam("keyboard.imu!", IM_SOUND_PAN) .. " group " .. ImGetParam("keyboard.imu!", IM_SOUND_GROUP) .. " prio " .. ImGetParam("keyboard.imu!", IM_SOUND_PRIORITY))
ar_log("CSND bang count " .. ImGetParam("keyboard.imu!", IM_SOUND_PLAY_COUNT) .. " vol " .. ImGetParam("keyboard.imu!", IM_SOUND_VOL))
ImStopSound("keyboard.imu!")
ImStartSound("keyboard.imu", 127, 1)
probe_wait(10)
ar_log("CSND plain count " .. ImGetParam("keyboard.imu", IM_SOUND_PLAY_COUNT) .. " vol " .. ImGetParam("keyboard.imu", IM_SOUND_VOL))
ImStopSound("keyboard.imu")
AR_KEEP_GOING = nil
ar_finish()
