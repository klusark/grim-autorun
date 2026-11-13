-- Where the line of an actor is put on the screen (SayLine), seen on a picture of the screen (cr_snap: the box of the white
-- text, x0 y0 x1 y1). On the original, Actor_CreateSubtitle (0x48b2e0) places it once, when SayLine starts:
--   - above the rectangle the actor was drawn in, centred on it, when it was drawn (a model with faces; ours have none);
--   - else, for an actor without a costume in the current set, above the point its position projects to, centred on it;
--   - else (and when the projection fails: off the screen, behind the camera) at the off-screen position
--     (SetOffscreenTextPos);
--   - the x and y of SayLine's table replace the x and the y;
--   - then clamped: the text at least 40 pixels from the left and right edges and 10 from the top and bottom.
-- The camera of cr_flat sees about 90 pixels a metre on the floor: (0, 0, 0) is at (320, 240), x from -3.5 to 3.5 m.

cr_tp_actor = function(name, x, y, z)
	local a = LoadActor(name)
	SetActorTalkColor(a, MakeColor(255, 255, 255))
	if x then
		PutActorInSet(a, "cr_flat.set")
		PutActorAt(a, x, y, z or 0)
	end
	return a
end

-- (what is on the screen while a says msg (default crt001, "Clean room text one", 105 x 12 pixels); opts: SayLine's table)
cr_tp_say = function(key, a, msg, opts)
	SetSayLineDefaults({ font = LockFont("cr_font.laf") })
	SetTextSpeed(1)
	if opts then
		SayLine(a, msg or "/crt001/", opts)
	else
		SayLine(a, msg or "/crt001/")
	end
	cr_frames(3)
	cr_log(key .. "_going", IsMessageGoing())
	cr_snap(key .. "_text")
	cr_frames(3)
	ShutUpActor(a)
	cr_frames(2)
end

-- (the point the actor's position projects to, for reference)
cr_tp_where = function(key, a)
	local x, y, z = GetActorPos(a)
	local sx, sy = WorldToScreen(x, y, z)
	cr_log(key .. "_screen", sx, sy)
end

cr_tp_test = function(name, fn)
	cr_test("tp_" .. name, function()
		MakeCurrentSet("cr_flat.set")
		cr_frames(2)
		%fn(%name)
		SetTextSpeed(7)
	end)
end

-- the screen with nothing said: the background has no bright pixel
cr_tp_test("nothing", function(k)
	cr_snap(k .. "_text")
	cr_frames(3)
end)

-- an actor without a costume, in the current set: the point of its position
local spots = {
	{ "centre", 0, 0, 0 },
	{ "left", -2, 0.5, 0 },
	{ "right", 2.5, -1, 0 },
	{ "high", 0, 0, 3 },
	-- (near the edges: the text is clamped 40 pixels from the sides, 10 from the top)
	{ "left_edge", -3.3, 0, 0 },
	{ "right_edge", 3.3, 0, 0 },
	{ "top_edge", 0, 2.45, 0 },
	{ "bottom_edge", 0, -2.5, 0 },
	-- (off the screen: no projection)
	{ "off_left", -6, 0, 0 },
	{ "off_top", 0, 6, 0 },
	{ "behind_camera", 0, -0.5, 8 },
}
local i = 1
while spots[i] do
	cr_tp_test("spot_" .. spots[i][1], function(k)
		local s = %spots[%i]
		local a = cr_tp_actor("cr_tp_a", s[2], s[3], s[4])
		cr_tp_where(k, a)
		cr_tp_say(k, a)
		PutActorInSet(a, nil)
	end)
	i = i + 1
end

-- the text wider than the screen, and long text near an edge
cr_tp_test("long_centre", function(k)
	local a = cr_tp_actor("cr_tp_a", 0, 0, 0)
	cr_tp_say(k, a, "/crt004/")
	PutActorInSet(a, nil)
end)
cr_tp_test("medium_left_edge", function(k)
	local a = cr_tp_actor("cr_tp_a", -3, 0, 0)
	cr_tp_say(k, a, "/crt002/")
	PutActorInSet(a, nil)
end)

-- the actor moves while it talks: placed once (when SayLine starts) or again
cr_tp_test("moved", function(k)
	local a = cr_tp_actor("cr_tp_a", -1, 0, 0)
	SetSayLineDefaults({ font = LockFont("cr_font.laf") })
	SetTextSpeed(1)
	SayLine(a, "/crt001/")
	cr_frames(3)
	cr_snap(k .. "_before")
	cr_frames(3)
	PutActorAt(a, 1.5, -1, 0)
	cr_frames(3)
	cr_snap(k .. "_after")
	cr_frames(3)
	ShutUpActor(a)
	cr_frames(2)
	PutActorInSet(a, nil)
end)

-- not placed by its position: not in a set, in another set, hidden, with a costume (a model without faces: never drawn)
cr_tp_test("no_set", function(k)
	local a = cr_tp_actor("cr_tp_a")
	cr_tp_say(k, a)
end)
cr_tp_test("other_set", function(k)
	local a = cr_tp_actor("cr_tp_a")
	PutActorInSet(a, "cr_edge.set")
	PutActorAt(a, 0, 0, 0)
	cr_tp_say(k, a)
	PutActorInSet(a, nil)
end)
cr_tp_test("hidden", function(k)
	local a = cr_tp_actor("cr_tp_a", 1, 0, 0)
	SetActorVisibility(a, FALSE)
	cr_tp_say(k, a)
	SetActorVisibility(a, TRUE)
	PutActorInSet(a, nil)
end)
cr_tp_test("costume", function(k)
	local a = cr_tp_actor("cr_tp_a", 1, 0, 0)
	SetActorCostume(a, "cr_box.cos")
	cr_tp_say(k, a)
	PutActorInSet(a, nil)
end)

-- the off-screen position (SetOffscreenTextPos; the scripts set (320, 0) while a dialog is open and (nil, nil) after)
local offs = {
	{ "dialog", 320, 0 },
	{ "corner", 0, 0 },
	{ "far_corner", 640, 480 },
	{ "middle", 200, 300 },
}
i = 1
while offs[i] do
	cr_tp_test("offpos_" .. offs[i][1], function(k)
		local o = %offs[%i]
		SetOffscreenTextPos(o[2], o[3])
		local a = cr_tp_actor("cr_tp_a")
		cr_tp_say(k, a)
		SetOffscreenTextPos(nil, nil)
	end)
	i = i + 1
end
cr_tp_test("offpos_default", function(k)
	SetOffscreenTextPos(nil, nil)
	local a = cr_tp_actor("cr_tp_a")
	cr_tp_say(k, a)
end)

-- the x and y of SayLine's table, on an actor in view (they replace the position of the actor, then the clamping)
local xys = {
	{ "xy", { x = 100, y = 100 } },
	{ "x_only", { x = 500 } },
	{ "y_only", { y = 60 } },
	{ "xy_zero", { x = 0, y = 0 } },
	{ "xy_far", { x = 640, y = 480 } },
	{ "xy_negative", { x = -100, y = -50 } },
}
i = 1
while xys[i] do
	cr_tp_test("table_" .. xys[i][1], function(k)
		local a = cr_tp_actor("cr_tp_a", 1, 1, 0)
		cr_tp_say(k, a, nil, %xys[%i][2])
		PutActorInSet(a, nil)
	end)
	i = i + 1
end
cr_tp_test("table_xy_no_set", function(k)
	local a = cr_tp_actor("cr_tp_a")
	cr_tp_say(k, a, nil, { x = 150, y = 200 })
end)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("tp_hidden")
cr_scummvm_differs("tp_long_centre")
cr_scummvm_differs("tp_medium_left_edge")
cr_scummvm_differs("tp_moved")
cr_scummvm_differs("tp_offpos_corner")
cr_scummvm_differs("tp_offpos_dialog")
cr_scummvm_differs("tp_offpos_far_corner")
cr_scummvm_differs("tp_spot_behind_camera")
cr_scummvm_differs("tp_spot_bottom_edge")
cr_scummvm_differs("tp_spot_centre")
cr_scummvm_differs("tp_spot_high")
cr_scummvm_differs("tp_spot_left")
cr_scummvm_differs("tp_spot_left_edge")
cr_scummvm_differs("tp_spot_off_left")
cr_scummvm_differs("tp_spot_off_top")
cr_scummvm_differs("tp_spot_right")
cr_scummvm_differs("tp_spot_right_edge")
cr_scummvm_differs("tp_spot_top_edge")
cr_scummvm_differs("tp_table_x_only")
cr_scummvm_differs("tp_table_xy")
cr_scummvm_differs("tp_table_xy_far")
cr_scummvm_differs("tp_table_xy_negative")
cr_scummvm_differs("tp_table_xy_no_set")
cr_scummvm_differs("tp_table_xy_zero")
cr_scummvm_differs("tp_table_y_only")
