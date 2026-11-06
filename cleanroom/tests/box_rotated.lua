-- ScummVM commit ab9c9cca (Fix Line2d): the runner's way into forklift_box.lua (the standalone repro; this file loads first)
BX_LOG = function(yaw, off, x, y, ox, oy, ok)
	cr_log("box_yaw" .. yaw .. "_off" .. floor(off * 10), x, y)
end
cr_test("box_repro", function()
	bx_main()
end)
