-- ScummVM #11786: Guybrush's body turning at the catapult controls (gme.cp_controls.use). Act 1 chapters to the controls, then
-- CP READY, 12 s for the window capture to start, the controls, and 40 s held.
AR_CONTINUE = TRUE
ar_log("=== file ch01_wed ===")
ar_in_mdo = function() return ar_set_name() ~= "wedding ship" and cutSceneLevel == 0 end
ar_log("=== EMI ch01 wedding ship ===")
ar_wait_for_control()
ar_do("use", wed.brazier)
ar_state("after brazier")
ar_do("pickUp", wed.coalpile)
ar_state("after coal")
ar_do("use", wed.cannon, props.hotcoal)
ar_wait_for(ar_in_mdo, 60000, "set mdo")
ar_state("end")

ar_log("=== file ch02_scu ===")
ar_drunk_fell = function() return glob.drunk_fell end
-- EMI chapter 2: Melee, the SCUMM Bar: pop the balloon with the darts, the drunk falls, take the pretzel bowl
ar_log("=== EMI ch02 SCUMM bar ===")
ar_wait_for_control()
-- (the end of the walk is the edge of the door's box: whether the box is entered by it depends on the last hair of the floor test)
ar_walk_to(52, 0, -46)
ar_wait_for_control()
if system.currentSet == gme then
	ar_do("use", gme.mem_door)
	ar_wait_for_control()
end
ar_do("use", mem.mel_door)
ar_wait_for_control()
ar_check(ar_set_name() == "melee town", "in Melee town")
ar_do("use", mel.lua_door)
ar_wait_for_control()
ar_check(ar_set_name() == "SCUMM Bar", "in the SCUMM bar")
ar_do("lookAt", scu.balloon_obj)
-- (the conversation starts as the walk ends: the verb is only sent and the dialog is followed, whether the cutscene level is up yet or not)
ar_approach(scu.george_obj)
ar_send_verb("use", scu.george_obj, "the dart player")
ar_say("dart1", 60)
ar_say("dart1", 230)
ar_wait_for(ar_drunk_fell, 40000, "the drunk falls")
ar_say_exit("dart1")
ar_dlg_done("dart1")
ar_do("pickUp", scu.pretzbowl)
ar_check(props.pretzbowl.state == PROP_INV, "the pretzel bowl is Guybrush's")

ar_log("=== file ch03_navigator ===")
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

ar_log("=== file ch04_innertube ===")
-- EMI chapter 4: the inner tube from the harbor
ar_log("=== EMI ch04 inner tube ===")
ar_wait_for_control()
ar_do("use", scu.mel_door)
ar_wait_for_control()
ar_mel_patio_down()
ar_do("use", mel.mem_rdoor)
ar_wait_for_control()
ar_do("use", mem.shi_door)
ar_wait_for_control()
ar_check(ar_set_name() == "shipyards", "in the shipyards")
ar_do("pickUp", props.innertube)
ar_check(props.innertube.state == PROP_INV, "the inner tube is Guybrush's")

-- EMI chapter 5: the catapult at the mansion: pretzels for Tony, the inner tube on the cactus, then the controls (Tony recalibrates to the
-- cactus and the boulder comes back at his catapult)
ar_log("=== EMI ch05 catapult ===")
ar_wait_for_control()
ar_do("use", shi.mem_door)
ar_wait_for_control()
ar_do("use", mem.gme_door)
ar_wait_for_control()
ar_check(ar_set_name() == "gov mansion exterior", "at the mansion")
ar_do("use", gme.puz_cactus, props.innertube)
ar_wait_for_control()
ar_check(props.innertube.state == PROP_FINAL, "the inner tube is on the cactus")
ar_do("use", gme.tony, props.pretzbowl)
ar_wait_for_control()
ar_log("CP READY")
sleep_for(12000)
ar_log("CP USE")
ar_do("use", gme.cp_controls)
sleep_for(100000)
ar_log("CP done")
