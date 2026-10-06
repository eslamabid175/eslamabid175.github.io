#!/usr/bin/env bash
# PostToolUse hook (matcher: Edit|Write|MultiEdit).
#
# For the edited file:
#   1. .dart (not generated): `dart format` that ONE file          (KIT_FORMAT_ON_EDIT, default 1)
#   2. .dart (not generated): `dart analyze` that file, errors are fed
#      back to Claude as context so it fixes them in the next step  (KIT_ANALYZE_ON_EDIT, default 1)
#   3. once-per-session reminders for follow-up work the file type needs:
#      build_runner, gen-l10n + all .arb files, drift schema migration,
#      pub get, MCP config reload.
# Never blocks, always exits 0.
#
# Repo where most files are NOT dart-formatted? Set KIT_FORMAT_ON_EDIT=0
# (export it before starting Claude Code, or change the default below),
# otherwise the first edit of a file reformats all of it and buries the diff.
set -u
: "${KIT_FORMAT_ON_EDIT:=1}"
: "${KIT_ANALYZE_ON_EDIT:=1}"

input=$(cat)
field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null
  else
    printf '%s' "$input" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for k in sys.argv[1].strip(".").split("."):
    d = d.get(k) if isinstance(d, dict) else None
print("" if d is None else d)' "$1" 2>/dev/null
  fi
}
file=$(field .tool_input.file_path)
sid=$(field .session_id); sid=${sid:-nosession}
[ -n "$file" ] && [ -f "$file" ] || exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
seen="${TMPDIR:-/tmp}/claude-after-edit-${sid}"
msgs=()

once() { # once <key> <message>
  grep -qxF "$1" "$seen" 2>/dev/null && return 0
  echo "$1" >> "$seen"
  msgs+=("$2")
}

package_dir() { # nearest ancestor with a pubspec.yaml (monorepo friendly)
  local d; d=$(dirname "$1")
  while [ "$d" != "/" ] && [ "$d" != "." ]; do
    [ -f "$d/pubspec.yaml" ] && { echo "$d"; return; }
    [ "$d" = "$ROOT" ] && break
    d=$(dirname "$d")
  done
  echo "$ROOT"
}

run_t() { if command -v timeout >/dev/null 2>&1; then timeout "$@"; else shift; "$@"; fi; }

case "$file" in
  *.g.dart|*.freezed.dart|*.gr.dart|*.config.dart|*.mocks.dart|*/l10n/generated/*|*/build/*|*/.dart_tool/*) ;;
  *.dart)
    pkg=$(package_dir "$file")
    rel=${pkg#"$ROOT"}; rel=${rel#/}; rel=${rel:-.}
    if command -v dart >/dev/null 2>&1; then
      [ "$KIT_FORMAT_ON_EDIT" = 1 ] && dart format "$file" >/dev/null 2>&1
      if [ "$KIT_ANALYZE_ON_EDIT" = 1 ]; then
        errs=$(cd "$pkg" && run_t 45 dart analyze "$file" 2>&1 | grep -E '^[[:space:]]*error[[:space:]]' | head -n 15)
        [ -n "$errs" ] && msgs+=("after-edit: dart analyze reports errors in $(basename "$file"):
$errs")
      fi
    fi
    if grep -Eq "^part '.*\.(g|freezed)\.dart';" "$file"; then
      once "codegen:$pkg" "after-edit: $(basename "$file") feeds build_runner. Before analyze/test run: (cd $rel && dart run build_runner build --delete-conflicting-outputs)."
    fi
    if grep -Eq "extends[[:space:]]+Table[[:space:]]*\{|schemaVersion" "$file"; then
      once "schema:$file" "after-edit: drift schema touched. Follow the db-migration skill: bump schemaVersion, add a row-preserving onUpgrade step, regenerate, never edit a shipped migration step."
    fi
    ;;
  *.arb)
    once "l10n" "after-edit: .arb file changed. Add the same key + placeholders to EVERY locale file, then run flutter gen-l10n and python3 .claude/bin/check_arb_parity.py (see the l10n skill)."
    ;;
  */pubspec.yaml)
    once "pub:$file" "after-edit: pubspec.yaml changed. Run flutter pub get in $(dirname "${file#"$ROOT"/}") and mention the new dependency and why in your report."
    ;;
  "$ROOT"/.mcp.json|"$ROOT"/.claude/settings.json|"$ROOT"/.claude/mcp/*)
    once "mcp" "after-edit: MCP/settings changed. Claude Code loads them at session start; test servers now with python3 .claude/bin/mcp_probe.py <name>."
    ;;
esac

[ ${#msgs[@]} -eq 0 ] && exit 0
text=$(printf '%s\n' "${msgs[@]}")
if command -v jq >/dev/null 2>&1; then
  jq -cn --arg t "$text" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$t}}'
else
  printf '%s' "$text" | python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":sys.stdin.read()}}))'
fi
exit 0
