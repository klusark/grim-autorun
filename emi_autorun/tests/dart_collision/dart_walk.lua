-- ScummVM #11787: Guybrush walks through the dart players when he is sent to talk to them after the "stay out of my way" box
ar_log("=== t11787 ===")
ar_wait_for_control()
ar_walk_to(52, 0, -46)
ar_wait_for_control()
if system.currentSet == gme then
	ar_do("use", gme.mem_door)
	ar_wait_for_control()
end
ar_do("use", mem.mel_door)
ar_wait_for_control()
ar_do("use", mel.lua_door)
ar_wait_for_control()
ar_check(ar_set_name() == "SCUMM Bar", "in the SCUMM bar")

T87_TRIAL = 0
T87_MIN = { }
t87_d = function(a, b)
	local p = a:getpos()
	local q = b:getpos()
	local dx = p.x - q.x
	local dz = p.z - q.z
	return sqrt(dx * dx + dz * dz)
end
t87_watch = function()
	while TRUE do
		if T87_TRIAL > 0 and guybrush:is_moving() then
			local dg = t87_d(guybrush, george)
			local dn = t87_d(guybrush, ned)
			local m = T87_MIN[T87_TRIAL]
			if not m then
				m = { g = 99, n = 99 }
				T87_MIN[T87_TRIAL] = m
			end
			if dg < m.g then m.g = dg end
			if dn < m.n then m.n = dn end
		end
		break_here()
	end
end
start_script(t87_watch)

t87_dlg = function()
	return dart1 and dart1.running
end
t87_lane = function()
	return cutSceneLevel > 0
end

local i = 1
while i <= 16 do
	T87_TRIAL = 0
	ar_walk_to(-3.0, 0, 2.0)
	ar_wait_for_control()
	ar_walk_to(-4.9, 0, 1.7, t87_lane, 8000)
	ar_wait_for_control()
	local gp = guybrush:getpos()
	ar_log("T87 trial " .. i .. " after lane: guybrush " .. gp.x .. " " .. gp.z)
	sleep_for(i * 650)
	local a = george:getpos()
	local b = ned:getpos()
	ar_log("T87 trial " .. i .. " george " .. a.x .. " " .. a.z .. " ned " .. b.x .. " " .. b.z)
	T87_TRIAL = i

	start_script(scu.george_obj.talkTo, scu.george_obj)
	ar_wait_for(t87_dlg, 30000, "dart dialog")
	T87_TRIAL = 0
	local m = T87_MIN[i]
	if m then
		ar_log("T87 trial " .. i .. " closest: george " .. m.g .. " ned " .. m.n)
	else
		ar_log("T87 trial " .. i .. " closest: no walk")
	end
	ar_say("dart1", 90)
	ar_say_exit("dart1")
	ar_dlg_done("dart1")
	ar_wait_for_control()
	i = i + 1
end
ar_log("=== t11787 done ===")
