-- Models that are drawn (assets.py DRAW_BOX: a box 1 x 0.6 x 0.5 m, faces with a material, no lighting). What is on the
-- screen is seen through cr_snap (the box of the bright pixels: the white box, cr_dbox.cos); cr_gbox.cos is the same box in
-- grey (not bright), under the line of an actor. The camera of cr_open (cr_flat with a far z-buffer) sees about 90 pixels a metre on the floor.

cr_dr_actor = function(name, cos, x, y, yaw)
	local a = LoadActor(name)
	PutActorInSet(a, "cr_open.set")
	PutActorAt(a, x or 0, y or 0, 0)
	SetActorRot(a, 0, yaw or 0, 0)
	if cos then
		SetActorCostume(a, cos)
	end
	return a
end

cr_dr_rect = function(key, a)
	local x0, y0, x1, y1 = GetActorRect(a)
	cr_log(key, x0, y0, x1, y1)
end

cr_dr_test = function(name, fn)
	cr_test("draw_" .. name, function()
		MakeCurrentSet("cr_open.set")
		cr_frames(2)
		%fn(%name)
	end)
end

-- the box at a few places, turned, scaled
local places = {
	{ "centre", 0, 0, 0 },
	{ "right", 2, 0, 0 },
	{ "down", 0, -1.5, 0 },
	{ "yaw45", 0, 0, 45 },
	{ "yaw90", 0, 0, 90 },
	{ "edge", 3.4, 0, 0 },
	{ "off", 6, 0, 0 },
}
local i = 1
while places[i] do
	cr_dr_test("at_" .. places[i][1], function(k)
		local p = %places[%i]
		local a = cr_dr_actor("cr_dr_a", "cr_dbox.cos", p[2], p[3], p[4])
		cr_frames(2)
		cr_snap(k .. "_box")
		cr_dr_rect(k .. "_rect", a)
		cr_log(k .. "_costume", GetActorCostume(a))
		PutActorInSet(a, nil)
	end)
	i = i + 1
end

cr_dr_test("scale", function(k)
	local a = cr_dr_actor("cr_dr_a", "cr_dbox.cos")
	SetActorScale(a, 2)
	cr_frames(2)
	cr_snap(k .. "_double")
	SetActorScale(a, 0.5)
	cr_frames(2)
	cr_snap(k .. "_half")
	SetActorScale(a, 1)
	PutActorInSet(a, nil)
end)

cr_dr_test("visibility", function(k)
	local a = cr_dr_actor("cr_dr_a", "cr_dbox.cos")
	cr_frames(2)
	cr_snap(k .. "_shown")
	SetActorVisibility(a, FALSE)
	cr_frames(2)
	cr_snap(k .. "_hidden")
	cr_dr_rect(k .. "_hidden_rect", a)
	SetActorVisibility(a, TRUE)
	cr_frames(2)
	cr_snap(k .. "_again")
	PutActorInSet(a, nil)
	cr_frames(2)
	cr_snap(k .. "_out_of_set")
end)

-- the costume stack: a grey costume pushed over the white one, then popped
cr_dr_test("push_pop", function(k)
	local a = cr_dr_actor("cr_dr_a", "cr_dbox.cos")
	PushActorCostume(a, "cr_gbox.cos")
	cr_frames(2)
	cr_log(k .. "_depth", GetActorCostumeDepth(a))
	cr_snap(k .. "_pushed")
	PopActorCostume(a)
	cr_frames(2)
	cr_snap(k .. "_popped")
	PutActorInSet(a, nil)
end)

-- two boxes side by side: the box of both
cr_dr_test("two", function(k)
	local a = cr_dr_actor("cr_dr_a", "cr_dbox.cos", -1, 0, 0)
	local b = cr_dr_actor("cr_dr_b", "cr_dbox.cos", 1, 0.5, 0)
	cr_frames(2)
	cr_snap(k .. "_both")
	cr_dr_rect(k .. "_rect_a", a)
	cr_dr_rect(k .. "_rect_b", b)
	PutActorInSet(a, nil)
	cr_frames(2)
	cr_snap(k .. "_one")
	PutActorInSet(b, nil)
end)

-- a clip plane through the box (SetActorClipPlane: a point and a normal; what is behind it is not drawn)
cr_dr_test("clip", function(k)
	local a = cr_dr_actor("cr_dr_a", "cr_dbox.cos")
	SetActorClipPlane(a, 0, 0, 0, 1, 0, 0)
	SetActorClipActive(a, TRUE)
	cr_frames(2)
	cr_snap(k .. "_on")
	SetActorClipActive(a, FALSE)
	cr_frames(2)
	cr_snap(k .. "_off")
	PutActorInSet(a, nil)
end)

-- the line of a drawn actor (grey box): above the rectangle it was drawn in, centred on it
local talks = {
	{ "centre", 0, 0 },
	{ "left", -2, 1 },
	{ "top", 0, 2.3 },
	{ "left_edge", -3.3, 0 },
}
i = 1
while talks[i] do
	cr_dr_test("talk_" .. talks[i][1], function(k)
		local t = %talks[%i]
		local a = cr_dr_actor("cr_dr_a", "cr_gbox.cos", t[2], t[3], 0)
		SetActorTalkColor(a, MakeColor(255, 255, 255))
		cr_frames(2)
		cr_tp_say(k, a)
		PutActorInSet(a, nil)
	end)
	i = i + 1
end

-- the line of a drawn actor that moves while it talks, and of one that was drawn and is then hidden
cr_dr_test("talk_moved", function(k)
	local a = cr_dr_actor("cr_dr_a", "cr_gbox.cos", -1, 0, 0)
	SetActorTalkColor(a, MakeColor(255, 255, 255))
	SetSayLineDefaults({ font = LockFont("cr_font.laf") })
	SetTextSpeed(1)
	cr_frames(2)
	SayLine(a, "/crt001/")
	cr_frames(3)
	cr_snap(k .. "_before")
	PutActorAt(a, 1.5, -1, 0)
	cr_frames(3)
	cr_snap(k .. "_after")
	ShutUpActor(a)
	cr_frames(2)
	SetTextSpeed(7)
	PutActorInSet(a, nil)
end)
cr_dr_test("talk_hidden", function(k)
	local a = cr_dr_actor("cr_dr_a", "cr_gbox.cos", 1, 0, 0)
	SetActorTalkColor(a, MakeColor(255, 255, 255))
	cr_frames(2)
	SetActorVisibility(a, FALSE)
	cr_tp_say(k, a)
	SetActorVisibility(a, TRUE)
	PutActorInSet(a, nil)
end)

-- the components of a costume (cr_comp.cos, assets.py COMP_COMPONENTS): two boxes, the left one white, the right one with a
-- material of two cels (white, grey); chores 0 to 6: cel_grey, cel_white, hide_right, show_right, sprite_on, sprite_off,
-- bitmap (the image of the object state of cr_obj.bm)
cr_dr_chore = function(key, a, n)
	PlayActorChore(a, n, "cr_comp.cos")
	cr_frames(10)
	cr_log(key .. "_playing", IsActorChoring(a, n, FALSE, "cr_comp.cos"))
	cr_snap(key)
end

cr_dr_test("components", function(k)
	local a = cr_dr_actor("cr_dr_a", "cr_comp.cos")
	cr_frames(2)
	cr_snap(k .. "_start")
	cr_dr_chore(k .. "_grey", a, 0)
	cr_dr_chore(k .. "_white", a, 1)
	cr_dr_chore(k .. "_hidden", a, 2)
	cr_dr_chore(k .. "_shown", a, 3)
	cr_dr_chore(k .. "_sprite", a, 4)
	cr_dr_chore(k .. "_no_sprite", a, 5)
	PutActorInSet(a, nil)
end)

cr_dr_test("bitmap_component", function(k)
	local a = cr_dr_actor("cr_dr_a", "cr_comp.cos")
	local o = NewObjectState(0, 1, "cr_obj.bm", nil, TRUE)
	cr_log(k .. "_state", type(o))
	PlayActorChore(a, 6, "cr_comp.cos")
	cr_frames(5)
	cr_log(k .. "_image_mid", GetObjectStateImage and 1)
	cr_frames(15)
	cr_log(k .. "_done", IsActorChoring(a, 6, FALSE, "cr_comp.cos"))
	PutActorInSet(a, nil)
end)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("draw_at_centre")
cr_scummvm_differs("draw_at_down")
cr_scummvm_differs("draw_at_edge")
cr_scummvm_differs("draw_at_off")
cr_scummvm_differs("draw_at_right")
cr_scummvm_differs("draw_at_yaw45")
cr_scummvm_differs("draw_at_yaw90")
cr_scummvm_differs("draw_clip")
cr_scummvm_differs("draw_components")
cr_scummvm_differs("draw_push_pop")
cr_scummvm_differs("draw_scale")
cr_scummvm_differs("draw_talk_centre")
cr_scummvm_differs("draw_talk_hidden")
cr_scummvm_differs("draw_talk_left")
cr_scummvm_differs("draw_talk_left_edge")
cr_scummvm_differs("draw_talk_moved")
cr_scummvm_differs("draw_talk_top")
cr_scummvm_differs("draw_two")
cr_scummvm_differs("draw_visibility")
