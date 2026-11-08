-- Binary keyframes (formats.keyframe_binary): cr_kbbox.cos has cr_slide_b.key, the slide of keyframe.lua (cr_slide.key)
-- in the binary format, at 15 frames a second; cr_kfbox.cos has cr_slide_f.key, the same at 30 frames a second (ScummVM
-- plays every binary keyframe at 15). The original's node locations do not follow a keyframe (keyframe.lua): what is seen
-- is the box on the screen (cr_snap) during the slide and the frames until the chore ends.

cr_kfb_test = function(name, cos)
	cr_test("kfb_" .. name, function()
		MakeCurrentSet("cr_open.set")
		local a = LoadActor("cr_kfb_a")
		PutActorInSet(a, "cr_open.set")
		PutActorAt(a, -1, 0, 0)
		SetActorRot(a, 0, 0, 0)
		SetActorCostume(a, %cos)
		cr_frames(2)
		cr_snap("rest_box")
		PlayActorChore(a, 0, %cos)
		cr_frames(30)
		cr_snap("f30_box")
		local f = 30
		while IsActorChoring(a, 0, FALSE, %cos) and f < 300 do
			break_here()
			f = f + 1
		end
		cr_log("frames", f)
		cr_frames(2)
		cr_snap("end_box")
		StopActorChore(a)
		PutActorInSet(a, nil)
	end)
end

-- the text slide, as the reference for the binary one (the same file in text: cr_kbox.cos)
cr_scummvm_differs("kfb_text", "ScummVM shows the keyframe on the screen, the original does not (kf_once)") cr_kfb_test("text", "cr_kbox.cos")

-- the binary slide at 15 frames a second
cr_scummvm_differs("kfb_slide", "ScummVM shows the keyframe on the screen, the original does not (kf_once)") cr_kfb_test("slide", "cr_kbbox.cos")

-- the binary slide at 30 frames a second
cr_scummvm_differs("kfb_fast", "ScummVM shows the keyframe on the screen, the original does not (kf_once)") cr_kfb_test("fast", "cr_kfbox.cos")
