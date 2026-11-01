-- Chapter 65 (Year 4): the end. Manny opens the greenhouse door (the hothouse blows up with Hector in it), the last cutscene
-- (byebye) and the credits play, and the game ends. The run ends where the last cutscene begins.

AR_NEW = TRUE
AR_CONTROL_TIMEOUT = 900000
ar_load(65)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
local d = me.door
-- The way to the door is 13.5 m up a slope in a straight line. While Manny runs, the heading that is seen lags that of the walker, and then the engine ignores the turn keys
-- (turn_key_rule, as the original does): a heading that is off at the start stays off. The follower starts to walk while it is still turning, and Manny runs 13 m at a
-- heading 10 degrees off the way, 1.5 m of drift, onto the edge of the slope, where he is held up again and again. (The run used to get back on the way by being held up early,
-- by chance; with no hold-up it failed.) So he faces the door to a degree standing, lets the heading settle, and starts the walk only when he is turned.
AR_NO_START_WALK = TRUE
ar_face_precise({ obj_x = d.use_pnt_x, obj_y = d.use_pnt_y + 0.5 }, 1)
sleep_for(400)
ar_walk_to(d.use_pnt_x, d.use_pnt_y + 0.5, d.use_pnt_z)
AR_NO_START_WALK = nil
-- (the use point of the door is just out of its range, 0.604 of 0.6: Manny stays where he is, close to it, and faces it)
ar_face(d)
ar_wait_turn()
ar_face_precise(d, 3)
sleep_for(800)
AR_NO_WALK_APPROACH = TRUE
-- (the skipper of the run is off: it would skip the cutscene the moment it begins, and the credits, and the game would end before the run says its result)
AR_NO_SKIP = TRUE
ar_do("use", d, me.gun)
AR_NO_WALK_APPROACH = nil
-- the hothouse blows up and the last cutscene (byebye) begins. A run that plays everything (the recording, AR_REAL) goes on through the cutscene and the
-- credits until the game ends by itself; the speed run ends here, the cutscene and the credits are not sat through (a skip of the movie takes the game to the
-- credits and out of it before the run could say its result)
if AR_REAL then
	ar_wait_for(function() return find_script(cut_scene.end_credits) end, 1800000, "the credits to begin")
	ar_check(find_script(cut_scene.end_credits), "the last cutscene is over, the credits begin")
	ar_state("THE END, the credits are rolling")
	-- (the credits end the game: the recording ends with them)
	sleep_for(1200000)
else
	ar_wait_for(function() return find_script(cut_scene.byebye) end, 120000, "the last cutscene to begin")
	ar_check(find_script(cut_scene.byebye), "the last cutscene begins")
	ar_state("THE END, the last cutscene begins")
end
AR_CREDITS_REACHED = TRUE
