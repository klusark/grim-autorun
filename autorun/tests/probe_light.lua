-- Probe (PROBE lines): actor lighting in hq, setup hq_elews (near Eva), where the original is much darker than ScummVM was.
-- Manny is put at fixed places and headings, held for LIGHT_HOLD frames, then hidden for LIGHT_GAP frames (the gap separates the poses in
-- the tracer log of the original, which has no Lua lines). One frame of every pose is dumped (ar_frame light_<tag>). (His chores are not
-- stopped: a Grim costume with no chore playing hides its meshes.)
--   ScummVM: DEBUGFLAGS=models ... sh run_chapter.sh tests/probe_light.lua 300   (MESHLIGHT lines: the mean light level of each mesh)
--   original: GRIMRUN=./grimtrace.exe GRIMTRACE_BP=40d831 GRIMTRACE_PEEK="eax+0,eax+10,eax+50" GRIMTRACE_QUIET=1 GRIMTRACE_ARMAT=LIGHTARM
--            GRIMTRACE_DISARMAT=LIGHTDISARM GRIMTRACE_MAX=200000 sh orig_test.sh tests/probe_light.lua
--            (40d831: rdModel_DrawMesh right after the mean light level of the mesh is stored at mesh+0x5c; eax = the mesh, its name at +0)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
LIGHT_HOLD = 8
LIGHT_GAP = 4
light_place = { id = "lt", set = "hq", from = { -0.645928, -0.175311, 0 } }
ar_nt_place(light_place)
hq:current_setup(hq_elews)
manny:set_run(FALSE)
sleep_for(1000)
light_poses = {
	{ "eva_0", -0.645928, -0.175311, 0 },
	{ "eva_90", -0.645928, -0.175311, 90 },
	{ "eva_180", -0.645928, -0.175311, 180 },
	{ "eva_270", -0.645928, -0.175311, 270 },
	{ "beam_0", -0.35, 0.0, 0 },
	{ "beam_90", -0.35, 0.0, 90 },
	{ "beam_180", -0.35, 0.0, 180 },
	{ "beam_270", -0.35, 0.0, 270 },
	{ "mid_0", -0.3, -0.25, 0 },
	{ "mid_270", -0.3, -0.25, 270 },
	{ "far_0", 0.0, -0.2, 0 },
	{ "far_180", 0.0, -0.2, 180 },
}
PrintDebug("LIGHTARM\n")
-- (the tracer polls the log once a second)
sleep_for(2500)
local i = 1
while light_poses[i] do
	local p = light_poses[i]
	manny:set_visibility(FALSE)
	local k = 0
	while k < LIGHT_GAP do
		break_here()
		k = k + 1
	end
	manny:setpos(p[2], p[3], 0)
	manny:setrot(0, p[4], 0)
	manny:set_visibility(TRUE)
	k = 0
	while k < LIGHT_HOLD do
		break_here()
		k = k + 1
		local q = manny:getpos()
		local r = manny:getrot()
		PrintDebug("PROBE " .. p[1] .. " " .. k .. format(" pos %.6f %.6f %.6f rot %.6f %.6f %.6f setup %d", q.x, q.y, q.z, r.x, r.y, r.z, hq:current_setup()) .. "\n")
		if k == LIGHT_HOLD then
			ar_frame("light_" .. p[1])
		end
	end
	i = i + 1
end
PrintDebug("LIGHTDISARM\n")
sleep_for(2500)
AR_KEEP_GOING = nil
ar_finish()
