#!/bin/sh
# The autorun engine (Grim and EMI) is built by build_scummvm_autorun.sh (worktree ~/scummvm-autorun, branch autorun).
exec sh "$(dirname "$0")/build_scummvm_autorun.sh" "$@"
