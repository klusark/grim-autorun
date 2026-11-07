-- A load after SetEmergencyFont (text.lua's blast_print sets it, and it stays): the original crashes drawing the text
-- object after the load (TextObject_Draw 0x48ca13 reads a font that is not there). Last but the argument probe, as every
-- Load after it crashes the original; cr_save and cr_save_clean are save.lua's.

cr_t_save_emergency_font = function()
	cr_save_clean()
	SetEmergencyFont("cr_font.laf")
	local t = MakeTextObject("Emergency", { font = LockFont("cr_font.laf"), fgcolor = MakeColor(255, 255, 255), x = 300, y = 200 })
	cr_frames(2)
	WriteRegistryValue("CrSavePass", "saving")
	cr_save("crsave_emergency.gsv")
	if ReadRegistryValue("CrSavePass") == "saving" then
		WriteRegistryValue("CrSavePass", "loading")
		Load("crsave_emergency.gsv")
		cr_frames(10)
		cr_log("not_loaded", 1)
	else
		WriteRegistryValue("CrSavePass", "done")
		cr_frames(2)
		cr_snap("loaded_snap")
	end
	KillTextObject(t)
end
cr_test("save_emergency_font", cr_t_save_emergency_font)
