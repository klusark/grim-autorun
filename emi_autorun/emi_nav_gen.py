#!/usr/bin/env python3
"""Makes the Grim planner (autorun/ar_nav.lua, read only) into EMI's: generated/emi_nav_planner.lua.

The planner's own code is used as it is; only what touches the game goes through the functions of emi_nav.lua, which turn EMI's
world into the planner's: the floor x/z with y up becomes x/y with z up, scaled by AR_NAV_S (the planner's distances are Grim's
metres), and Manny's walk is Guybrush's keys. Each replacement must be found in the planner at least once, or this fails: a change
of the planner that one of them no longer fits is seen at once.
    python emi_nav_gen.py [out]   (default generated/emi_nav_planner.lua)
"""
import os, re, sys

here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(here, '..', 'autorun', 'ar_nav.lua')
dst = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, 'generated', 'emi_nav_planner.lua')
text = open(src, encoding='latin1').read()

# (what, by what, how: 's' a plain string, 'w' a whole word)
subs = [
    # where Guybrush is, in the planner's axes
    ('manny:getpos()', 'ar_np()', 's'),
    # a step: the forward key (held for the frame; emi_nav.lua lets it go after a frame of the follower that did not step)
    ('manny:walk_forward()', 'ar_nstep()', 's'),
    # run or walk: the run key
    ('manny:set_run(', 'ar_nrun(', 's'),
    # the heading toward a point (Monkey4's builtin gives the turn, Grim's the heading)
    ('GetActorYawToPoint(', 'ar_nyaw(', 's'),
    # where another actor is
    ('GetActorPos(', 'ar_nap(', 's'),
    # (for the log of a hold-up: EMI's Actor has no get_costume, and Monkey4.exe no GetActorCostume (the port has one))
    ('manny:get_costume()', 'manny.costume_name', 's'),
    # the turn keys toward a point
    ('ar_steer(', 'ar_nsteer(', 'w'),
    # (EMI's stairman only changes the walk chore: no constraint)
    ('SetActorConstrain(', 'ar_nconstrain(', 's'),
    # (the place a script puts Guybrush, in the planner's axes)
    ('\t\t\tar_tele_note(x, y, z)\n', '\t\t\tar_ntele(x, y, z)\n', 's'),
    # (no stair or curb constrains Guybrush: EMI's stairman only changes his walk chore, and curbman is in no set. The test is off, so that
    # a hot sector named after a stair is what it is otherwise: Lucre town's west_stair_cheatbox is a cheat box)
    ('if ar_has_word(nav.n[i], "stair") or ar_has_word(nav.n[i], "curb") then',
     'if AR_NAV_CONS and (ar_has_word(nav.n[i], "stair") or ar_has_word(nav.n[i], "curb")) then', 's'),
    ('if ar_has_word(name, "stair") or ar_has_word(name, "curb") then',
     'if AR_NAV_CONS and (ar_has_word(name, "stair") or ar_has_word(name, "curb")) then', 's'),
    # (a cheat box is stepped into only from a floor at its own height: the game finds the walker in a hot box only there. Lucre
    # town's west_stair_cheatbox lies on the lower level, under the edge of the upper one, and a link from above made Guybrush turn
    # on the spot at its edge)
    ('\t\t\t\t\tif wi and wo then\n',
     '\t\t\t\t\tif wi and wo and ar_w_hot_zok(nav, h, ar_nav_z(nav, wi, xx - nx * 0.22, xy - ny * 0.22)) then\n', 's'),
    # (a goal far off the floor: Grim takes it for a mistake of the caller; EMI's approach walks to the place of the object, the SCUMM
    # Bar's door is 10 units from the floor, and the walk goes as near as the floor does, as the grid planner's did)
    ('\t\t\tif off > 1.5 then\n', '\t\t\tif off > (AR_GOAL_OFF_MAX or 1.5) then\n', 's'),
    # (a point of the way is passed within AR_P_REACH: on the original, Guybrush landed from Lucre town's long_cheatbox 8 cm from the
    # first point, and turned on the spot toward it for good)
    ('if d < 0.06 or t >= l2 then', 'if d < (AR_P_REACH or 0.06) or t >= l2 then', 's'),
    # (the hooks are made again at every load of the planner, the game's own function kept from the first: a save brings back the
    # hooks of the run that made it, and with "only once" a fix to them was never seen after a resume (the original died of an old
    # hook's arithmetic at the gate of the Mysts o' Tyme, Nov 11))
    ('if not AR_PUT_HOOKED then\n\tAR_PUT_HOOKED = TRUE\n\tAR_PUT_ORIG = PutActorAt\n',
     'if TRUE then\n\tAR_PUT_HOOKED = TRUE\n\tAR_PUT_ORIG = AR_PUT_ORIG or PutActorAt\n', 's'),
    ('if not AR_COLL_HOOKED then\n\tAR_COLL_HOOKED = TRUE\n\tAR_COLL_ORIG = SetActorCollisionMode\n',
     'if TRUE then\n\tAR_COLL_HOOKED = TRUE\n\tAR_COLL_ORIG = AR_COLL_ORIG or SetActorCollisionMode\n', 's'),
    ('if not AR_SET_HOOKED then\n\tAR_SET_HOOKED = TRUE\n\tAR_SET_ORIG = PutActorInSet\n',
     'if TRUE then\n\tAR_SET_HOOKED = TRUE\n\tAR_SET_ORIG = AR_SET_ORIG or PutActorInSet\n', 's'),
    # (emi_lib.lua has a heap of its own, with its arguments in another order)
    ('ar_heap_push', 'ar_nheap_push', 'w'),
    ('ar_heap_pop', 'ar_nheap_pop', 'w'),
    # (the cells searched in a frame: Grim's 300 left Guybrush standing 4.5 s for a search of Lucre town, 80,000 cells; Monkey4.exe kills
    # a script only after 10 million instructions in one function without a break_here, FUN_004533b0)
    ('mod(steps, 300)', 'mod(steps, AR_SLICE_N or 300)', 's'),
    # (no way: tried again AR_NAV_TRIES times, 300 ms apart; Grim waits 18 s for an elevator. EMI falls back on its own planner)
    ('tries < 60', 'tries < (AR_NAV_TRIES or 60)', 's'),
]
for what, by, how in subs:
    if how == 'w':
        pat = r'(?<![A-Za-z0-9_])' + re.escape(what) + (r'(?![A-Za-z0-9_])' if what[-1].isalnum() or what[-1] == '_' else '')
        text, n = re.subn(pat, lambda m: by, text)
    else:
        n = text.count(what)
        text = text.replace(what, by)
    if n == 0:
        sys.exit('emi_nav_gen.py: "%s" is no longer in ar_nav.lua' % what.strip())
# (what is left that would touch the game in Grim's axes)
for left in ('manny:getpos', 'GetActorYawToPoint', 'GetActorPos(', 'IsPointInSector(', 'walk_forward'):
    for i, line in enumerate(text.split('\n'), 1):
        if left in line and not line.lstrip().startswith('--') and 'IsPointInSector(x, y, z, nav.n[i])' not in line:
            sys.exit('emi_nav_gen.py: line %d still has %s: %s' % (i, left, line.strip()))
# (every builtin the planner calls must be one of Monkey4.exe's: the port has some more (GetActorCostume), and a call of one is an
# error on the original only. The names are in the exe's table of builtins, each a string of its own)
exe = r'C:\GOG Games\Escape from Monkey Island\Monkey4.exe'
if os.path.exists(exe):
    data = open(exe, 'rb').read()
    nav = open(os.path.join(here, 'emi_nav.lua'), encoding='latin1').read()
    for name in sorted(set(re.findall(r'(?<![A-Za-z0-9_.:])([A-Z][A-Za-z0-9]+)\(', text + nav))):
        if b'\0' + name.encode() + b'\0' not in data:
            sys.exit('emi_nav_gen.py: %s is not a builtin of Monkey4.exe' % name)
head = '-- GENERATED by emi_nav_gen.py from autorun/ar_nav.lua, do not edit (the game is reached through emi_nav.lua)\n'
os.makedirs(os.path.dirname(dst), exist_ok=True)
open(dst, 'w', newline='\n', encoding='latin1').write(head + text)
