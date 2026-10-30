-- The trigger of a door whose way through is off (ar_nav_door_trigger, ar_nav_passage_on): the trigger is found by the name of the door
ar_try_wait = ar_try_wait or function() end

local function door_of(set)
	local d = set["door"]
	d.passage = { "psg" }
	return d
end

do
	local set, nav, w = place("elev", 1, 2)
	local door = door_of(set)
	check("door: the passage is off at the start", not ar_nav_passage_on(door), "on")
	local trig = ar_nav_door_trigger(door)
	check("door: the trigger of a door with its way through off", trig ~= nil and trig == set["door_trigger"], tostring(trig))
	AR_OFF["psg"] = nil
	check("door: the passage on", ar_nav_passage_on(door) == TRUE, "off")
	check("door: no trigger once the way through is on", ar_nav_door_trigger(door) == nil, "a trigger")
	AR_OFF["psg"] = TRUE
	door.is_locked = function() return TRUE end
	check("door: no trigger for a door that is locked", ar_nav_door_trigger(door) == nil, "a trigger")
	door.is_locked = nil
	door.passage = nil
	check("door: no trigger for a door with no passage", ar_nav_door_trigger(door) == nil, "a trigger")
end

-- the way into the cab exists only over the passage that is off: found by the second try, as the walk does
do
	local path = plan("elev", 1, 2, 6, 2)
	check("door: a way into the cab over the passage that is off", path ~= nil, "no way")
end
