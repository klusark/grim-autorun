-- Diagnostic wrappers (DIAG lines in the log): the game's waits and movie calls log when they begin and end, with the caller's actor. Installed by DIAG_install()
-- after a load (a load brings the game's own functions back).
DIAG_install = function()
	if DIAG_ON then
		return
	end
	DIAG_ON = TRUE
	DIAG_wfc = Actor.wait_for_chore
	Actor.wait_for_chore = function(a, b, c)
		PrintDebug("DIAG wait_for_chore begin " .. tostring(a.name) .. " " .. tostring(b) .. " " .. tostring(c) .. "\n")
		DIAG_wfc(a, b, c)
		PrintDebug("DIAG wait_for_chore end " .. tostring(a.name) .. "\n")
	end
	DIAG_wfm = Actor.wait_for_message
	Actor.wait_for_message = function(a)
		PrintDebug("DIAG Actor.wait_for_message begin " .. tostring(a.name) .. "\n")
		DIAG_wfm(a)
		PrintDebug("DIAG Actor.wait_for_message end " .. tostring(a.name) .. "\n")
	end
	DIAG_wm = wait_for_message
	wait_for_message = function()
		PrintDebug("DIAG wait_for_message begin\n")
		DIAG_wm()
		PrintDebug("DIAG wait_for_message end\n")
	end
	DIAG_sl = Actor.say_line
	Actor.say_line = function(a, b, c, d, e)
		PrintDebug("DIAG say_line " .. tostring(a.name) .. " " .. tostring(b) .. "\n")
		return DIAG_sl(a, b, c, d, e)
	end
	DIAG_rfm = RunFullscreenMovie
	RunFullscreenMovie = function(a, b, c)
		PrintDebug("DIAG RunFullscreenMovie begin " .. tostring(a) .. "\n")
		local r = DIAG_rfm(a, b, c)
		PrintDebug("DIAG RunFullscreenMovie end " .. tostring(a) .. "\n")
		return r
	end
	DIAG_pc = Actor.play_chore
	Actor.play_chore = function(a, b, c, d)
		PrintDebug("DIAG play_chore " .. tostring(a.name) .. " " .. tostring(b) .. " " .. tostring(c) .. "\n")
		return DIAG_pc(a, b, c, d)
	end
	DIAG_el = Dialog.execute_line
	Dialog.execute_line = function(a, b, c)
		PrintDebug("DIAG execute_line begin\n")
		DIAG_el(a, b, c)
		PrintDebug("DIAG execute_line end\n")
	end
	DIAG_fin = Dialog.finish
	Dialog.finish = function(a)
		PrintDebug("DIAG Dialog.finish begin\n")
		DIAG_fin(a)
		PrintDebug("DIAG Dialog.finish end\n")
	end
	DIAG_dl = Dialog.display_lines
	Dialog.display_lines = function(a)
		PrintDebug("DIAG display_lines begin node " .. tostring(a.node) .. "\n")
		DIAG_dl(a)
		PrintDebug("DIAG display_lines end\n")
	end
	DIAG_ehc = enable_head_control
	enable_head_control = function(a)
		PrintDebug("DIAG enable_head_control begin\n")
		DIAG_ehc(a)
		PrintDebug("DIAG enable_head_control end\n")
	end
	DIAG_sotp = SetOffscreenTextPos
	SetOffscreenTextPos = function(a, b)
		PrintDebug("DIAG SetOffscreenTextPos\n")
		return DIAG_sotp(a, b)
	end
	start_script(DIAG_watch)
end
DIAG_watch = function()
	local n = 0
	while TRUE do
		sleep_for(5000)
		n = n + 1
		PrintDebug("DIAG watch " .. n .. " execute_line running: " .. tostring(find_script(cp1.execute_line)) .. " finish running: " .. tostring(find_script(Dialog.finish)) .. " buttonHandler cp1: " .. tostring(system.buttonHandler == cp1) .. "\n")
	end
end
