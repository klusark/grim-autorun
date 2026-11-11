# Shared by sweep_fix.sh: block "<kind>:<name>|<why>" [chapter] puts the set or dialog into ex00_sweep.lua; returns 1 when it is already there (nothing new
# to try). A person (talker) is blocked in the chapter given only: Meche broke chapter 44, not 42 and 43.
block() {
	who=${1%%|*}; why=${1#*|}; kind=${who%%:*}; name=${who#*:}
	[ "$who" = "?" ] && return 1
	why=$(echo "$why" | tr -d '"')
	case "$kind" in
		heavy) var=AR_NO_HEAVY; text="use, pick up and items" ;;
		use) var=AR_NO_USE; text="the heavy step used it (it took Manny out of the set or took an item he carried)" ;;
		people) var=AR_NO_PEOPLE; text="the people of it were talked to" ;;
		talker) var=AR_NO_TALKER; text="this person was talked to"; [ -n "$2" ] && name="$name@$2" ;;
		talk) var=AR_NO_TALK; text="lines of it were said" ;;
		*) var=AR_NO_SWEEP; text="the sweep" ;;
	esac
	grep -q "$var\[\"$name\"\]" ex00_sweep.lua && return 1
	printf '%s["%s"] = "a chapter failed after %s: %s"\n' "$var" "$name" "$text" "$why" >> ex00_sweep.lua
	return 0
}
