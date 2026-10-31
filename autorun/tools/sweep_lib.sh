# Shared by sweep_fix.sh: block "<kind>:<name>|<why>" puts the set or dialog into ex00_sweep.lua; returns 1 when it is already there (nothing new to try).
block() {
	who=${1%%|*}; why=${1#*|}; kind=${who%%:*}; name=${who#*:}
	[ "$who" = "?" ] && return 1
	why=$(echo "$why" | tr -d '"')
	case "$kind" in
		heavy) var=AR_NO_HEAVY; text="use, pick up and items" ;;
		people) var=AR_NO_PEOPLE; text="the people of it were talked to" ;;
		talk) var=AR_NO_TALK; text="lines of it were said" ;;
		*) var=AR_NO_SWEEP; text="the sweep" ;;
	esac
	grep -q "$var\[\"$name\"\]" ex00_sweep.lua && return 1
	printf '%s["%s"] = "a chapter failed after %s: %s"\n' "$var" "$name" "$text" "$why" >> ex00_sweep.lua
	return 0
}
