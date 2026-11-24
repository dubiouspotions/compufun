#!/bin/zsh
# Xcode Cloud runs this after the clone: it exports the game from Godot into the committed Xcode project (docs/ios.md).
set -euo pipefail

GODOT_VERSION=4.7.2
ROOT=${CI_PRIMARY_REPOSITORY_PATH:?not running in Xcode Cloud}
TOOLS=${TMPDIR:-/tmp}/godot-$GODOT_VERSION
RELEASES=https://github.com/godotengine/godot/releases/download/$GODOT_VERSION-stable
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$GODOT_VERSION.stable"

command -v git-lfs >/dev/null || brew install git-lfs
git -C "$ROOT" lfs install --local
git -C "$ROOT" lfs pull
git -C "$ROOT" fetch --tags --quiet  # write-build-info.sh describes the version from the tags, which a CI clone may lack

mkdir -p "$TOOLS" "$TEMPLATES"
curl -fsSL -o "$TOOLS/godot.zip" "$RELEASES/Godot_v$GODOT_VERSION-stable_macos.universal.zip"
unzip -q -o "$TOOLS/godot.zip" -d "$TOOLS"
GODOT="$TOOLS/Godot.app/Contents/MacOS/Godot"
curl -fsSL -o "$TOOLS/templates.tpz" "$RELEASES/Godot_v$GODOT_VERSION-stable_export_templates.tpz"
unzip -q -o -j "$TOOLS/templates.tpz" templates/ios.zip templates/version.txt -d "$TEMPLATES"

cd "$ROOT/Godot"
version=${CI_TAG#v}
if [[ -n "${CI_TAG:-}" && "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
	sed -i '' "s/^application\/short_version=.*/application\/short_version=\"$version\"/" export_presets.cfg
fi
../tools/write-build-info.sh
"$GODOT" --headless --import
"$GODOT" --headless --export-debug iOS "$ROOT/ios/CompuFun.ipa"
[ -f "$ROOT/ios/CompuFun.pck" ] || { echo "error: the Godot export wrote no $ROOT/ios/CompuFun.pck"; exit 1; }
