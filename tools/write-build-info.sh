#!/bin/bash
# Writes Godot/build_info.txt (line 1 the version, line 2 the commit) for Godot/build_info.gd.
# The version is $VERSION when set, otherwise `git describe` against the vX.Y.Z tags. --stamp-project
# also sets config/version in Godot/project.godot (CI only), which the macOS and Windows exports use.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
info="$root/Godot/build_info.txt"
tags=(--tags --match 'v[0-9]*.[0-9]*.[0-9]*')

version="${VERSION:-}"
if [ -z "$version" ]; then
	desc="$(git -C "$root" describe "${tags[@]}" 2>/dev/null)" || desc=""
	version="${desc#v}"
	[ -n "$version" ] || version="unversioned"
fi
commit="$(git -C "$root" log -1 --format='%h %cd' --date=format:'%Y-%m-%d %H:%M')"
[ -n "$commit" ] || { echo "Error: git log printed no commit for $root" >&2; exit 1; }
printf '%s\n%s\n' "$version" "$commit" > "$info"
echo "Build: $version ($commit)"

if [ "${1:-}" = "--stamp-project" ]; then
	number="$(printf '%s' "$version" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')" || {
		echo "Error: version '$version' doesn't start with X.Y.Z, so it can't go into config/version" >&2; exit 1; }
	project="$root/Godot/project.godot"
	grep -q '^config/version=' "$project" && { echo "Error: $project already sets config/version" >&2; exit 1; }
	awk -v v="$number" '{ print } /^config\/name=/ { print "config/version=\"" v "\"" }' "$project" > "$project.new"
	mv "$project.new" "$project"
	grep -qx "config/version=\"$number\"" "$project" || { echo "Error: config/version didn't land in $project" >&2; exit 1; }
	echo "config/version: $number"
fi
