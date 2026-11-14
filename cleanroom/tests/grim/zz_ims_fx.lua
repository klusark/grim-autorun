-- Voices through the voice effect (ImSetVoiceEffect: iMUSE_SetVoiceEffect, the HMI effects of IMUSE.PSL, the suite's own
-- preset file, assets.PRESET_LIBRARY: one preset, cr_band_pass). With an effect set, iMUSE's read callback (ihost_read,
-- IMUSE.DLL 0x10007ca0) runs the voice (sound 10000) through it. "OFF" (any case) turns it off; a name the file does not
-- have leaves it off. The lines are zz_ims.lua's voices (imsv01, a stored MCMP block; imsv02, stored 8 KB blocks).

cr_fx_line = function(key, a, line)
	SayLine(a, line, { x = 100, y = 100 })
	cr_frames(2)
	cr_log(key .. "_going", IsMessageGoing(), CR_LV)
	cr_wait_s(1)
	cr_log(key .. "_1s", IsMessageGoing(), CR_LV)
	local f = cr_until(cr_fx_quiet, 900)
	cr_log(key .. "_ended", f, IsMessageGoing())
end

cr_fx_quiet = function()
	return not IsMessageGoing()
end

cr_t_ims_voice_fx = function()
	cr_allow_frames(1000000000)
	ims_reset()
	local a = cr_talker()
	cr_log("set", ImSetVoiceEffect("cr_band_pass"))
	cr_fx_line("fx_v01", a, "/imsv01/")
	cr_fx_line("fx_v02", a, "/imsv02/")
	cr_log("off", ImSetVoiceEffect("OFF"))
	cr_fx_line("plain_v01", a, "/imsv01/")
end
cr_test("ims_voice_fx", cr_t_ims_voice_fx)

-- the name's case; a name the preset file does not have; "off" in lower case
cr_t_ims_voice_fx_names = function()
	cr_allow_frames(1000000000)
	ims_reset()
	local a = cr_talker()
	cr_log("upper", ImSetVoiceEffect("CR_BAND_PASS"))
	cr_fx_line("upper", a, "/imsv01/")
	cr_log("unknown", ImSetVoiceEffect("no_such_effect"))
	cr_fx_line("unknown", a, "/imsv01/")
	cr_log("lower_off", ImSetVoiceEffect("off"))
	cr_log("empty", ImSetVoiceEffect(""))
	cr_log("again_off", ImSetVoiceEffect("OFF"))
end
cr_test("ims_voice_fx_names", cr_t_ims_voice_fx_names)

-- the effect switched while the line plays, and the line cut short with the effect on
cr_t_ims_voice_fx_switch = function()
	cr_allow_frames(1000000000)
	ims_reset()
	local a = cr_talker()
	SayLine(a, "/imsv02/", { x = 100, y = 100 })
	cr_frames(10)
	cr_log("on_mid_line", ImSetVoiceEffect("cr_band_pass"))
	cr_frames(30)
	cr_log("going", IsMessageGoing())
	ShutUpActor(a)
	cr_frames(2)
	cr_log("shut_up", IsMessageGoing())
	SayLine(a, "/imsv01/", { x = 100, y = 100 })
	cr_frames(20)
	cr_log("off_mid_line", ImSetVoiceEffect("OFF"))
	local f = cr_until(cr_fx_quiet, 900)
	cr_log("ended", f, IsMessageGoing())
end
cr_test("ims_voice_fx_switch", cr_t_ims_voice_fx_switch)
