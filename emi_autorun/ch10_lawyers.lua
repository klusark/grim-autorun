-- EMI chapter 10: the lawyers: Marley's letter read, then everything the lawyers have to say
ar_load(9)
ar_log("=== EMI ch10 lawyers ===")
ar_wait_for_control()
ar_look_item(props.herman_letter or Inventory.ordered_inventory_table[1])
ar_put_away()
ar_talk(law.lawyers_obj)
ar_dlg("dlg_law")
sleep_for(1500)
AR_EXH_REPEAT = 2
ar_exhaust("dlg_law", nil, 40)
AR_EXH_REPEAT = nil
if getglobal("dlg_law") and dlg_law.running then
	ar_say_exit("dlg_law")
end
ar_dlg_done("dlg_law")
ar_log("flags: read=" .. tostring(glob.guybrush_read_marley_letter) .. " deed=" .. tostring(glob.dlaw_talked_deed) .. " bank=" .. tostring(glob.dlaw_talked_bank))
ar_checkpoint(10)
