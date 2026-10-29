#!/bin/sh
# runs run_whole.sh N times in a row (default 4); the summary of each run is kept in logs/batch_<i>.txt, the logs in logs/batch_<i>_whole_*.log
EM=/c/Users/Joel/grim_tools/emi_autorun
cd "$EM" || exit 1
N=${1:-4}
: > logs/batch.txt
i=0
while [ $i -lt $N ]; do
	i=$((i + 1))
	rm -f saves_single/grim*.gsv
	start=$(date +%s)
	./run_whole.sh > logs/batch_${i}_out.txt 2>&1
	rc=$?
	cp logs/whole.txt logs/batch_$i.txt
	for f in logs/whole_*.log; do cp "$f" "logs/batch_${i}_$(basename $f)"; done
	echo "run $i: rc=$rc, $(( $(date +%s) - start )) s, $(tail -1 logs/whole.txt)" >> logs/batch.txt
done
echo "BATCH DONE" >> logs/batch.txt
