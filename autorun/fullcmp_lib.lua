-- For the frame-by-frame comparison of the two engines over the whole game (EXTRALIB=fullcmp_lib.lua): the same random numbers on both (the game's scripts
-- call random(): the generator of the Lua of each engine is not the same), and a trace line for every frame (FT lines, ftrace_lib.lua).
-- Park and Miller's generator: the products stay under 2^53, so the numbers are the same in every Lua.
RND_STATE = 123457
random = function(a, b)
	RND_STATE = mod(RND_STATE * 16807, 2147483647)
	local r = RND_STATE / 2147483647
	if a == nil then
		return r
	end
	if b == nil then
		return floor(r * a) + 1
	end
	return floor(r * (b - a + 1)) + a
end
randomseed = function(s)
	if s and s > 0 then
		RND_STATE = mod(floor(s), 2147483646) + 1
	end
end
-- Frame trace of the whole game (FT lines): every frame, the game time (the sum of the frame times), the set, the cutscene level and, for Manny and every
-- other actor that is in the set, the position and the angles. Run on both engines (EXTRALIB=ftrace_lib.lua for build_original.sh, EXTRA for the ScummVM
-- scripts) and compared by tools/ftrace_cmp.py. Lines are short: FT <t> <set> <cut> <actor> x y z yaw ...
FT_T = 0
FT_FRAME = 0
FT_CHAPTER = "?"
FT_ACTORS = nil
ft_chapter = function(name)
	FT_CHAPTER = name
	PrintDebug("FTCHAPTER " .. name .. " " .. FT_FRAME .. "\n")
end
ft_run = function()
	while TRUE do
		local s = system.currentSet
		local line = "FT " .. FT_FRAME .. " " .. format("%d", FT_T) .. " " .. tostring(s and s.name) .. " c" .. cutSceneLevel
		local p = manny:getpos()
		local r = manny:getrot()
		line = line .. format(" M %.6f %.6f %.6f %.4f %.5f %.4f", p.x, p.y, p.z, r.x, r.y, r.z)
		PrintDebug(line .. "\n")
		FT_FRAME = FT_FRAME + 1
		FT_T = FT_T + system.frameTime
		break_here()
	end
end
start_script(ft_run)
FT_OLD_CHAPTER = ar_frame_chapter
ar_frame_chapter = function(name)
	ft_chapter(name)
	if FT_OLD_CHAPTER then
		FT_OLD_CHAPTER(name)
	end
end
-- The calls that change what the game does, with the frame they were made in and their first arguments (FTEV lines), to be compared between the engines: the
-- first line that differs says which script event came at another frame. Actors are numbered in the order they appear. (Lua 3.1: no closures, one wrapper each)
FT_HID = { }
FT_HIDN = 0
ft_arg = function(v)
	if type(v) == "number" then
		return format("%.4f", v)
	end
	local t = tostring(v)
	if strfind(t, "userdata") then
		if not FT_HID[t] then
			FT_HIDN = FT_HIDN + 1
			FT_HID[t] = FT_HIDN
		end
		return "u" .. FT_HID[t]
	end
	return t
end
ft_ev = function(name, a, b, c, d)
	PrintDebug("FTEV " .. FT_FRAME .. " " .. name .. " " .. ft_arg(a) .. " " .. ft_arg(b) .. " " .. ft_arg(c) .. " " .. ft_arg(d) .. "\n")
end
if not FT_OLD_MakeSectorActive and MakeSectorActive then
	FT_OLD_MakeSectorActive = MakeSectorActive
	MakeSectorActive = function(a, b, c, d, e)
		ft_ev("MakeSectorActive", a, b, c, d)
		return FT_OLD_MakeSectorActive(a, b, c, d, e)
	end
end
if not FT_OLD_PlayActorChore and PlayActorChore then
	FT_OLD_PlayActorChore = PlayActorChore
	PlayActorChore = function(a, b, c, d, e)
		ft_ev("PlayActorChore", a, b, c, d)
		return FT_OLD_PlayActorChore(a, b, c, d, e)
	end
end
if not FT_OLD_PlayActorChoreLooping and PlayActorChoreLooping then
	FT_OLD_PlayActorChoreLooping = PlayActorChoreLooping
	PlayActorChoreLooping = function(a, b, c, d, e)
		ft_ev("PlayActorChoreLooping", a, b, c, d)
		return FT_OLD_PlayActorChoreLooping(a, b, c, d, e)
	end
end
if not FT_OLD_StopActorChore and StopActorChore then
	FT_OLD_StopActorChore = StopActorChore
	StopActorChore = function(a, b, c, d, e)
		ft_ev("StopActorChore", a, b, c, d)
		return FT_OLD_StopActorChore(a, b, c, d, e)
	end
end
if not FT_OLD_CompleteActorChore and CompleteActorChore then
	FT_OLD_CompleteActorChore = CompleteActorChore
	CompleteActorChore = function(a, b, c, d, e)
		ft_ev("CompleteActorChore", a, b, c, d)
		return FT_OLD_CompleteActorChore(a, b, c, d, e)
	end
end
if not FT_OLD_SayLine and SayLine then
	FT_OLD_SayLine = SayLine
	SayLine = function(a, b, c, d, e)
		ft_ev("SayLine", a, b, c, d)
		return FT_OLD_SayLine(a, b, c, d, e)
	end
end
if not FT_OLD_StartMovie and StartMovie then
	FT_OLD_StartMovie = StartMovie
	StartMovie = function(a, b, c, d, e)
		ft_ev("StartMovie", a, b, c, d)
		return FT_OLD_StartMovie(a, b, c, d, e)
	end
end
if not FT_OLD_PutActorInSet and PutActorInSet then
	FT_OLD_PutActorInSet = PutActorInSet
	PutActorInSet = function(a, b, c, d, e)
		ft_ev("PutActorInSet", a, b, c, d)
		return FT_OLD_PutActorInSet(a, b, c, d, e)
	end
end
if not FT_OLD_SetActorCostume and SetActorCostume then
	FT_OLD_SetActorCostume = SetActorCostume
	SetActorCostume = function(a, b, c, d, e)
		ft_ev("SetActorCostume", a, b, c, d)
		return FT_OLD_SetActorCostume(a, b, c, d, e)
	end
end
if not FT_OLD_PushActorCostume and PushActorCostume then
	FT_OLD_PushActorCostume = PushActorCostume
	PushActorCostume = function(a, b, c, d, e)
		ft_ev("PushActorCostume", a, b, c, d)
		return FT_OLD_PushActorCostume(a, b, c, d, e)
	end
end
if not FT_OLD_PopActorCostume and PopActorCostume then
	FT_OLD_PopActorCostume = PopActorCostume
	PopActorCostume = function(a, b, c, d, e)
		ft_ev("PopActorCostume", a, b, c, d)
		return FT_OLD_PopActorCostume(a, b, c, d, e)
	end
end
if not FT_OLD_SetActorWalkRate and SetActorWalkRate then
	FT_OLD_SetActorWalkRate = SetActorWalkRate
	SetActorWalkRate = function(a, b, c, d, e)
		ft_ev("SetActorWalkRate", a, b, c, d)
		return FT_OLD_SetActorWalkRate(a, b, c, d, e)
	end
end
if not FT_OLD_SetActorTurnRate and SetActorTurnRate then
	FT_OLD_SetActorTurnRate = SetActorTurnRate
	SetActorTurnRate = function(a, b, c, d, e)
		ft_ev("SetActorTurnRate", a, b, c, d)
		return FT_OLD_SetActorTurnRate(a, b, c, d, e)
	end
end
if not FT_OLD_WalkActorTo and WalkActorTo then
	FT_OLD_WalkActorTo = WalkActorTo
	WalkActorTo = function(a, b, c, d, e)
		ft_ev("WalkActorTo", a, b, c, d)
		return FT_OLD_WalkActorTo(a, b, c, d, e)
	end
end
if not FT_OLD_SetActorRot and SetActorRot then
	FT_OLD_SetActorRot = SetActorRot
	SetActorRot = function(a, b, c, d, e)
		ft_ev("SetActorRot", a, b, c, d)
		return FT_OLD_SetActorRot(a, b, c, d, e)
	end
end
if not FT_OLD_PutActorAt and PutActorAt then
	FT_OLD_PutActorAt = PutActorAt
	PutActorAt = function(a, b, c, d, e)
		ft_ev("PutActorAt", a, b, c, d)
		return FT_OLD_PutActorAt(a, b, c, d, e)
	end
end
if not FT_OLD_SetActorPos and SetActorPos then
	FT_OLD_SetActorPos = SetActorPos
	SetActorPos = function(a, b, c, d, e)
		ft_ev("SetActorPos", a, b, c, d)
		return FT_OLD_SetActorPos(a, b, c, d, e)
	end
end
if not FT_OLD_SetActorFollowBoxes and SetActorFollowBoxes then
	FT_OLD_SetActorFollowBoxes = SetActorFollowBoxes
	SetActorFollowBoxes = function(a, b, c, d, e)
		ft_ev("SetActorFollowBoxes", a, b, c, d)
		return FT_OLD_SetActorFollowBoxes(a, b, c, d, e)
	end
end
if not FT_OLD_SetActorConstrain and SetActorConstrain then
	FT_OLD_SetActorConstrain = SetActorConstrain
	SetActorConstrain = function(a, b, c, d, e)
		ft_ev("SetActorConstrain", a, b, c, d)
		return FT_OLD_SetActorConstrain(a, b, c, d, e)
	end
end
if not FT_OLD_SetActorWalkDominate and SetActorWalkDominate then
	FT_OLD_SetActorWalkDominate = SetActorWalkDominate
	SetActorWalkDominate = function(a, b, c, d, e)
		ft_ev("SetActorWalkDominate", a, b, c, d)
		return FT_OLD_SetActorWalkDominate(a, b, c, d, e)
	end
end
if not FT_OLD_ImStartSound and ImStartSound then
	FT_OLD_ImStartSound = ImStartSound
	ImStartSound = function(a, b, c, d, e)
		ft_ev("ImStartSound", a, b, c, d)
		return FT_OLD_ImStartSound(a, b, c, d, e)
	end
end
if not FT_OLD_ImStopSound and ImStopSound then
	FT_OLD_ImStopSound = ImStopSound
	ImStopSound = function(a, b, c, d, e)
		ft_ev("ImStopSound", a, b, c, d)
		return FT_OLD_ImStopSound(a, b, c, d, e)
	end
end
if not FT_OLD_StartSound and StartSound then
	FT_OLD_StartSound = StartSound
	StartSound = function(a, b, c, d, e)
		ft_ev("StartSound", a, b, c, d)
		return FT_OLD_StartSound(a, b, c, d, e)
	end
end
if not FT_OLD_StopSound and StopSound then
	FT_OLD_StopSound = StopSound
	StopSound = function(a, b, c, d, e)
		ft_ev("StopSound", a, b, c, d)
		return FT_OLD_StopSound(a, b, c, d, e)
	end
end
if not FT_OLD_SetSoundState and SetSoundState then
	FT_OLD_SetSoundState = SetSoundState
	SetSoundState = function(a, b, c, d, e)
		ft_ev("SetSoundState", a, b, c, d)
		return FT_OLD_SetSoundState(a, b, c, d, e)
	end
end
if not FT_OLD_ImSetState and ImSetState then
	FT_OLD_ImSetState = ImSetState
	ImSetState = function(a, b, c, d, e)
		ft_ev("ImSetState", a, b, c, d)
		return FT_OLD_ImSetState(a, b, c, d, e)
	end
end
if not FT_OLD_SetAmbientLight and SetAmbientLight then
	FT_OLD_SetAmbientLight = SetAmbientLight
	SetAmbientLight = function(a, b, c, d, e)
		ft_ev("SetAmbientLight", a, b, c, d)
		return FT_OLD_SetAmbientLight(a, b, c, d, e)
	end
end
if not FT_OLD_LockSet and LockSet then
	FT_OLD_LockSet = LockSet
	LockSet = function(a, b, c, d, e)
		ft_ev("LockSet", a, b, c, d)
		return FT_OLD_LockSet(a, b, c, d, e)
	end
end
if not FT_OLD_UnLockSet and UnLockSet then
	FT_OLD_UnLockSet = UnLockSet
	UnLockSet = function(a, b, c, d, e)
		ft_ev("UnLockSet", a, b, c, d)
		return FT_OLD_UnLockSet(a, b, c, d, e)
	end
end
if not FT_OLD_SetActorVisibility and SetActorVisibility then
	FT_OLD_SetActorVisibility = SetActorVisibility
	SetActorVisibility = function(a, b, c, d, e)
		ft_ev("SetActorVisibility", a, b, c, d)
		return FT_OLD_SetActorVisibility(a, b, c, d, e)
	end
end
if not FT_OLD_StopMovie and StopMovie then
	FT_OLD_StopMovie = StopMovie
	StopMovie = function(a, b, c, d, e)
		ft_ev("StopMovie", a, b, c, d)
		return FT_OLD_StopMovie(a, b, c, d, e)
	end
end
if not FT_OLD_FadeOutChore and FadeOutChore then
	FT_OLD_FadeOutChore = FadeOutChore
	FadeOutChore = function(a, b, c, d, e)
		ft_ev("FadeOutChore", a, b, c, d)
		return FT_OLD_FadeOutChore(a, b, c, d, e)
	end
end
if not FT_OLD_FadeInChore and FadeInChore then
	FT_OLD_FadeInChore = FadeInChore
	FadeInChore = function(a, b, c, d, e)
		ft_ev("FadeInChore", a, b, c, d)
		return FT_OLD_FadeInChore(a, b, c, d, e)
	end
end
if not FT_OLD_SetActorCollisionMode and SetActorCollisionMode then
	FT_OLD_SetActorCollisionMode = SetActorCollisionMode
	SetActorCollisionMode = function(a, b, c, d, e)
		ft_ev("SetActorCollisionMode", a, b, c, d)
		return FT_OLD_SetActorCollisionMode(a, b, c, d, e)
	end
end
if not FT_OLD_SetActorCollisionScale and SetActorCollisionScale then
	FT_OLD_SetActorCollisionScale = SetActorCollisionScale
	SetActorCollisionScale = function(a, b, c, d, e)
		ft_ev("SetActorCollisionScale", a, b, c, d)
		return FT_OLD_SetActorCollisionScale(a, b, c, d, e)
	end
end
if not FT_OLD_SetActorReflection and SetActorReflection then
	FT_OLD_SetActorReflection = SetActorReflection
	SetActorReflection = function(a, b, c, d, e)
		ft_ev("SetActorReflection", a, b, c, d)
		return FT_OLD_SetActorReflection(a, b, c, d, e)
	end
end
if not FT_OLD_TurnActorTo and TurnActorTo then
	FT_OLD_TurnActorTo = TurnActorTo
	TurnActorTo = function(a, b, c, d, e)
		ft_ev("TurnActorTo", a, b, c, d)
		return FT_OLD_TurnActorTo(a, b, c, d, e)
	end
end
if not FT_OLD_PointActorAt and PointActorAt then
	FT_OLD_PointActorAt = PointActorAt
	PointActorAt = function(a, b, c, d, e)
		ft_ev("PointActorAt", a, b, c, d)
		return FT_OLD_PointActorAt(a, b, c, d, e)
	end
end
-- the cut scenes (Lua functions of the game)
if not FT_OLD_START_CUT_SCENE and START_CUT_SCENE then
	FT_OLD_START_CUT_SCENE = START_CUT_SCENE
	START_CUT_SCENE = function(a)
		ft_ev("START_CUT_SCENE", a)
		return FT_OLD_START_CUT_SCENE(a)
	end
end
if not FT_OLD_END_CUT_SCENE and END_CUT_SCENE then
	FT_OLD_END_CUT_SCENE = END_CUT_SCENE
	END_CUT_SCENE = function(a)
		ft_ev("END_CUT_SCENE", a)
		return FT_OLD_END_CUT_SCENE(a)
	end
end

-- GetActorYawToPoint with its answer to 6 digits, in the frames FT_YAW_FROM..FT_YAW_TO (FTYAW lines): the steering of the autorun depends on it
FT_YAW_FROM = 0
FT_YAW_TO = -1
if not FT_OLD_GetActorYawToPoint and GetActorYawToPoint then
	FT_OLD_GetActorYawToPoint = GetActorYawToPoint
	GetActorYawToPoint = function(h, x, y, z)
		local r = FT_OLD_GetActorYawToPoint(h, x, y, z)
		if FT_FRAME >= FT_YAW_FROM and FT_FRAME <= FT_YAW_TO then
			PrintDebug("FTYAW " .. FT_FRAME .. " " .. format("%.6f %.6f %.6f -> %.6f rot %.6f", x, y, z, r, manny:getrot().y) .. "\n")
		end
		return r
	end
end
