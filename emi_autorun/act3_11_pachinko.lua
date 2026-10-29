-- Act 3 chapter 11: Pachinko Rock at the vista point: the rocks. A rock thrown down a chute rolls on the pachinko pins to the beach,
-- the canyon or the lava. A rock only goes to the lava when it collides with another at the last fork, and that takes four rocks
-- released at the right moments (found with the game's own chute code: slot 3, then slot 2 11.5 s later, slot 1 28.0 s and slot 1
-- again 38.9 s after the first rock).
ar_log("=== ACT3 ch11 pachinko ===")
ar_wait_for_control()
a3_goto("Pachinko Rock")
a3_pac_wrap()
A3_K = 0.59
a3_pac_gone = function()
	return next(pac.rocks, nil) == nil
end
a3_throw = function(slot)
	ar_do("pickUp", pac.rockpile)
	ar_do("use", pac["slot" .. slot], pac.rock_obj)
end
-- first the rocks to the canyon (slot 3) and the beach (slot 2), each alone, so that nothing but the lava is left to happen
if not glob.rock_canyon then
	a3_throw(3)
	a3_wait(function() return glob.rock_canyon end, 200000, "the rock in the canyon")
	a3_wait(a3_pac_gone, 100000, "the rocks gone")
	ar_wait_for_control()
end
if not glob.rock_beach then
	a3_throw(2)
	a3_wait(function() return glob.rock_beach end, 200000, "the rock on the beach")
	a3_wait(a3_pac_gone, 100000, "the rocks gone")
	ar_wait_for_control()
end
-- one more to the beach: the game remarks once that there are no more rocks on that ramp
a3_throw(1)
a3_wait(a3_pac_gone, 100000, "the rocks gone")
ar_wait_for_control()
local tries = 0
while not glob.rock_lava and tries < 4 do
	tries = tries + 1
	ar_log("the four rocks, try " .. tries)
	-- (third number: the time from the verb to the rock being made, which differs with the animation of the throw; measured in these runs)
	local plan = { { 3, 0 }, { 2, 11.47, 2290 }, { 1, 28.0, 1620 }, { 1, 38.93, 1630 } }
	local c0 = nil
	local i = 1
	while plan[i] do
		ar_do("pickUp", pac.rockpile)
		if c0 then
			local at = c0 + plan[i][2] * 1000 - (plan[i][3] or A3_K * 1000)
			while A3_CLK < at do
				sleep_for(20)
			end
		end
		ar_do("use", pac["slot" .. plan[i][1]], pac.rock_obj)
		if not c0 then
			c0 = A3_LAST_CREATE
		end
		ar_log("rock " .. i .. " (slot " .. plan[i][1] .. ") made at +" .. floor((A3_LAST_CREATE - c0)) .. " ms")
		i = i + 1
	end
	a3_wait(a3_pac_gone, 150000, "the rocks gone")
	ar_wait_for_control()
end
ar_check(glob.rock_lava, "the rock fell into the lava ditch")
ar_state("lava rock")
ar_checkpoint(311)
