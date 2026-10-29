-- Probe: the state after loading a checkpoint
ar_load(29)
PrintDebug("LOADPROBE idle_timer_var=" .. tostring(manny.idle_timer_var) .. " TIME_TO_IDLE=" .. tostring(TIME_TO_IDLE) .. " PerSecond=" .. tostring(PerSecond(1)) .. " set=" .. tostring(system.currentSet and system.currentSet.name) .. " objects=" .. type(system.currentSet and system.currentSet.objects) .. " frameTime=" .. tostring(system.frameTime) .. "\n")
ar_finish()
