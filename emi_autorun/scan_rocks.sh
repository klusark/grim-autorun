#!/bin/sh
cd /c/Users/Joel/grim_tools/emi_autorun
out=generated/scan_rocks.txt
: > $out
for w0 in 1700 1900 2100 2300; do
 for w2 in 5800 6200 6600 7000; do
  sed -i "s/^sleep_for(AR_A4_W0 or [0-9]*)/sleep_for(AR_A4_W0 or $w0)/; s/^sleep_for(AR_A4_W2 or [0-9]*)/sleep_for(AR_A4_W2 or $w2)/" act4_y09_rocks.lua
  r=$(LOG=scan_rocks ./run_act4.sh act4_y09_rocks 300 2>&1 | grep -a "rock_lava\|FAIL" | cut -c20-200)
  echo "w0=$w0 w2=$w2 $r" >> $out
 done
done
echo finished >> $out
