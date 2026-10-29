#!/bin/sh
# Compiles the ports of the original's math (engines/grim/sincos.cpp and friends) outside ScummVM and compares them with what the
# running original produced (recorded with crashdbg/grimtrace.exe): sh tools/origmath/check.sh
D=$(cd "$(dirname "$0")" && pwd)
SRC=/c/msys64/home/Joel/scummvm/engines/grim
T=/c/msys64/tmp/w
sed 's|#include "common/scummsys.h"|#include <cmath>|; s|#include "engines/grim/sincos.h"||; s|#include "engines/grim/sintable.h"|#include "C:/msys64/home/Joel/scummvm/engines/grim/sintable.h"|' $SRC/sincos.cpp > $T/sc_port.cpp
g++ -O1 -o $T/sctest.exe $D/sincos_test.cpp $T/sc_port.cpp && $T/sctest.exe $D/sincos_original.txt
g++ -O1 -o $T/asintest.exe $D/asin_test.cpp $T/sc_port.cpp && $T/asintest.exe $D/asin_original.txt
g++ -O1 -o $T/turntest.exe $D/turn_test.cpp $T/sc_port.cpp && $T/turntest.exe $D/turn_original.txt
