-- Files and settings: CheckForFile, the registry (grim.ini on the original, the ScummVM settings)

cr_t_files = function()
	cr_log("check_set", CheckForFile("cr_flat.set"))
	cr_log("check_tab", CheckForFile("grim.tab"))
	cr_log("check_missing", CheckForFile("no_such_file.xyz"))
	cr_log("check_case", CheckForFile("CR_FLAT.SET"))
end
cr_test("files", cr_t_files)

cr_t_registry = function()
	cr_log("unset", ReadRegistryValue("CrNeverWritten"))
	WriteRegistryValue("CrTestString", "hello")
	cr_log("string", ReadRegistryValue("CrTestString"))
	WriteRegistryValue("CrTestNumber", 42)
	cr_log("number", ReadRegistryValue("CrTestNumber"))
	WriteRegistryValue("CrTestFloat", 1.5)
	cr_log("float", ReadRegistryValue("CrTestFloat"))
end
cr_scummvm_differs("registry") cr_test("registry", cr_t_registry)
