#!/bin/sh
# Regression test: how many frames a spoken line lasts (subtitles only, text speed 7): 640 ms and 60 ms for each character, counted down in the update of the
# actor, against the original (tests/golden/probe_speech_orig.txt).   sh tools/golden_speech.sh
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR"
SIMMS=17 SIMFPS=60 TS=100 timeout 400 sh run_chapter.sh tests/probe_speech.lua 400 > /dev/null 2>&1
grep -a PROBE logs/probe_speech.log | sed 's/^.*PROBE/PROBE/' > logs/golden_speech_sv.txt
if diff -q logs/golden_speech_sv.txt tests/golden/probe_speech_orig.txt > /dev/null; then echo "GOLDEN speech PASSED"; else echo "GOLDEN speech FAILED"; diff logs/golden_speech_sv.txt tests/golden/probe_speech_orig.txt | head; exit 1; fi
