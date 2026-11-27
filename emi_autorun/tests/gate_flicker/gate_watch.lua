-- ScummVM #11785 (future Guybrush flickers as he comes through the gate): each frame in the Mysts o' Tyme, the sort order and the
-- sector under mot.raft2 and mot.guybrush2, logged when they change (GW), with a frame counter.
GW_F = 0
gw_watch = function()
	local last = ""
	while TRUE do
		GW_F = GW_F + 1
		if system.currentSet == mot and mot.raft2 and mot.raft2.hActor and mot.guybrush2 and mot.guybrush2.hActor then
			local p = mot.raft2:getpos()
			local s = GetSectorName(p.x, p.y, p.z)
			local cur = "raft2 " .. tostring(GetActorSortOrder(mot.raft2.hActor)) .. " " .. tostring(s) .. " guy2 " .. tostring(GetActorSortOrder(mot.guybrush2.hActor)) .. " gate " .. tostring(mot.opened_gate)
			if cur ~= last then
				ar_log("GW " .. GW_F .. " " .. cur .. " at " .. p.x .. " " .. p.z)
				last = cur
			end
		end
		break_here()
	end
end
start_script(gw_watch)
