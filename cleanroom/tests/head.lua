-- A head that turns toward what the actor looks at (cr_head.cos: a white bar along x on the head node, see assets.py
-- HEAD_NODES; SetActorHead with the joints body, neck, head). Seen through cr_snap: the box of the bar from above.

cr_hd_test = function(name, fn)
	cr_test("head_" .. name, function()
		MakeCurrentSet("cr_open.set")
		local a = LoadActor("cr_hd_a")
		PutActorInSet(a, "cr_open.set")
		PutActorAt(a, 0, 0, 0)
		SetActorRot(a, 0, 0, 0)
		SetActorCostume(a, "cr_head.cos")
		cr_frames(2)
		%fn(%name, a)
		ActorLookAt(a, nil)
		cr_frames(2)
		PutActorInSet(a, nil)
	end)
end

-- (where the bar is after n frames of looking)
cr_hd_after = function(key, a, n)
	cr_frames(n)
	cr_snap(key)
	local x, y, z = GetActorNodeLocation(a, 3)
	cr_log(key .. "_node", x, y, z)
end

cr_hd_test("rest", function(k, a)
	cr_hd_after(k, a, 1)
end)

cr_hd_test("no_head_set", function(k, a)
	ActorLookAt(a, 2, 0, 1, 1000)
	cr_hd_after(k, a, 30)
end)

local looks = {
	{ "side", 2, 0, 1 },
	{ "front", 0, 2, 1 },
	{ "behind", 0, -2, 1 },
	{ "up", 0, 0.5, 5 },
	{ "diagonal", 1.5, 1.5, 1 },
}
local i = 1
while looks[i] do
	cr_hd_test("look_" .. looks[i][1], function(k, a)
		local l = %looks[%i]
		SetActorHead(a, 1, 2, 3, 30, 60, 80)
		ActorLookAt(a, l[2], l[3], l[4], 1000)
		cr_hd_after(k .. "_early", a, 3)
		cr_hd_after(k .. "_late", a, 60)
	end)
	i = i + 1
end

cr_hd_test("limits", function(k, a)
	SetActorHead(a, 1, 2, 3, 10, 10, 20)
	ActorLookAt(a, 2, 0, 1, 1000)
	cr_hd_after(k, a, 60)
end)

cr_hd_test("rate", function(k, a)
	SetActorHead(a, 1, 2, 3, 30, 60, 80)
	SetActorLookRate(a, 50)
	cr_log(k .. "_rate", GetActorLookRate(a))
	ActorLookAt(a, 2, 0, 1)
	cr_hd_after(k .. "_10", a, 10)
	cr_hd_after(k .. "_40", a, 30)
end)

cr_hd_test("back", function(k, a)
	SetActorHead(a, 1, 2, 3, 30, 60, 80)
	ActorLookAt(a, 2, 0, 1, 1000)
	cr_frames(60)
	ActorLookAt(a, nil)
	cr_hd_after(k .. "_10", a, 10)
	cr_hd_after(k .. "_60", a, 50)
end)

cr_hd_test("actor", function(k, a)
	SetActorHead(a, 1, 2, 3, 30, 60, 80)
	local b = LoadActor("cr_hd_b")
	PutActorInSet(b, "cr_open.set")
	PutActorAt(b, -1.5, 1.5, 0)
	ActorLookAt(a, b, 1000)
	cr_hd_after(k, a, 60)
	PutActorInSet(b, nil)
end)
