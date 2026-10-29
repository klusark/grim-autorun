-- Chapter 39: inside the Pearl sub, along the corridor to the barnacles at the back door.
-- Checkpoint in slot 55.

ar_load(38)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_walk_to(-11.45, 4.6, 2.52)
ar_wait_for_control()
local p = manny:getpos()
ar_log("pos " .. p.x .. " " .. p.y .. " in " .. ar_set_name())
local tries = 0
while system.currentSet == ps and not find_script(cut_scene.subjacked) and tries < 5 do
	ar_walk_to(-11.4, 3.4, 2.5, function() return find_script(cut_scene.subjacked) or system.currentSet ~= ps end)
	ar_wait_for_control()
	tries = tries + 1
	local q = manny:getpos()
	ar_log("try " .. tries .. " pos " .. q.x .. " " .. q.y .. " groped=" .. tostring(ps.groped))
end
ar_wait_for(function() return find_script(cut_scene.subjacked) or system.currentSet ~= ps end, 60000)
ar_wait_for(function() return system.currentSet ~= ps and cutSceneLevel == 0 end, 900000)
ar_wait_for_control()
ar_state("end of chapter 39")
ar_checkpoint(39)
