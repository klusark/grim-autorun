#!/bin/sh
# usage: gt.sh id [id ...]   or   gt.sh -r regex   (search the text)
if [ "$1" = "-r" ]; then grep -i -E "$2" /c/Users/Joel/grim_tools/grim_text.txt | head -${3:-40}; exit; fi
for i in "$@"; do grep -m1 -E "^$i	" /c/Users/Joel/grim_tools/grim_text.txt || echo "$i ?"; done
