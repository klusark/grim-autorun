-- Shadows (as the game's scripts set them up: SetActiveShadow, SetActorShadowPoint, SetActorShadowPlane and AddShadowPlane
-- with the sector shadow1 of cr_open, then ActivateActorShadow), seen through cr_snap(key, "dark"): the box of the pixels
-- darker than the background, the shadow of the white box of draw.lua.

cr_sh_test = function(name, fn)
	cr_test("shadow_" .. name, function()
		MakeCurrentSet("cr_open.set")
		local a = LoadActor("cr_sh_a")
		PutActorInSet(a, "cr_open.set")
		PutActorAt(a, 0, 0, 0)
		SetActorRot(a, 0, 0, 0)
		SetActorCostume(a, "cr_dbox.cos")
		cr_frames(2)
		%fn(%name, a)
		KillActorShadows(a)
		cr_frames(2)
		PutActorInSet(a, nil)
	end)
end

cr_sh_setup = function(a, x, y, z)
	SetActiveShadow(a, 0)
	SetActorShadowPoint(a, x, y, z)
	SetActorShadowPlane(a, "shadow1")
	AddShadowPlane(a, "shadow1")
end

cr_sh_test("none", function(k, a)
	cr_snap(k .. "_dark", "dark")
end)

local points = {
	{ "above", 0, 0, 10 },
	{ "left", -4, 0, 3 },
	{ "front", 0, 4, 2 },
	{ "low", 3, 3, 1 },
}
local i = 1
while points[i] do
	cr_sh_test("point_" .. points[i][1], function(k, a)
		local p = %points[%i]
		cr_sh_setup(a, p[2], p[3], p[4])
		ActivateActorShadow(a, TRUE, 0)
		cr_frames(3)
		cr_snap(k .. "_dark", "dark")
		cr_snap(k .. "_box")
	end)
	i = i + 1
end

cr_sh_test("not_activated", function(k, a)
	cr_sh_setup(a, -4, 0, 3)
	cr_frames(3)
	cr_snap(k .. "_dark", "dark")
end)

cr_sh_test("deactivated", function(k, a)
	cr_sh_setup(a, -4, 0, 3)
	ActivateActorShadow(a, TRUE, 0)
	cr_frames(3)
	ActivateActorShadow(a, FALSE, 0)
	cr_frames(3)
	cr_snap(k .. "_dark", "dark")
end)

cr_sh_test("killed", function(k, a)
	cr_sh_setup(a, -4, 0, 3)
	ActivateActorShadow(a, TRUE, 0)
	cr_frames(3)
	KillActorShadows(a)
	cr_frames(3)
	cr_snap(k .. "_dark", "dark")
end)

cr_sh_test("second_slot", function(k, a)
	SetActiveShadow(a, 1)
	SetActorShadowPoint(a, 4, 0, 3)
	SetActorShadowPlane(a, "shadow1")
	AddShadowPlane(a, "shadow1")
	ActivateActorShadow(a, TRUE, 1)
	cr_frames(3)
	cr_snap(k .. "_dark", "dark")
end)

cr_sh_test("moved", function(k, a)
	cr_sh_setup(a, -4, 0, 3)
	ActivateActorShadow(a, TRUE, 0)
	cr_frames(3)
	PutActorAt(a, 1, 1, 0)
	cr_frames(3)
	cr_snap(k .. "_dark", "dark")
end)
