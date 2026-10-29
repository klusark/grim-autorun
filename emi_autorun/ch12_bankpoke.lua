-- EMI chapter 12: the bank: the teller, all her topics, the safe deposit box under the name Marley, the letter and the Gubernatorial Symbol:
-- the robbery
ar_load(11)
ar_log("=== EMI ch12 bank poke ===")
ar_wait_for_control()
ar_do("pickUp", props.scupperware)
ar_wait_for_control()
ar_put_away()
ar_talk(ban.teller_obj)
ar_dlg("bt1")
sleep_for(1500)
ar_exhaust("bt1", nil, 30)
if getglobal("bt1") and bt1.running then
	ar_say_exit("bt1")
end
ar_dlg_done("bt1")
ar_wait_for(function() return glob.bank_robbed end, 60000, "the robbery")
ar_wait_for_control()
ar_check(props.scupperware.state == PROP_INV, "the ScupperWare from the flyer in hand")
ar_check(glob.bank_robbed, "the bank is robbed")
ar_checkpoint(12)
