-- EMI's side of the Lua builtins that Grim's lua_v1*.cpp gives both games: the primitives in EMI's coordinates (-1 to 1,
-- y up), changed (moved, a new end point), BlastRect (ScummVM's only), a text object with a layer. Monkey4.exe draws no picture for the clean room, so the values are what the builtins give.

cr_scummvm_differs("egl1_prims", "primitives are userdata on ScummVM, numbers on the original") cr_test("egl1_prims", function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
	local c = MakeColor(255, 255, 255)
	local l = DrawLine(-0.5, 0.5, 0.5, -0.5, { color = c, layer = 1 })
	cr_log("line", type(l))
	local r = DrawRectangle(-0.5, 0.5, 0.25, -0.25, { color = c, filled = TRUE })
	cr_log("rect", type(r))
	local p = DrawPolygon({ -0.5, 0.5, 0.5, 0.5, 0.5, -0.5, -0.5, -0.5 }, { color = c, layer = 2 })
	cr_log("polygon", type(p))
	cr_frames(2)
	cr_log("change_line", ChangePrimitive(l, { x = 0.1, y = 0.2, x2 = 0.3, y2 = -0.4 }))
	cr_log("change_rect", ChangePrimitive(r, { x = -0.1, y = 0.1 }))
	cr_log("change_poly", ChangePrimitive(p, { x = 0, y = 0 }))
	cr_frames(2)
	KillPrimitive(l)
	KillPrimitive(r)
	KillPrimitive(p)
	cr_frames(1)
end)

cr_scummvm_differs("egl1_blast_rect", "BlastRect is ScummVM's only") cr_test("egl1_blast_rect", function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
	local f = getglobal("BlastRect")
	cr_log("has", type(f))
	if f then
		cr_log("r", f(-0.5, 0.5, 0.5, -0.5, { color = MakeColor(255, 255, 255), filled = TRUE }))
		cr_log("outline", f(-0.5, 0.5, 0.5, -0.5, { color = MakeColor(255, 255, 255) }))
	end
	cr_frames(1)
end)

cr_test("egl1_text_layer", function()
	local t = MakeTextObject("Layered", { font = "cr_font.laf", x = -0.5, y = 0.5, layer = 3 })
	cr_log("type", type(t))
	cr_log("dims", GetTextObjectDimensions(t))
	ChangeTextObject(t, { layer = 1 })
	cr_log("changed", GetTextObjectDimensions(t))
	KillTextObject(t)
end)

-- (a text object saved and loaded, for TextObject::saveState's layer, is not here: Monkey4.exe's Save ends it in the clean
-- room, as emi_actor_save.lua's asv_emi_actor)
