-- 2D primitives (DrawRectangle, DrawLine, DrawPolygon) in white on cr_flat, seen through cr_snap(key, "count"): the box of
-- the bright pixels and how many there are. Which pixels a primitive covers: its right and bottom edges, the thickness of
-- its lines, the screen's edges. (GfxTinyGL::drawRectangle and drawPolygon add 1 to some corners, copied from GfxOpenGL.)

cr_prim_test = function(name, fn)
	cr_test("prim_" .. name, function()
		MakeCurrentSet("cr_flat.set")
		cr_frames(2)
		local p = %fn(MakeColor(255, 255, 255))
		cr_frames(3)
		cr_snap("px", "count")
		KillPrimitive(p)
		cr_frames(2)
		cr_snap("gone", "count")
	end)
end

cr_prim_test("rect_filled", function(c)
	return DrawRectangle(100, 100, 199, 149, { color = c, filled = TRUE })
end)

cr_prim_test("rect_outline", function(c)
	return DrawRectangle(100, 100, 199, 149, { color = c })
end)

cr_prim_test("rect_filled_point", function(c)
	return DrawRectangle(300, 200, 300, 200, { color = c, filled = TRUE })
end)

cr_prim_test("rect_filled_screen", function(c)
	return DrawRectangle(0, 0, 639, 479, { color = c, filled = TRUE })
end)

cr_prim_test("rect_outline_screen", function(c)
	return DrawRectangle(0, 0, 639, 479, { color = c })
end)

cr_prim_test("rect_outline_reversed", function(c)
	return DrawRectangle(199, 149, 100, 100, { color = c })
end)

cr_prim_test("line_h", function(c)
	return DrawLine(100, 100, 200, 100, { color = c })
end)

cr_prim_test("line_v", function(c)
	return DrawLine(100, 100, 100, 200, { color = c })
end)

cr_prim_test("line_diag", function(c)
	return DrawLine(100, 100, 200, 150, { color = c })
end)

cr_prim_test("line_back", function(c)
	return DrawLine(200, 150, 100, 100, { color = c })
end)

cr_prim_test("line_edge", function(c)
	return DrawLine(0, 479, 639, 479, { color = c })
end)

cr_prim_test("polygon", function(c)
	return DrawPolygon({ 100, 100, 200, 100, 200, 150, 100, 150 }, { color = c })
end)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("prim_line_back")
cr_scummvm_differs("prim_line_diag")
cr_scummvm_differs("prim_line_edge")
cr_scummvm_differs("prim_line_h")
cr_scummvm_differs("prim_line_v")
cr_scummvm_differs("prim_polygon")
cr_scummvm_differs("prim_rect_outline")
cr_scummvm_differs("prim_rect_outline_reversed")
cr_scummvm_differs("prim_rect_outline_screen")
