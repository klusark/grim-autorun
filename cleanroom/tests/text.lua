-- The text table (grim.tab of the clean-room data)

cr_t_localize = function()
	cr_log("one", LocalizeString("/crt001/"))
	cr_log("two", LocalizeString("/crt002/"))
	cr_log("short", LocalizeString("/crt003/"))
	cr_log("missing", LocalizeString("/nosuchid/"))
	cr_log("plain", LocalizeString("no slashes"))
end
cr_test("localize", cr_t_localize)
