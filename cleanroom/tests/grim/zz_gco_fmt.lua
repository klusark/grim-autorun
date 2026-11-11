-- The engine core: file formats the other tests do not load. A binary model with faces, texture vertices and a material
-- (gco_bbox.3do: cr_dbox.3do's drawn box in the LDOM format, assets_extra_gco.py model3do_faces), drawn and measured next
-- to the text one; the registry keys the engine keeps itself, read.

cr_t_gco_fmt_bmodel = function()
	MakeCurrentSet("cr_open.set")
	cr_frames(1)
	local a = LoadActor("gco_bm")
	PutActorInSet(a, "cr_open.set")
	PutActorAt(a, 0, 0, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, "gco_bbox.cos")
	cr_frames(2)
	cr_log("costume", GetActorCostume(a))
	local x, y, z = GetActorNodeLocation(a, 1)
	cr_log("body", x, y, z)
	cr_snap("binary_snap")
	SetActorCostume(a, "cr_dbox.cos")
	cr_frames(2)
	cr_snap("text_snap")
	PutActorInSet(a, nil)
	cr_frames(1)
end
cr_scummvm_differs("gco_fmt_bmodel", "the drawn box a pixel smaller on ScummVM, the same for both formats (as draw.lua's)") cr_test("gco_fmt_bmodel", cr_t_gco_fmt_bmodel)

-- (the keys ScummVM keeps in its own config: only the kind of each value, the values are the machine's)
GCO_REG_KEYS = { "good_times", "GrimDeveloper", "GrimDataDir", "savepath", "SpewOnError", "DirectorsCommentary",
	"Widescreen", "Language", "ResolutionScaling", "MouseSpeed", "AdvancedLighting", "DirectorsCommentaryVolume",
	"RenderingMode", "Fullscreen" }
cr_t_gco_registry_keys = function()
	local i = 1
	while GCO_REG_KEYS[i] do
		cr_log(GCO_REG_KEYS[i], type(ReadRegistryValue(GCO_REG_KEYS[i])))
		i = i + 1
	end
end
cr_scummvm_differs("gco_registry_keys", "ScummVM answers keys of its own (savepath, SpewOnError, the Remastered's) the original does not have, and not good_times (registry.cpp:141-190)") cr_test("gco_registry_keys", cr_t_gco_registry_keys)
