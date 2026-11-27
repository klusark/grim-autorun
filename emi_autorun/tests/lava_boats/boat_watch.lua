-- ScummVM #11824 (the lava ride's boats float back facing one way after a bump): logs every empty boat of the flume each time it
-- comes to rest (still for 30 frames): its node, its yaw and the yaw the game gives a boat on that node at the start
-- (flume.make_boat: GetActorYawToPoint(node.pos_B) - 90), and the difference.
LB_ID = { }
LB_N = 0
LB_LAST = { }
LB_STILL = { }
lb_norm = function(a)
	while a > 180 do a = a - 360 end
	while a < -180 do a = a + 360 end
	return a
end
lb_watch = function()
	while TRUE do
		if flume and flume.boats and system.currentSet == lav then
			local b = next(flume.boats, nil)
			while b do
				if b ~= flume.guyboat and b.hActor then
					if not LB_ID[b] then
						LB_N = LB_N + 1
						LB_ID[b] = LB_N
					end
					local id = LB_ID[b]
					local p = b:getpos()
					local q = LB_LAST[id]
					local moved = not q or abs(p.x - q.x) + abs(p.z - q.z) > 0.001
					LB_LAST[id] = p
					if moved then
						if (LB_STILL[id] or 0) < 0 then
							ar_log("LB move " .. id)
						end
						LB_STILL[id] = 0
					elseif LB_STILL[id] and LB_STILL[id] >= 0 then
						LB_STILL[id] = LB_STILL[id] + 1
						if LB_STILL[id] == 30 then
							LB_STILL[id] = -1
							local n = b.at_node
							local yaw = b:getrot().y
							if n and n.pos_B then
								local want = GetActorYawToPoint(b.hActor, n.pos_B) - 90
								ar_log("LB rest " .. id .. " node " .. tostring(n.name) .. " yaw " .. lb_norm(yaw) .. " start yaw " .. lb_norm(want) .. " off " .. lb_norm(yaw - want))
							else
								ar_log("LB rest " .. id .. " no node, yaw " .. lb_norm(yaw))
							end
						end
					end
				end
				b = next(flume.boats, b)
			end
		end
		break_here()
	end
end
start_script(lb_watch)
