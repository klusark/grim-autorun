-- Save and Load without a name (ScummVM: grim.sav) and with a table as the name (ScummVM: a warning, nothing done), as
-- save.lua's cr_save (RenderModeUser around the Save; CrSavePass in the registry tells the passes apart).

cr_scummvm_differs("gl1_save_nil", "in the whole run ScummVM (OpenGL) ended with 0xC0000409 in this save, as smv_save_movie: a Save while a movie plays") cr_test("gl1_save_nil", function()
	MakeCurrentSet("cr_flat.set")
	cr_save_clean()
	GL1_SAVED = "saved"
	WriteRegistryValue("CrSavePass", "saving")
	RenderModeUser(TRUE)
	Save(nil)
	cr_frames(3)
	RenderModeUser(nil)
	if ReadRegistryValue("CrSavePass") == "saving" then
		WriteRegistryValue("CrSavePass", "loading")
		GL1_SAVED = "changed"
		Load(nil)
		cr_frames(10)
		cr_log("not_loaded", GL1_SAVED)
	else
		cr_log("pass", ReadRegistryValue("CrSavePass"))
		WriteRegistryValue("CrSavePass", "done")
		cr_frames(1)
		cr_log("saved", GL1_SAVED)
	end
	GL1_SAVED = nil
end)

cr_test("gl1_save_table", function()
	MakeCurrentSet("cr_flat.set")
	cr_save_clean()
	GL1_SAVED = "saved"
	WriteRegistryValue("CrSavePass", "saving")
	RenderModeUser(TRUE)
	cr_log("save", Save({ }))
	cr_frames(3)
	RenderModeUser(nil)
	if ReadRegistryValue("CrSavePass") == "saving" then
		WriteRegistryValue("CrSavePass", "loading")
		GL1_SAVED = "changed"
		cr_log("load", Load({ }))
		cr_frames(10)
		cr_log("not_loaded", GL1_SAVED)
	else
		cr_log("pass", ReadRegistryValue("CrSavePass"))
		cr_frames(1)
		cr_log("saved", GL1_SAVED)
	end
	WriteRegistryValue("CrSavePass", "done")
	GL1_SAVED = nil
end)
