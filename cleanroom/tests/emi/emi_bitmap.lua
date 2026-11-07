-- EMI's set backgrounds (.til, drawn in 256x256 tiles), seen through cr_snap(key, "lit"): the box of the background's
-- pixels. GfxTinyGL::drawBitmap adds 1 to both corners of every tile (b751942f138, "broken lines at edges of tiled
-- bitmaps"), GfxOpenGL does not. (The original's EMI has no screenshot in the clean room: the snaps are "missing" there.)
cr_test("emi_bitmap_flat", function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(3)
	cr_snap("lit", "lit")
	cr_snap("count", "count")
end)
