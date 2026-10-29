local o = AR_OBJ
local p = manny:getpos()
PrintDebug("ORL obj=" .. tostring(o and o.name) .. " set=" .. system.currentSet.name .. " manny=" .. format("%.2f %.2f %.2f", p.x, p.y, p.z) .. " obj=" .. format("%.2f %.2f", o.obj_x, o.obj_y) .. " use=" .. tostring(o.use_pnt_x) .. "," .. tostring(o.use_pnt_y) .. " range=" .. tostring(o.range) .. " prox=" .. tostring(o.interest_actor and proximity(o.interest_actor)))
