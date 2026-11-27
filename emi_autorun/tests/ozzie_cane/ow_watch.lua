-- ScummVM #11817 (Ozzie walks off the screen when he goes for his new cane in the House of Sticks): logs Ozzie's walks in hos, their
-- points (OWP) and how far each strays from the straight line between its ends. Put in front of the Act 1 chapters by run_test.sh.
OW_WALK = 0
OW_WAS = nil
ow_watch = function()
	local f = 0
	local sx, sz, far
	while TRUE do
		if system.currentSet == hos and ozzie.hActor and ozzie:is_moving() then
			local p = ozzie:getpos()
			if not OW_WAS then
				OW_WALK = OW_WALK + 1
				sx = p.x
				sz = p.z
				far = 0
				OW_PTS = { }
				OW_N = 0
				ar_log("OW walk " .. OW_WALK .. " starts at " .. p.x .. " " .. p.z)
			end
			OW_WAS = TRUE
			f = f + 1
			OW_N = OW_N + 1
			OW_PTS[OW_N] = { x = p.x, z = p.z }
			if mod(f, 4) == 0 then
				ar_log("OWP " .. OW_WALK .. " " .. p.x .. " " .. p.z)
			end
		elseif OW_WAS then
			OW_WAS = nil
			local p = ozzie:getpos()
			local dx = p.x - sx
			local dz = p.z - sz
			local len = sqrt(dx * dx + dz * dz)
			local i = 1
			far = 0
			while OW_PTS[i] do
				local qx = OW_PTS[i].x - sx
				local qz = OW_PTS[i].z - sz
				local d = 0
				if len > 0.001 then
					d = (qx * dz - qz * dx) / len
					if d < 0 then d = -d end
				end
				if d > far then far = d end
				i = i + 1
			end
			ar_log("OW walk " .. OW_WALK .. " ends at " .. p.x .. " " .. p.z .. " strays " .. far)
		end
		break_here()
	end
end
start_script(ow_watch)
