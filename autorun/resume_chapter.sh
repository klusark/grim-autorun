#!/bin/sh
# Resumes the ORIGINAL game at a chapter: the checkpoint that the chapter loads itself. Usage: resume_chapter.sh <chNN>
AR=/c/Users/Joel/grim_tools/autorun
f=$(ls "$AR"/$1*.lua | head -1)
slot=$(grep -o "^ar_load([0-9]*)" "$f" | head -1 | grep -o "[0-9]*")
name=$(basename "$f" .lua)
echo "resuming $name from slot $slot"
sh "$AR/resume_original.sh" "$slot" "$name"
