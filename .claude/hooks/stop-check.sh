#!/usr/bin/env bash
# Stop hook: blocks the turn from ending while scripts/check fails.
# Skips instantly when no .gd file differs from the last commit.
# Deliberately ignores stop_hook_active: it keeps blocking until the check passes.
# Interrupt the turn to escape.
cat >/dev/null  # hook input JSON (unused)
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0

if [ -z "$(git status --porcelain --untracked-files=all -- '*.gd' 2>/dev/null)" ]; then
	exit 0
fi

if ! output="$(scripts/check 2>&1)"; then
	{
		echo "scripts/check failed. Fix it before ending the turn."
		echo "$output" | sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g' | grep -vE "remote port number|Remote Debugger|connect_to_host|create_tcp" | tail -40
	} >&2
	exit 2
fi
exit 0
