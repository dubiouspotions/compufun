#!/bin/bash
# Writes Godot/build_commit.txt, which an exported build shows in its title (Godot/build_info.gd
# reads it, and uses the same git format in an editor run).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
git -C "$root" log -1 --format='%h %cd' --date=format:'%Y-%m-%d %H:%M' > "$root/Godot/build_commit.txt"
[ -s "$root/Godot/build_commit.txt" ] || { echo "Error: git wrote an empty $root/Godot/build_commit.txt" >&2; exit 1; }
echo "Build commit: $(cat "$root/Godot/build_commit.txt")"
