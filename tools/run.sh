#!/bin/bash
# Runs the game from this checkout without the Godot editor: imports, then plays.
# Usage: tools/run.sh [res://path/to/scene.tscn]   (no scene: the main scene)
# Godot: $GODOT, else the last Godot*.app by name in /Applications, then ~/Applications.
# It refuses while the editor has this project open: two Godot processes writing one .godot
# folder corrupt its caches, and the editor then saves wrong data over scenes and resources.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
project="$repo/Godot"

if [ -n "${GODOT:-}" ]; then
	godot="$GODOT"
else
	godot=""
	shopt -s nullglob
	for app in /Applications/Godot*.app "$HOME"/Applications/Godot*.app; do
		godot="$app/Contents/MacOS/Godot"
	done
fi
[ -x "$godot" ] || { echo "Error: no Godot program found; set GODOT to its path (tried: '${godot:-none}')" >&2; exit 1; }

for pid in $(pgrep -x Godot || true); do
	cmd="$(ps -o args= -p "$pid")"
	[[ "$cmd" == *"--path $project"* || "$cmd" == *"--path $project/"* ]] || continue
	if [[ " $cmd " == *" -e "* || " $cmd " == *" --editor "* ]]; then
		echo "Error: the Godot editor has $project open (pid $pid). Close it first; see the comment at the top of $0." >&2
		exit 1
	fi
	kill "$pid"  # an earlier game run
done

echo "Importing with $("$godot" --version)..."
if ! out="$("$godot" --headless --path "$project" --import 2>&1)"; then
	echo "$out" | tail -30 >&2
	echo "Error: the import failed" >&2
	exit 1
fi
echo "$out" | grep -E 'ERROR|WARNING' || true

exec "$godot" --path "$project" "$@"
