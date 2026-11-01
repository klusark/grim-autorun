-- Reads the sectors of a set from its set file (ha.set), the text file the game itself loads: name, id, type, whether it is on
-- when the set starts, and its corners. Lua 3.1: readfrom opens a file by the name the game knows it by (inside its archives too),
-- read() reads a line; the line is cut into words by hand (the patterns of 3.1 have no + and no ?).
-- Returns { n = { names }, id = { ids }, t = { type words }, on = { TRUE/nil }, p = { { x, y, z, ... } }, count, lines }.
AR_SF_CR = format("%c", 13)
ar_sf_words = function(line)
	local w = { }
	local n = 0
	local pos = 1
	local len = strlen(line)
	local a = strfind(line, "[^ 	\n]", pos)
	while a do
		local e = strfind(line, "[ 	\n]", a)
		if not e then
			e = len + 1
		end
		-- (a word ends at the last character that is more than a blank: the end of a line of a file can bring a carriage return)
		e = e - 1
		while e > a and (strsub(line, e, e) == AR_SF_CR or strsub(line, e, e) == " ") do
			e = e - 1
		end
		local word = strsub(line, a, e)
		if word ~= AR_SF_CR then
			n = n + 1
			w[n] = word
		end
		e = e + 1
		pos = e
		a = strfind(line, "[^ 	\n]", pos)
	end
	return w, n
end

ar_sf_load = function(file)
	local old = readfrom(file)
	if not old then
		return nil
	end
	local sf = { n = { }, id = { }, t = { }, on = { }, p = { }, lines = 0 }
	local line = read()
	local cur = 0
	local want = 0
	local corners = 0
	while line do
		sf.lines = sf.lines + 1
		local w, n = ar_sf_words(strlower(line))
		local first = w[1]
		if first == "sector" then
			cur = cur + 1
			sf.n[cur] = ""
			if n >= 2 then
				-- (the name in the case it has: the second word of the line itself)
				local w2 = ar_sf_words(line)
				sf.n[cur] = w2[2]
			end
			sf.p[cur] = { }
			want = 0
			corners = 0
		elseif cur > 0 then
			if first == "id" then
				sf.id[cur] = tonumber(w[2])
			elseif first == "type" then
				sf.t[cur] = w[2]
			elseif first == "default" then
				if w[3] == "visible" then
					sf.on[cur] = TRUE
				end
			elseif first == "numvertices" then
				want = tonumber(w[2])
			elseif corners < want then
				local x = nil
				if first == "vertices:" then
					x = 2
				elseif tonumber(first) then
					x = 1
				end
				if x then
					local p = sf.p[cur]
					p[corners * 3 + 1] = tonumber(w[x])
					p[corners * 3 + 2] = tonumber(w[x + 1])
					p[corners * 3 + 3] = tonumber(w[x + 2])
					corners = corners + 1
				end
			end
		end
		line = read()
	end
	readfrom(old)
	sf.count = cur
	return sf
end

-- The nav (see ar_nav.lua) of a set, read from its set file the first time and kept: n / p the walk sectors, hn / hp the hot ones
-- (type chernobyl), both in the order of their ids as the game keeps them, and off the names of those that are off when the set
-- starts. A set that has already got one (the tests put the lists of a ScummVM dump there) keeps it.
ar_nav_of = function(set)
	if not set then
		return nil
	end
	local nav = AR_NAV[set.name]
	if nav then
		return nav
	end
	if not set.setFile then
		return nil
	end
	-- (two sets can have one name: the lists are kept by the file)
	nav = AR_NAV[set.setFile]
	if nav then
		return nav
	end
	local sf = ar_sf_load(set.setFile)
	if not sf then
		return nil
	end
	nav = { n = { }, p = { }, hn = { }, hp = { }, off = { }, adj = { } }
	local top = 0
	local i = 1
	while sf.n[i] do
		if sf.id[i] and sf.id[i] > top then
			top = sf.id[i]
		end
		i = i + 1
	end
	-- (by id as the game keeps them, and the ones with an id alike one after the other)
	local byid = { }
	i = 1
	while sf.n[i] do
		local id = sf.id[i] or 0
		if not byid[id] then
			byid[id] = { }
		end
		local l = byid[id]
		l[ar_nav_len(l) + 1] = i
		i = i + 1
	end
	local id = 0
	while id <= top do
		local l = byid[id]
		local li = 1
		while l and l[li] do
			i = l[li]
			li = li + 1
			if ar_nav_len(sf.p[i]) >= 9 then
				-- (a funnel sector is walk floor of the type 0x1100: the dumps count it as walk)
				local walk = sf.t[i] and (strfind(sf.t[i], "walk", 1, 1) or strfind(sf.t[i], "funnel", 1, 1))
				local hot = sf.t[i] == "chernobyl"
				if walk then
					local c = ar_nav_len(nav.n) + 1
					nav.n[c] = sf.n[i]
					nav.p[c] = sf.p[i]
				elseif hot then
					local c = ar_nav_len(nav.hn) + 1
					nav.hn[c] = sf.n[i]
					nav.hp[c] = sf.p[i]
				elseif sf.t[i] == "camera" then
					-- (the camera sectors, for the planner to keep out of the ones that are not the start's or the goal's: the camera would go there and come back)
					nav.cp = nav.cp or { }
					nav.cn = nav.cn or { }
					local cc = ar_nav_len(nav.cn) + 1
					nav.cn[cc] = sf.n[i]
					nav.cp[cc] = sf.p[i]
				end
				if AR_FULL and sf.t[i] == "camera" then
					-- (the 100% modes walk into every camera sector, to see every setup: the middle of it)
					nav.camera = nav.camera or { }
					local p = sf.p[i]
					local m = ar_nav_len(p) / 3
					local sx, sy, k = 0, 0, 0
					while k < m do
						sx = sx + p[k * 3 + 1]
						sy = sy + p[k * 3 + 2]
						k = k + 1
					end
					nav.camera[ar_nav_len(nav.camera) + 1] = { x = sx / m, y = sy / m, z = 0, name = sf.n[i] }
				end
				if (walk or hot) and not sf.on[i] then
					nav.off[ar_nav_len(nav.off) + 1] = sf.n[i]
				end
			end
		end
		id = id + 1
	end
	AR_NAV[set.setFile] = nav
	-- the links that earlier runs learned (ar_nav_known.lua, written by tools/export_nav_known.py): a hot sector that a script moves Manny out of
	-- is a link from the start, not from the first time he is carried
	-- (AR_USE_KNOWN, on unless the run script has NOKNOWN=1: with all of them the speed run was 2,550 frames longer than without)
	if AR_USE_KNOWN and AR_NAV_KNOWN and AR_NAV_KNOWN[set.setFile] then
		nav.learned = nav.learned or { }
		local hn, l = next(AR_NAV_KNOWN[set.setFile], nil)
		while hn do
			nav.learned[hn] = { x = l.x, y = l.y, z = l.z }
			hn, l = next(AR_NAV_KNOWN[set.setFile], hn)
		end
	end
	ar_log("nav: " .. tostring(set.setFile) .. " read, " .. ar_nav_len(nav.n) .. " walk sectors, " .. ar_nav_len(nav.hn) .. " hot")
	return nav
end
