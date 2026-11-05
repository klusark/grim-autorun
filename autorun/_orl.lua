walkdir_log = function(s) PrintDebug("ORL " .. s .. "\n") end
walkdir_yaws = { 0, 45, 90, 135, 180, 225, 270, 315 }
walkdir_run = function()
  me:switch_to_set("noenter")
  manny:put_in_set(me)
  manny:follow_boxes()
  manny:set_walk_rate(0.2)
  local yi = 1
  while yi <= 8 do
    local yaw = walkdir_yaws[yi]
    manny:setpos(-3.033, -5.650, -1.961)
    manny:setrot(0, yaw, 0, TRUE)
    local w = 0
    while w < 20 do
      break_here()
      w = w + 1
    end
    local p0 = manny:getpos()
    local r = manny:getrot()
    local k = 0
    while k < 30 do
      manny:walk_forward()
      break_here()
      k = k + 1
    end
    local p1 = manny:getpos()
    walkdir_log(format("walk yaw %3d rot %.2f p0 %.5f %.5f %.5f p1 %.5f %.5f %.5f", yaw, r.y, p0.x, p0.y, p0.z, p1.x, p1.y, p1.z))
    yi = yi + 1
  end
  manny:set_walk_rate(MANNY_WALK_RATE)
  walkdir_log("walk finished")
end
start_script(walkdir_run)
