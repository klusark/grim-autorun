-- Act 3 chapter 9: Jojo Jr. in Monkey Kombat: the bronze hat
ar_log("=== ACT3 ch09 jojo ===")
ar_wait_for_control()
local bot = start_script(a3_kombat_bot)
a3_goto("monkey town")
local tries = 0
while props.jojo_hat.state == PROP_INITIAL and tries < 6 do
	tries = tries + 1
	local line = 120
	if tries > 1 then line = 125 end
	a3_dialog_lines("jj1", { line })
	a3_talk(mon.jojo_obj, "jj1")
	ar_wait_for(function() return mk ~= nil or props.jojo_hat.state ~= PROP_INITIAL end, 120000, "the fight")
	ar_log("fight with Jojo, try " .. tries)
	ar_wait_for(function() return mk == nil end, 600000, "the fight to end")
	ar_wait_for_control()
	ar_state("after the fight " .. tries)
end
stop_script(bot)
ar_check(props.jojo_hat.state ~= PROP_INITIAL, "the bronze hat")
ar_checkpoint(309)
