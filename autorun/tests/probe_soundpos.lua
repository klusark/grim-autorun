-- Probe (the values are logged as "SNDPOS <case> vol pan"; run on either engine, tools/golden_soundpos.sh compares them): the volume and the pan that
-- SetSoundPosition gives a playing sound at places around the camera, with several volume ranges and falloff distances, and after a change of the setup
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
snd = "dpCreak.imu"
ImStartSound(snd, 127, 1)
probe_wait(10)
probe_at = function(tag, x, y, z, a, b, c)
	if c then
		SetSoundPosition(snd, x, y, z, a, b, c)
	elseif b then
		SetSoundPosition(snd, x, y, z, a, b)
	elseif a then
		SetSoundPosition(snd, x, y, z, a)
	else
		SetSoundPosition(snd, x, y, z)
	end
	ar_log("SNDPOS " .. tag .. " vol " .. ImGetParam(snd, IM_SOUND_VOL) .. " pan " .. ImGetParam(snd, IM_SOUND_PAN))
end
xs = { -4, -1.5, 0, 0.7, 2, 5 }
ys = { -4, -1, 0.3, 2, 6 }
zs = { 0, 1.5 }
xi = 1
while xs[xi] do
	yi = 1
	while ys[yi] do
		zi = 1
		while zs[zi] do
			tag = "d" .. xi .. yi .. zi
			probe_at(tag, xs[xi], ys[yi], zs[zi])
			zi = zi + 1
		end
		yi = yi + 1
	end
	xi = xi + 1
end
ranges = { { 0, 127 }, { 50, 100 }, { 200, 300 }, { -5, 50 }, { 30, 20 }, { 10, 90 } }
ri = 1
while ranges[ri] do
	probe_at("r" .. ri .. "a", 1, -2, 0.5, ranges[ri][1], ranges[ri][2])
	probe_at("r" .. ri .. "b", 6, 5, 0.5, ranges[ri][1], ranges[ri][2])
	probe_at("r" .. ri .. "c", -3, 12, 0.5, ranges[ri][1], ranges[ri][2])
	ri = ri + 1
end
scs = { 0.5, 2, 4, 20, 40 }
si = 1
while scs[si] do
	probe_at("s" .. si .. "a", 1, -2, 0.5, 20, 127, scs[si])
	probe_at("s" .. si .. "b", 5, 4, 0.5, 20, 127, scs[si])
	si = si + 1
end
probe_at("setup0", 2, -3, 0.5, 20, 127)
n = 1
while n <= 3 do
	system.currentSet:current_setup(n)
	probe_wait(10)
	ar_log("SNDPOS setup" .. n .. " vol " .. ImGetParam(snd, IM_SOUND_VOL) .. " pan " .. ImGetParam(snd, IM_SOUND_PAN))
	n = n + 1
end
ImStopSound(snd)
AR_KEEP_GOING = nil
ar_finish()
