-- Probe: what the checkpoint of slot 37 brings back (execute_line tasks alive right after the load, before any dialog is run)
ar_load(18)
sleep_for(1500)
local h = next_script(nil)
local n = 0
while h do
	local s = "PROBE task " .. tostring(h)
	if h == find_script(Dialog.execute_line) then s = s .. "  <- Dialog.execute_line" end
	if h == find_script(WalkManny) then s = s .. " <- WalkManny" end
	PrintDebug(s)
	h = next_script(h)
	n = n + 1
end
PrintDebug("PROBE tasks " .. n .. " set " .. tostring(system.currentSet.name) .. " handler " .. tostring(system.buttonHandler))
PrintDebug("PROBE cutSceneLevel " .. tostring(cutSceneLevel) .. " execute_line alive " .. tostring(find_script(Dialog.execute_line)))
print_scripts()
