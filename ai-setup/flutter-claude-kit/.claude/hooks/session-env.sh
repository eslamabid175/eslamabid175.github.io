#!/usr/bin/env bash
# SessionStart hook: put the tools a Flutter repo needs on PATH for every Bash
# call in the session. IDE-managed SDKs are often missing from a plain shell,
# and then every `flutter analyze` / `flutter test` gate fails.
#
# Writes `export PATH=...` lines to $CLAUDE_ENV_FILE (Claude Code sources it
# before each Bash command). Silent no-op for anything it cannot find; never
# fails the session.
set -u
[ -n "${CLAUDE_ENV_FILE:-}" ] || exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

add() { [ -n "$1" ] && [ -d "$1" ] && echo "export PATH=\"$1:\$PATH\"" >> "$CLAUDE_ENV_FILE"; }

# Flutter: project FVM pin first, then whatever is on PATH, then common installs.
if [ -x "$ROOT/.fvm/flutter_sdk/bin/flutter" ]; then
  add "$ROOT/.fvm/flutter_sdk/bin"
  echo "export FLUTTER_ROOT=\"$ROOT/.fvm/flutter_sdk\"" >> "$CLAUDE_ENV_FILE"
elif ! command -v flutter >/dev/null 2>&1; then
  for sdk in "${FLUTTER_ROOT:-}" "$HOME/fvm/default" "$HOME/flutter" \
    "$HOME/development/flutter" \
    "$HOME/snap/flutter/common/flutter" "/opt/flutter" "/usr/local/flutter" \
    "/opt/homebrew/share/flutter"; do
    if [ -n "$sdk" ] && [ -x "$sdk/bin/flutter" ]; then
      add "$sdk/bin"
      echo "export FLUTTER_ROOT=\"$sdk\"" >> "$CLAUDE_ENV_FILE"
      break
    fi
  done
fi

add "$HOME/.pub-cache/bin"   # patrol, marionette_mcp, flutterfire
add "$HOME/.local/bin"

if ! command -v node >/dev/null 2>&1; then
  add "$HOME/.local/share/node/current/bin"
  if [ -d "$HOME/.nvm/versions/node" ]; then
    latest=$(ls -1 "$HOME/.nvm/versions/node" 2>/dev/null | sort -V | tail -n 1)
    [ -n "$latest" ] && add "$HOME/.nvm/versions/node/$latest/bin"
  fi
fi

if ! command -v adb >/dev/null 2>&1; then
  for sdk in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk" "$HOME/Library/Android/sdk"; do
    if [ -n "$sdk" ] && [ -x "$sdk/platform-tools/adb" ]; then
      add "$sdk/platform-tools"
      add "$sdk/emulator"
      echo "export ANDROID_HOME=\"$sdk\"" >> "$CLAUDE_ENV_FILE"
      break
    fi
  done
fi
exit 0
