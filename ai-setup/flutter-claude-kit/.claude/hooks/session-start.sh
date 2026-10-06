#!/usr/bin/env bash
# SessionStart hook (startup|resume|compact|clear): re-inject the state a
# session needs to keep working without re-investigating:
#   - the active task file .claude/progress/CURRENT.md (unless status: none)
#   - an open architect plan (.claude/plans/current-task.md)
#   - branch + number of uncommitted paths
# Stdout becomes context for Claude. Keep it short; never fail the session.
set -u
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$ROOT" 2>/dev/null || exit 0

p=".claude/progress/CURRENT.md"
if [ -s "$p" ] && ! grep -q '^status: none' "$p"; then
  echo "=== Active task: $p (resume with /continue-task) ==="
  head -n 140 "$p"
  echo "=== end of task state ==="
fi

plan=".claude/plans/current-task.md"
if [ -s "$plan" ]; then
  echo "Open plan: $plan ($(head -n 1 "$plan" | cut -c1-100)). /execute implements it; delete it when the task is archived."
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  b=$(git branch --show-current 2>/dev/null)
  c=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  echo "git: branch ${b:-detached}, ${c} uncommitted path(s). Treat them as the user's work: never discard or reformat them."
fi

exit 0
