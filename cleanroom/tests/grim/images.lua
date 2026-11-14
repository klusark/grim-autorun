-- The image writers and readers of the game (stdWriteImage 0x473810, stdLoadImage 0x473630: the format from the extension).
-- PrintDebug("CRSNAP:<file>") writes the screen with the game's own screenshot code (sputRender_SaveDrawBuffer 0x487340:
-- the back buffer as a 24-bit bitmap, handed to stdWriteImage), so each format's writer runs on a known scene: white text
-- on cr_flat's dark background. The file is then read with Lua's io library: its first bytes (up to the first zero).
--
-- Only .bmp, .bm and .zbm are read back with GetImage. GetImage treats the pixels as 16-bit (sputRender_ColorCorrect over
-- width * height shorts): the 8-bit bitmaps of the .gif, .pcx and .lbm readers would be overrun, and BlastImage of the
-- 24-bit screen bitmap copies rows wider than the screen's. Neither is done here. (The files are not cr_snap's: run.py does
-- not read them.)

cr_im_font = function()
	if not CR_IM_FONT then
		CR_IM_FONT = LockFont("cr_font.laf")
	end
	return CR_IM_FONT
end

-- white text at (x, y), drawn for two frames; returns the text object
cr_im_scene = function(text, x, y)
	MakeCurrentSet("cr_flat.set")
	local t = MakeTextObject(text, { font = cr_im_font(), fgcolor = MakeColor(255, 255, 255), x = x, y = y })
	cr_frames(2)
	return t
end

-- the start of a file: its bytes up to the first zero byte, at most n (Lua 3.1's read stops at a zero byte: its strings
-- end there). readfrom opens the file in text mode, the same on every engine.
cr_im_file = function(key, file, n)
	if not readfrom(file) then
		cr_log(key .. "_file", nil)
		return
	end
	local head, len = "", 0
	local c = read(".")
	while c and len < (n or 64) do
		head = head .. ascii(c) .. " "
		len = len + 1
		c = read(".")
	end
	readfrom()
	cr_log(key .. "_head", len, head)
end

-- the screen with text, written as file
cr_im_write = function(file, text, x, y)
	local t = cr_im_scene(text, x, y)
	PrintDebug("CRSNAP:" .. file)
	cr_frames(1)
	KillTextObject(t)
	cr_frames(1)
end

local formats = { "bmp", "gif", "pcx", "lbm", "bm", "zbm" }
local i = 1
while formats[i] do
	cr_test("image_write_" .. formats[i], function()
		local f = "cr_im_w." .. %formats[%i]
		cr_im_write(f, "WRITE 42", 200, 150)
		cr_im_file("file", f)
	end)
	i = i + 1
end

-- the same scene twice gives the same file; another scene another one
cr_t_image_write_again = function()
	cr_im_write("cr_im_a1.gif", "SAME", 100, 100)
	cr_im_write("cr_im_a2.gif", "SAME", 100, 100)
	cr_im_write("cr_im_a3.gif", "OTHER TEXT", 300, 200)
	cr_im_file("first", "cr_im_a1.gif")
	cr_im_file("second", "cr_im_a2.gif")
	cr_im_file("other", "cr_im_a3.gif")
end
cr_scummvm_differs("image_write_again") cr_test("image_write_again", cr_t_image_write_again)

-- an empty screen (only the background) in the run-length formats
cr_t_image_write_plain = function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(2)
	PrintDebug("CRSNAP:cr_im_p.pcx")
	PrintDebug("CRSNAP:cr_im_p.lbm")
	PrintDebug("CRSNAP:cr_im_p.gif")
	cr_frames(1)
	cr_im_file("pcx", "cr_im_p.pcx")
	cr_im_file("lbm", "cr_im_p.lbm")
	cr_im_file("gif", "cr_im_p.gif")
end
cr_scummvm_differs("image_write_plain") cr_test("image_write_plain", cr_t_image_write_plain)

-- the extension in upper case; an extension no writer knows (nothing is written)
cr_t_image_write_ext = function()
	cr_im_write("CR_IM_UP.PCX", "UPPER", 50, 50)
	cr_im_file("upper", "CR_IM_UP.PCX")
	cr_im_write("cr_im_w.xyz", "UNKNOWN", 50, 50)
	cr_im_file("unknown", "cr_im_w.xyz")
	cr_log("read_unknown", type(GetImage("cr_im_w.xyz")))
end
cr_scummvm_differs("image_write_ext") cr_test("image_write_ext", cr_t_image_write_ext)

-- the 24-bit formats read back (GetImage, then FreeImage: the bitmap is not drawn)
local readable = { "bmp", "bm", "zbm" }
i = 1
while readable[i] do
	cr_test("image_read_" .. readable[i], function()
		local f = "cr_im_r." .. %readable[%i]
		cr_im_write(f, "READ", 120, 80)
		local img = GetImage(f)
		cr_log("image", type(img))
		if img then
			FreeImage(img)
		end
		cr_frames(1)
		cr_log("ok", 1)
	end)
	i = i + 1
end

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("image_read_bm")
cr_scummvm_differs("image_read_bmp")
cr_scummvm_differs("image_read_zbm")
cr_scummvm_differs("image_write_bm")
cr_scummvm_differs("image_write_bmp")
cr_scummvm_differs("image_write_gif")
cr_scummvm_differs("image_write_lbm")
cr_scummvm_differs("image_write_pcx")
cr_scummvm_differs("image_write_zbm")
