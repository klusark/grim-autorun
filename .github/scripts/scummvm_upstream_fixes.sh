#!/bin/bash
# Work around breakages in ScummVM's master that stop our Grim-only build. Run from the ScummVM checkout before
# configure. Each fix only applies while the breakage is there, so it does nothing once upstream fixes it.
set -e

# Snatcher's fan translations (ef203bb72f2) put fantranslations.o into the detection objects, which are linked
# even with the engine disabled, but it uses MEM_MODULE_LOCATION and MEM_SCRIPT_LOCATION of mem_mapping.o,
# which is only built with the engine: undefined references at the link of scummvm.exe.
mk=engines/snatcher/module.mk
if [ -f "$mk" ] && grep -q 'DETECT_OBJS += $(MODULE)/fantranslations.o' "$mk" &&
		! grep -q 'DETECT_OBJS += $(MODULE)/mem_mapping.o' "$mk"; then
	# inside the same ifneq STATIC_PLUGIN, where a static engine already has it
	sed -i 's|^DETECT_OBJS += $(MODULE)/fantranslations.o$|&\nDETECT_OBJS += $(MODULE)/mem_mapping.o|' "$mk"
	echo "upstream fix: Snatcher's detection links mem_mapping.o"
fi
