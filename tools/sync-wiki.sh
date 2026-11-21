#!/usr/bin/env bash
# Clones the GitHub wiki into wiki/, or pulls it when it is there. git ignores wiki/.
# Claude Code runs this at the start of each session (.claude/settings.json). Run it by hand
# with: bash tools/sync-wiki.sh
# The wiki URL follows the remote "origin", so SSH and HTTPS clones both work.
set -euo pipefail

cd "$(dirname "$0")/.."
export GIT_TERMINAL_PROMPT=0

origin="$(git remote get-url origin)"
url="${origin%.git}.wiki.git"

if [ -d wiki/.git ]; then
	if ! git -C wiki pull --ff-only --quiet; then
		echo "wiki: the pull failed. Commit or push your edits in wiki/, then run: git -C wiki pull --rebase" >&2
		exit 1
	fi
else
	git clone --quiet "$url" wiki
fi

echo "Wiki synced to $(git -C wiki log -1 --format='%h %ad %s' --date=short)." \
	"The design is in wiki/Architecture.md; read it before you add or change structure (AGENTS.md)."
