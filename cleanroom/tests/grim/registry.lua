-- The registry keys the game uses (ReadRegistryValue / WriteRegistryValue): what kind of value each has, and whether a
-- value written is read back. The values themselves depend on the engine's configuration (paths, volumes), so only
-- their type is logged; every key gets its old value back.

CR_REG_KEYS = { "good_times", "GrimDeveloper", "GrimDataDir", "savepath", "GrimLastSet", "MusicVolume", "SfxVolume",
	"VoiceVolume", "LastSavedGame", "Gamma", "GammaCorrection", "VoiceEffects", "TextSpeed", "TextMode", "SpeechMode",
	"MovementMode", "JoystickEnabled", "SpewOnError", "Transcript", "DirectorsCommentary", "Widescreen", "Language",
	"ResolutionScaling", "MouseSpeed", "AdvancedLighting", "DirectorsCommentaryVolume", "RenderingMode", "Fullscreen" }

-- (the keys a test may write, and a value of the kind the game writes to each)
CR_REG_WRITE = { GrimLastSet = "cr_flat.set", MusicVolume = 90, SfxVolume = 80, VoiceVolume = 70,
	LastSavedGame = 3, Gamma = 1, VoiceEffects = "FALSE", TextSpeed = 5, SpeechMode = 2, MovementMode = "FALSE",
	JoystickEnabled = "FALSE", Transcript = "FALSE" }

cr_t_registry_keys = function()
	local i = 1
	while CR_REG_KEYS[i] do
		local v = ReadRegistryValue(CR_REG_KEYS[i])
		cr_log(CR_REG_KEYS[i], type(v))
		i = i + 1
	end
end
cr_scummvm_differs("registry_keys") cr_test("registry_keys", cr_t_registry_keys)

cr_t_registry_write = function()
	local k, v = next(CR_REG_WRITE, nil)
	while k do
		local old = ReadRegistryValue(k)
		WriteRegistryValue(k, v)
		local now = ReadRegistryValue(k)
		cr_log(k, tostring(now), tostring(now) == tostring(v))
		if old then
			WriteRegistryValue(k, old)
		end
		k, v = next(CR_REG_WRITE, k)
	end
end
cr_test("registry_write", cr_t_registry_write)

-- the case of a key, and a number written as a string and the other way round
cr_t_registry_kinds = function()
	WriteRegistryValue("CrKind", "12")
	cr_log("string_digits", type(ReadRegistryValue("CrKind")), ReadRegistryValue("CrKind"))
	WriteRegistryValue("CrKind", 12)
	cr_log("number", type(ReadRegistryValue("CrKind")), ReadRegistryValue("CrKind"))
	cr_log("other_case", type(ReadRegistryValue("crkind")), type(ReadRegistryValue("CRKIND")))
	WriteRegistryValue("CrKind", "")
	cr_log("empty", type(ReadRegistryValue("CrKind")), ReadRegistryValue("CrKind"))
end
cr_scummvm_differs("registry_kinds") cr_test("registry_kinds", cr_t_registry_kinds)
