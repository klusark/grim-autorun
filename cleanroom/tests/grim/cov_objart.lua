-- A setup with background objects of its own (cov_objart.set of assets_extra_cov.py: object_art and object_z,
-- Set::Setup::load): three white bitmaps at the top left, art1 40 x 30 with its z-buffer, art2 20 x 60 without one,
-- art3 80 x 10 with the z-buffer of another name. The box of the white pixels says which are drawn.

cr_t_cov_objart = function()
	MakeCurrentSet("cov_objart.set")
	cr_frames(3)
	cr_snap("drawn", "count")
	cr_log("setup", GetCurrentSetup("cov_objart.set"))
	MakeCurrentSet("cr_flat.set")
	cr_frames(2)
	cr_snap("other_set", "count")
	MakeCurrentSet("cov_objart.set")
	cr_frames(2)
	cr_snap("again", "count")
end
cr_scummvm_differs("cov_objart", "the original does not load a set whose setup has object_art lines (no current setup, nothing drawn); ScummVM loads it (set.cpp:414-425) and draws none of the objects either") cr_test("cov_objart", cr_t_cov_objart)

-- a codec 3 bitmap of short repeats (cov_short.bm: decompress_codec3's short copies), loaded and drawn
cr_t_cov_codec3_short = function()
	MakeCurrentSet("cr_flat.set")
	local img = GetImage("cov_short.bm")
	cr_log("image", type(img))
	if img then
		BlastImage(img, 0, 0)
		cr_frames(1)
		FreeImage(img)
	end
	cr_frames(1)
	cr_log("ok", 1)
end
cr_test("cov_codec3_short", cr_t_cov_codec3_short)
