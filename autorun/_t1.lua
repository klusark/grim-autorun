stop_script(__autorun__)
stop_script(ar_skipper)
AR_T = function()
	local i = 0
	TurnActorTo(manny.hActor, -1.14, 2.61, 0)
	PrintDebug("ORL T start rot " .. manny:getrot().y)
	while i < 40 do
		manny:walk_forward()
		break_here()
		i = i + 1
		if i - floor(i / 8) * 8 == 0 then
			local p = manny:getpos()
			PrintDebug(format("ORL T %d pos %.3f %.3f rot %.1f turning %s", i, p.x, p.y, manny:getrot().y, tostring(manny:is_turning())))
		end
	end
end
start_script(AR_T)
PrintDebug("ORL started")
