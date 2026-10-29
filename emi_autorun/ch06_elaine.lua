ar_has_symbol = function() return props.gubernatorial_symbol.state == PROP_INV end
ar_cushy_signed = function() return glob.signed_cushy end
-- EMI chapter 6: the mansion: Elaine gives the Gubernatorial Symbol; the cushy contract form is signed
ar_log("=== EMI ch06 Elaine ===")
ar_wait_for_control()
ar_do("use", gme.gmi_door)
ar_wait_for_control()
ar_check(ar_set_name() == "governors mansion interior", "inside the mansion")
ar_talk(gmi.elaine)
ar_dlg("el1")
sleep_for(1500)
ar_say("el1", 90)
sleep_for(800)
if ar_offered_line("el1", 420) then
	ar_say("el1", 420)
else
	ar_say("el1", 410)
end
sleep_for(1500)
ar_wait_for(ar_has_symbol, 40000, "the symbol")
ar_say_exit("el1")
ar_dlg_done("el1")
ar_check(props.gubernatorial_symbol.state == PROP_INV, "the Gubernatorial Symbol is Guybrush's")
ar_do("pickUp", gmi.cushycontract)
ar_check(props.cushycontract.state == PROP_INV, "the government paper is Guybrush's")
ar_look_item(props.cushycontract)
ar_check(glob.found_cushy, "the paper has been read")
ar_do("use", gmi.elaine, props.cushycontract)
ar_wait_for(ar_cushy_signed, 60000, "the contract to be signed")
ar_wait_for_control()
ar_check(glob.signed_cushy, "the cushy contract is signed")
