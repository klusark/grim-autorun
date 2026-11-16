-- The dialog walker of the 100% modes (ar_talk_before in ar_full.lua) on a dialog of our own, made as the game's are (_dialog.lua: lines flagged with the
-- name of their node, an exit line per node, display_lines offering the lines of the node that are not off). No game data, no ScummVM.
--   lua5.1 synth/test_talk.lua        (run from autorun/; luajit works too)
dofile("synth/compat.lua")
TRUE = 1
AR_LOG = { }
ar_log = function(s) AR_LOG[#AR_LOG + 1] = s end
getglobal = function(n) return _G[n] end
system = { }
dofile(os.getenv("AR_FULL_FILE") or "ar_full.lua")

local fails = 0
local function check(ok, what)
	print((ok and "PASS " or "FAIL ") .. what)
	if not ok then fails = fails + 1 end
end

-- the dialog: n1 has two plain lines (10, 70: 70 is what the chapter picks), a way into "sub" (20) that comes back by a line (50), a way into "dead" (30)
-- whose exit ends the talk, and a line that ends the talk (80); sub has a plain line (40) and the way back (50); dead has a plain line (60)
local function make()
	local d = { exit_lines = { }, current_choices = { }, node = "n1" }
	d[10] = { text = "/t10/", n1 = TRUE }
	d[20] = { text = "/t20/", n1 = TRUE, response = function() d.node = "sub" end }
	d[30] = { text = "/t30/", n1 = TRUE, response = function() d.node = "dead" end }
	d[70] = { text = "/t70/", n1 = TRUE }
	d[80] = { text = "/t80/", n1 = TRUE, response = function() d.node = "exit_dialog" end }
	d[40] = { text = "/t40/", sub = TRUE }
	d[50] = { text = "/t50/", sub = TRUE, response = function() d.node = "n1" end }
	d[60] = { text = "/t60/", dead = TRUE }
	d.exit_lines.n1 = { text = "/tx1/", response = function() d.node = "exit_dialog" end }
	d.exit_lines.sub = { text = "/tx2/", response = function() d.node = "exit_dialog" end }
	d.exit_lines.dead = { text = "/tx3/", response = function() d.node = "exit_dialog" end }
	d[999] = "EOD"
	d.display = function()
		d.current_choices = { }
		if d.node == "exit_dialog" then
			system.buttonHandler = nil
			return
		end
		local n = 0
		for i = 1, 998 do
			local l = d[i]
			if type(l) == "table" and l[d.node] and not l.off then
				n = n + 1
				d.current_choices[n] = l
			end
		end
		n = n + 1
		d.current_choices[n] = d.exit_lines[d.node]
		system.buttonHandler = d
	end
	d.display()
	return d
end
tdlg = nil
AR_DIALOG_NAMES = { "tdlg" }
AR_NO_AUTO = { tdlg = { [20] = TRUE, [30] = TRUE, [50] = TRUE, [80] = TRUE } }
AR_DLG_MOVE = { tdlg = { [20] = "sub", [30] = "dead", [50] = "n1" } }
AR_DLG_EXIT = { tdlg = { n1 = "exit_dialog", sub = "exit_dialog", dead = "exit_dialog" } }
local said
AR_PICK_OLD = function(d, c)
	said[#said + 1] = c.text
	if c.response then c.response() end
	d.display()
end
AR_PICK_EXIT_OLD = function(d) AR_PICK_OLD(d, d.exit_lines[d.node]) end

-- a pick in the middle of the talk: every line but the target, the sub-menu that comes back, never the one that does not or the line that ends it
said = { }
AR_SAID = { }
tdlg = make()
ar_talk_before(tdlg, tdlg[70])
local s = table.concat(said, " ")
check(s == "/t10/ /t20/ /t40/ /t50/", "a pick: the plain line, into sub, its line, back (" .. s .. ")")
check(tdlg.node == "n1" and system.buttonHandler == tdlg, "a pick: the talk is back in n1, waiting for the chapter's line")
check(not AR_TALK_ENDED, "a pick: the talk has not ended")

-- the exit of the talk: the same, then the sub-menu that does not come back as the last thing, whose exit ends the talk
said = { }
AR_SAID = { }
tdlg = make()
ar_talk_before(tdlg, tdlg.exit_lines.n1)
s = table.concat(said, " ")
check(s == "/t10/ /t70/ /t20/ /t40/ /t50/ /t30/ /t60/ /tx3/", "the exit: every line, both sub-menus, the talk ends in dead (" .. s .. ")")
check(AR_TALK_ENDED, "the exit: AR_TALK_ENDED tells ar_pick_exit not to say the exit line")

-- a second visit (the same dialog opened again, as the game keeps its tables) says nothing that was said in the first
said = { }
tdlg.node = "n1"
tdlg.display()
ar_talk_before(tdlg, tdlg[70])
s = table.concat(said, " ")
check(s == "", "a second visit: nothing is said again (" .. s .. ")")

-- a line that only ends the talk (AR_DLG_END): said in place of the exit line when the talk is to end, on a visit with no sub-menu left to end it
AR_DLG_END = { tdlg = { [80] = TRUE } }
said = { }
tdlg.node = "n1"
tdlg.display()
ar_talk_before(tdlg, tdlg.exit_lines.n1)
s = table.concat(said, " ")
check(s == "/t80/", "the end line: said in place of the exit line (" .. s .. ")")
check(AR_TALK_ENDED, "the end line: the talk has ended")
said = { }
tdlg.node = "n1"
tdlg.display()
ar_talk_before(tdlg, tdlg[70])
check(table.concat(said, " ") == "", "the end line: never for a pick that is not the exit")
AR_DLG_END = { }

-- a dialog of AR_NO_TALK right after a talk that ended: no "ended" is left over from the other talk (it made ar_pick_exit leave Celso's talk open)
AR_TALK_ENDED = TRUE
AR_NO_TALK = { tdlg = "blocked" }
tdlg.node = "n1"
tdlg.display()
ar_talk_before(tdlg, tdlg.exit_lines.n1)
check(not AR_TALK_ENDED, "a blocked dialog: AR_TALK_ENDED is not left from the talk before")
AR_NO_TALK = { }

-- a sub-menu with no way back is never entered for a pick that is not the exit
said = { }
AR_SAID = { }
AR_DLG_MOVE = { tdlg = { [20] = "sub", [30] = "dead" } }
tdlg = make()
ar_talk_before(tdlg, tdlg[70])
s = table.concat(said, " ")
check(s == "/t10/", "no way back from sub: only the plain line (" .. s .. ")")

-- a dialog that a later chapter talks in (AR_DLG_LAST): an extra talks in it too
AR_DLG_LAST = { tdlg = "ch60_celso" }
AR_FRAME_CH = "ch59_keno"
said = { }
AR_SAID = { }
tdlg = make()
AR_IN_EXTRA = TRUE
ar_talk_before(tdlg, nil)
check(table.concat(said, " ") == "/t10/ /t70/", "a dialog a later chapter talks in: an extra talks in it too (" .. table.concat(said, " ") .. ")")
AR_IN_EXTRA = nil
AR_DLG_LAST = { }

-- AR_NO_EXTRA_TALK: up to its chapter an extra says nothing in the dialog, the chapter's own talk still does; after it the extra talks
AR_NO_EXTRA_TALK = { tdlg = "ch60_celso" }
said = { }
AR_SAID = { }
tdlg = make()
AR_IN_EXTRA = TRUE
ar_talk_before(tdlg, nil)
check(table.concat(said, " ") == "", "AR_NO_EXTRA_TALK: an extra says nothing in it before its chapter (" .. table.concat(said, " ") .. ")")
AR_IN_EXTRA = nil
ar_talk_before(tdlg, tdlg[70])
check(table.concat(said, " ") == "/t10/", "AR_NO_EXTRA_TALK: the chapter's own talk says its lines (" .. table.concat(said, " ") .. ")")
AR_FRAME_CH = "ch60_celso"
said = { }
AR_SAID = { }
tdlg = make()
AR_IN_EXTRA = TRUE
ar_talk_before(tdlg, nil)
check(table.concat(said, " ") == "", "AR_NO_EXTRA_TALK: in its chapter an extra leaves it to the chapter too (" .. table.concat(said, " ") .. ")")
AR_FRAME_CH = "ch61_neon_ledge"
said = { }
ar_talk_before(tdlg, nil)
check(table.concat(said, " ") == "/t10/ /t70/", "AR_NO_EXTRA_TALK: after its chapter an extra talks in it (" .. table.concat(said, " ") .. ")")
AR_IN_EXTRA = nil
AR_NO_EXTRA_TALK = { }

-- AR_NO_TALK with AR_NO_TALK_UNTIL: blocked up to that chapter, for the chapter's own talk too; after it the dialog is talked in
AR_NO_TALK = { tdlg = "why" }
AR_NO_TALK_UNTIL = { tdlg = "ch60_celso" }
AR_FRAME_CH = "ch60_celso"
said = { }
AR_SAID = { }
tdlg = make()
ar_talk_before(tdlg, tdlg[70])
check(table.concat(said, " ") == "", "AR_NO_TALK_UNTIL: blocked in its chapter (" .. table.concat(said, " ") .. ")")
AR_FRAME_CH = "ch61_neon_ledge"
ar_talk_before(tdlg, tdlg[70])
check(table.concat(said, " ") == "/t10/", "AR_NO_TALK_UNTIL: talked in after its chapter (" .. table.concat(said, " ") .. ")")
AR_FRAME_CH = nil
AR_NO_TALK = { }
AR_NO_TALK_UNTIL = { }

-- a line that this chapter picks later (AR_DLG_PICKS) is left to that pick, also in a run of one chapter whose name has a tag after it
AR_DLG_MOVE = { tdlg = { [20] = "sub", [30] = "dead", [50] = "n1" } }
AR_DLG_PICKS = { tdlg = { [10] = "ch13_plunge" } }
AR_CHAPTERS = { "ch12_beavers", "ch13_plunge", "ch14_velasco" }
AR_CHAPTER = "ch13_plunge_s100"
said = { }
AR_SAID = { }
tdlg = make()
ar_talk_before(tdlg, tdlg[70])
s = table.concat(said, " ")
check(s == "/t20/ /t40/ /t50/", "a line the chapter picks later: not said before (" .. s .. ")")
AR_CHAPTER = "ch14_velasco"
said = { }
AR_SAID = { }
tdlg = make()
ar_talk_before(tdlg, tdlg[70])
s = table.concat(said, " ")
check(s == "/t10/ /t20/ /t40/ /t50/", "a line an earlier chapter picked: said (" .. s .. ")")
AR_CHAPTER = nil
AR_DLG_PICKS = { }

-- nodes at any depth, and two lines into one node: n1 has 10, two ways into sub (20, 22) and the target 70; sub has 40, a way into deep (45) and the way
-- back (50); deep has 46 and a way back to sub (47)
local function make_deep()
	local d = make()
	d[22] = { text = "/t22/", n1 = TRUE, response = function() d.node = "sub" end }
	d[45] = { text = "/t45/", sub = TRUE, response = function() d.node = "deep" end }
	d[46] = { text = "/t46/", deep = TRUE }
	d[47] = { text = "/t47/", deep = TRUE, response = function() d.node = "sub" end }
	d[30] = nil
	d[80] = nil
	d.exit_lines.deep = { text = "/tx4/", response = function() d.node = "exit_dialog" end }
	d.display()
	return d
end
AR_NO_AUTO = { tdlg = { [20] = TRUE, [22] = TRUE, [45] = TRUE, [47] = TRUE, [50] = TRUE } }
AR_DLG_MOVE = { tdlg = { [20] = "sub", [22] = "sub", [45] = "deep", [47] = "sub", [50] = "n1" } }
AR_DLG_EXIT = { tdlg = { n1 = "exit_dialog", sub = "exit_dialog", deep = "exit_dialog" } }
said = { }
AR_SAID = { }
tdlg = make_deep()
ar_talk_before(tdlg, tdlg[70])
s = table.concat(said, " ")
check(s == "/t10/ /t20/ /t40/ /t45/ /t46/ /t47/ /t50/ /t22/ /t50/", "nodes at any depth, both ways into sub, back home each time (" .. s .. ")")
check(tdlg.node == "n1" and system.buttonHandler == tdlg, "nodes at any depth: the talk is back in n1, waiting for the chapter's line")
-- a deep node with no way back is not entered for a pick that is not the exit
AR_DLG_MOVE = { tdlg = { [20] = "sub", [22] = "sub", [45] = "deep", [50] = "n1" } }
said = { }
AR_SAID = { }
tdlg = make_deep()
tdlg[47] = nil
tdlg.display()
ar_talk_before(tdlg, tdlg[70])
s = table.concat(said, " ")
check(s == "/t10/ /t20/ /t40/ /t50/ /t22/ /t50/", "a deep node with no way back: not entered (" .. s .. ")")
AR_NO_AUTO = { tdlg = { [20] = TRUE, [30] = TRUE, [50] = TRUE, [80] = TRUE } }
AR_DLG_MOVE = { tdlg = { [20] = "sub", [30] = "dead", [50] = "n1" } }
AR_DLG_EXIT = { tdlg = { n1 = "exit_dialog", sub = "exit_dialog", dead = "exit_dialog" } }

-- one-way nodes over several visits (Salvador at the jail door): n1 has 10, a move to n1 itself (60), a way into fold (20); fold has no way back:
-- 30, a line that ends the talk (40) and a way into angry (45, it stays on); angry has two lines that end the talk (50, 55)
local function make_oneway()
	local d = { exit_lines = { }, current_choices = { }, node = "n1" }
	d[10] = { text = "/t10/", n1 = TRUE }
	d[60] = { text = "/t60/", n1 = TRUE, response = function() d.node = "n1" end }
	d[20] = { text = "/t20/", n1 = TRUE, response = function() d.node = "fold" end }
	d[30] = { text = "/t30/", fold = TRUE }
	d[40] = { text = "/t40/", fold = TRUE, response = function() d.node = "exit_dialog" end }
	d[45] = { text = "/t45/", fold = TRUE, response = function() d.node = "angry" end }
	d[50] = { text = "/t50/", angry = TRUE, response = function() d.node = "exit_dialog" end }
	d[55] = { text = "/t55/", angry = TRUE, response = function() d.node = "exit_dialog" end }
	d.exit_lines.n1 = { text = "/tx1/", response = function() d.node = "exit_dialog" end }
	d[999] = "EOD"
	d.display = function()
		d.current_choices = { }
		if d.node == "exit_dialog" then
			system.buttonHandler = nil
			return
		end
		local n = 0
		for i = 1, 998 do
			local l = d[i]
			if type(l) == "table" and l[d.node] and not l.off then
				n = n + 1
				d.current_choices[n] = l
			end
		end
		if d.exit_lines[d.node] then
			n = n + 1
			d.current_choices[n] = d.exit_lines[d.node]
		end
		system.buttonHandler = d
	end
	d.display()
	return d
end
AR_NO_AUTO = { tdlg = { [20] = TRUE, [40] = TRUE, [45] = TRUE, [50] = TRUE, [55] = TRUE, [60] = TRUE } }
AR_DLG_MOVE = { tdlg = { [20] = "fold", [45] = "angry", [60] = "n1" } }
AR_DLG_EXIT = { tdlg = { n1 = "exit_dialog" } }
AR_DLG_END = { tdlg = { [40] = TRUE, [50] = TRUE, [55] = TRUE } }
AR_SAID = { }
tdlg = make_oneway()
local function visit()
	said = { }
	tdlg.node = "n1"
	tdlg.display()
	ar_talk_before(tdlg, tdlg.exit_lines.n1)
	return table.concat(said, " ")
end
s = visit()
check(s == "/t10/ /t60/ /t20/ /t30/ /t45/ /t50/", "one-way nodes, visit 1: the plain lines, the move to its own node, then deeper to the end (" .. s .. ")")
check(AR_TALK_ENDED, "one-way nodes, visit 1: the talk has ended (no exit line to say)")
s = visit()
check(s == "/t20/ /t45/ /t55/", "one-way nodes, visit 2: the moves said before, into angry for its other end (" .. s .. ")")
s = visit()
check(s == "/t20/ /t40/", "one-way nodes, visit 3: into fold for its line that ends the talk (" .. s .. ")")
s = visit()
check(s == "" and not AR_TALK_ENDED, "one-way nodes, visit 4: nothing new, the exit line is left to the caller (" .. s .. ")")
AR_NO_AUTO = { tdlg = { [20] = TRUE, [30] = TRUE, [50] = TRUE, [80] = TRUE } }
AR_DLG_MOVE = { tdlg = { [20] = "sub", [30] = "dead", [50] = "n1" } }
AR_DLG_EXIT = { tdlg = { n1 = "exit_dialog", sub = "exit_dialog", dead = "exit_dialog" } }
AR_DLG_END = { }

print(fails == 0 and "talk: all passed" or ("talk: " .. fails .. " failed"))
os.exit(fails == 0 and 0 or 1)
