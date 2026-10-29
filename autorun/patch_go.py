import re
branch = '''	if AR_ORIGINAL and door.use_pnt_x then
		-- the original searches its walk boxes for a path and takes minutes when the target is outside them
		-- (the out point of a door often is): walk to the use point, as a click on the door does, and use it
		if AR_NEW and manny.is_holding and not AR_KEEP_HELD then
			ar_put_away()
		end
		AR_START_SET_GO = system.currentSet
		AR_SEEN_TARGET = nil
		ar_walk_to(door.use_pnt_x, door.use_pnt_y, door.use_pnt_z, ar_target_reached)
		ar_wait_for_control()
		if not ar_target_reached() then
			ar_do("use", door)
			ar_wait_for(ar_target_reached, 15000)
		end
		ar_wait_for_control()
		return ar_check(ar_target_reached(), "reached " .. tostring(target.name))
	end
'''
for f in ('ar_lib.lua', 'ar_lib_legacy.lua'):
    s = open(f).read()
    key = '\tar_log("go: " .. ar_set_name() .. " -> " .. tostring(target.name))\n'
    assert s.count(key) == 1, f
    if 'AR_ORIGINAL and door.use_pnt_x' not in s:
        s = s.replace(key, key + branch)
        open(f, 'w', newline='\n').write(s)
print('done')
