-- puts Manny where the walk that killed the autorun started, and repeats it with the functions it calls wrapped to log their entry
AR_ENTERED = ""
ar_wrap = function(name)
	local orig = getglobal(name)
	setglobal(name, function(...)
		AR_ENTERED = %name
		return call(%orig, arg)
	end)
end
ar_wrap("ar_nav_smooth")
ar_wrap("ar_nav_narrow")
ar_wrap("ar_walk_path")
ar_wrap("ar_nav_hot_list")
ar_wrap("ar_nav_in_all")
ar_wrap("ar_nav_unstick")
ar_wrap("ar_wiggle")
ar_wrap("ar_nav_clear")
ar_wrap("ar_nav_near_hot")
ar_wrap("ar_nav_path")
ar_wrap("ar_nav_walk")
ar_wrap("ar_steer")
ar_wrap("ar_nav_find_z")
ar_wrap("ar_nav_inside")
local z = manny:getpos().z
manny:setpos(0.10, -2.50, z)
sleep_for(300)
PrintDebug("ORL start at " .. tostring(manny:getpos().x) .. " " .. tostring(manny:getpos().y) .. "\n")
AR_ENTERED = "none"
local r = call(ar_walk_to, { 0.45, -2.6, -0.1 }, "x")
PrintDebug("ORL walk returned " .. tostring(r) .. " last entered " .. AR_ENTERED .. "\n")
