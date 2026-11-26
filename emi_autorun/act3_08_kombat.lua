-- Act 3 chapter 8: Monkey Kombat practice: two wins over the wild monkeys of the jungle (a bot answers every phrase with a stance that
-- beats the monkey's) bring the level to 4, the least Jojo Jr. takes on (dlg_jojojr.lua jj1[120])
-- (a wild monkey's level is the player's one less, the same or one more (_actorsmonkey.lua MImonkey.default, rolled each time the jungle is
-- entered; its name tells it: Timid, Smelly, Strapping, Brawny), and a win raises the player's level to one above the monkey's
-- (monkey_kombat2.lua). The monkey moves first when it is not below the player, and a lost exchange costs 2 either way: a monkey a level
-- up is an even race at best. The speed runners' choice, which a simulation of these rules finds the quickest too: at level 1 a level 1
-- monkey (won 4 times in 5), at level 2 or 3 a level 3 one (7 and 9 in 10); any other is left: out of the jungle and straight back in, by
-- walking into the map's monkey, which the game puts near the jungle's way out (mom.generate_monkeys))
ar_log("=== ACT3 ch08 kombat practice ===")
ar_wait_for_control()
local bot = start_script(a3_kombat_bot)
A3_STAY_JUN = TRUE

a3_kombat_worth = function(level, monkey)
	if level == 1 then
		return monkey == 1
	end
	return monkey == 3
end

-- From the map into the jungle: walks into the map's wild monkey (it runs about: the walk is aimed again where it has gone). Only just out
-- of the jungle, when the monkey is near: the map is in pieces (the canyon), and a walk towards a monkey in another piece is planned only
-- part of the way, into some door's box (Nov 25: into the canyon, whose plateau has no way back to the map)
a3_meet_monkey = function()
	local n = 0
	while ar_set_name() == A3_SET_MOM and n < 12 do
		local m = mom and (mom.special_monkey or (mom.monkeys and mom.monkeys[1]))
		if not m then
			return nil
		end
		local p = m:getpos()
		local g = manny:getpos()
		if sqrt((p.x - g.x) * (p.x - g.x) + (p.z - g.z) * (p.z - g.z)) > 10 then
			ar_log("the map's monkey is " .. format("%.1f %.1f", p.x, p.z) .. ", too far to meet")
			return nil
		end
		ar_walk_to(p.x, p.y, p.z, function() return ar_set_name() ~= A3_SET_MOM end, 2500)
		n = n + 1
	end
	return ar_set_name() == A3_SET_JUN
end

local tries = 0
A3K_WALKS = 0
A3K_LEFT_JUN = nil
while glob.monkey_kombat_level < 4 and tries < 40 do
	tries = tries + 1
	if ar_set_name() ~= A3_SET_JUN then
		a3_to_map()
		if not (A3K_LEFT_JUN and a3_meet_monkey()) and ar_set_name() ~= A3_SET_JUN then
			-- (no monkey met on the map: across it, where one catches Guybrush on the way)
			A3K_WALKS = A3K_WALKS + 1
			if mod(A3K_WALKS, 2) == 1 then
				a3_goto("monkey town")
			else
				a3_goto("monkey head")
			end
		end
		A3K_LEFT_JUN = nil
	end
	if ar_set_name() == A3_SET_JUN then
		-- (the set tables are built while the set is entered: the name is there before the monkey object is)
		ar_try_wait(function() return jun and jun.MImonkey_obj and cutSceneLevel == 0 end, 15000)
	end
	if ar_set_name() == A3_SET_JUN and jun and jun.MImonkey_obj and glob.level_offset and not a3_kombat_worth(glob.monkey_kombat_level, glob.level_offset) then
		ar_log("a level " .. glob.level_offset .. " monkey in the jungle, try " .. tries .. ": walked past at level " .. glob.monkey_kombat_level)
		A3K_LEFT_JUN = a3_to_map()
	elseif ar_set_name() == A3_SET_JUN and jun and jun.MImonkey_obj then
		ar_log("a level " .. tostring(glob.level_offset) .. " monkey in the jungle, try " .. tries .. ", level " .. glob.monkey_kombat_level)
		AR_KEEP_GOING = TRUE
		ar_do("use", jun.MImonkey_obj)
		AR_KEEP_GOING = FALSE
		ar_wait_for(function() return mk == nil end, 300000, "the fight to end")
		ar_wait_for_control()
		ar_log("kombat level " .. tostring(glob.monkey_kombat_level))
		-- the jungle is left by its way back to the map
		A3K_LEFT_JUN = a3_to_map()
	end
end
A3_STAY_JUN = nil
stop_script(bot)
ar_check(glob.monkey_kombat_level >= 4, "Monkey Kombat level 4")
ar_checkpoint(308)
