-- Text object keys the other tests leave out (height, duration and coords as numbers, bgcolor and fxcolor), and the
-- concatenation fallback with a userdata that is not an actor (a colour: the old fallback, an error) and with an actor.
-- (cr_font.laf: see text.lua)

cr_ctk_dims = function(key, t)
	if t then
		local w, h = GetTextObjectDimensions(t)
		cr_log(key, w, h)
	else
		cr_log(key, nil)
	end
end

cr_t_ctk_keys = function()
	MakeCurrentSet("cr_flat.set")
	local f = LockFont("cr_font.laf")
	local t = MakeTextObject("Keys 12", { font = f, x = 10, y = 20, height = 30, width = 200, duration = 200, coords = 1,
		bgcolor = MakeColor(10, 20, 30), fxcolor = MakeColor(40, 50, 60), fgcolor = MakeColor(255, 255, 255) })
	cr_ctk_dims("made", t)
	cr_frames(2)
	cr_ctk_dims("after_frames", t)
	ChangeTextObject(t, { height = 5, duration = 0, coords = 0, x = 30, y = 40 })
	cr_ctk_dims("changed", t)
	ChangeTextObject(t, { height = "tall", duration = "long", coords = "c" })
	cr_ctk_dims("changed_strings", t)
	KillTextObject(t)
end
cr_test("ctk_keys", cr_t_ctk_keys)

cr_t_ctk_concat = function()
	local c = MakeColor(1, 2, 3)
	cr_log("color", call(function(x) return "x" .. x end, { c }, "x", nil))
	cr_log("color_left", call(function(x) return x .. "x" end, { c }, "x", nil))
	cr_log("nil_right", call(function(x) return "x" .. x end, { nil }, "x", nil))
	local a = cr_actor("cr_flat.set")
	local s = "x" .. a
	cr_log("actor_type", type(s), strsub(s, 1, 1))
	local f = LockFont("cr_font.laf")
	cr_log("font", call(function(x) return "x" .. x end, { f }, "x", nil))
end
cr_test("ctk_concat", cr_t_ctk_concat)
