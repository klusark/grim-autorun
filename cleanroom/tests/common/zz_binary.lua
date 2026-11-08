-- A precompiled Lua chunk (assets.BIN_CHUNK, formats.lua_chunk), as the game's own scripts are; one cut short, one of another
-- version. Last of the tests: after it the original's Save and Load (save.lua) crashed now and then, even with the chunk's
-- globals cleared and its garbage collected.
cr_test("lex_binary", function()
	CR_BIN, CR_BIN_N, CR_BIN_X, CR_BIN_F = nil, nil, nil, nil
	cr_log("dofile", dofile("cr_bin.lua"))
	cr_log("values", CR_BIN, CR_BIN_N, CR_BIN_X, type(CR_BIN_F))
	cr_log("call", CR_BIN_F and CR_BIN_F())
	cr_log("short", dofile("cr_bin_short.lua"))
	cr_log("old", dofile("cr_bin_old.lua"))
	CR_BIN, CR_BIN_N, CR_BIN_X, CR_BIN_F = nil, nil, nil, nil
	collectgarbage()
end)
