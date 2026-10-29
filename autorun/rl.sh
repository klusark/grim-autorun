#!/bin/sh
# Remote Lua into a running game (SCUMMVM_LUA_REMOTE).
#   rl.sh start [slot]   starts the game on the checkpoint (default 14), at normal speed 8x
#   rl.sh 'lua code'     runs the code in the game; set the global R (a string) to return something
#   rl.sh stop
AR=/c/Users/Joel/grim_tools/autorun
D=$AR/remote
mkdir -p $D
case "$1" in
start)
	rm -f $D/cmd.* ; slot=${2:-14}
	cat > $D/boot.lua <<EOT
$(cat $AR/ar_lib.lua)
AR_KEEP_GOING = TRUE
ar_load($slot)
ar_wait_for_control()
ar_log("remote ready")
while TRUE do sleep_for(1000) end
EOT
	cp "$APPDATA/ScummVM/scummvm.ini" $D/scummvm.ini
	sed -i '/^\[grim-win\]/a speech_mute=true\nsubtitles=true' $D/scummvm.ini
	cd /home/Joel/scummvm/build
	SCUMMVM_LUA_REMOTE=$(cygpath -m $D) nohup ./scummvm.exe --config="$(cygpath -w $D/scummvm.ini)" --savepath="$(cygpath -w $AR/saves)" --autorun="$(cygpath -w $D/boot.lua)" --debugflags=scripts --engine-speed=0 --sim-fps=${SIMFPS:-60} grim-win > $D/game.log 2>&1 &
	echo $! > $D/pid
	i=0; while ! grep -aq "remote ready" $D/game.log && [ $i -lt 120 ]; do sleep 1; i=$((i+1)); done
	echo started ;;
stop)
	taskkill //F //IM scummvm.exe > /dev/null 2>&1; echo stopped ;;
*)
	rm -f $D/cmd.out
	printf '%s' "$1" > $D/cmd.tmp.lua && mv $D/cmd.tmp.lua $D/cmd.lua
	i=0; while [ ! -f $D/cmd.out ] && [ $i -lt 600 ]; do sleep 0.2; i=$((i+1)); done
	cat $D/cmd.out 2>/dev/null; echo ;;
esac
