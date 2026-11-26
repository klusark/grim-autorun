# Functions renamed in Ghidra (project /v101/GRIMFANDANGO.EXE, 2026-10-26)

Rule: every function that is decoded gets a name (and a plate comment for what it does). Names are `Module_Verb...`.

| Address | Name | What |
| --- | --- | --- |
| 0x004016a0 | Game_FrameUpdate | per-frame function; fixed frame time global DAT_004f5a48 (patched by patches/grim/simtime.py at 0x401721) |
| 0x00482990 | Engine_UpdateFrame | sound, timer, Lua tasks, actor update |
| 0x004a3c10 / 0x004a3c80 / 0x004a3ce0 | Timer_UpdateFromWallClock / Timer_UpdateFixedStep / Timer_Reset | frame time (ms, seconds, total) |
| 0x004a3be0 / bf0 / c00 | Timer_GetTotalMs / Timer_GetFrameMs / Timer_GetFrameSeconds | |
| 0x0048fbd0 | Actor_TurnKey | TurnActor: turn = rate * frame seconds * timescale |
| 0x00490360 / 0x00490580 / 0x00490730 | Actor_FromHandle / Actor_CreateExtra / Actor_CreateWalker | actor+0xa4 extra struct (walker) |
| 0x00490900 / 0x00490870 | Actor_SetRot / Actor_SetPositionClamped | |
| 0x00491230 / 0x004a8610 / 0x00491650 | Walker_UpdateYaw / Walker_WalkSectors / Walker_ReplanPath | |
| 0x004a8500 | Actor_GetYawToPoint | |
| 0x004a6980 | Sector_ContainsPoint | plane margin, edge tolerance 2e-5 (cross units) |
| 0x004a6490 / 0x004a7ab0 / 0x004a7bc0 | Sector_Construct / SectorVertexPool_GetOrAdd / SetFile_ParseSectors | vertex welding 1e-4, newest-first chain, height 0.005 |
| 0x004a71e0 | SectorList_FindByPoint | |
| 0x0049b1d0 / 0x0049b160 / 0x0049c180 | Lua_SetActorTurnRate / Lua_GetActorTurnRate / Lua_TurnActor | |
| 0x0049c4c0 / 0x0049c3b0 / 0x0049c200 | Lua_IsPointInSector / Lua_GetPointSector / Lua_GetActorSector | |
| 0x004939f0 / 0x004939a0 / 0x00494100 / 0x004922d0 | Collision_TestActorAgainstOthers / Collision_UpdateMovedActors / Collision_BoxSlide / Collision_PushOutOfBox | |
| 0x004469a0 / 0x004aef70 | Vec3_Normalize / String_ContainsSubstring | |
| 0x004891b0 / 0x004892a0 | Movie_PollPlayback / Movie_Start | |
| 0x00482e30 / 0x00482e80 | Profile_Begin / Profile_End | QueryPerformanceCounter pairs |
| 0x00402fd0 / 0x0049de00 / 0x0049ddd0 | Win_WndProc / Lua_InitGameLibs / Lua_PrintDebug_NoOp | |

## Added 2026-10-26 (shrink boxes and the walker's helpers)

| Address | Name | What |
| --- | --- | --- |
| 0x00498e50 / 0x00498e90 / 0x00498ea0 | Lua_ShrinkBoxes / Lua_UnShrinkBoxes / Lua_GetShrinkPos | ShrinkBoxes = unshrink, save, shrink |
| 0x004a9d00 | SectorList_ShrinkWalkSectors | bisector shift, validity, collapse, switch off, mean over the shared vertices |
| 0x004a9070 / 0x004a9180 | Sector_EdgeDistance / Sector_CollapseShortestEdge | |
| 0x004a61c0 / 0x004a6380 / 0x004a6330 | SectorList_SaveForShrink / SectorList_RestoreAfterShrink / SectorList_FreeShrinkSave | |
| 0x004a6b30 / 0x004a72b0 / 0x004a7000 | Sector_ClampPoint / SectorList_FindNearestPoint / Sector_FixPlaneCoordinate | |
| 0x004a7ba0 | SectorVertexPool_Release | refcount of a pool vertex |
| 0x0047bd20 / 0x0047c4a0 / 0x00446920 | Math_SinCosTable / Math_AsinDegreesSeries / Vec3_NormalizeTo | |
| 0x004a83c0 / 0x004a89b0 / 0x004a8a90 | Walker_TurnHeading / Walker_SetSectorFrame / Walker_RebuildRightVector | |
| 0x004a85b0 / 0x004a6d10 | Walker_SetConstraint / Sector_FindExitPoint | the constraint line = forward; exit point of the step and 90.2 - asin(dot) |
| 0x004933e0 / 0x0048fc80 / 0x00491110 | Actor_SetConstrain / Actor_WalkForward / Actor_UpdateWalker | per-frame: key turn, Walker_WalkSectors, Walker_UpdateYaw |
| 0x004a1900 / 0x00499800 | Lua_SetActorConstrain / Lua_WalkActorForward | |

## IMUSE.DLL (project /v101/IMUSE.DLL, image base 0x10000000)

| Address | Name | Notes |
| --- | --- | --- |
| 0x10008ec0 | Sounds_ResolveName_LoadIfNeeded | name or handle -> cache slot 100..131 (32 slots, 0x40 bytes each at 0x10031528); loads a name that is not cached; 0 when it cannot |
| 0x100092f0 | Sounds_EvictOldestIdleSlot | frees the longest unused slot that has no playing/pending track; -1 when none |
| 0x10007520 | SoundsGetParam | **returns 1 when Sounds_ResolveName_LoadIfNeeded gives 0**: ImGetParam(name or stale handle, PLAY_COUNT) then reads "playing" |
| 0x10007410 / 0x10007470 | SoundsLoadStartSound / SoundsLoadProcessStartSound | return the handle (slot +0x20, 0x457 + counter) = one per cached sound, not per playing instance |
| 0x1000ab00 / 0x1000af50 / 0x1000b110 | Im_StartSoundImpl / Im_GetParamImpl / Im_AllocTrackOrSteal | track list at 0x10032300, track pool at 0x10031f28 |
| 0x10004f50 / 0x10004f60 | Im_GuardEnter / Im_GuardLeave | the counter DAT_100172c0: INC and load-dec-store, not atomic; a lost update leaves it at 1 and ImHeartbeat never runs again (the sound freeze of the original) |
| 0x1000ada0 | Im_SetParamImpl | leaks one count for the group param (0x400) with a value >= 16 |
| 0x1000aa40 / 0x1000a6d0 | Im_HeartbeatBody / Im_RefillStreamTrack | |

## Added 2026-10-27 (path planner, TurnActorTo, chores)

| Address | Name | What |
| --- | --- | --- |
| 0x004a9430 / 0x004a94d0 | Planner_PlanPath / Planner_SearchSectors | depth-first search over the walk sectors (exit point of the line to the goal, then the corners the sectors share, nearest to the goal first); path array DAT_008cf0b0, count DAT_008cf248 (max 29); sector flag +0x2c marks a sector the search has been through |
| 0x004a96f0 / 0x004a9920 | Planner_CollectSharedCorners / Planner_PortalPoint | corners of the other free sectors that lie in the sector (dedup by bits, insertion sort by distance to the goal); corner of two sectors that lies in the other, nearest to the goal |
| 0x004a9ca0 / 0x004a9aa0 / 0x004a7a90 / 0x004a9420 | Planner_SharedSector / Planner_SmoothPath / SectorList_ResetFree / Planner_GetPath | sector with both points; pull corners onto the line of their neighbours (exit point, moved if > 0.05 m), drop points closer than 0.01 m, repeat; all +0x2c = 1 |
| 0x004917e0 | Walker_AvoidActorPath | adds the detour round the other actor to a path (WalkActorToAvoiding, collision replan): not ported yet |
| 0x0049fc60 / 0x004a8450 | Lua_TurnActorTo / Walker_TurnToPoint | turns the frame of the walker at once by at most rate * frame seconds; true while that was all the rate allowed |
| CHORE.DLL 0x100053e0 / 0x10003530 | Chore_AdvanceTime / Cos_InstUpdateChore | the first update takes the frame time; keys in [cur, cur+dt); ends when time >= length |

## Clip planes, shadow side test, frustum cull, set locks (2026-10-27)
| address | name | what |
|---|---|---|
| 0x4a2750 | Lua_SetActorClipActive | extra+0x3fc = round(n) |
| 0x4a27b0 | Lua_SetActorClipPlane | normal (normalized) at extra+0x400, point at extra+0x40c |
| 0x49afd0 | Lua_SetActorFrustrumCull | actor flag bit 4, model instance +0x44 of the costume components |
| 0x4a1fd0 | Lua_SetActorShadowValid | slot valid (extra+0x1fc + active*0x54) = round(n) |
| 0x4a3ae0 | Lua_SetActorInvClipNode | extra+0x420 = node (nil: -1) |
| 0x494710 / 0x4946b0 / 0x494780 | Actor_SetClipActive / Actor_SetClipPlane / Actor_SetFrustumCull | the setters of the above |
| 0x493570 | Actor_SetShadowPlane | the plane (normal, d = -n.v0) of the sector, valid = 0 |
| 0x4936e0 | Actor_DrawShadows | valid 0 always, -1 only when pos.n+d <= 0, 1 only when >= 0 |
| 0x4950a0 | Actor_DrawCostumeMeshes | sets the clip plane (script, or the inventory node: actor facing = actor+0x44..0x4c, point = actor+0xc) |
| 0x40a870 / 0x40a880 | Renderer_EnableClipPlane / Renderer_SetClipPlane | globals 0x7f3204 (on), 0x4ddb70 normal, 0x7f3208 point |
| 0x44ea50 | Polygon_ClipToPlane | Sutherland-Hodgman against the plane, keeps dist >= 0 (eye space) |
| 0x44e7d0 | Frustum_TestSphere | sphere against the camera frustum, 2 = outside |
| 0x49dcb0 / 0x49dd10 | Lua_LockSet / Lua_UnLockSet | lock/unlock of the set resource (set+0x1ac0) |

## Positioned sounds, camera basis, small Lua builtins (2026-10-27)

| Address | Name | What |
| --- | --- | --- |
| 0x0049e590 | Lua_SetSoundPosition | (sound, actor or x y z, min, max, scale); min and max are kept as bytes, defaults from the set (20, 127, 8.0) |
| 0x004a40a0 | Sound_SetPosition | adds the sound to the list of positioned sounds and applies it at once |
| 0x004a4e20 / 0x004a4dc0 / 0x004a3fe0 | PositionedSound_Add / PositionedSounds_DropFinished / PositionedSounds_UpdateAll | list (newest first); finished sounds dropped; all moved again at a setup change |
| 0x004a4e80 | PositionedSound_Apply | volume: straight line from the loudest at 0.8 over `scale` (unsigned clamp), pan from the dot product with the camera right vector |
| 0x004a4010 | Set_SetSoundParams | min 20, max 127, scale 8.0, pan scale 1.5, near 0.8 (set+0x1af8..0x1b04); never changed by scripts |
| 0x00482820 | Set_ChangeSetup | resets the sound parameters, camera change handler, moves the positioned sounds |
| 0x00446a10 | Vec3_NormalizeApprox | rough length max + 0.34375 mid + 0.25 min, normalises with it |
| 0x0044f490 / 0x0044f210 | Camera_BuildBasis / Matrix_AxisAngle | camera right/forward/up (setup+0x50) from position, interest, roll |
| 0x0049f040 | Lua_LoadCostume | only caches the costume (not used for anything visible) |
| 0x00499360 | Lua_SetSelectedActor | gives back the actor that was selected before (nil if none) |

## Puck orientation, matrices (2026-10-27)

| Address | Name | Notes |
|---|---|---|
| 0x00490f50 | Actor_PuckOrient | end of the actor update for ActorPuckOrient: up row turned toward the walker's up at min(angle, seconds * turn rate) when over 2 degrees |
| 0x0044fc60 | Matrix_Multiply | m = m * p (3x3 rows and position) |
| 0x0044f650 | Matrix_ToAngles | pitch, yaw, roll of a matrix |
| 0x0044eeb0 / 0x0044f080 | Angles_ToMatrix / Angles_ToMatrixNoPos | matrix of the three angles (with / without the position); Actor_SetRot uses the forward row of the second for the heading |

## Added 2026-10-28 (SetActorRot)

| Address | Name | Notes |
|---|---|---|
| 0x0049bfa0 | Lua_SetActorRot | Actor_SetRot(actor, angles, snap = isnil(arg 5)); pitch/roll always set at once, only yaw eases |
| 0x0049fb00 | Lua_PointActorAt | makes the walker, turns its heading all the way, negates the turn rate (the body jumps in the next update) |
| 0x0049bcc0 | Lua_GetActorYawToPoint | makes the walker |
| 0x004906b0 | Actor_SetFollowBoxes | on: makes the walker |
| 0x0048fd90 | Actor_UpdateMovement | per frame: path, walker, move chores, costume, puck orient |
| 0x00493230 | Actor_FollowPath | walk to a point; actor+8 bit 0 while it lasts (SetActorRot and TurnActor clear it) |
| 0x004913f0 | Actor_UpdateMoveChores | walk/left/right/rest chores from walker+0xc, +0x10, +0x14; eased turns always the right chore; fades 130 ms |
| 0x00493410 / 0x00493450 | Cos_StartChoreFaded / Cos_StopChoreFaded | play looping, advance 70 ms, fade in / fade out, stop |
| 0x00499be0 | Lua_IsActorTurning | walker+0x28 != 0 |
| 0x00499da0 | Lua_IsActorResting | walker+0x14 (rest chore flag) |
| 0x0047bd20 | Math_SinCosTable | (named before) a small negative turn of a walker comes out 0.022 deg short |

## Monkey4.exe (/emi/Monkey4.exe), 2026-10-28: turning

| Address | Name | Notes |
|---|---|---|
| 0x004163b0 / 0x00429490 | Lua_SetActorRot / Actor_SetRot | as Grim; snap is the flag walker+0xa9, not a negative rate; no heading frame: all three set |
| 0x0041a7d0 | Lua_PointActorAt | heading all the way, snap flag |
| 0x0041a960 | Lua_TurnActorTo | heading by at most |rate|*dt, no time scale; true while a whole step |
| 0x00416630 / 0x00428770 | Lua_TurnActor / Actor_TurnKey | walker+0x98 = +-1, ends path walk; no two-step rule |
| 0x00411550 / 0x004115d0 | Lua_IsActorTurning / Lua_IsActorResting | walker+0xb0 != 0 / walker+0x9c |
| 0x00413240 | Lua_EnableActorPuck | creates or deletes the heading frame |
| 0x00413170 / 0x00428eb0 | Lua_SetActorFollowBoxes / Actor_SetFollowBoxes | creates the heading frame when on |
| 0x00410960 | Lua_WalkActorVector | |
| 0x004287d0 | Actor_StartWalkForward | walker+0x94 = 1, creates the heading frame |
| 0x00428fe0 | Actor_SetHeadingFrame | walker+0x23c create/delete |
| 0x00444b60 | HeadingFrame_Reset | Actor_SetHeadingFrame(1) on an existing frame: clears +0x148, +0x110, +0x114 = (0, 1, 0); heading kept |
| 0x00425740 | Actor_CreateWalker | actor+0x1a0 |
| 0x0040d9a0 | Sys_GetFrameSeconds | |
| 0x00428b80 | Actor_UpdateMovement | dt *= walker+0x28c (time scale); path, walker, chores, look-at |
| 0x0042a730 | Actor_UpdateWalker | key step uses the time scale twice; eased turn chore by direction |
| 0x0042a530 | Walker_UpdateYaw | as Grim's ease, threshold s+0.01; snap cleared every update, a snap plays no turn chore |
| 0x0042a8c0 | Actor_UpdateMoveChores | as Grim, fades 0.25 |
| 0x00428170 | Actor_UpdateLookAt | head look-at |
| 0x0042cb60 | Actor_FollowPath | heading all the way to the next point; walks only within 80 degrees |
| 0x00410e30 / 0x0042ac80 | Lua_WalkActorTo / Actor_WalkTo | does nothing without the heading frame and does not make one |
| 0x00415fd0 | Lua_GetActorYawToPoint | makes the walker and the heading frame |
| 0x00413ef0 | Lua_SetActorTurnRate | stores |rate|; no special values (ScummVM's 1 -> 100 for the voodoo chair is not in the original) |
| 0x004114f0 | Lua_IsActorMoving | path walk flag only, turning does not count |
| 0x004111a0 | Lua_ActorStopMoving | ends the path walk, heading frame = actor position and rotation (a turn stops where it is) |

## Added 2026-10-28 (EMI sort order, Monkey4.exe)

| Address | Name | Note |
| --- | --- | --- |
| 0x004257b0 | Actor_GetEffectiveSortOrder | the sort plane of the walk sector the actor stands in (exact point test) while it follows boxes, else its own order; -2 = the order of the actor it is attached to; a negative plane is kept |
| 0x00413880 / 0x004138f0 | Lua_SetActorSortOrder / Lua_GetActorSortOrder | store the int / return Actor_GetEffectiveSortOrder for the current setup |
| 0x00446490 / 0x00443de0 | Set_FindSectorOfType / Sector_ContainsPointExact | first sector of the type mask that contains the point (height tolerance +0x1c, then the polygon) |
| 0x004433b0 | Sector_Create | visible/active, tolerance 0.005, plane count 0 and the 32 inline sort planes (+0x24) zeroed: planes a set file leaves out read as 0 |
| 0x00446690 | Set_LoadSectorsFromText | text set sector parser; copies only the listed sort planes |
| 0x00413c50 | Lua_DetachActor | the actor's own sort order becomes the parent's effective one (a negative plane included) |
| 0x0041d300 / 0x0042c2c0 | Lua_SayLine / Actor_SayLine | say line: voice, speaker, text object, talk chore |
| 0x0042c6f0 | Actor_CreateSayText | places the text once: over the rectangle at actor+0x140 when the byte actor+0x13c is set and the mode is not 3, else bottom centre of the screen; rect written each frame by Actor_ComputeScreenRect, text x = rect.x + rect.w/2, y = rect.y - text height |
| 0x004130f0 | Lua_SetActorVisibility | bit 1 of actor+0x124 (set = hidden) |

## Added 2026-10-29 (Grim actor lighting, v101 GRIMFANDANGO.EXE)

| Address | Name | Note |
| --- | --- | --- |
| 0x00451510 | rdLight_CalcVertexIntensities | was misnamed rdKeyframe_Interpolate; monochrome per-vertex lighting, see its plate comment for direct/omni/spot formulas; linear attenuation k = 0.2 |
| 0x004514a0 | rdLight_SetAngles | umbra = inner, penumbra = outer, degrees, not halved; 1/(cosInner-cosOuter) only when positive (else hard edge at the penumbra) |
| 0x004a5600 | SetFile_ParseLights | text set lights parser; light record layout in its plate comment |
| 0x0040a050 area | rdCamera_Init | sets attenuation camera+0x45c = 0.2 |

## Added 2026-10-29 (EMI actor lighting, Monkey4.exe)

| Address | Name | Note |
| --- | --- | --- |
| 0x004a1830 | Light_GetShade | per light shade at a vertex; formulas in its plate comment (matches EMIModel::updateLighting) |
| 0x004a1780 | Light_AddToColor | accum.rgb += round(color * shade) |
| 0x004a1b20 | Light_IsOutOfReach | omni/spot: bbox closest point further than far |
| 0x0049acc0 | Model_LightVertices | nearest maxLights lights (32 static, 4 dynamic) by distance to the bbox centre; base = last light in the list (ambient), 128 grey if none; Color_Saturate |
| 0x00465350 | Color_Saturate | divide by the largest channel when over 255 |
| 0x0049dc90 | Model_UpdateLighting | static once with 32 lights, dynamic with 4; flag 0x20000 uses FUN_0049b210 instead (not decoded) |
| 0x004635a0 / 0x00463680 / 0x00463760 | (GL device vtable +0x54/+0x58/+0x5c) | fixed function directional/point/spot light setters; no callers found |
| 0x004a00a0 (Grim) | Lua_GetAngleBetweenActors | unsigned angle between the walker heading axis and the 3D direction to the other actor (delta normalized with its vertical part, not flattened) |
| 0x0041af40 (EMI, Monkey4.exe) | Lua_GetAngleBetweenActors | acos(dot((sin yaw, 0, cos yaw), normalized 3D delta)), degrees, unsigned; actor yaw = +0xb4 |
| 0x00451800 | rdLight_CalcFaceIntensity | (was rdKeyframe_InterpolateNode) flat face light for face light mode 2; every light treated as omni at the face's first vertex, normal negated for back faces |
| 0x00450060 | Matrix34_TransformPoint | (was Vec3_Sub) out = a*R + t |
| 0x0044efd0 | Matrix34_InvertRigid | (was Matrix_Transpose) rotation transposed, translation -(R^T t) |

## Added 2026-11-11 (EMI skeleton animation, Monkey4.exe)
| Address | Name | What it does |
|---|---|---|
| 0x0044b7d0 | Skeleton_BuildNodes | builds the node tree of a .skl: local pos at node+0x94, quat at +0xa0, parent found by name ("no_parent" = root) |
| 0x00466450 | Node_UpdateLocalPosFromWorld | local pos (+0x94) from world pos (+0xe0) through the parent's world rotation |
| 0x004661f0 | Node_UpdateLocalRot | local quat (+0xa0) from the world rotation matrix (+0xbc) and the parent's |
| 0x00466560 | Node_UpdateChildren | recursive dirty-flag update of the children (flags at +0x90) |
| 0x0047f590 | Animation_Load | loads an animation (ANIMNAME, ANIMENTRIES, ANIMLENGTH, ANIMENTRY); track type 3 = translation (vtable 0x4aee84), 4 = rotation (vtable 0x4aee54) |
| 0x00481550 | RotationTrack_Evaluate | rotation key at a time: slerp between keys (vtable slot 0x24) |
| 0x0047dec0 | ANode_ApplyAnimationChannels | a node with animation channels: position from translation channels only, starting at (0,0,0); rotation from rotation channels only, starting at identity; the bind pose is not the base (kitchen lever, bug 11794) |
| 0x0047e4b0 | ANode_BlendRotationChannels | per-priority weighted quaternion blend of the rotation channels, levels combined low to high |
| 0x004955e0 | Costume_ApplyComponentState | 'cmap' component writes its colormap into the parent model instance (+0x4c); called at draw for every costume sharing the main model, top first, so the lowest costume's colormap wins (bug #11818) |
| 0x00496950 | ThingInstancer | model instance (+0x4c colormap) shared with the same-named component of the costume below |
| 0x00494e80 / 0x00494e10 | sputCostume_PushCostume / sputCostume_PopCostume | push shares the draw list when the main model is the same; pop restores nothing |
| 0x00466f10 | ??0CQuaternion@@QAE@XZ | (library name) the default quaternion is (0,0,0,0), not identity: the animation blend starts from it |
| 0x0047e9f0 | Quat_AddInPlace | this += q component-wise |
| 0x0046bf10 | Quat_ToMatrix33 | rotation matrix from a quaternion, not normalized: s*q gives (1-s^2)I + s^2 R |
| 0x00465d80 | Node_UpdateWorld | world matrix of a node from its local quaternion/matrix and the parent's |
| 0x0047dce0 | ANode_Construct | skeleton node animation part: channel count +4 = 0, flag +8 = 1, translation channel list +0xc, rotation list +0x10 |
| 0x0047de40 | ANode_AddChannel | count++, channel into the translation (track type 3) or rotation (4) list |
| 0x0047de80 | ANode_RemoveChannel | count--, channel out of its list |
| 0x0047ec80 | ChannelList_Remove | removes a channel from the active or the inactive sublist (by the playback's 0x10 flag) |
| 0x0047ee40 | ChannelList_Activate | channel from the inactive sublist into the active one, kept sorted by priority |
| 0x0047ef40 | ChannelList_Deactivate | channel from the active sublist to the inactive one (stays attached) |
| 0x0044ba00 | AnimInstance_Construct | animation component instance; attaches its channels to the skeleton nodes |
| 0x0044bca0 | AnimInstance_Destruct | detaches the channels |
| 0x0044bd80 | AnimInstance_AttachChannels | one channel per track to the node of that bone |
| 0x0044bec0 | AnimInstance_DetachChannels | the reverse |
| 0x0044c000 | AnimInstance_SetKey | costume keys 0 stop, 1 play, 2 pause, 3/4 loop on/off, 5-9 fade in, 10-14 fade out |
| 0x00481e80 | AnimPlayback_Play | sets playing (time 0 unless paused, weight 1 unless fading), activates the channels |
| 0x00481f10 | AnimPlayback_Pause | paused, channels activated (the pose is held) |
| 0x00481f60 | AnimPlayback_Stop | flags 0, channels deactivated (still attached) |
| 0x00481fa0 | AnimPlayback_FadeIn | weight 0, rate 1/t |
| 0x00481fd0 | AnimPlayback_FadeOut | rate weight/t |
| 0x00481ff0 | AnimPlayback_Update | fades (fade-out ends at weight 0 still playing), time; a one-shot past its end: flags 0, channels deactivated |
| 0x0042ec80 | ChoreInstance_Construct | each PlayActorChore makes a new chore instance with a new handle |
| 0x0042ed80 | ChoreInstance_CreateComponents | one component instance per track (the animation ones attach channels) |
| 0x0042f580 | ChoreInstance_Update | chore time and keys; past the length and not looping: flagged done 0x80000000 |
| 0x0042f1a0 | ChoreInstance_IsDone | flag 0x80000000 |
| 0x00429810 | Actor_CreateChoreInstance | new chore instance, its handle appended to the actor's chore list +0x18c |
| 0x00429690 | Actor_DestroyFinishedChores | destroys the done chore instances each frame: channels detached; a node with none left keeps its last pose |

## Added 2026-11-11 (EMI joystick axes, Monkey4.exe)

| Address | Name | What |
| --- | --- | --- |
| 0x00410080 | sputLua_NotifyAxisHandler | per frame: system.axisHandler(id, analog value) when the value changed; same as Grim's sputLua_NotifyControlHandlers (0x0049e150 area) axis branch |
| 0x00443210 | stdControl_ReadAxis | (raw - centre) * scale, 0 inside the per-axis dead zone; same as Grim's 0x00477160 |

## Added 2026-11-16 (EMI sprites, Monkey4.exe)

| Address | Name | What |
| --- | --- | --- |
| 0x0043ab00 | Costume_CreateComponentByTag | builds a costume component from its '!tag' ('sprt' = sprite) |
| 0x004a27d0 | Sprite_Construct | sprite object: size +0x18, pos +0x20, 4 per-corner colours +0x2c (a,r,g,b ints), 4 UVs +0x6c |
| 0x004a36c0 | Sprite_Draw | D3D quad, each corner gets its own colour; then global alpha (+0xc/+0x10) and per-vertex local alpha (+0x14/+0x18 map) |
| 0x00413570 | Lua_SetActorLocalAlpha | alpha -1/2/3 = mode off/replace/modulate, else per-vertex alpha in the primitive's map; only shipped use is wed.fuse (a mesh) |
| 0x00489bbe | __RTDynamicCast | MSVC CRT dynamic_cast |
| 0x00429f90 | Actor_DrawShadows | (named earlier) only primitives that dynamic_cast RPrimitive -> RMesh are drawn into a shadow; sprites never cast shadows |
| 0x004a01f0 | (empty) | sprite vtable slot after Sprite_Draw does nothing |
| 0x004a2ed0 | Sprite_LoadBinary | .sprb loader; render flags (ScummVM _flags2) at sprite+0x8c go to the draw primitive unchanged, no overworld case |

## Added 2026-11-16 (EMI say-text rect, Monkey4.exe)

| Address | Name | Note |
| --- | --- | --- |
| 0x004258f0 | Actor_ComputeScreenRect | say-text rect: 8 corners of each primitive's model-space bbox (resource vbase +0x28) through the actor world matrix + camera, z < 0 skipped, one unclipped min/max -> actor+0x140 {x, y, w, h} via ftol; returns rect overlaps viewport |
| 0x00428a10 | Set_UpdateActors | per frame: draw list, actor+0x13c = Actor_ComputeScreenRect, Actor_UpdateMovement |
| 0x00465930 | Node_TransformPointToWorld | point by the node world matrix (+0xbc..0xe8) |
| 0x004260e0 | Actor_Save | actor save; writes the say rect +0x140..0x14c, +0x13c and primitives by resource name |
| 0x0041c820 | Lua_SetOffscreenTextPos | off-screen say rect DAT_004d6800 {x, y, 0, 0}; startup default (W/2, H/16) = (320, 30); Actor_CreateSayText uses it when actor+0x13c is clear |
| 0x0048ad30 | CRT_ftol | MSVC _ftol, truncates |
| 0x004a0be0 | Node_RemovePrimitiveAt | erase from node+0x110 primitive vector; called by costume component destructors |

## Grim say-text box (v101 GRIMFANDANGO.EXE, existing names, 2026-11-16)

| Address | Name | Note |
| --- | --- | --- |
| 0x0048b2e0 | sputText_CreateActorText | x = box.x + box.w/2, y = box.y - text height when nScreenBoxValid and mode != 3; else default subtitle pos, or the projected actor position when it has no costume or is hidden; clamps 40 px sides, 10 px top/bottom |
| 0x004950a0 | sputCostume_InternalDraw3D | per model component: extents reset to (640,480,0,0), rdThing_Draw, nScreenBoxValid = drew something (last component wins); aScreenBox = extents only for the costume's main model |
| 0x00406860 | rdCache_AddProcFace | extents = min/max of each frustum-clipped, projected face (round + ftol) |
| 0x00485290 | Actor_ComputeScreenBox | same box for draw items of type 1 (main model only) |
| 0x0040dc30 | rdPrimit3_GetScreenCoord | fallback for an actor with no costume or hidden (only when the box is not valid and it is in the current set): projected actor position if inside the view frustum |
| 0x004a5ecc in sputRoom_RemoveActor | (store) | nScreenBoxValid only cleared here and by the draw, so hiding an actor keeps its last box |

## Added 2026-11-21 (EMI say-line / text layout, Monkey4.exe; ScummVM bugs 11790, 11807, 11809)

| Address | Name | Note |
| --- | --- | --- |
| 0x00416ef0 | Lua_WorldToScreen | (function created) camera projection to pixels, nil, nil off the viewport, else normalized x and y UP |
| 0x0041d470 | SayLine_ParseTable | SayLine table x AND y = ftol(320*(v+1)) (y uses the width, not 240); explicit y is the text TOP |
| 0x0041cd70 | TextObject_SetParamsFromTable | MakeTextObject x = ftol(320v+320), y = ftol(240-240v) (truncation; ScummVM truncates v*320 first for x) |
| 0x00433830 | TextObject_BreakLine | greedy wrap; centred max width 2*min(x-left, left+width-x) from the CURRENT x |
| 0x00433a80 / 0x00433bf0 | TextObject_GetMaxLineWidth / TextObject_GetHeight | widest wrapped line / lines * font height |
| 0x00432970 / 0x00432d80 | TextObject_Construct / TextObject_InitFromDefaults | x = 0 unless the defaults object DAT_004d7270 has one |

Actor_CreateSayText detail (disassembly 0x42c828..0x42c8bd): width measured BEFORE x is set (x = 0, so one word per line: half the
widest word); x = rect.x + rect.w/2 (or explicit x), clamped so x -/+ halfWidest stays 40 px inside the screen; height then measured
at that x; y = rect.y - height (or explicit y as is), clamped to [25, 480 - 25 - height].

Grim v1.01 (GRIMFANDANGO.EXE) uses the same rule, decoded 2026-11-21: sputText_CreateActorText (0x0048b2e0) copies
g_SubtitleTextCtx (0x004e84c8: nX = 0, flags 5; scripts only call SetSayLineDefaults({ font = talk_font })), measures
Text_GetStringWidth (0x004aaa80, via text_FindNextBreak 0x004ab210: centred max width 2*min(nX - clip.x, clip.x + clip.w - nX))
before setting nX, so the width is the widest word; x clamped 40 px inside; y clamped to [10, H - 10 - height] (EMI: 25).

## Added 2026-11-21 (EMI pictures for the clean room, Monkey4.exe)

| Address | Name | Note |
| --- | --- | --- |
| 0x0040be30 | Game_RunFrame | frame time, Lua tasks (0x40f740), actors, draw (0x43d0c0, ends in SwapBuffers 0x4631ba with -gl), then the game's screenshot when DAT_004d53b0 |
| 0x0040da30 | Game_SaveScreenshotTga | numbered ".\%s\%s%02d.tga" (counter DAT_004d53b4), then Render_WriteScreenshotTga |
| 0x0040cd60 | Render_WriteScreenshotTga | the frame through the renderer's vtable +0xd4, written as .tga; not decoded further |
| 0x0041cd70 | TextObject_SetParamsFromTable | (more) width / height are pixels into the text's rectangle +0x24 / +0x28; Actor_CreateSayText replaces that rectangle by the screen's, so SetSayLineDefaults' width and height do nothing to say lines |

## Added 2026-11-21 (EMI sort-order sectors, bug 11816, Monkey4.exe)

| Address | Name | Note |
| --- | --- | --- |
| 0x00438a40 | Set_LoadBinary | .setb reader; a sector's sort planes are counted ints into the 32 inline planes (+0x24, zeroed by Sector_Create); height 0 becomes 0.005 (+0x1c, the plane tolerance); sectors kept in file order |
| 0x00445880 | Set_LinkWalkSectors | neighbour links between touching walk sectors after loading |
| 0x00446590 | Set_FindSectorOfTypeOrClosest | Set_FindSectorOfType, else the nearest active visible sector of the type (first of equals) |
| 0x00429270 | Actor_PlaceViaHeadingFrame | placement and every path waypoint: the heading frame's sector is cleared and picked again by position (first holding it, else closest), the point snapped into it |
| 0x00444b90 | HeadingFrame_AttachToSet | frame+0x14c = set; picks the sector when there is none; snaps the frame into it |
| 0x00444fa0 | HeadingFrame_Step | one walk step on the sector plane; at an edge hands over to the first active sector holding the exit point (its own deactivated meanwhile); keeps its sector between edges, also where an earlier-listed sector overlaps |
| 0x00444cf0 / 0x00444d40 / 0x00444c50 | HeadingFrame_TurnToward / HeadingFrame_YawDeltaTo / HeadingFrame_AddYaw | yaw helpers of the heading frame |
| 0x00445980 | WalkPlaneCollection_BuildPath | (name from the exe's error strings) start/end by the walk mask 0x1000, search over Set_LinkWalkSectors' links: hot, camera and special sectors are never on a path |
| 0x0042aee0 | Actor_PathAvoidActor | plain WalkActorTo passes no actor (path unchanged); WalkActorToAvoiding: way round a box about the other actor, corners snapped to the floor |

Sort order rule (Actor_GetEffectiveSortOrder 0x4257b0, computed when asked, not cached): the heading frame's sector plane for the
current setup (planes past the count read 0); before the frame exists, the first active walk sector holding the position.
The sector is not re-checked for being active: switching it off under a standing actor keeps its plane and its position
(cleanroom emi_sort_sector.lua: ess_box_off).

Grim v1.01 (GRIMFANDANGO.EXE), checked for the same bug: BuildPath (0x4a9430), Planner_FindPath (0x4a94d0) and
FindExitPoints (0x4a96f0) take walk planes only (WalkPlane_PlaneAt(.., 0x1000), dwType & 0x1000), and ParseCollection
(0x4a7bc0) types `chernobyl` 0x8000, `funnel` 0x1100: chernobyl sectors are never on a path (cleanroom fake_links.lua:
fkl_hot_path).

## Added 2026-11-22 (actor collisions on path walks, ScummVM bug 11813)

| Address | Name | Note |
| --- | --- | --- |
| 0x0042ce50 (Monkey4.exe) | Actor_CollideWithOthers | EMI's collision pass for one moved actor, path walks included: only when the mover's mode (extra+0x270) is on (box or sphere, both act as a sphere); radius = half the x-z diagonal of the model's bounding box * scale (extra+0x274), no 0.8; centre = the model's centre through the world matrix, 3D distance; only sphere-mode (2) actors push, to r1 + r2 (Actor_PlaceViaHeadingFrame); then the Lua callback FUN_0040f9a0 (cleanroom emi_collision_path.lua) |

Grim (GRIMFANDANGO.EXE): Collision_UpdateMovedActors (0x4939a0) tests every actor whose position changed in the frame, path
walks included, whatever the mover's own mode; the sphere branch of Collision_TestActorAgainstOthers (0x4939f0) only pushes,
the box branch also re-plans the path (Walker_AvoidActorPath). The sphere centre is the model header's centre (rdModel3
+0x78) turned with the actor, without the insert offset (+0x84); rdModel3_LoadEntryBinary keeps the header's radius, centre
and box (no rdModel3_LoadPostProcess for binary models). Cleanroom collision_edge.lua.

## Monkey4.exe (/emi/Monkey4.exe), 2026-11-22: sector lookups by name

| Address | Name | What |
| --- | --- | --- |
| 0x00416790 | Lua_IsActorInSector | sector by exact name (first with it), Sector_ContainsPointExact(world pos +0xe0, 1): off or invisible sector contains nothing |
| 0x00416a40 | Lua_IsPointInSector | the same with a point (exact name, not Grim's substring) |
| 0x004464e0 | SectorList_FindByExactName | first sector of the set's list whose name equals the string (case-sensitive, same length) |

Grim v1.01 for comparison (already named): sputLua_IsActorInSector 0x49c2c0, sputLua_IsPointInSector 0x49c4c0: substring
(String_ContainsSubstring) over the walk-plane list from g_pWalkPlane_wp_head, first that contains the point, WalkPlane_Within(.., 1)
(0x4a6980) skips inactive / invisible sectors.

## Monkey4.exe (/emi/Monkey4.exe), 2026-11-22: MakeSectorActive, GetSectorOppositeEdge

| Address | Name | What |
| --- | --- | --- |
| 0x004199d0 | Lua_MakeSectorActive | a number is the sector's id (lua_isnumber first), a string the exact name; visible byte +0x18 = 0 for nil, 1 otherwise |
| 0x0042cb10 | Actor_MoveToSectorOppositeEdge | GetSectorOppositeEdge's work: Sector_JumpOut on the actor's node, then the actor placed there; nothing returned |
| 0x00444780 | Sector_JumpOut | four edges only; the line to 10 units behind the actor crossed with the edges (FUN_004441a0: segments on x-z, farthest crossing, first of a tie; none: no move), then the same fraction from the other end on edge (i+2)%4 |

Grim v1.01 for comparison (already named): sputLua_MakeSectorActiveL 0x49eeb0 checks lua_isstring first (true for a number in Lua 3.1), so a
number is a name; sputLua_GetSectorOppositeEdge 0x49ed90 -> sputActor_LeaveSector 0x4931f0 -> WalkPlane_JumpOut 0x4a7390: the far point
clipped back onto each edge it is outside of (WalkPlane_Intersection 0x4a6d10, no move when it is inside the sector), the actor moved,
nothing returned. Cleanroom sector_opposite.lua, emi_sector_opposite.lua.

## Added 2026-11-24 (what an actor sees: GetVisibleThings, Monkey4.exe)

| Address | Name | What it does |
|---|---|---|
| 0x415c80 | Lua_GetVisibleThings | the other actors of the viewer's set it sees (skips itself; none when viewer +0x124 bit 1) |
| 0x428070 | Actor_CanSeeActor | both in the same set (exact name compare), then Actor_CanSeePoint at the other's world position |
| 0x427eb0 | Actor_CanSeePoint | needs the walker (+0x1a0); forward (x-z, normalized) . way to the point (normalized, y dropped, normalized) >= walker+0x8c |
| 0x412ff0 | Lua_SetActorFOV | creates the walker if missing, walker+0x8c = cos(fov/2) |

Grim v1.01 (already named): sputLua_GetVisibleThingsL 0x49b9e0, sputActor_CanActorSeeActor 0x48fb80 (stricmp of the set names),
sputActor_CanActorSeePoint 0x48fa60 (from head joint 0 of the top costume, forward row of the orient matrix not renormalized,
>= costume flViewCos), sputActor_SetActorHead 0x48f9d0 (flViewCos = cos(|maxRoll|/2)), Costume_InitRecord 0x494fb0 (joints -1,
flViewCos -0.35), sputCostume_PushCostume 0x494e80 (copies the head of the costume below when the main model is the same).
ScummVM: Actor::canSee / canSeePoint. Cleanroom grim/sight.lua (sight_head_*), emi/emi_sight.lua.

## Monkey4.exe (/emi/Monkey4.exe), 2026-11-26: the walk step's exit point (precision)

| Address | Name | What |
| --- | --- | --- |
| 0x004440c0 | Segment2D_Intersect | x-z crossing of the step with an edge (vertex i -> i-1); x87: edge difference unrounded, step and start-vertex stored as floats, denominator (step x edge) computed in extended and stored as a float, t rounded to float, u kept in extended; 0 <= t, u <= 1 |
| 0x004441a0 | Sector_FindStepExit | last crossing (t > best, best starts -1; a later t == 0 tie sets the angle to 0); angle = acos(float dot of the normalized step and edge, clamped) * rad2deg (0x4d8dd0, set at run time); exit = (end-start)*t + start in extended; returns angle + 0.1f or -(180.2f - angle) over 90 (float constants), raw angle and exit = start when best <= 0. ScummVM Sector::getExitInfo(Line3d) |
