-- Probe: is the east edge of sector156 walkable where cf_drive.lua starts?
ar_wait_for_control()
dofile("_jumpscripts.lua")
start_script(jump_script, "275")
local t = 0
while (system.currentSet ~= cpt or cutSceneLevel > 0) and t < 600 do
	break_here()
	t = t + 1
end
ar_wait_for_control()
sleep_for(1000)
local spots = { { 4.3, -2.6 }, { 3.0, -2.6 }, { 2.5, -1.0 }, { 5.5, -6.0 }, { 6.6, -7.8 } }
local i = 1
while spots[i] do
	guybrush:setpos(spots[i][1], 3.25, spots[i][2])
	guybrush:setrot(0, 155, 0)
	sleep_for(300)
	local p = guybrush:getpos()
	local id, name = GetActorSector(guybrush.hActor, WALK)
	local hid, hname = GetActorSector(guybrush.hActor, HOT)
	local k = 0
	local lasth = "-"
	while k < 40 do
		guybrush:walk_forward()
		break_here()
		local hi, hn = GetActorSector(guybrush.hActor, HOT)
		if tostring(hn) ~= lasth then
			lasth = tostring(hn)
			local w = guybrush:getpos()
			ar_log("CFP " .. i .. " step " .. k .. " hot " .. lasth .. format(" %.3f %.3f", w.x, w.z) .. " track " .. tostring(find_script(TrackGuybrush)) .. " dd " .. tostring(doorman_disabled) .. " cd " .. tostring(cameraman_disabled) .. " in " .. tostring(doorman_in_hot_box))
		end
		k = k + 1
	end
	local q = guybrush:getpos()
	ar_log("CFP " .. i .. format(" at %.3f %.3f %.3f", p.x, p.y, p.z) .. " walk " .. tostring(name) .. " hot " .. tostring(hname) .. format(" after 40 steps %.3f %.3f %.3f", q.x, q.y, q.z))
	i = i + 1
end
