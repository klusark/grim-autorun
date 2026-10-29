-- DEV TOOL (run with run_chapter.sh, ScummVM): writes what the offline tests (tools/lua31) need of the set tables to the
-- log: for every set the names of its global, its cheat boxes, and for each hot sector the keys of the door object that the
-- set holds under the name of the sector. Not part of the run. Output lines: NAVSET ...
ar_load(19)
AR_DS_CH = "abcdefghijklmnopqrstuvwxyz"
ar_ds_try = function(g)
	local s = getglobal(g)
	if type(s) == "table" and s.setFile and s.name then
		local line = "NAVSET " .. g .. " " .. s.name .. " | f:" .. s.setFile
		if s.cheat_boxes then
			local k = next(s.cheat_boxes, nil)
			while k do
				line = line .. " c:" .. k
				k = next(s.cheat_boxes, k)
			end
		end
		local nav = ar_nav_of(s)
		if nav and nav.hn then
			local i = 1
			while nav.hn[i] do
				local obj = s[nav.hn[i]]
				if type(obj) == "table" and (obj.walkOut or obj.climbOut) then
					line = line .. " d:" .. nav.hn[i] .. "="
					local k = next(s, nil)
					while k do
						if s[k] == obj and k ~= nav.hn[i] then
							line = line .. k .. ","
						end
						k = next(s, k)
					end
				end
				i = i + 1
			end
		end
		PrintDebug(line .. "\n")
	end
end
AR_DS_I = 1
while AR_DS_I <= 26 do
	AR_DS_J = 1
	while AR_DS_J <= 26 do
		ar_ds_try(strsub(AR_DS_CH, AR_DS_I, AR_DS_I) .. strsub(AR_DS_CH, AR_DS_J, AR_DS_J))
		AR_DS_K = 1
		while AR_DS_K <= 26 do
			ar_ds_try(strsub(AR_DS_CH, AR_DS_I, AR_DS_I) .. strsub(AR_DS_CH, AR_DS_J, AR_DS_J) .. strsub(AR_DS_CH, AR_DS_K, AR_DS_K))
			AR_DS_K = AR_DS_K + 1
		end
		AR_DS_J = AR_DS_J + 1
	end
	AR_DS_I = AR_DS_I + 1
end
PrintDebug("NAVSET DONE\n")
