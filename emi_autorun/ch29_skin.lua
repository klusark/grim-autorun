-- EMI chapter 29: the manhole cover tells the sweethearts (Jerry/Larry/Harry, Mindy/Cindy/Wendy, Fred/Ned/Jed): told as Deadeye's story it
-- gives the prosthetic skin; the skin over the manhole is the trampoline into the bank
ar_load(28)
ar_log("=== EMI ch29 skin ===")
ar_wait_for_control()
ar_do("use", unc.caveexit)
ar_wait_for_control()
ar_do("use", ulg.lag_door)
ar_wait_for_control()
ar_do("use", lag.lum_door)
ar_wait_for_control()
ar_do("use", lum.luc_door)
ar_wait_for_control()
ar_state("luc")
ar_do("use", luc.manhole, props.old_sword)
ar_wait_for_control()
ar_log("manhole open " .. tostring(glob.luc_manhole_open))
ar_do("use", luc.manhole_cover)
ar_wait_for_control()
ar_do("lookAt", props.manhole_cover)
ar_wait_for_control()
ar_log("sweethearts: guy1=" .. tostring(glob.guy1) .. " guy2=" .. tostring(glob.guy2) .. " girl=" .. tostring(glob.girl))
-- the story to Deadeye
ar_do("use", luc.pop_door)
ar_wait_for_control()
ar_talk(pop.deadeye_obj)
ar_dlg("de1")
sleep_for(1500)
ar_pick_avail = function(d, list)
	local i = 1
	while list[i] do
		local v = d[list[i]]
		if type(v) == "table" and v.text and v[d.node] and not v.off then
			ar_pick(d, list[i])
			return TRUE
		end
		i = i + 1
	end
	return nil
end
local guard = 0
while de1.running and props.prosthetic_skin.state == PROP_INITIAL and guard < 20 do
	guard = guard + 1
	ar_dialog_ready(de1, 20000)
	local n = de1.node
	ar_log("story step node " .. tostring(n))
	if n == "intro_node" then
		ar_pick_avail(de1, { 70, 95 })
	elseif n == "first_node" then
		ar_pick_avail(de1, { 120, 125 })
	elseif n == "gift_node" then
		ar_pick_avail(de1, { 345, 340 })
	elseif n == "story1_node" then
		ar_pick_avail(de1, { 390 + 10 * glob.guy1 })
	elseif n == "story2_node" then
		ar_pick_avail(de1, { 490 + 10 * glob.girl })
	elseif n == "story3_node" then
		ar_pick_avail(de1, { 590 + 10 * glob.guy2 })
	else
		ar_log("unexpected node " .. tostring(n))
		ar_say_exit("de1")
	end
	sleep_for(2500)
end
ar_log("skin state " .. tostring(props.prosthetic_skin.state))
if getglobal("de1") and de1.running then
	ar_say_exit("de1")
end
ar_dlg_done("de1")
ar_check(props.prosthetic_skin.state == PROP_INV, "the prosthetic skin in hand")
ar_checkpoint(29)
