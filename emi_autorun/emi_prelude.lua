manny = guybrush
AR_IDLE_MAX = 30000
AR_CONTROL_TIMEOUT = 120000
-- (Grim builtins the original Monkey4.exe does not have, which ScummVM's EMI shares with Grim; the library calls them at its start)
if not LockFont then
	LockFont = function(name)
		return nil
	end
end
