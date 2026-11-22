-- EMI's side of collision_edge.lua (ScummVM bug 11813): a WalkActorTo past, into and towards another actor's collision
-- sphere. The floor of cr_ell is in x-z (ell_a is x and z from -2 to 0; x < 0, z > 0 is off every floor). The walker
-- (cr_ebox.cos, collision scale 0.3) walks from (x0, z0) to (x1, z1) past the other actor (cr_ebox.cos, scale 0.3) at
-- (ox, oz). Logged: the walker's place every 30 frames, the closest it came to the other (squared, rounded to 1e-3),
-- where it ended and whether it still walks.

cr_ecle_walk = function(key, wmode, omode, ox, oz, x0, z0, x1, z1)
	MakeCurrentSet("cr_ell.set")
	local w = amc_e_actor("ecle_walker", "cr_ell.set", x0, 0, z0, 1)
	PlayActorChore(w, "wear_default", "cr_ebox.cos")
	SetActorWalkRate(w, 1)
	local o = amc_e_actor("ecle_other", "cr_ell.set", ox, 0, oz)
	PlayActorChore(o, "wear_default", "cr_ebox.cos")
	cr_frames(2)
	SetActorCollisionMode(w, wmode)
	SetActorCollisionScale(w, 0.3)
	SetActorCollisionMode(o, omode)
	SetActorCollisionScale(o, 0.3)
	cr_frames(1)
	WalkActorTo(w, x1, 0, z1)
	local best = 1000
	local i = 0
	while i < 240 do
		break_here()
		i = i + 1
		local x, y, z = GetActorPos(w)
		local d2 = (x - ox) * (x - ox) + (z - oz) * (z - oz)
		if d2 < best then
			best = d2
		end
		if mod(i, 30) == 0 then
			cr_log(key .. "_f" .. i, floor(x * 1000 + 0.5) / 1000, floor(z * 1000 + 0.5) / 1000)
		end
	end
	cr_log(key .. "_closest", floor(best * 1000 + 0.5))
	local x, y, z = GetActorPos(w)
	cr_log(key .. "_end", floor(x * 1000 + 0.5) / 1000, floor(z * 1000 + 0.5) / 1000)
	cr_log(key .. "_moving", IsActorMoving(w))
	SetActorCollisionMode(w, 0)
	SetActorCollisionMode(o, 0)
	SetActorCollisionScale(w, 1)
	SetActorCollisionScale(o, 1)
	StopActorChores(w)
	StopActorChores(o)
	cr_frames(1)
	PutActorInSet(w, nil)
	PutActorInSet(o, nil)
end

-- along the edge z = 0 past the other actor standing 15 cm off the floor (Toto on the phone in Grim's set si)
cr_test("ecle_walkto", function()
	cr_ecle_walk("ecle_walkto", 2, 2, -1, 0.15, -1.8, -0.3, -0.2, -0.05)
end)
-- head-on, the other on the floor in the way
cr_test("ecle_walkto_floor", function()
	cr_ecle_walk("ecle_walkto_floor", 2, 2, -1, -1, -1.8, -1, -0.2, -1)
end)
-- just off the way
cr_test("ecle_walkto_graze", function()
	cr_ecle_walk("ecle_walkto_graze", 2, 2, -1, -1, -1.8, -1.15, -0.2, -1.15)
end)
-- to a point inside the other's sphere
cr_test("ecle_walkto_into", function()
	cr_ecle_walk("ecle_walkto_into", 2, 2, -1, -1, -1.8, -1.05, -1.1, -1.05)
end)
-- the walker's mode off
cr_test("ecle_walkto_mover_off", function()
	cr_ecle_walk("ecle_walkto_mover_off", 0, 2, -1, -1, -1.8, -1.15, -0.2, -1.15)
end)
-- the other's mode off: no collision
cr_test("ecle_walkto_other_off", function()
	cr_ecle_walk("ecle_walkto_other_off", 2, 0, -1, -1, -1.8, -1.15, -0.2, -1.15)
end)
-- the other in box mode
cr_test("ecle_walkto_other_box", function()
	cr_ecle_walk("ecle_walkto_other_box", 2, 1, -1, -1, -1.8, -1.15, -0.2, -1.15)
end)

-- ScummVM: the walker is a little behind at frame 30 (as amc_ewalk_along_z); master (bug 11813) also walks into the
-- other's sphere: a path walk was not pushed, and its sphere was 0.8 of the model's radius, not half the floor diagonal of
-- its bounding box (Monkey4.exe 0x42ce50)
cr_scummvm_differs("ecle_walkto", "the walker is behind at frame 30")
cr_scummvm_differs("ecle_walkto_floor", "the path walk goes through the other actor")
cr_scummvm_differs("ecle_walkto_graze", "the path walk goes into the other actor's sphere")
cr_scummvm_differs("ecle_walkto_into", "the path walk goes into the other actor's sphere")
cr_scummvm_differs("ecle_walkto_mover_off", "the walker is behind at frame 30")
cr_scummvm_differs("ecle_walkto_other_off", "the walker is behind at frame 30")
cr_scummvm_differs("ecle_walkto_other_box", "the walker is behind at frame 30")
