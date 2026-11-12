-- The two formats of a model, binary (LDOM) and text, and the bounding box, centre and radius each gives an actor. The
-- models are in assets.py FORMAT_MODELS (cr_t*: text). The original reads either and then works the box, its centre and the
-- radius out from the vertices through the full node transforms (rdModel3_LoadPostProcess, rdModel3_CalcBoundingBoxes):
-- the radius of a text model and the header of a binary one make no difference. ScummVM reads the header of a binary model;
-- from a text model it reads the radius and works the box out from the vertices moved by each mesh's position, without the
-- node's rotation.
--   cr_tbox: cr_box.3do in text           cr_trad / cr_brad: the radius of the file 3 m (text / binary header)
--   cr_tnodex, cr_tfloat: cr_nodex and cr_float in text
--   cr_wide: a 1 x 0.2 m body             cr_rot / cr_trot: the same, its node turned 90 degrees about z
--   cr_rotx / cr_trotx: the body box turned 90 degrees about x (lying along -y, 0.3 m high)
--   cr_piv / cr_tpiv: the body node's pivot 0.5 m to +x
--   cr_prot / cr_tprot: the pivot 0.5 m to +x and a turn of 90 degrees about z
-- Each case walks a mover into a wall actor at 20 degrees, as collision_mode.lua does (a move straight into a face of a box
-- gives NaN positions on the original).

cr_mf_actor = function(name, cos, x, y, yaw)
	local a = LoadActor(name)
	PutActorInSet(a, "cr_flat.set")
	PutActorAt(a, x, y, 0)
	SetActorRot(a, 0, yaw, 0)
	SetActorCostume(a, cos)
	return a
end

-- (the mover, model ma, walks forward for 160 frames from (0.5, -1.9) into the wall, model mb, at (0, wy); mode 1 box, 2 sphere, for both;
-- the collision scale 0.5)
cr_mf_case = function(key, ma, mb, mode, wy)
	MakeCurrentSet("cr_flat.set")
	local a = cr_mf_actor("cr_mf_mover", ma .. ".cos", 0.5, -1.9, 20)
	local b = cr_mf_actor("cr_mf_wall", mb .. ".cos", 0, wy or 0.2, 0)
	SetActorFollowBoxes(a, TRUE)
	SetActorWalkRate(a, 1)
	SetActorCollisionMode(a, mode)
	SetActorCollisionMode(b, mode)
	SetActorCollisionScale(a, 0.5)
	SetActorCollisionScale(b, 0.5)
	cr_frames(1)
	local i = 0
	while i < 160 do
		WalkActorForward(a)
		if mod(i, 40) == 0 then
			cr_pos(key .. "_f" .. i, a)
		end
		break_here()
		i = i + 1
	end
	cr_pos(key .. "_end", a)
	SetActorCollisionMode(a, 0)
	SetActorCollisionMode(b, 0)
	PutActorInSet(a, nil)
	PutActorInSet(b, nil)
end

cr_mf_test = function(key, ma, mb, mode, wy)
	cr_test("mf_" .. key, function()
		cr_mf_case(%key, %ma, %mb, %mode, %wy)
	end)
end

-- every model as the wall, against a box and a sphere (the boxes of cr_rotx and cr_trotx reach 1.8 m to -y: further away)
local walls = { "cr_box", "cr_tbox", "cr_trad", "cr_brad", "cr_nodex", "cr_tnodex", "cr_float", "cr_tfloat", "cr_wide",
	"cr_rot", "cr_trot", "cr_rotx", "cr_trotx", "cr_piv", "cr_tpiv", "cr_prot", "cr_tprot" }
local i = 1
while walls[i] do
	local wy = 0.2
	if walls[i] == "cr_rotx" or walls[i] == "cr_trotx" then
		wy = 2
	end
	cr_mf_test(walls[i] .. "_wall_box", "cr_box", walls[i], 1, wy)
	cr_mf_test(walls[i] .. "_wall_sphere", "cr_box", walls[i], 2, wy)
	i = i + 1
end

-- the models as the mover, against a sphere (the mover is a sphere whatever its mode: Collision_TestActorAgainstOthers)
local movers = { "cr_tbox", "cr_trad", "cr_brad", "cr_tnodex", "cr_tfloat", "cr_rot", "cr_trot", "cr_rotx", "cr_trotx",
	"cr_piv", "cr_tpiv", "cr_prot", "cr_tprot" }
i = 1
while movers[i] do
	cr_mf_test(movers[i] .. "_mover_sphere", movers[i], "cr_box", 2)
	i = i + 1
end

-- what each model gives the Lua side: the rectangle on the screen and the node locations
-- (in expected/crashers.txt, so skipped on both engines: on the original this test damages the heap, and in a whole run a
-- later test crashes or hangs, a different one each run: gco_save_shrunk, gco_save_zstate, gl1_music_state_load,
-- gco_lip_unknown at Lua.dll+0x93A2, smv_save_movie, rnd_holes... Found 2026-11-12 by runs from different start points: every
-- run with this test and its text models (cr_t*) crashed later, 3 of 3; with only the binary models, or none of it, no run
-- did. Neither cr_tbox nor cr_trot alone did it. The decomp under GRIM_FENCE, a guard page after every block, finds no
-- overrun or use after free here.)
cr_t_mf_rects = function()
	MakeCurrentSet("cr_flat.set")
	local names = { "cr_box", "cr_tbox", "cr_trad", "cr_brad", "cr_tnodex", "cr_tfloat", "cr_wide", "cr_rot", "cr_trot",
		"cr_rotx", "cr_trotx", "cr_piv", "cr_tpiv", "cr_prot", "cr_tprot" }
	local i = 1
	while names[i] do
		local a = cr_mf_actor("cr_mf_r" .. i, names[i] .. ".cos", 0.5, -0.5, 0)
		cr_frames(1)
		cr_log(names[i] .. "_rect", GetActorRect(a))
		local n = 0
		while n < 4 do
			local x, y, z = GetActorNodeLocation(a, n)
			cr_log(names[i] .. "_node" .. n, x, y, z)
			n = n + 1
		end
		PutActorInSet(a, nil)
		i = i + 1
	end
end
cr_scummvm_differs("mf_rects") cr_test("mf_rects", cr_t_mf_rects)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("mf_cr_box_wall_box")
cr_scummvm_differs("mf_cr_box_wall_sphere")
cr_scummvm_differs("mf_cr_brad_mover_sphere")
cr_scummvm_differs("mf_cr_brad_wall_box")
cr_scummvm_differs("mf_cr_brad_wall_sphere")
cr_scummvm_differs("mf_cr_float_wall_box")
cr_scummvm_differs("mf_cr_float_wall_sphere")
cr_scummvm_differs("mf_cr_nodex_wall_box")
cr_scummvm_differs("mf_cr_nodex_wall_sphere")
cr_scummvm_differs("mf_cr_piv_mover_sphere")
cr_scummvm_differs("mf_cr_piv_wall_box")
cr_scummvm_differs("mf_cr_piv_wall_sphere")
cr_scummvm_differs("mf_cr_prot_mover_sphere")
cr_scummvm_differs("mf_cr_prot_wall_box")
cr_scummvm_differs("mf_cr_prot_wall_sphere")
cr_scummvm_differs("mf_cr_rot_mover_sphere")
cr_scummvm_differs("mf_cr_rot_wall_box")
cr_scummvm_differs("mf_cr_rot_wall_sphere")
cr_scummvm_differs("mf_cr_rotx_mover_sphere")
cr_scummvm_differs("mf_cr_rotx_wall_box")
cr_scummvm_differs("mf_cr_rotx_wall_sphere")
cr_scummvm_differs("mf_cr_tbox_mover_sphere")
cr_scummvm_differs("mf_cr_tbox_wall_box")
cr_scummvm_differs("mf_cr_tbox_wall_sphere")
cr_scummvm_differs("mf_cr_tfloat_mover_sphere")
cr_scummvm_differs("mf_cr_tfloat_wall_box")
cr_scummvm_differs("mf_cr_tfloat_wall_sphere")
cr_scummvm_differs("mf_cr_tnodex_mover_sphere")
cr_scummvm_differs("mf_cr_tnodex_wall_box")
cr_scummvm_differs("mf_cr_tnodex_wall_sphere")
cr_scummvm_differs("mf_cr_tpiv_mover_sphere")
cr_scummvm_differs("mf_cr_tpiv_wall_box")
cr_scummvm_differs("mf_cr_tpiv_wall_sphere")
cr_scummvm_differs("mf_cr_tprot_mover_sphere")
cr_scummvm_differs("mf_cr_tprot_wall_box")
cr_scummvm_differs("mf_cr_tprot_wall_sphere")
cr_scummvm_differs("mf_cr_trad_mover_sphere")
cr_scummvm_differs("mf_cr_trad_wall_box")
cr_scummvm_differs("mf_cr_trad_wall_sphere")
cr_scummvm_differs("mf_cr_trot_mover_sphere")
cr_scummvm_differs("mf_cr_trot_wall_box")
cr_scummvm_differs("mf_cr_trot_wall_sphere")
cr_scummvm_differs("mf_cr_trotx_mover_sphere")
cr_scummvm_differs("mf_cr_trotx_wall_box")
cr_scummvm_differs("mf_cr_trotx_wall_sphere")
cr_scummvm_differs("mf_cr_wide_wall_box")
cr_scummvm_differs("mf_cr_wide_wall_sphere")
