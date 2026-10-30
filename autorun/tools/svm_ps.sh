#!/bin/sh
# The scummvm.exe of this checkout's build (SVM_BUILD, default build-opt), not any other scummvm.exe that runs at the same time (another build, a worktree):
#   sh tools/svm_ps.sh pid    the process id
#   sh tools/svm_ps.sh cpu    the cpu time so far as h:mm:ss
b="${SVM_BUILD:-build-opt}"
SVM_PAT='*\scummvm\'"$b"'\*'
export SVM_PAT
case "$1" in
	cpu) show='$p.TotalProcessorTime.ToString("hh\:mm\:ss")';;
	*) show='$p.Id';;
esac
powershell -NoProfile -Command '$p = Get-Process scummvm -ErrorAction SilentlyContinue | Where-Object { $_.Path -like $env:SVM_PAT } | Select-Object -First 1; if ($p) { '"$show"' }' | tr -d '\r'
