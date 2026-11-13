-- The save files as files: FileFindFirst / FileFindNext / FileFindDispose over the saves, GetSaveGameImage (the thumbnail
-- at the head of a save). No Load here.
-- On the original FileFindFirst(ext, dir) is stdFileUtil_NewFind(dir, 3, ext) (0x49e980): the pattern is dir .. "\" .. ext
-- when ext has a dot, else dir .. "\*." .. ext; with no dir, dir is "" (so "*.set" alone looks in the root of the drive,
-- which is why file_find of lua4.lua finds no set). FileFindNext skips folders. ScummVM ignores dir, takes ext as the
-- pattern of its save files and turns "*.gsv" into "grim##.gsv".
-- GetSaveGameImage: SaveGame_LoadThumbnail (0x483490) skips the head of the save and reads a 250 x 188 16-bit picture,
-- returned with the tag of ScreenShot's ('VBUF').

-- (the names FileFindFirst / FileFindNext give, at most 200)
cr_sf_list = function(ext, dir)
	local t = { }
	local n = 0
	local f
	if dir then
		f = FileFindFirst(ext, dir)
	else
		f = FileFindFirst(ext)
	end
	while f and n < 200 do
		n = n + 1
		t[n] = f
		f = FileFindNext()
	end
	FileFindDispose()
	return t, n
end

-- (the grim##.gsv names of a list, in its order, as one string, and how many other names it has)
cr_sf_grim = function(t)
	local s = ""
	local other = 0
	local i = 1
	while t[i] do
		if strfind(strlower(t[i]), "^grim%d%d%.gsv$") then
			s = s .. " " .. strlower(t[i])
		else
			other = other + 1
		end
		i = i + 1
	end
	return s, other
end

-- (once: the two saves the tests look for, made in cr_flat with a white word on the screen)
CR_SF_SAVED = nil
cr_sf_saves = function()
	if CR_SF_SAVED then
		return
	end
	CR_SF_SAVED = 1
	MakeCurrentSet("cr_flat.set")
	cr_frames(2)
	local t = MakeTextObject("Saved", { font = LockFont("cr_font.laf"), fgcolor = MakeColor(255, 255, 255), x = 300, y = 200 })
	cr_frames(2)
	cr_save("grim07.gsv")
	cr_save("grim03.gsv")
	KillTextObject(t)
	cr_frames(1)
end

-- the folder given: both saves, in the order of their names
cr_t_save_find_dir = function()
	cr_sf_saves()
	local t, n = cr_sf_list("*.gsv", ".")
	local s, other = cr_sf_grim(t)
	cr_log("grim", s)
	cr_log("any", n > 0)
end
cr_test("save_find_dir", cr_t_save_find_dir)

-- the other .gsv files of the folder (the saves of save.lua): the original lists every one
cr_t_save_find_others = function()
	cr_sf_saves()
	local t, n = cr_sf_list("*.gsv", ".")
	local s, other = cr_sf_grim(t)
	cr_log("others", other > 0)
end
cr_scummvm_differs("save_find_others", "ScummVM lists only grim##.gsv for *.gsv") cr_test("save_find_others", cr_t_save_find_others)

-- no folder: the original looks in the root of the drive
cr_t_save_find_nodir = function()
	cr_sf_saves()
	local t, n = cr_sf_list("*.gsv")
	local s, other = cr_sf_grim(t)
	cr_log("grim", s)
end
cr_scummvm_differs("save_find_nodir", "ScummVM ignores the folder argument") cr_test("save_find_nodir", cr_t_save_find_nodir)

-- an extension without a dot: the original makes "*.gsv" of it
cr_t_save_find_bare = function()
	cr_sf_saves()
	local t, n = cr_sf_list("gsv", ".")
	local s, other = cr_sf_grim(t)
	cr_log("grim", s)
end
cr_scummvm_differs("save_find_bare", "ScummVM takes the extension as the whole pattern") cr_test("save_find_bare", cr_t_save_find_bare)

-- one name only, a pattern without a wildcard
cr_t_save_find_one = function()
	cr_sf_saves()
	local t, n = cr_sf_list("grim03.gsv", ".")
	cr_log("n", n)
	cr_log("first", t[1] and strlower(t[1]))
	local t2, n2 = cr_sf_list("grim99.gsv", ".")
	cr_log("none", n2)
end
cr_test("save_find_one", cr_t_save_find_one)

-- FileFindNext past the end, after a dispose, and with no find at all
cr_t_save_find_end = function()
	cr_sf_saves()
	local f = FileFindFirst("grim03.gsv", ".")
	cr_log("first", f and strlower(f))
	cr_log("next", FileFindNext())
	cr_log("again", FileFindNext())
	FileFindDispose()
	cr_log("disposed", FileFindNext())
	f = FileFindFirst("*.gsv", ".")
	cr_log("restart", f ~= nil)
	FileFindDispose()
	cr_log("dispose_mid", FileFindNext())
	FileFindDispose()
	FileFindDispose()
	cr_log("twice", FileFindNext())
end
cr_test("save_find_end", cr_t_save_find_end)

-- a second FileFindFirst while one goes on starts over
cr_t_save_find_restart = function()
	cr_sf_saves()
	local a = FileFindFirst("grim03.gsv", ".")
	local b = FileFindFirst("grim07.gsv", ".")
	cr_log("a", a and strlower(a))
	cr_log("b", b and strlower(b))
	cr_log("next", FileFindNext())
	FileFindDispose()
end
cr_test("save_find_restart", cr_t_save_find_restart)

-- the thumbnail of a save: a picture of ScreenShot's kind, which FreeImage takes
cr_t_save_image = function()
	cr_sf_saves()
	local img = GetSaveGameImage("grim07.gsv")
	cr_log("type", type(img))
	local shot = ScreenShot(160, 120)
	cr_log("same_tag", img and shot and tag(img) == tag(shot))
	cr_log("other", type(GetSaveGameImage("grim03.gsv")))
	cr_log("missing", GetSaveGameImage("grim99.gsv"))
	if img then
		FreeImage(img)
	end
	if shot then
		FreeImage(shot)
	end
end
cr_test("save_image", cr_t_save_image)

-- the thumbnail drawn with BlastImage every frame on the black background of cr_lit: the box of what is not dark (at 100,
-- 100, 250 x 188) and its mean brightness. On the original the thumbnail is the set's background drawn again, dimmed
-- (Render_CaptureThumbnail 0x486f90: Render_DimBackground, then scaled to 250 x 188), without the text on the screen.
-- BlastImage (0x4a3130) blits into the back buffer, which the original redraws only where something changed: the picture
-- stays after FreeImage. ScummVM's save takes its thumbnail from the stored display (getScreenshot(250, 188, true)),
-- which DimScreen stores (the menu calls it): with OpenGL it is black here; with the shader and software renderers it is
-- the scene, darker than the original's (a mean of 64.9 against 104; the test patch's cr_snap stores the display of the
-- software renderer). (Outside RenderModeUser ScummVM's cr_snap draws the scene again before it takes the picture.)
cr_sf_blast = function(user)
	cr_sf_saves()
	MakeCurrentSet("cr_lit.set")
	cr_frames(2)
	local img = GetSaveGameImage("grim07.gsv")
	if not img then
		cr_log("img", nil)
		return
	end
	if user then
		RenderModeUser(TRUE)
	end
	local i = 0
	while i < 4 do
		BlastImage(img, 100, 100, nil)
		i = i + 1
		if i == 3 then
			cr_snap("blast", "mean")
		end
		break_here()
	end
	FreeImage(img)
	cr_frames(2)
	cr_snap("after", "mean")
	if user then
		RenderModeUser(nil)
		cr_frames(2)
	end
end
cr_t_save_image_blast = function()
	cr_sf_blast(nil)
end
cr_scummvm_differs("save_image_blast", "ScummVM's thumbnail: black (OpenGL) or darker") cr_test("save_image_blast", cr_t_save_image_blast)

-- the same in RenderModeUser(TRUE), as the game's menu draws the thumbnails of its saves
cr_t_save_image_blast_user = function()
	cr_sf_blast(TRUE)
end
cr_scummvm_differs("save_image_blast_user", "ScummVM's thumbnail: black (OpenGL) or darker") cr_test("save_image_blast_user", cr_t_save_image_blast_user)

-- a save made after DimScreen, as the game's menu does it (DimScreen stores ScummVM's display, from which its save takes
-- the thumbnail): the thumbnail blasted on cr_lit, in RenderModeUser. With OpenGL ScummVM's is the screen as DimScreen left
-- it, almost black (16 to 20 of 255 in cr_flat's checks); the original's is grey (88 and 120)
cr_t_save_image_dim = function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(2)
	RenderModeUser(TRUE)
	DimScreen()
	cr_frames(1)
	Save("crdim.gsv")
	cr_frames(3)
	CleanBuffer()
	RenderModeUser(nil)
	cr_frames(2)
	MakeCurrentSet("cr_lit.set")
	cr_frames(2)
	local img = GetSaveGameImage("crdim.gsv")
	cr_log("type", type(img))
	if not img then
		return
	end
	RenderModeUser(TRUE)
	BlastImage(img, 100, 100, nil)
	cr_snap("blast", "mean")
	cr_frames(1)
	FreeImage(img)
	RenderModeUser(nil)
	cr_frames(2)
end
cr_scummvm_differs("save_image_dim", "ScummVM's thumbnail: almost black (OpenGL) or darker") cr_test("save_image_dim", cr_t_save_image_dim)
