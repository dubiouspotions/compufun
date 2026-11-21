#!/usr/bin/env bash
# Clones the GitHub wiki into wiki/, or pulls it when it is there. git ignores wiki/.
# Claude Code runs this at the start of each session (.claude/settings.json), and AGENTS.md
# includes wiki/Architecture.md. Run it by hand with: bash tools/sync-wiki.sh
# The wiki URL follows the remote "origin", so SSH and HTTPS clones both work.
# The output must stay short: Claude Code caps hook output at 10,000 characters.
set -euo pipefail

cd "$(dirname "$0")/.."
export GIT_TERMINAL_PROMPT=0

origin="$(git remote get-url origin)"
url="${origin%.git}.wiki.git"
page="Architecture.md"

if [ -d wiki/.git ]; then
	before="$(git -C wiki rev-parse HEAD)"
	if ! git -C wiki pull --ff-only --quiet; then
		echo "wiki: the pull failed. Commit or push your edits in wiki/, then run: git -C wiki pull --rebase" >&2
		exit 1
	fi
	if git -C wiki diff --quiet "$before" HEAD -- "$page"; then
		echo "Wiki up to date at $(git -C wiki log -1 --format='%h %ad' --date=short)."
	else
		echo "wiki/$page changed in this pull ($(git -C wiki log -1 --format='%h %an %ad' --date=short -- "$page"))." \
			"The copy in your context can be the old one: read wiki/$page again before you work."
	fi
else
	git clone --quiet "$url" wiki
	echo "Wiki cloned at $(git -C wiki log -1 --format='%h %ad' --date=short)." \
		"wiki/$page is not in your context yet: read it before you work."
fi
