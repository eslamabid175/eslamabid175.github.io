#!/usr/bin/env bash
# Quality gates, diffed against a committed baseline.
#
#   bash .claude/bin/gates.sh                    # all gates; exit 1 on anything NEW
#   bash .claude/bin/gates.sh --quick            # analyzer only
#   bash .claude/bin/gates.sh --update-baseline  # snapshot today's issues (user decision only)
#
# Why a baseline: most real repos start with some analyzer issues. A gate that
# fails on all of them is ignored; a gate that fails only on NEW issues is
# trusted. Issues are keyed "severity rule path" (no line numbers), so editing
# above an old issue does not make it look new.
#
# Gates:
#   1. flutter analyze --no-pub          vs .claude/baseline/analyze.txt
#   2. arb parity (if l10n.yaml exists)  must pass
#   3. flutter test (full mode only)     must pass; skipped if there is no test/ dir
#   4. your own checks: add them in the EXTRA GATES block below
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2
BASE="$ROOT/.claude/baseline"
mkdir -p "$BASE"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
quick=0; update=0
for a in "$@"; do
  case "$a" in
    --quick) quick=1 ;;
    --update-baseline) update=1 ;;
    *) echo "usage: gates.sh [--quick] [--update-baseline]" >&2; exit 2 ;;
  esac
done
fail=0

compare() { # compare <name> <current file> <baseline file>
  local name=$1 cur=$2 base=$3 b new fixed total
  b="$base"; [ -f "$b" ] || b=/dev/null
  new=$(sort "$cur" | comm -23 - <(sort "$b"))
  fixed=$(sort "$b" | comm -23 - <(sort "$cur"))
  total=$(grep -c . "$cur" || true)
  if [ -n "$new" ]; then
    echo "FAIL  $name: $(printf '%s\n' "$new" | grep -c .) new (total $total, baseline $(grep -c . "$b" || true))"
    printf '%s\n' "$new" | sed 's/^/        + /'
    fail=1
  else
    echo "PASS  $name: nothing new (total $total)"
  fi
  if [ -n "$fixed" ]; then
    printf '%s\n' "$fixed" | sed 's/^/        fixed: /'
  fi
  return 0
}

# 1. analyzer
flutter analyze --no-pub > "$TMP/analyze.log" 2>&1
sed -nE 's/^[[:space:]]*(error|warning|info) • .* • ([^ ]+):[0-9]+:[0-9]+ • ([a-z_0-9]+)[[:space:]]*$/\1 \3 \2/p' \
  "$TMP/analyze.log" > "$TMP/analyze.txt"
[ "$update" = 1 ] && cp "$TMP/analyze.txt" "$BASE/analyze.txt"
compare "flutter analyze" "$TMP/analyze.txt" "$BASE/analyze.txt"
if grep -qE "uri_has_not_been_generated|Target of URI doesn't exist.*\.(g|freezed)\.dart" "$TMP/analyze.log"; then
  echo "        hint: generated code missing or stale -> dart run build_runner build --delete-conflicting-outputs"
fi

if [ "$quick" = 0 ]; then
  # 2. arb parity
  if [ -f l10n.yaml ]; then
    if out=$(python3 .claude/bin/check_arb_parity.py 2>&1); then
      echo "PASS  arb parity: $(printf '%s\n' "$out" | tail -n 1)"
    else
      echo "FAIL  arb parity"; printf '%s\n' "$out" | tail -n 20 | sed 's/^/        /'; fail=1
    fi
  fi
  # 3. tests
  if [ -d test ]; then
    if flutter test --no-pub > "$TMP/test.log" 2>&1; then
      echo "PASS  flutter test: $(tail -n 1 "$TMP/test.log")"
    else
      echo "FAIL  flutter test"; grep -E '\[E\]|Expected|Actual|Error' "$TMP/test.log" | head -n 20 | sed 's/^/        /'; fail=1
    fi
  fi
  # 4. EXTRA GATES (examples; uncomment / adapt):
  # dart run tool/check_theme_usage.dart || { echo "FAIL  theme usage"; fail=1; }
  # python3 tools/check_contrast.py      || { echo "FAIL  contrast";    fail=1; }
fi

[ "$update" = 1 ] && echo "baseline rewritten: .claude/baseline/analyze.txt (review with git diff)"
exit "$fail"
