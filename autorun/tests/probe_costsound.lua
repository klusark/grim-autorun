-- Probe (logged as "CSND <case> vol pan"): the volume and pan of a sound that a costume chore starts (the keyboard of ma_note_type.cos) with Manny at several
-- places of mo in the setup 2: whether the original puts such a sound in space
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
probe_wait(40)
mo:current_setup(2)
probe_wait(10)
manny:ignore_boxes()
manny:push_costume("ma_note_type.cos")
places = { { 0.45, 1.875 }, { 0.45, -1 }, { -1.5, 1.875 }, { 2.5, 3 }, { 0.45, 6 } }
i = 1
while places[i] do
	manny:setpos(places[i][1], places[i][2], 0)
	manny:setrot(0, 87.75, 0)
	manny:play_chore(ma_note_type_to_type, "ma_note_type.cos")
	manny:wait_for_chore()
	manny:play_chore(ma_note_type_type_loop, "ma_note_type.cos")
	probe_wait(20)
	ar_log("CSND p" .. i .. " plain " .. ImGetParam("keyboard.imu", IM_SOUND_PLAY_COUNT) .. " vol " .. ImGetParam("keyboard.imu", IM_SOUND_VOL) .. " pan " .. ImGetParam("keyboard.imu", IM_SOUND_PAN) .. " | bang " .. ImGetParam("keyboard.imu!", IM_SOUND_PLAY_COUNT) .. " vol " .. ImGetParam("keyboard.imu!", IM_SOUND_VOL) .. " pan " .. ImGetParam("keyboard.imu!", IM_SOUND_PAN))
	j = 0
	while j < 8 do
		probe_wait(8)
		ar_log("CSND p" .. i .. " t" .. j .. " plain count " .. ImGetParam("keyboard.imu", IM_SOUND_PLAY_COUNT))
		j = j + 1
	end
	manny:stop_chore(ma_note_type_type_loop, "ma_note_type.cos")
	ImStopSound("keyboard.imu")
	ImStopSound("keyboard.imu!")
	probe_wait(10)
	i = i + 1
end
AR_KEEP_GOING = nil
ar_finish()
