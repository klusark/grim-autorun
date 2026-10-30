-- Extras of chapter 1 for the 100% modes (AR_FULL): the hooks are the ar_extra calls of ch01_work_order.lua.

-- the garage, before the fountain starts the talk with Glottis: everything there is to look at
AR_EXTRAS["ch01 garage"] = function()
	ar_look_all(ga)
end

-- (the lines of the talk with Glottis are said by the dialog hook of ar_full.lua, ar_talk_before)
