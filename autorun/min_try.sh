#!/bin/sh
# Commit minimisation of the autorun branch: builds master + the chosen commits of generated/min_commits.txt in worktree
# ~/scummvm-minN and plays the speed run with it.
#   min_try.sh N "1 2 5-9 55" [label]   (SPEC "-": the worktree as it is)
# The numbers are 1-based lines of min_commits.txt (the branch as it was before the minimisation). Prints one line:
#   RESULT <label> PASS|FAIL|CONFLICT <n>|BUILDFAIL  (details in logs/min_<label>.log / logs/min_<label>.build)
N=$1; SPEC=$2; LABEL=${3:-w$1}
AR=/c/Users/Joel/grim_tools/autorun
WT=/home/Joel/scummvm-min$N
LIST="$AR/generated/min_commits.txt"
export CCACHE_BASEDIR=/home/Joel CCACHE_NOHASHDIR=1
if [ ! -d "$WT" ]; then
	git -C /home/Joel/scummvm-autorun worktree add --detach "$WT" master >/dev/null 2>&1 || { echo "RESULT $LABEL NOWORKTREE"; exit 1; }
fi
nums=""
for p in $SPEC; do
	case "$p" in
		*-*) a=${p%-*}; b=${p#*-}; nums="$nums $(seq "$a" "$b" | tr '\n' ' ')" ;;
		*) nums="$nums $p" ;;
	esac
done
cd "$WT" || exit 1
if [ "$SPEC" = "-" ]; then nums=""; else
git cherry-pick --abort >/dev/null 2>&1
git checkout -q -f --detach master || { echo "RESULT $LABEL CHECKOUTFAIL"; exit 1; }
for n in $nums; do
	c=$(sed -n "${n}p" "$LIST")
	if ! git cherry-pick --allow-empty "$c" >/dev/null 2>&1; then
		files=$(git diff --name-only --diff-filter=U | tr '\n' ' ')
		git cherry-pick --abort >/dev/null 2>&1
		echo "RESULT $LABEL CONFLICT $n $files"
		exit 0
	fi
done
fi
mkdir -p build-opt && cd build-opt
if [ ! -f config.mk ]; then
	CXX="ccache g++" CC="ccache gcc" ../configure --disable-all-engines --enable-engines=grim,monkey4 --enable-release > /dev/null 2>&1
fi
if ! make -j${JOBS:-6} > "$AR/logs/min_$LABEL.build" 2>&1; then
	echo "RESULT $LABEL BUILDFAIL $(grep -m1 'error' "$AR/logs/min_$LABEL.build")"
	exit 0
fi
cd "$AR"
SVM_DIR="$WT/build-opt" LOG="min_$LABEL" SIMFPS=60 TS=100 sh run_all.sh 1500 > /dev/null 2>&1
L="$AR/logs/min_$LABEL.log"
last=$(grep "=== chapter" "$L" | tail -1 | sed 's/.*=== chapter \(.*\) ===/\1/')
if grep -q "AUTORUN RESULT PASSED" "$L"; then
	echo "RESULT $LABEL PASS $(tail -1 "$L")"
else
	echo "RESULT $LABEL FAIL at $last: $(grep -m1 -E 'AUTORUN (FAIL|RESULT)|stalled|walk took more' "$L" | cut -c1-200)"
fi
