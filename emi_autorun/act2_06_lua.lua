-- Act 2 chapter 6: Lua Bar: chopsticks, a flaming scuttlefish ordered from the stool, the paint brush in the sushi boats' works while
-- the flame passes the wax painting
ar_load(205)
ar_log("=== ACT2 ch06 lua ===")
ar_wait_for_control()
ar_do("use", shi.mem_door)
ar_wait_for_control()
ar_do("use", mem.mel_door)
ar_wait_for_control()
ar_do("use", mel.lua_door)
ar_wait_for_control()
ar_check(ar_set_name() == "lua bar", "in the Lua bar")
ar_do("pickUp", lua.chopsticks)
ar_wait_for_control()
ar_check(props.chopsticks.state == PROP_INV, "chopsticks")
ar_do("use", lua.stool)
ar_wait_for_control()
ar_check(lua.sitting_down, "sitting")
a2_start("use", lua.waitress_obj)
ar_dlg("lw1")
a2_ready("lw1", 3000)
ar_say("lw1", 100)
a2_ready("lw1", 1500)
ar_say("lw1", 500)
ar_dlg_done("lw1")
-- (the kitchen takes the order when the dialog is cleared and a sushi boat comes by: ordered goes from 1 to 2)
ar_try_wait(function() return lua.ordered and lua.ordered >= 2 end, 60000)
ar_check(lua.ordered and lua.ordered >= 2, "the scuttlefish is ordered")
-- (the can of grog is bound to a number key now, while there is time: in the kitchen every second counts)
ar_hold(props.grogcan)
ar_put_away()
-- wait for the flame
ar_wait_for(function() return lua.flamin end, 120000, "the flaming scuttlefish")
-- The jam holds the boats where they are when the brush goes in, and the pour into the boiler works if the flame is on the place of the
-- painting then (the game wants it within 0.3 of flamin_target). The flame passes it on the lower lane of the belt, moving east, at about
-- a unit a second; the brush needs A2_JAM_LEAD units of the flame's way from the press to the jam. So Guybrush is standing at the
-- mechanism with the brush in hand, and the verb is sent when the flame is that far before the place.
-- (from the verb to the stop the flame goes on 2.95 or 3.28 units, one or the other from run to run (Nov 10: 3.28 at dx 3.295, 2.95 at
-- dx 3.278 and 3.262; the pour takes the flame within about 0.32 of the place). A lead of 3.3 only works with the longer one: the middle
-- of the two leaves it 0.17 off either way)
A2_JAM_LEAD = 3.12
ar_hold(props.paintbrush)
a2_flame_dx = function()
	local t = lua.flamin_target
	local p = lua.sushiflame:getworldpos()
	return t.x - p.x
end
a2_flame_close = function()
	local dx = a2_flame_dx()
	return lua.flamin and lua.sushiflame:getworldpos().z < -4.0 and dx <= A2_JAM_LEAD and dx > A2_JAM_LEAD - 1.5
end
-- (the lines run their course from the jam to the pour: the boats and the flame are timed with the cutscenes; not skipped as elsewhere)
AR_KEEP_LINES = TRUE
AR_START_SET = system.currentSet
AR_CODE = lua.mech["use_" .. trim_header(props.paintbrush.system_name or props.paintbrush.string_name)]
ar_approach(lua.mech)
ar_log("at the mechanism, flame dx=" .. a2_flame_dx())
local n = 0
while not a2_flame_close() and n < 6000 do
	sleep_for(20)
	n = n + 1
	if n == 1 or mod(n, 100) == 0 then ar_log("flame dx=" .. a2_flame_dx()) end
end
ar_log("jam at dx=" .. a2_flame_dx() .. " clock " .. tostring(AR_CLOCK))
ar_send_verb("use", lua.mech, "use the paint brush on the sushi boat propulsion mechanism")
ar_try_wait(function() return find_script(lua.chef_fixes_boats) end, 60000)
ar_wait_for_control()
ar_log("jammed; t=" .. lua.flamin_target.x .. "," .. lua.flamin_target.z .. " flame=" .. lua.sushiflame:getworldpos().x .. "," .. lua.sushiflame:getworldpos().z .. " d to target=" .. point2_proximity(lua.flamin_target.x, 0, lua.flamin_target.z, lua.sushiflame:getworldpos().x, 0, lua.sushiflame:getworldpos().z))
ar_state("jammed")
ar_log("chef_fix running: " .. tostring(find_script(lua.chef_fixes_boats)) .. " in_place " .. tostring(lua.chef_in_place) .. " cs " .. cutSceneLevel)
-- Where the door walk starts: when the door does not open (a walk that got stuck on the way leaves Guybrush near the door but not at its use
-- point, and the clicks from there do nothing), he goes back here and the walk is started again
-- (the chef is at the mechanism, next to Guybrush, for a good while; a way along the south edge of the room leads into him and the boats:
-- first up into the room, then east to the kitchen door, as quickly as possible: the time in the kitchen is what is left of the chef's
-- time at the mechanism when the door is reached)
-- (the can of grog in hand on the way: in the kitchen every second counts)
ar_log("clock " .. tostring(AR_CLOCK) .. " jammed")
ar_hold(props.grogcan)
ar_log("clock " .. tostring(AR_CLOCK) .. " can in hand")
ar_walk_to(-4.5, 0.01, 0.8)
ar_log("clock " .. tostring(AR_CLOCK) .. " at the way point")
a2_hx = manny:getpos().x
a2_hy = manny:getpos().y
a2_hz = manny:getpos().z
a2_kt = 0
while ar_set_name() ~= "kitchen" and a2_kt < 6 do
	a2_kt = a2_kt + 1
	if a2_kt > 2 then
		ar_log("the kitchen door did not open, back to where the walk started")
		ar_walk_to(a2_hx, a2_hy, a2_hz)
	end
	ar_do("use", lua.kit_door)
	ar_wait_for_control()
	sleep_for(1500)
end
ar_state("kitchen?")
ar_log("clock " .. tostring(AR_CLOCK) .. " kitchen time limit " .. tostring(kit.timelimit) .. " ms, lead " .. tostring(lua.lead))
ar_check(ar_set_name() == "kitchen", "in the kitchen")
-- (the pour is a cutscene that ends with the flame stopped: not skipped)
AR_NO_SKIP = TRUE
ar_do("use", kit.boiler, props.grogcan)
ar_wait_for_control()
AR_NO_SKIP = nil
sleep_for(3000)
ar_wait_for_control()
ar_state("after boiler")
AR_KEEP_LINES = nil
ar_log("clock " .. tostring(AR_CLOCK) .. " after the pour: poured_grog " .. tostring(kit.poured_grog) .. " lua_solved " .. tostring(glob.lua_solved) .. " painting " .. tostring(props.painting.state) .. " flamin " .. tostring(lua.flamin) .. " set " .. ar_set_name())
-- (the flame boat goes on its way to the painting and stops there)
ar_try_wait(function() return glob.lua_solved end, 120000)
ar_check(glob.lua_solved, "the flame stopped at the painting")
ar_check(props.painting.state == PROP_INV, "the painting")
ar_checkpoint(206)
