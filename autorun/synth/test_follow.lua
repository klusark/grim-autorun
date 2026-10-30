-- The follower (ar_follow_frame of ar_nav.lua) with a simulated Manny: he turns on the spot at a fixed rate, walks forward in the way he faces, and does not
-- move when the next place is not in a sector that is on (the walls of the game: a wall stops him; no sector joins a corner).

local TURN = 3.0
local STEP = 0.025

-- yaw 0 faces +y, positive turns toward -x (the games')
GetActorYawToPoint = function(h, x, y, z)
	return math.deg(math.atan2(-(x - manny.pos.x), y - manny.pos.y))
end

local function normal(d)
	return d - 360 * math.floor(d / 360 + 0.5)
end

manny.set_run = function(self, on) end

ar_steer = function(x, y, z, thr)
	local d = normal(GetActorYawToPoint(manny.hActor, x, y, z) - manny.rot.y)
	AR_STEER_D = d
	if math.abs(d) > math.max(6, thr or 0) then
		manny.rot.y = manny.rot.y + (d > 0 and TURN or -TURN)
		return TRUE
	end
	return nil
end

nav_now = nil

-- the sector that has (x, y) and is on, at about the height z
local function sector_at(nav, x, y)
	local count = ar_nav_count(nav)
	local i = 1
	while i <= count do
		if not AR_OFF[nav.n[i]] and ar_nav_inside(nav, i, x, y) then
			return i
		end
		i = i + 1
	end
	return nil
end

manny.walk_forward = function(self)
	local yaw = math.rad(self.rot.y)
	local nx = self.pos.x - math.sin(yaw) * STEP
	local ny = self.pos.y + math.cos(yaw) * STEP
	-- (a wall stops the part of the step that goes into it, and he slides along it with the rest, as the walker of the game does along an edge)
	local tries = { { nx, ny }, { nx, self.pos.y }, { self.pos.x, ny } }
	for _, t in ipairs(tries) do
		local si = sector_at(nav_now, t[1], t[2])
		if si then
			self.pos = { x = t[1], y = t[2], z = ar_nav_z(nav_now, si, t[1], t[2]) }
			self.moved = true
			return
		end
	end
end

-- Walks the way; returns "arrived" or "held up" (with where), and the frames it took.
function follow(name, x1, y1, x2, y2, yaw, given)
	local path, nav, w = plan(name, x1, y1, x2, y2)
	if given then
		path = given
	end
	if not path then
		return "no way", 0
	end
	nav_now = nav
	manny.rot.y = yaw or 0
	local n = ar_nav_len(path)
	local cum = ar_way_cum(path)
	local i = 2
	local frames = 0
	local still = 0
	while frames < 4000 do
		frames = frames + 1
		local before = manny.pos.x * 1000 + manny.pos.y
		local turning = ar_follow_frame(nav, w, path, n, cum, i)
		i = AR_FOLLOW_I or i
		if FOLLOW_TRACE and frames % FOLLOW_TRACE == 0 then
			print(string.format("  frame %d pos %.3f %.3f yaw %.0f point %d off %.0f", frames, manny.pos.x, manny.pos.y, manny.rot.y, i, AR_STEER_D or 0))
		end
		if math.sqrt((manny.pos.x - x2) ^ 2 + (manny.pos.y - y2) ^ 2) < 0.15 then
			return "arrived", frames
		end
		if i > n then
			return "arrived", frames
		end
		if manny.pos.x * 1000 + manny.pos.y == before then
			still = still + 1
		else
			still = 0
		end
		-- (turning on the spot for long is not held up: a full turn takes 120 frames)
		if still > 200 then
			return string.format("held up at %.3f %.3f", manny.pos.x, manny.pos.y), frames
		end
	end
	return string.format("did not arrive in %d frames, at %.3f %.3f", frames, manny.pos.x, manny.pos.y), frames
end

do
	local r, f = follow("flat", 1, 1, 7, 1)
	check("follow flat: arrives", r == "arrived", r)
end

do
	local r, f = follow("ramp", 0.5, 3.8, -2.5, -0.45)
	check("follow ramp: down the ramp and round its foot to the west landing", r == "arrived", r)
end

do
	local r, f = follow("neck", 1, 1.5, 6, 1.5, -90)
	check("follow neck: through 12 cm", r == "arrived", r)
end

-- The corner at the foot of a ramp: the way turns west at a point 2 cm below the bottom edge of the ramp, at its west corner, and the straight line to the next point,
-- from a place on the ramp 6 cm from that point, leaves the ramp over its side edge, where no sector joins. The turn must not be cut there: Manny is held up at the
-- edge for ever (chapter 50, the back stairs of the temple).
do
	local given = {
		{ 0.5, 3.8, 1.9, "p" },
		{ 0.10, -0.02, 0, "p" },
		{ -2.5, -0.45, 0, "g" },
	}
	local r, f = follow("ramp", 0.5, 3.8, -2.5, -0.45, 0, given)
	check("follow ramp foot: the turn at the corner is not cut over the void", r == "arrived", r)
end

-- The rule itself: 5.5 cm from the corner point, on the ramp, the line to the next point crosses the void beside the ramp, so the follower stays on the corner
-- point; from below the edge the line is floor all along, and it goes on.
do
	local given = {
		{ 0.5, 3.8, 1.9, "p" },
		{ 0.10, -0.02, 0, "p" },
		{ -2.5, -0.45, 0, "g" },
	}
	local function step(x, y)
		local set, nav, w = place("ramp", x, y)
		nav_now = nav
		manny.rot.y = 0
		ar_follow_frame(nav, w, given, 3, ar_way_cum(given), 2)
		return AR_FOLLOW_I
	end
	check("follow rule: stays on the corner point while the line to the next leaves the floor", step(0.10, 0.035) == 2, "went on to the point " .. tostring(step(0.10, 0.035)))
	check("follow rule: goes on once the line to the next point is floor", step(0.10, -0.01) == 3, "stayed on the point " .. tostring(step(0.10, -0.01)))
end
