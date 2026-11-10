-- A LAB archive in the game folder (assets.py cr_extra.lab) beside the loose files: what is read from it, and which of a
-- file that is both loose and in the archive is read.

cr_t_lab_files = function()
	cr_log("check_archive", CheckForFile("cr_extra.lab"))
	cr_log("check_member", CheckForFile("cr_lab_only.lua"))
	cr_log("check_member_case", CheckForFile("CR_LAB_ONLY.LUA"))
	cr_log("check_dup", CheckForFile("cr_dup.lua"))
	cr_log("check_text", CheckForFile("cr_lab_text.txt"))
end
cr_test("lab_files", cr_t_lab_files)

cr_t_lab_dofile = function()
	CR_LAB = nil
	CR_DUP = nil
	cr_log("only", dofile("cr_lab_only.lua"), CR_LAB)
	cr_log("dup", dofile("cr_dup.lua"), CR_DUP)
	cr_log("missing", dofile("cr_lab_missing.lua"))
end
cr_test("lab_dofile", cr_t_lab_dofile)

cr_t_lab_costume = function()
	MakeCurrentSet("cr_flat.set")
	local a = LoadActor("cr_lab_a")
	PutActorInSet(a, "cr_flat.set")
	SetActorCostume(a, "cr_lab_box.cos")
	cr_log("costume", GetActorCostume(a))
	PlayActorChore(a, 0, "cr_lab_box.cos")
	cr_frames(3)
	cr_log("chore", IsActorChoring(a, 0, FALSE, "cr_lab_box.cos"), CR_LV)
	PutActorInSet(a, nil)
end
cr_test("lab_costume", cr_t_lab_costume)

cr_t_lab_text = function()
	cr_log("line_count", TextFileGetLineCount("cr_lab_text.txt"))
	cr_log("line", TextFileGetLine("cr_lab_text.txt", 0))
end
cr_test("lab_text", cr_t_lab_text)
