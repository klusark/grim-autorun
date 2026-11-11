-- ChangePrimitive calls that end ScummVM in an assert (lua_v1_graphics.cpp: xoffset / yoffset are assert(0), and
-- PrimitiveObject::setEndpoint asserts that the primitive is a line) and a movie whose name is
-- shorter than 4 characters (movie/smush.cpp:149 erases the last 4 for the Theora name): in a file of their own, after zz_gl1.lua, since a
-- crash restarts the run at the first test of the file that crashed.

cr_scummvm_differs("gl1_prim_offset", "ChangePrimitive with xoffset / yoffset asserts (lua_v1_graphics.cpp:306); the original moves the primitive") cr_test("gl1_prim_offset", function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(2)
	local p = DrawRectangle(100, 100, 199, 149, { color = MakeColor(255, 255, 255), filled = TRUE })
	cr_log("r", ChangePrimitive(p, { xoffset = 10, yoffset = 5 }))
	cr_frames(2)
	cr_snap("px", "count")
	KillPrimitive(p)
	cr_frames(2)
end)

cr_scummvm_differs("gl1_prim_rect_end", "ChangePrimitive with x2 / y2 of a rectangle asserts (primitives.cpp:134); the original resizes it") cr_test("gl1_prim_rect_end", function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(2)
	local p = DrawRectangle(100, 100, 199, 149, { color = MakeColor(255, 255, 255), filled = TRUE })
	cr_log("r", ChangePrimitive(p, { x2 = 300, y2 = 300 }))
	cr_frames(2)
	cr_snap("px", "count")
	KillPrimitive(p)
	cr_frames(2)
end)

cr_scummvm_differs("gl1_movie_short_name", "StartMovie of a name shorter than 4 characters crashes (movie/smush.cpp:149 erase)") cr_test("gl1_movie_short_name", function()
	cr_log("num", StartMovie(5))
	cr_log("short", StartMovie("ab"))
	cr_frames(2)
	cr_log("playing", IsMoviePlaying())
end)

-- (SubmitSaveGameData outside a save crashes the original, and ends ScummVM with error(): not tested)

-- SpewStartup (a debug builtin: nothing on ScummVM)
cr_test("gl1_spew_startup", function()
	cr_log("r", SpewStartup())
end)
