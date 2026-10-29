-- Probe (frames through DumpFrame, DUMPDIR=<dir>): Manny taking his first inventory item out and putting it away (SetActorInvClipNode 13 while the inventory is open),
-- a frame every 2 frames; run with and without GRIMOFF=clip_plane
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
probe_wait = function(n)
	local k = 0
	while k < n do
		k = k + 1
		break_here()
	end
end
ar_nt_place({ id = "mo", set = "mo" })
probe_wait(60)
n = 1
while Inventory.ordered_inventory_table[n] do
	ar_log("PROBE inventory " .. n .. " " .. tostring(Inventory.ordered_inventory_table[n].name))
	n = n + 1
end
ar_press_key(KEY1)
k = 0
while k < 70 do
	probe_wait(2)
	ar_frame("t" .. format("%03d", k))
	k = k + 1
end
ar_log("PROBE holding " .. tostring(manny.is_holding and manny.is_holding.name))
AR_KEEP_GOING = nil
ar_finish()
