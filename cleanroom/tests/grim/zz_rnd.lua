-- The renderers (assets_extra_rnd.py): what the tests elsewhere do not draw yet. Most are drawn on cr_lit (black, the far
-- z-buffer of cr_open) and seen through cr_snap(key, "mean"): the box of what is not black, how many pixels and their
-- mean brightness.
-- - bitmaps: one with the transparent colour (magenta, 0xf81f) in it, BlastImage at the screen's corners, an object state
--   of two images placed by its header (with a z-buffer image of two), switched by a costume's bitmap component;
-- - materials with transparent texels (index 0), marked as having alpha or not;
-- - text in the colour TinyGL keys its text images with (pure green), fonts of other sizes, with an outline colour;
-- - a camera straight above its interest, a set with more lights than a renderer takes, a box across the near plane
--   and a talking box below the screen.

-- (a full redraw of cr_lit: BlastImage draws into the original's back buffer, which keeps it until it is redrawn)
cr_rnd_lit = function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(2)
	MakeCurrentSet("cr_lit.set")
	cr_frames(2)
end

-- BlastImage every frame (as the game's menu does), the snap at the third
cr_rnd_blast = function(key, img, x, y, transparent)
	local i = 0
	while i < 4 do
		BlastImage(img, x, y, transparent)
		i = i + 1
		if i == 3 then
			cr_snap(key, "mean")
		end
		break_here()
	end
end

cr_t_rnd_blast_key = function()
	cr_rnd_lit()
	local img = GetImage("rnd_key.bm")
	cr_log("type", type(img))
	cr_rnd_blast("opaque", img, 100, 100, nil)
	cr_rnd_lit()
	cr_rnd_blast("transparent", img, 100, 100, TRUE)
	FreeImage(img)
	cr_rnd_lit()
end
cr_scummvm_differs("rnd_blast_key", "BlastImage draws at the call, outside the scene: ScummVM's snap, the scene drawn again, has none of it") cr_test("rnd_blast_key", cr_t_rnd_blast_key)

-- a bitmap half off each edge of the screen
CR_RND_EDGES = { { "left_top", -32, -24 }, { "right_bottom", 608, 456 }, { "right_top", 620, -40 }, { "left_bottom", -60, 470 } }
cr_t_rnd_blast_edges = function()
	local img = GetImage("rnd_plain.bm")
	local i = 1
	while CR_RND_EDGES[i] do
		local e = CR_RND_EDGES[i]
		cr_rnd_lit()
		cr_rnd_blast(e[1], img, e[2], e[3], nil)
		i = i + 1
	end
	FreeImage(img)
	cr_rnd_lit()
end
cr_scummvm_differs("rnd_blast_edges", "BlastImage draws at the call, outside the scene: ScummVM's snap, the scene drawn again, has none of it") cr_test("rnd_blast_edges", cr_t_rnd_blast_edges)

-- an object state of two images at 200, 150 (its header), with a z-buffer image: the costume's bitmap component shows
-- image 2 (grey, its left half transparent), 1 (white), none and 2 again
cr_t_rnd_objstate = function()
	cr_rnd_lit()
	local s = NewObjectState(0, 3, "rnd_anim.bm", "rnd_anim.zbm", TRUE)
	cr_log("state", type(s))
	local a = LoadActor("rnd_bk")
	PutActorInSet(a, "cr_lit.set")
	PutActorAt(a, 0, 0, 0)
	SetActorCostume(a, "rnd_bk.cos")
	cr_frames(2)
	cr_snap("start", "mean")
	local chores = { { "img2", 1 }, { "img1", 0 }, { "img0", 2 }, { "img2_again", 1 } }
	local i = 1
	while chores[i] do
		PlayActorChore(a, chores[i][2], "rnd_bk.cos")
		cr_frames(8)
		cr_snap(chores[i][1], "mean")
		i = i + 1
	end
	PutActorInSet(a, nil)
	cr_frames(2)
	cr_snap("actor_gone", "mean")
	cr_rnd_lit()
end
cr_scummvm_differs("rnd_objstate", "the original leaves the old picture where an object state's image is hidden or transparent; ScummVM's white is 255, the original's 249.3 (RGB 565)") cr_test("rnd_objstate", cr_t_rnd_objstate)

-- the box with a checker of white and transparent texels, its material marked as having alpha (rnd_holes) or not
cr_rnd_box = function(key, cos, x, y, z)
	local a = LoadActor("rnd_box")
	PutActorInSet(a, "cr_lit.set")
	PutActorAt(a, x or 0, y or 0, z or 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, cos)
	cr_frames(2)
	cr_snap(key, "mean")
	return a
end

cr_t_rnd_holes = function()
	MakeCurrentSet("cr_lit.set")
	local a = cr_rnd_box("alpha", "rnd_holes.cos")
	SetActorCostume(a, "rnd_holes0.cos")
	cr_frames(2)
	cr_snap("no_alpha", "mean")
	SetActorCostume(a, "cr_dbox.cos")
	cr_frames(2)
	cr_snap("white", "mean")
	SetActorCostume(a, "rnd_mixed.cos")
	cr_frames(2)
	cr_snap("mixed", "mean")
	PutActorInSet(a, nil)
end
cr_scummvm_differs("rnd_holes", "ScummVM draws the texels of index 0 blended (linear filtering) or opaque; the original leaves them out") cr_test("rnd_holes", cr_t_rnd_holes)

-- text: pure green (the colour key of TinyGL's text images), grey, and the fonts of other sizes
cr_rnd_text = function(key, text, font, colour)
	local t = MakeTextObject(text, { font = LockFont(font), fgcolor = colour, x = 100, y = 200 })
	cr_frames(2)
	cr_log(key .. "_size", GetTextObjectDimensions(t))
	cr_snap(key, "mean")
	KillTextObject(t)
	cr_frames(1)
end

cr_t_rnd_text_colours = function()
	MakeCurrentSet("cr_lit.set")
	cr_frames(1)
	cr_rnd_text("green", "Green text", "cr_font.laf", MakeColor(0, 255, 0))
	cr_rnd_text("grey", "Grey text", "cr_font.laf", MakeColor(128, 128, 128))
	cr_rnd_text("white", "White text", "cr_font.laf", MakeColor(255, 255, 255))
end
cr_scummvm_differs("rnd_text_colours", "ScummVM draws the text 3 pixels lower (the top of the characters at y; the original's at y + 5 - baseline); ScummVM's white is 255, the original's 249.3 (RGB 565)") cr_test("rnd_text_colours", cr_t_rnd_text_colours)

cr_t_rnd_fonts = function()
	MakeCurrentSet("cr_lit.set")
	cr_frames(1)
	cr_rnd_text("f5", "Small", "rnd_f5.laf", MakeColor(255, 255, 255))
	cr_rnd_text("f20", "Big", "rnd_f20.laf", MakeColor(255, 255, 255))
	cr_rnd_text("f40", "Huge", "rnd_f40.laf", MakeColor(255, 255, 255))
end
cr_scummvm_differs("rnd_fonts", "ScummVM puts the top of the characters at y whatever the font's baseline; the original at y + 5 - baseline; ScummVM's white is 255, the original's 249.3 (RGB 565)") cr_test("rnd_fonts", cr_t_rnd_fonts)

-- a camera straight above its interest (ScummVM takes another up vector there): the white box at the origin and at 1, 1
cr_t_rnd_cam_down = function()
	MakeCurrentSet("rnd_down.set")
	cr_frames(2)
	local a = cr_dr_actor("rnd_down", "cr_dbox.cos", 0, 0, 0)
	PutActorInSet(a, "rnd_down.set")
	cr_frames(2)
	cr_snap("origin")
	PutActorAt(a, 1, 1, 0)
	cr_frames(2)
	cr_snap("moved")
	SetActorRot(a, 0, 30, 0)
	cr_frames(2)
	cr_snap("turned")
	PutActorInSet(a, nil)
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
end
cr_scummvm_differs("rnd_cam_down", "ScummVM's box is one pixel smaller (as draw.lua's)") cr_test("rnd_cam_down", cr_t_rnd_cam_down)

-- 34 lights (ScummVM's GL renderers set up 8, TinyGL 32): the lit box (zz_lit.lua: the original lights it by its vertices only)
cr_scummvm_differs("rnd_lights_many", "ScummVM lights the box with the set's lights, not at its vertices' level")
cr_t_rnd_lights_many = function()
	MakeCurrentSet("rnd_lights.set")
	cr_frames(1)
	local a = LoadActor("rnd_lit")
	PutActorInSet(a, "rnd_lights.set")
	PutActorAt(a, 0, 0, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, "cr_lbox.cos")
	LightMgrSetChange()
	cr_frames(2)
	cr_snap("unlit", "mean")
	-- (ScummVM: the lights of a text set are off until SetAmbientLight(0))
	SetAmbientLight(0)
	LightMgrSetChange()
	cr_frames(2)
	cr_snap("lit", "mean")
	PopActorCostume(a)
	PutActorInSet(a, nil)
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
end
cr_test("rnd_lights_many", cr_t_rnd_lights_many)

-- the box across the camera's near plane and around the camera (cr_lit's camera is at 0, -0.5, 6, looking at the origin)
cr_t_rnd_near = function()
	MakeCurrentSet("cr_lit.set")
	local a = cr_rnd_box("start", "cr_dbox.cos")
	PutActorAt(a, 0, -0.45, 5.8)
	cr_frames(2)
	cr_snap("across", "mean")
	PutActorAt(a, 0.3, -0.2, 5.5)
	cr_frames(2)
	cr_snap("near", "mean")
	PutActorAt(a, 0, -0.5, 5.9)
	SetActorScale(a, 4)
	cr_frames(2)
	cr_snap("around", "mean")
	SetActorScale(a, 1)
	PutActorAt(a, 0, -1, 7)
	cr_frames(2)
	cr_snap("behind", "mean")
	PutActorInSet(a, nil)
end
cr_scummvm_differs("rnd_near", "ScummVM's white is 255, the original's 249.3 (RGB 565); the box one pixel off") cr_test("rnd_near", cr_t_rnd_near)

-- a talking box below the screen's bottom and right edges: where its line goes (ScummVM: from the box of the model on the
-- screen, cut at the screen's edges)
CR_RND_LOW = { { "low", 0, -2.3 }, { "lower", 0, -2.8 }, { "corner", 3.2, -2.4 } }
cr_t_rnd_say_low = function()
	MakeCurrentSet("cr_open.set")
	cr_frames(2)
	local i = 1
	while CR_RND_LOW[i] do
		local p = CR_RND_LOW[i]
		local a = cr_dr_actor("rnd_say", "cr_gbox.cos", p[2], p[3], 0)
		SetActorTalkColor(a, MakeColor(255, 255, 255))
		cr_frames(2)
		cr_dr_rect(p[1] .. "_rect", a)
		cr_tp_say(p[1], a)
		PutActorInSet(a, nil)
		i = i + 1
	end
	SetTextSpeed(7)
end
cr_scummvm_differs("rnd_say_low", "GetActorRect is 1 on ScummVM; the line of an actor at the screen's edge is placed elsewhere") cr_test("rnd_say_low", cr_t_rnd_say_low)
