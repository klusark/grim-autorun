ar_wait_for_control()
PrintDebug("DATEPROBE none=[" .. tostring(date()) .. "] H=[" .. tostring(date("%H")) .. "] c=[" .. tostring(date("%c")) .. "] x=[" .. tostring(date("%x")) .. "] X=[" .. tostring(date("%X")) .. "] mix=[" .. tostring(date("%d/%m/%Y %H:%M:%S %p %a %b %j %y %Z %%")) .. "]\n")
ar_finish()
