#!/bin/sh
# usage: sectors.sh set [step]  - maps the sectors of a set (plots with tools/sectors.py), from the save grim14
cd /c/Users/Joel/grim_tools/autorun
cat > x_sec.lua <<EOT
ar_load(54)
ar_wait_for_control()
$1:switch_to_set()
manny:put_in_set($1)
sleep_for(500)
DumpSectors()
exit()
EOT
sh run_chapter.sh x_sec.lua 60 > /dev/null
python ../tools/sectors.py logs/x_sec.log ${2:-0.3}
