-- Extras of chapter 1 for the 100% modes (AR_FULL): the hooks are the ar_extra calls of ch01_work_order.lua.

-- the garage, before the fountain starts the talk with Glottis: everything there is to look at
AR_EXTRAS["ch01 garage"] = function()
	ar_look_all(ga)
end

-- the first node of the talk, before the line that starts the story
AR_EXTRAS["ch01 glottis first"] = function()
	ar_pick_if(gl1, 50)
end

-- the begging node, before the line that makes Glottis help (it ends the talk)
AR_EXTRAS["ch01 glottis beg"] = function()
	ar_pick_if(gl1, 200)
	ar_pick_if(gl1, 210)
	ar_pick_if(gl1, 230)
	ar_pick_if(gl1, 240)
end
