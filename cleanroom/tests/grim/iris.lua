-- The iris (IrisDown closes the screen to a point, IrisUp opens it again), seen through cr_snap(key, "lit"): the box of
-- the pixels the iris leaves open (the background of cr_flat is lighter than the dark level of snaps.py; the iris is black).
-- On the original (Render_StartIrisClose 0x486eb0 / Render_StartIrisOpen 0x486ef0) IrisDown(x, y, ms) stores the clock
-- (Timer_GetTotalMs: 17 ms a frame with simtime), x, y and ms (IrisUp: -ms) and sets render flag 4. Each frame
-- Engine_RenderFrame takes t = |elapsed / ms|; past 1 an opening iris ends (flag 4 off), a closing one stays closed
-- (flag 8); Render_DrawIris (0x486d00) blacks out the screen outside a rectangle around (x, y), closed by t (IrisDown) or
-- 1 - t (IrisUp). IrisComplete (original only) is 1 when no iris is running or it is closed; IrisClear (original only)
-- takes the iris away at once. A time of 0 divides 0 by 0 on the original (the argument probe's IrisDown(0, 0, 0)
-- crashes it), so the tests use none.

-- (no iris left over for the next test: IrisClear on the original, a short IrisUp on ScummVM, which has no IrisClear)
cr_iris_reset = function()
	local clear = getglobal("IrisClear")
	if type(clear) == "function" or type(clear) == "cfunction" then
		clear()
	else
		IrisUp(320, 240, 17)
	end
	cr_frames(3)
end

cr_iris_test = function(name, fn)
	cr_test("iris_" .. name, function()
		MakeCurrentSet("cr_flat.set")
		cr_frames(2)
		cr_iris_reset()
		%fn(%name)
		cr_iris_reset()
	end)
end

-- (what is open after each step frames, up to n frames after the call. Not in the frame of the call: the original's
-- picture is the frame drawn before it, ScummVM draws the scene for the picture at once, with the iris just started)
cr_iris_watch = function(k, n, step)
	local i = step or 1
	while i <= n do
		cr_frames(step or 1)
		cr_snap(k .. "_" .. i, "lit")
		i = i + (step or 1)
	end
end

-- (IrisComplete on each of n frames; nil on ScummVM, which does not have it)
cr_iris_done = function(k, n)
	local f = getglobal("IrisComplete")
	if type(f) ~= "function" and type(f) ~= "cfunction" then
		cr_log(k .. "_missing", 1)
		return
	end
	local i = 0
	while i < n do
		cr_log(k .. "_" .. i, f())
		break_here()
		i = i + 1
	end
end

-- no iris: the whole screen is open
cr_iris_test("none", function(k)
	cr_snap("open", "lit")
end)

-- closing over 170 ms (10 frames) around the centre, every frame, then long after
cr_iris_test("down", function(k)
	IrisDown(320, 240, 170)
	cr_iris_watch("f", 13)
	cr_frames(20)
	cr_snap("later", "lit")
end)

-- opening over 170 ms from closed
cr_iris_test("up", function(k)
	IrisDown(320, 240, 17)
	cr_frames(5)
	cr_snap("closed", "lit")
	IrisUp(320, 240, 170)
	cr_iris_watch("f", 13)
	cr_frames(20)
	cr_snap("later", "lit")
end)

-- off the centre: the rectangle closes on (100, 400) and opens from (500, 100)
cr_iris_test("corner", function(k)
	IrisDown(100, 400, 170)
	cr_iris_watch("down", 12, 3)
	cr_frames(5)
	IrisUp(500, 100, 170)
	cr_iris_watch("up", 12, 3)
end)

-- a longer one: 680 ms (40 frames), every 8 frames
cr_iris_test("long", function(k)
	IrisDown(320, 240, 680)
	cr_iris_watch("f", 48, 8)
end)

-- IrisUp while IrisDown is half way: the opening starts from closed, not from where the closing was
cr_iris_test("reverse", function(k)
	IrisDown(320, 240, 340)
	cr_frames(10)
	cr_snap("half", "lit")
	IrisUp(320, 240, 340)
	cr_iris_watch("f", 6)
	cr_frames(25)
	cr_snap("later", "lit")
end)

-- IrisDown again while it closes: it starts over from open
cr_scummvm_differs("iris_restart", "the original redraws only what changed: an iris that starts again from open leaves the black of the old one until it gets back there; ScummVM draws the whole screen")
cr_iris_test("restart", function(k)
	IrisDown(320, 240, 340)
	cr_frames(10)
	cr_snap("half", "lit")
	IrisDown(320, 240, 340)
	cr_iris_watch("f", 16, 2)
end)

-- a negative time: on the original IrisDown(-ms) is IrisUp(ms) and the other way round (the sign is the direction)
cr_scummvm_differs("iris_negative_down", "on the original the sign of the time is the direction (IrisDown(-ms) opens); ScummVM ends at once (the time is already past) and stays closed")
cr_iris_test("negative_down", function(k)
	IrisDown(320, 240, 17)
	cr_frames(5)
	IrisDown(320, 240, -170)
	cr_iris_watch("f", 13, 2)
end)

cr_scummvm_differs("iris_negative_up", "on the original IrisUp(-ms) closes; ScummVM ends at once and is open")
cr_iris_test("negative_up", function(k)
	IrisUp(320, 240, -170)
	cr_iris_watch("f", 13, 2)
end)

-- a closed iris and a new set: does it stay closed?
cr_iris_test("set_change", function(k)
	IrisDown(320, 240, 17)
	cr_frames(5)
	MakeCurrentSet("cr_edge.set")
	cr_frames(3)
	cr_snap("new_set", "lit")
	MakeCurrentSet("cr_flat.set")
	cr_frames(3)
	cr_snap("back", "lit")
end)

-- a text object over a closed iris: drawn after the iris or under it (the box of the bright pixels: the white text)
cr_scummvm_differs("iris_text", "the text is 3 pixels lower on ScummVM (the text object, not the iris)")
cr_iris_test("text", function(k)
	local t = MakeTextObject("Clean room", { font = LockFont("cr_font.laf"), fgcolor = MakeColor(255, 255, 255), x = 300, y = 230 })
	cr_frames(3)
	cr_snap("open")
	IrisDown(320, 240, 17)
	cr_frames(5)
	cr_snap("closed")
	IrisUp(320, 240, 170)
	cr_frames(5)
	cr_snap("half")
	KillTextObject(t)
end)

-- IrisComplete, frame by frame: before, while closing, closed, while opening, open
cr_scummvm_differs("iris_complete", "no IrisComplete on ScummVM")
cr_iris_test("complete", function(k)
	cr_iris_done("idle", 2)
	IrisDown(320, 240, 170)
	cr_iris_done("down", 13)
	cr_frames(10)
	cr_iris_done("closed", 2)
	IrisUp(320, 240, 170)
	cr_iris_done("up", 13)
	cr_frames(10)
	cr_iris_done("open", 2)
end)

-- IrisComplete with a negative time
cr_scummvm_differs("iris_complete_negative", "no IrisComplete on ScummVM")
cr_iris_test("complete_negative", function(k)
	IrisDown(320, 240, -170)
	cr_iris_done("down", 13)
end)

-- IrisClear (the original only): half way and closed, the screen is open at once and IrisComplete is 1
cr_scummvm_differs("iris_clear", "no IrisClear on ScummVM")
cr_iris_test("clear", function(k)
	local clear = cr_fn("IrisClear")
	if not clear then
		return
	end
	IrisDown(320, 240, 340)
	cr_frames(10)
	clear()
	cr_iris_done("half_done", 1)
	cr_snap("half", "lit")
	cr_frames(2)
	cr_snap("half_later", "lit")
	IrisDown(320, 240, 17)
	cr_frames(5)
	clear()
	cr_iris_done("closed_done", 1)
	cr_frames(2)
	cr_snap("closed_later", "lit")
	IrisUp(320, 240, 340)
	cr_frames(10)
	clear()
	cr_frames(2)
	cr_snap("up_later", "lit")
end)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("iris_corner")
cr_scummvm_differs("iris_down")
cr_scummvm_differs("iris_long")
cr_scummvm_differs("iris_reverse")
cr_scummvm_differs("iris_up")
