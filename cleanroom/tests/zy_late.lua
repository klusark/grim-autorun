-- Builtins with side effects, run late (just before the argument probe): Lua's file library on a scratch file in the
-- game folder, the error method and fallbacks (put back afterwards), dofile, render mode, devices, iMuse state, missing
-- movies, detaching and attaching the resources. Not tested: the dialogs (they wait for input), SetGamma (the gamma of
-- the desktop), execute, Load and Save (they replace the running state).

cr_t_io_write_read = function()
	CR_IO_OK = writeto("cr_io_test.txt")
	cr_log("writeto", type(CR_IO_OK))
	write("first line\n")
	write("second ", 42, "\n")
	writeto()
	cr_log("readfrom", type(readfrom("cr_io_test.txt")))
	cr_log("line1", read("*l"))
	cr_log("line2", read("*l"))
	cr_log("eof", read("*l"))
	readfrom()
	cr_log("appendto", type(appendto("cr_io_test.txt")))
	write("third\n")
	writeto()
	readfrom("cr_io_test.txt")
	read("*l")
	read("*l")
	cr_log("appended", read("*l"))
	readfrom()
	local f = cr_fn("rename")
	if f then
		cr_log("rename", type(f("cr_io_test.txt", "cr_io_test2.txt")))
		cr_log("removed", type(remove("cr_io_test2.txt")))
	else
		cr_log("removed", type(remove("cr_io_test.txt")))
	end
	cr_log("remove_missing", remove("cr_no_such_file.txt"))
	cr_log("readfrom_missing", readfrom("cr_no_such_file.txt"))
end
cr_test("io_write_read", cr_t_io_write_read)

cr_t_errormethod = function()
	CR_EM = nil
	local old = seterrormethod(cr_t_em)
	cr_log("old_type", type(old))
	dostring("local x = nil; x.y = 1")
	cr_log("called", CR_EM ~= nil)
	seterrormethod(cr_error)
end
cr_t_em = function(m)
	CR_EM = m
end
cr_test("errormethod", cr_t_errormethod)

cr_t_fallback = function()
	local old = setfallback("index", cr_t_fb_index)
	cr_log("old_type", type(old))
	local t = { }
	cr_log("index", t.anything)
	setfallback("index", old)
	cr_log("restored", t.anything)
end
cr_t_fb_index = function(t, k)
	return "fb:" .. k
end
cr_test("fallback", cr_t_fallback)

cr_t_dofile = function()
	CR_DOFILE = nil
	cr_log("ok", dofile("cr_dofile_target.lua"))
	cr_log("ran", CR_DOFILE)
	cr_log("missing", dofile("cr_no_such_file.lua"))
end
cr_test("dofile", cr_t_dofile)

cr_t_print_stack = function()
	print_stack()
	print("cr print line")
	cr_log("ok", 1)
end
cr_test("print_stack", cr_t_print_stack)

cr_t_render_mode = function()
	RenderModeUser(TRUE)
	cr_frames(2)
	RenderModeUser(nil)
	cr_frames(2)
	EngineDisplay(TRUE)
	cr_frames(1)
	cr_log("ok", 1)
end
cr_test("render_mode", cr_t_render_mode)

cr_t_devices = function()
	cr_log("video", type(GetVideoDevices()))
	cr_log("enumerate", type(EnumerateVideoDevices()))
	cr_log("enumerate3d", type(Enumerate3DDevices()))
end
cr_test("devices", cr_t_devices)

cr_t_imuse_state = function()
	SaveIMuse()
	RestoreIMuse()
	cr_log("ok", 1)
end
cr_test("imuse_state", cr_t_imuse_state)

cr_t_movie_missing = function()
	cr_log("start", StartMovie("no_such.snm", nil, 0, 0))
	cr_frames(2)
	cr_log("playing", IsMoviePlaying())
	StopMovie()
	cr_log("fullscreen", StartFullscreenMovie("no_such.snm"))
	cr_frames(2)
	cr_log("fullscreen_playing", IsFullscreenMoviePlaying())
end
cr_test("movie_missing", cr_t_movie_missing)

cr_t_screenshot = function()
	local s = ScreenShot(160, 120)
	cr_log("shot", type(s))
	if s then
		FreeImage(s)
	end
end
cr_test("screenshot", cr_t_screenshot)

-- (last: the archives and the folder are let go and taken again)
cr_t_resources = function()
	cr_log("before", CheckForFile("cr_flat.set"))
	DetachFromResources()
	cr_log("detached", CheckForFile("cr_flat.set"))
	AttachToResources()
	cr_log("attached", CheckForFile("cr_flat.set"))
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
	cr_log("set_after", GetCurrentSetup("cr_flat.set"))
end
cr_test("resources", cr_t_resources)
