-- The Lua 3.1 of the game on Lua 5.1, as far as the autorun libraries use it: the string, math and file functions, with 3.1's degrees and 1-based
-- semantics. No game data is read: the sets come from synth/sets/.

strfind = string.find
strsub = string.sub
strlen = string.len
strlower = string.lower
strupper = string.upper
strrep = string.rep
strbyte = string.byte
strchar = string.char
format = string.format
gsub = string.gsub
floor = math.floor
ceil = math.ceil
abs = math.abs
sqrt = math.sqrt
min = math.min
max = math.max
-- (the angles of 3.1 are degrees)
sin = function(d) return math.sin(math.rad(d)) end
cos = function(d) return math.cos(math.rad(d)) end
tan = function(d) return math.tan(math.rad(d)) end
asin = function(x) return math.deg(math.asin(x)) end
acos = function(x) return math.deg(math.acos(x)) end
atan = function(x) return math.deg(math.atan(x)) end
atan2 = function(y, x) return math.deg(math.atan2(y, x)) end
mod = function(a, b) return math.fmod(a, b) end
random = function(a, b)
	if a == nil then return math.random() end
	if b == nil then return math.random(a) end
	return math.random(a, b)
end
tinsert = table.insert
tremove = table.remove
getn = function(t)
	local n = 0
	while t[n + 1] ~= nil do n = n + 1 end
	return n
end
date = function(f) return os.date(f) end
getenv = os.getenv
exit = os.exit
PrintDebug = function(s) io.write(s) end
call = function(f, args) return f(unpack(args)) end

-- readfrom / read: the text files of a set, found in synth/sets (the game finds them in its archives). readfrom(name) returns what was read from before,
-- readfrom(that) goes back to it.
SYNTH_DIR = SYNTH_DIR or "synth"
local cur = nil
readfrom = function(name)
	local prev = cur or "stdin"
	if name == nil or name == "stdin" or type(name) == "userdata" then
		if cur then
			cur:close()
		end
		cur = nil
		if type(name) == "userdata" then
			cur = name
		end
		return prev
	end
	local f = io.open(SYNTH_DIR .. "/sets/" .. name, "r")
	if not f then
		return nil
	end
	cur = f
	return prev
end
read = function()
	if not cur then
		return nil
	end
	return cur:read("*l")
end
