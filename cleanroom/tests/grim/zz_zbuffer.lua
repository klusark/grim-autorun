-- The z-buffer of the background hides the parts of a model behind it, pixel by pixel: cr_zpost.set (assets.py) is
-- cr_open with a near post 2 pixels wide (columns 320, 321), a near bar 2 pixels high (rows 237, 238) and near columns
-- left of 290, in front of the white box of draw.lua (270..370 x 207..267 at the centre). Seen through
-- cr_snap(key, "count"): the box of the white pixels and how many there are. A z-buffer read filtered or half a pixel
-- off hides a third column / row, or moves the edge at 290 (ScummVM's OpenGL with shaders, the fence by the crane in
-- the beach).

cr_zb_test = function(name, fn)
	cr_test("zbuffer_" .. name, function()
		MakeCurrentSet("cr_zpost.set")
		cr_frames(2)
		%fn(%name)
	end)
end

cr_zb_actor = function(x, y)
	local a = LoadActor("cr_zb_a")
	PutActorInSet(a, "cr_zpost.set")
	PutActorAt(a, x, y, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, "cr_dbox.cos")
	return a
end

-- the box at the centre: the post, the bar and the near columns cut it
cr_zb_test("post", function(k)
	local a = cr_zb_actor(0, 0)
	cr_frames(2)
	cr_snap(k .. "_box", "count")
	PutActorInSet(a, nil)
end)

-- the box to the right, clear of the near columns: only the bar cuts it
cr_zb_test("bar", function(k)
	local a = cr_zb_actor(2, 0)
	cr_frames(2)
	cr_snap(k .. "_box", "count")
	PutActorInSet(a, nil)
end)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("zbuffer_bar")
cr_scummvm_differs("zbuffer_post")
