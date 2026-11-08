-- ScummVM's patch files (assets.py: cr_patch_target.lua with cr_patch_target.lua.patchr, a patch for another file, and
-- cr_patch_target.lua_1.patchr, which makes "no" "yes" and adds a line; formats.patchr). ScummVM reads a file through its
-- first patch whose MD5 matches; the original has no patch files and reads the file as it is.

cr_scummvm_differs("patchr_dofile", "ScummVM only: its patch files")
cr_test("patchr_dofile", function()
	CR_PATCHED, CR_PATCH_LINE, CR_PATCH_MORE = nil, nil, nil
	dofile("cr_patch_target.lua")
	cr_log("values", CR_PATCHED, CR_PATCH_LINE, CR_PATCH_MORE)
	CR_PATCHED, CR_PATCH_LINE, CR_PATCH_MORE = nil, nil, nil
end)

-- read through the io library: each pattern that stops on a character puts it back (a seek back in the patched file)
cr_scummvm_differs("patchr_read", "ScummVM only: its patch files")
cr_test("patchr_read", function()
	if not readfrom("cr_patch_target.lua") then
		cr_log("no_file", 1)
		return
	end
	cr_log("word", read("[A-Z_]*"))
	cr_log("rest", read("[^\n]*"))
	cr_log("line2", read("{\n}[^\n]*"))
	cr_log("line3", read("{\n}[^\n]*"))
	readfrom()
end)
