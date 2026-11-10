t1_probe = function() local f = 0 while f < 2400 do local x, y, z = GetActorPos(manny.hActor) local rp, r = GetActorRot(manny.hActor) local hid, hn = GetActorSector(manny.hActor, HOT) PrintDebug(format("T1F %d %.4f %.4f %.4f yaw %.2f hot %s ft %s", f, x, y, z, r or -1, tostring(hn), tostring(system.frameTime))) f = f + 1 break_here() end end
start_script(t1_probe)
