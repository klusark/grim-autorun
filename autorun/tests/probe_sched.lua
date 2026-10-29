-- Scheduling probe (PROBE lines): how the tasks of the Lua of the game are scheduled, to be run on both engines and compared line by line.
-- CLK counts the frames, as seen by a task that was started first; every line has the CLK at which it was printed, so that the order of the tasks in a frame,
-- the start of a task from a task, and the time that sleep_for takes show up as differences in the lines.
CLK = 0
PN = 0
probe = function(s)
	PN = PN + 1
	PrintDebug("PROBE " .. PN .. " clk " .. CLK .. " ft " .. tostring(system.frameTime) .. " " .. s .. "\n")
end
probe_clock = function()
	while TRUE do
		CLK = CLK + 1
		break_here()
	end
end
probe_clock_task = start_script(probe_clock)
probe("main after clock start")
p_child2 = function()
	probe("child2 first line")
	break_here()
	probe("child2 after one break_here")
end
p_child1 = function()
	probe("child1 first line")
	start_script(p_child2)
	probe("child1 after starting child2")
	break_here()
	probe("child1 after one break_here")
end
probe("main before starting child1")
start_script(p_child1)
probe("main after starting child1")
break_here()
probe("main after one break_here")
-- three tasks in one frame: the order in which they run
p_order = function(name)
	local n = 0
	while n < 3 do
		probe("order " .. name .. " " .. n)
		n = n + 1
		break_here()
	end
end
start_script(p_order, "a")
start_script(p_order, "b")
start_script(p_order, "c")
sleep_for(100)
probe("main after sleep_for(100)")
-- the time that sleep_for takes: the clocks at the end of sleeps of several lengths
p_sleep = function(ms)
	local c0 = CLK
	sleep_for(ms)
	probe("slept " .. ms .. " ms in " .. (CLK - c0) .. " clocks")
end
start_script(p_sleep, 0)
start_script(p_sleep, 1)
start_script(p_sleep, 16)
start_script(p_sleep, 17)
start_script(p_sleep, 18)
start_script(p_sleep, 33)
start_script(p_sleep, 34)
start_script(p_sleep, 100)
start_script(p_sleep, 1000)
sleep_for(1500)
-- wait_for_script and find_script
p_short = function()
	break_here()
	break_here()
	probe("short done")
end
local h = start_script(p_short)
probe("found right after the start: " .. tostring(find_script(p_short) ~= nil))
wait_for_script(h)
probe("after wait_for_script")
probe("found after the end: " .. tostring(find_script(p_short) ~= nil))
-- a script that stops a script
p_forever = function()
	while TRUE do
		break_here()
	end
end
local hf = start_script(p_forever)
break_here()
stop_script(p_forever)
break_here()
probe("forever found after stop_script and a frame: " .. tostring(find_script(p_forever) ~= nil))
probe("END")
ar_finish()
