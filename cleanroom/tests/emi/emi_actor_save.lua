-- Saving and loading EMI's actors (Save(file) and Load(file), as Grim's save.lua: the engine does them between frames
-- and the Load brings back the Lua tasks, so the test goes on after its Save a second time; the registry, which is not in
-- a save, tells the two passes apart in Grim; on EMI, ScummVM has no registry: WriteRegistryValue and ReadRegistryValue
-- crash it, so JustLoaded() does it here). EMI's own part of an actor's save: the global alpha, the sort order, the
-- overworld, the actor it is attached to and the joint, the textures of its materials, the actor it looks at and the
-- local alpha of its meshes. The carrier wears cr_ebox.cos (a skeleton, a box mesh with a texture, an animation); the
-- rider, attached at the joint "body", has no costume.

-- (the values as one string)
asv_es = function(a, b, c, d)
	return tostring(a) .. " " .. tostring(b) .. " " .. tostring(c) .. " " .. tostring(d)
end

-- (how many keys of two looks differ)
asv_ediff = function(a, b)
	local n = 0
	local k, v = next(a, nil)
	while k do
		if b[k] ~= v then
			n = n + 1
		end
		k, v = next(a, k)
	end
	return n
end

asv_elook = function()
	local l = { }
	l.c_pos = asv_es(GetActorPos(ASV_EC))
	l.r_pos = asv_es(GetActorPos(ASV_ER))
	l.r_world = asv_es(GetActorWorldPos(ASV_ER))
	l.c_sort = tostring(GetActorSortOrder(ASV_EC))
	l.r_sort = tostring(GetActorSortOrder(ASV_ER))
	l.chore = tostring(IsChorePlaying(ASV_ECH))
	return l
end

-- (the test is one function without upvalues, its state in globals)
cr_t_asv_emi_actor = function()
	MakeCurrentSet("cr_flat.set")
	ASV_EC = LoadActor("cr_asv_carrier")
	PutActorInSet(ASV_EC, "cr_flat.set")
	PutActorAt(ASV_EC, 1, 0, 0)
	SetActorRot(ASV_EC, 0, 0, 0)
	ASV_ECH = PlayActorChore(ASV_EC, "wear_default", "cr_ebox.cos")
	ASV_ER = LoadActor("cr_asv_rider")
	PutActorInSet(ASV_ER, "cr_flat.set")
	PutActorAt(ASV_ER, 0, 0, 0)
	SetActorRot(ASV_ER, 0, 0, 0)
	cr_frames(2)
	AttachActor(ASV_ER, ASV_EC, "body")
	SetActorGlobalAlpha(ASV_EC, 0.5)
	SetActorLocalAlpha(ASV_EC, 0, 0.25)
	SetActorSortOrder(ASV_EC, 7)
	SetActorSortOrder(ASV_ER, -3)
	ActorLookAt(ASV_ER, ASV_EC)
	cr_frames(2)
	ASV_ELOOK = asv_elook()
	-- (clears the flag)
	cr_log("just_loaded_before", JustLoaded())
	-- (Monkey4.exe's Save writes system.version, nil in the clean room: without it, the original crashes in strlen of
	-- nil at 0x40f83b; with it, it ends by itself a little later, with no dump and a save file of 0 bytes: the original
	-- does not save in the clean room yet, and this test is one of its crashers)
	ASV_EVERSION = system.version
	system.version = "cr 1.0"
	Save("crasv_emi_actor.gsv")
	cr_frames(3)
	-- (here twice: after the save, and after the Load)
	if not JustLoaded() then
		DetachActor(ASV_ER)
		PutActorAt(ASV_EC, -1, 0, 1)
		PutActorAt(ASV_ER, 0.5, 0, 0.5)
		SetActorSortOrder(ASV_EC, 1)
		SetActorSortOrder(ASV_ER, 2)
		SetActorGlobalAlpha(ASV_EC, 1)
		cr_frames(2)
		cr_log("changed", asv_ediff(ASV_ELOOK, asv_elook()))
		Load("crasv_emi_actor.gsv")
		cr_frames(10)
		cr_log("not_loaded", 1)
	else
		cr_log("pass", "loaded", JustLoaded())
		cr_frames(1)
		local now = asv_elook()
		local ks = cr_keys(ASV_ELOOK)
		local j = 1
		while ks[j] do
			local k = ks[j]
			local v = ASV_ELOOK[k]
			if now[k] == v then
				cr_log("kept_" .. k, 1)
			else
				cr_log("kept_" .. k, v, now[k])
			end
			j = j + 1
		end
		-- (still attached: the rider follows the carrier)
		PutActorAt(ASV_EC, 2, 0, 1)
		cr_frames(2)
		cr_log("carrier_moved", GetActorWorldPos(ASV_ER))
	end
	system.version = ASV_EVERSION
	DetachActor(ASV_ER)
	StopActorChores(ASV_EC)
	PutActorInSet(ASV_ER, nil)
	PutActorInSet(ASV_EC, nil)
	cr_frames(1)
end
cr_test("asv_emi_actor", cr_t_asv_emi_actor)

