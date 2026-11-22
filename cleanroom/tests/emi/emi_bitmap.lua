-- EMI's set backgrounds (.til, drawn in 256x256 tiles), seen through cr_snap(key, "lit"): the box of the background's
-- pixels. GfxTinyGL::drawBitmap adds 1 to both corners of every tile (b751942f138, "broken lines at edges of tiled
-- bitmaps"), GfxOpenGL does not. On the original (pictures with -gl since 2026-11-21) the box is the whole screen, as with
-- ScummVM's OpenGL renderers; TinyGL's starts at (1, 1).
cr_scummvm_differs("emi_bitmap_flat", "TinyGL (software) draws the tiles from (1, 1); OpenGL and the original from (0, 0)")
cr_test("emi_bitmap_flat", function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(3)
	cr_snap("lit", "lit")
	cr_snap("count", "count")
end)
