-- Valid calls of builtins whose args tests ScummVM skips (GetCameraActor crashes it with no actor selected:
-- expected/scummvm_crashers_*.txt), and of builtins tools/gen_args.py leaves out (SetGamma, SetVideoDevices).
-- (SetShadowColor and GetFontDimensions crash the original whatever the arguments, expected/crashers.txt: not called)

-- the actor the camera follows: the selected one
cr_t_cov_camera_actor = function()
	MakeCurrentSet("cr_flat.set")
	local a = LoadActor("cov_cam_actor")
	PutActorInSet(a, "cr_flat.set")
	PutActorAt(a, 0, 0, 0)
	SetSelectedActor(a)
	local c = GetCameraActor()
	cr_log("type", type(c))
	cr_log("same", c == a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("cov_camera_actor", "GetCameraActor() is not == the selected actor on the original (another handle of it), on ScummVM it is (lua_v1_actor.cpp:67-71)") cr_test("cov_camera_actor", cr_t_cov_camera_actor)

-- the gamma (Lua_V1::SetGamma: a number, or nothing done)
cr_t_cov_gamma = function()
	cr_log("num", SetGamma(1.5))
	cr_log("str", SetGamma("cr"))
	cr_log("none", SetGamma())
	cr_log("back", SetGamma(1))
	cr_frames(1)
	cr_log("ok", 1)
end
cr_test("cov_gamma", cr_t_cov_gamma)

cr_t_cov_video_devices = function()
	cr_log("set", SetVideoDevices(0, 0))
	cr_frames(1)
	cr_log("ok", 1)
end
cr_test("cov_video_devices", cr_t_cov_video_devices)
