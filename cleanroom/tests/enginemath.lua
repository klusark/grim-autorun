-- The engine's math builtins (Lua 3.1's own math is in core.lua)

cr_vec = function(key, v)
	if v == nil then
		cr_log(key, nil)
	else
		cr_log(key, v.x, v.y, v.z)
	end
end

cr_t_rotate_vector = function()
	cr_vec("yaw90", RotateVector({ x = 1, y = 0, z = 0 }, { x = 0, y = 90, z = 0 }))
	cr_vec("yaw45", RotateVector({ x = 0, y = 1, z = 0 }, { x = 0, y = 45, z = 0 }))
	cr_vec("pitch30", RotateVector({ x = 0, y = 1, z = 0 }, { x = 30, y = 0, z = 0 }))
	cr_vec("roll60", RotateVector({ x = 1, y = 0, z = 0 }, { x = 0, y = 0, z = 60 }))
	cr_vec("all", RotateVector({ x = 1, y = 2, z = 3 }, { x = 10, y = 20, z = 30 }))
	cr_vec("yaw_neg", RotateVector({ x = 1, y = 1, z = 0 }, { x = 0, y = -135, z = 0 }))
end
cr_test("rotate_vector", cr_t_rotate_vector)

cr_t_angle_between_vectors = function()
	cr_log("right", GetAngleBetweenVectors({ x = 1, y = 0, z = 0 }, { x = 0, y = 1, z = 0 }))
	cr_log("same", GetAngleBetweenVectors({ x = 1, y = 1, z = 0 }, { x = 2, y = 2, z = 0 }))
	cr_log("opposite", GetAngleBetweenVectors({ x = 1, y = 0, z = 0 }, { x = -1, y = 0, z = 0 }))
	cr_log("skew", GetAngleBetweenVectors({ x = 1, y = 2, z = 3 }, { x = -2, y = 0.5, z = 1 }))
	cr_log("unnormal", GetAngleBetweenVectors({ x = 10, y = 0, z = 0 }, { x = 0, y = 0, z = 0.1 }))
end
cr_test("angle_between_vectors", cr_t_angle_between_vectors)

cr_t_per_second = function()
	cr_log("values", PerSecond(1), PerSecond(60), PerSecond(-2.5), PerSecond(0))
end
cr_test("per_second", cr_t_per_second)

cr_t_colors = function()
	local c = MakeColor(10, 128, 255)
	local r, g, b = GetColorComponents(c)
	cr_log("components", r, g, b)
	c = MakeColor(300, -5, 7.6)
	r, g, b = GetColorComponents(c)
	cr_log("clamped", r, g, b)
end
cr_test("colors", cr_t_colors)
