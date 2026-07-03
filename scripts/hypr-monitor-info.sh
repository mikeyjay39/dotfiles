#!/usr/bin/env bash
# Print connected monitor details for Hyprland profile setup.
# Run while docked to a specific monitor set, then copy the output into
# asusDescriptionPatterns / hpDescriptionPatterns in hyprland.lua.

set -euo pipefail

if ! command -v hyprctl >/dev/null 2>&1; then
	echo "hyprctl not found; is Hyprland running?" >&2
	exit 1
fi

echo "=== Hyprland monitor info ==="
echo "Run this while connected to one monitor set, then add description"
echo "substrings to the matching profile in ~/.config/hypr/hyprland.lua"
echo

hyprctl monitors all | awk '
/^Monitor / {
	if (name != "") print_block()
	name = $2
	mode = desc = make = model = serial = ""
}
/^[[:space:]]+[0-9]+x[0-9]+@/ { mode = $1 }
/^[[:space:]]+description:/ { desc = substr($0, index($0, ":") + 2) }
/^[[:space:]]+make:/ { make = substr($0, index($0, ":") + 2) }
/^[[:space:]]+model:/ { model = substr($0, index($0, ":") + 2) }
/^[[:space:]]+serial:/ { serial = substr($0, index($0, ":") + 2) }
END {
	if (name != "") print_block()
}
function print_block() {
	print ""
	print "Monitor: " name
	print "  mode:        " mode
	print "  description: " desc
	print "  make:        " make
	print "  model:       " model
	print "  serial:      " serial
	if (desc != "" && name != "eDP-1") {
		print "  lua pattern: \"" desc "\""
	}
}
'

echo
echo "=== Suggested lua entries (externals only) ==="
hyprctl -j monitors all | jq -r '
	.[] | select(.name != "eDP-1") |
	"  \"" + .description + "\","
'
