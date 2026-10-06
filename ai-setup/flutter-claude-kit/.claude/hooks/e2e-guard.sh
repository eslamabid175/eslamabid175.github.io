#!/usr/bin/env bash
# PreToolUse guard for Patrol E2E runs (matcher: mcp__patrol__run).
#
# An E2E test logs in, creates and deletes data. If the app still points at the
# production API, a "test" edits real users' data. This hook asks before a run
# when any safety precondition is missing:
#   - the dev API placeholder in .mcp.json was never filled in
#   - the app's API config does not read the URL from String.fromEnvironment
#   - pubspec.yaml has no patrol dev_dependency
#   - a physical phone is connected (patrol_mcp may pick it, and each run
#     clears the app's data on the device)
#
# Configure: KIT_API_CONFIG_FILE = the Dart file that holds your base URL,
#            KIT_API_DEFINE     = the --dart-define name it reads.
set -u
: "${KIT_API_CONFIG_FILE:=lib/core/config/api_config.dart}"
: "${KIT_API_DEFINE:=API_BASE_URL}"

cat >/dev/null   # hook input not needed
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$ROOT" || exit 0

ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

if grep -q '<YOUR_DEV_API_URL>' .mcp.json 2>/dev/null; then
  ask "PATROL_FLAGS in .mcp.json still has the <YOUR_DEV_API_URL> placeholder, so the run would use the URL compiled into the app."
fi
if [ ! -f "$KIT_API_CONFIG_FILE" ]; then
  ask "API config file $KIT_API_CONFIG_FILE not found (set KIT_API_CONFIG_FILE). Cannot confirm the run targets a dev API."
fi
if ! grep -qF -e "String.fromEnvironment('$KIT_API_DEFINE'" -e "String.fromEnvironment(\"$KIT_API_DEFINE\"" "$KIT_API_CONFIG_FILE"; then
  ask "$KIT_API_CONFIG_FILE does not read String.fromEnvironment('$KIT_API_DEFINE'): the app may still call the production API."
fi
if ! grep -Eq '^[[:space:]]+patrol:' pubspec.yaml 2>/dev/null; then
  ask "pubspec.yaml has no patrol dev_dependency; run the e2e-patrol skill setup first."
fi
if command -v adb >/dev/null 2>&1; then
  phys=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" && $1 !~ /^emulator-/ {print $1}' | head -n 1)
  [ -n "$phys" ] && ask "A physical device is connected. patrol_mcp may pick it and every run clears the app data. Disconnect it or confirm."
fi
exit 0
