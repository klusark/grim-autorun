-- Cases in which the original and ScummVM end up in different places for a reason that is known and not worth copying (tools/test_all.py counts them
-- apart from the failures). Each has its reason. The collision of the original with a box, head on, slides the mover sideways by the length of its
-- way into the box, in a direction that comes from the float noise of a rotation axis that is zero (FUN_00494100 turns the direction by the angle
-- to the face about n x dir): within 1.5 cm at the first contact, more where the steered walks go on sliding.
AR_KNOWN = {
	collisionS_box_0_0_35 = "head-on slide of the original (float noise of the axis)",
	collisionS_box_0_180_35 = "head-on slide of the original (float noise of the axis)",
	collisionS_box_0_270_35 = "head-on slide of the original (float noise of the axis)",
	collisionS_box_0_90_35 = "head-on slide of the original (float noise of the axis)",
	collisionS_box_90_0_35 = "head-on slide of the original (float noise of the axis)",
	collisionS_box_90_180_35 = "head-on slide of the original (float noise of the axis)",
	collisionS_box_90_270_35 = "head-on slide of the original (float noise of the axis)",
	collisionS_box_90_90_35 = "head-on slide of the original (float noise of the axis)",
	collisionS_box_velasco = "head-on slide of the original (float noise of the axis)",
	collision_box_90_180_35 = "head-on slide of the original (float noise of the axis)",
	collision_box_0_0_35 = "head-on slide of the original (float noise of the axis)",
	collision_box_0_180_35 = "head-on slide of the original (float noise of the axis)",
	collision_box_90_270_50 = "head-on slide of the original (float noise of the axis)",
	collision_box_140_270_50 = "head-on slide of the original (float noise of the axis)",
	collision_box_140_270_35 = "head-on slide of the original (float noise of the axis)",
	collision_sphere_0_90_50 = "head-on slide of the original (float noise of the axis)",
	collision_sphere_0_135_50 = "head-on slide of the original (float noise of the axis)",
	collision_sphere_0_180_50 = "head-on slide of the original (float noise of the axis)",
	collision_sphere_0_225_50 = "head-on slide of the original (float noise of the axis)",
	collision_sphere_0_270_50 = "head-on slide of the original (float noise of the axis)",
	pc_stair_to_morgue = "the original is held up on this stair at -3.55 5.78 as well (ch23); ScummVM now ends there too, since its edge rules are the original's",
	slide_stairwall_left = "the stair slide with the left key follows the original to the landing, then differs by 4 mm of path (the visible yaw of ScummVM leads by a fraction of a degree), which decides whether it crosses the corner",
	ledge_window = "a goal 3 cm off the floor: both engines end 10-11 cm from it, the original at 0.11 and ScummVM at 0.10 (the tolerance)",
	dam_slivers = "ScummVM follows the original within 4 mm for 360 frames, then the follower's wiggle at the sliver choke point (chaotic: 2 mm decide which side) ends differently",
}
