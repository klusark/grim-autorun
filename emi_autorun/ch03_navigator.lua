-- EMI chapter 3: Melee, the SCUMM Bar: Mr. Cheese, the navigator, by insult arm wrestling
ar_log("=== EMI ch03 navigator ===")
ar_wait_for_control()
ar_try_attempt = 0
ar_arm_wrestle_pick = function()
	-- one step of the contest: the dialog is at its offense node (pick an insult) or a defense node (pick the comeback that answers)
	local d = iaw
	if d.node == "offense_node" then
		-- (an insult that is on the screen now, else the first unused one: the list slides and ar_pick scrolls to it)
		local k = 1
		local any = nil
		while k <= d.insult_count do
			if d[k] and not d[k].off then
				if ar_line_shown(d, d[k]) then
					return k
				end
				if not any then
					any = k
				end
			end
			k = k + 1
		end
		return any
	elseif d.node == "defense_node" then
		local k, v = next(d, nil)
		while k do
			if type(k) == "number" and type(v) == "table" and v.defense_node and not v.off and v.text == d.guycomebacks[d.correct_response] then
				return k
			end
			k, v = next(d, k)
		end
	elseif d.node == "easy_defense_node" then
		local k = d.lame_insult_comeback_offset + 1
		return k
	end
	return nil
end
ar_do("use", scu.navigator_obj)
ar_dlg("nv1")
sleep_for(1500)
ar_say("nv1", 70)
sleep_for(800)
ar_say("nv1", 120)
sleep_for(800)
ar_say("nv1", 200)
sleep_for(800)
ar_say("nv1", 300)
sleep_for(800)
ar_say("nv1", 82)
sleep_for(800)
ar_say("nv1", 76)
sleep_for(800)
ar_say("nv1", 600)
ar_iaw_running = function() return getglobal("iaw") and iaw.running end
-- the contest
ar_wait_for(ar_iaw_running, 90000, "the arm wrestling to start")
local guard = 0
while iaw.running and guard < 200 do
	ar_dialog_ready(iaw, 20000)
	-- (the node changes when the navigator has spoken, the list on the screen a moment later: wait until the lines shown are those of the node)
	local settle = 0
	while iaw.running and settle < 4000 and not (iaw.current_choices and iaw.current_choices[1] and iaw.current_choices[1][iaw.node]) do
		sleep_for(100)
		settle = settle + 100
	end
	local n = ar_arm_wrestle_pick()
	if n then
		ar_pick(iaw, n)
	else
		ar_log("arm wrestling: nothing to pick in node " .. tostring(iaw.node))
		sleep_for(500)
	end
	sleep_for(300)
	guard = guard + 1
end
ar_dlg_done("iaw")
ar_log("arm wrestling over, got_navigator=" .. tostring(glob.got_navigator))
ar_check(glob.got_navigator, "Mr. Cheese is the navigator")
