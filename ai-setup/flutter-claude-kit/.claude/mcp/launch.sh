#!/usr/bin/env bash
# Launcher for every MCP server in .mcp.json.
#
# Why: Claude Code starts stdio MCP servers from the project root with a
# minimal PATH. Flutter (IDE-managed or FVM), `dart pub global` binaries,
# Node (nvm / per-user installs) and adb usually live outside it, so servers
# fail with "command not found". This script resolves them, then execs the
# real server command passed as arguments:
#
#   bash .claude/mcp/launch.sh dart mcp-server
#   bash .claude/mcp/launch.sh dart pub global run patrol_mcp
#   bash .claude/mcp/launch.sh npx -y @mobilenext/mobile-mcp@latest
#   bash .claude/mcp/launch.sh --cd apps/admin npx -y @playwright/mcp@latest
#
# --cd <dir>  run the server inside <dir> (relative to the project root).
# Relative PROJECT_ROOT (used by patrol_mcp) is made absolute.
# Optional: if PATROL_DEFINES_FILE points at an existing JSON file (personal,
# gitignored test-account defines), it is appended to PATROL_FLAGS as
# --dart-define-from-file=<file>.
#
# Test every server without restarting Claude Code:
#   python3 .claude/bin/mcp_probe.py [server ...]
set -u

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT" || exit 1
if [ "${1:-}" = "--cd" ]; then
  [ -n "${2:-}" ] || { echo "launch.sh: --cd needs a directory" >&2; exit 1; }
  cd "$ROOT/$2" || { echo "launch.sh: no such directory: $2" >&2; exit 1; }
  shift 2
fi
[ $# -gt 0 ] || { echo "launch.sh: no server command given" >&2; exit 1; }

prepend() { [ -n "$1" ] && [ -d "$1" ] && case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }

# --- Flutter / Dart SDK --------------------------------------------------
# Order: project FVM pin, global FVM default, $FLUTTER_ROOT, common installs.
if [ -x "$ROOT/.fvm/flutter_sdk/bin/flutter" ]; then
  prepend "$ROOT/.fvm/flutter_sdk/bin"
  export FLUTTER_ROOT="$ROOT/.fvm/flutter_sdk"
elif ! command -v flutter >/dev/null 2>&1; then
  for sdk in "${FLUTTER_ROOT:-}" "$HOME/fvm/default" "$HOME/flutter" \
    "$HOME/development/flutter" \
    "$HOME/snap/flutter/common/flutter" "/opt/flutter" "/usr/local/flutter" \
    "/opt/homebrew/share/flutter"; do
    if [ -n "$sdk" ] && [ -x "$sdk/bin/flutter" ]; then
      prepend "$sdk/bin"
      export FLUTTER_ROOT="$sdk"
      break
    fi
  done
fi

# `dart pub global activate` binaries (patrol_cli, patrol_mcp, marionette_mcp,
# flutterfire) and per-user installs (uv, standalone CLIs).
prepend "$HOME/.pub-cache/bin"
prepend "$HOME/.local/bin"

# --- Node.js for npx-based servers ---------------------------------------
if ! command -v node >/dev/null 2>&1; then
  prepend "$HOME/.local/share/node/current/bin"
  prepend "/opt/homebrew/bin"
  if ! command -v node >/dev/null 2>&1 && [ -d "$HOME/.nvm/versions/node" ]; then
    latest=$(ls -1 "$HOME/.nvm/versions/node" | sort -V | tail -n 1)
    [ -n "$latest" ] && prepend "$HOME/.nvm/versions/node/$latest/bin"
  fi
fi

# --- Android SDK (adb, emulator) for patrol / mobile servers -------------
for sdk in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk" "$HOME/Library/Android/sdk"; do
  if [ -n "$sdk" ] && [ -x "$sdk/platform-tools/adb" ]; then
    prepend "$sdk/platform-tools"
    prepend "$sdk/emulator"
    export ANDROID_HOME="$sdk"
    break
  fi
done

# --- patrol_mcp helpers ---------------------------------------------------
if [ -n "${PROJECT_ROOT:-}" ]; then
  case "$PROJECT_ROOT" in
    /*) ;;
    *) PROJECT_ROOT="$(cd "$ROOT/$PROJECT_ROOT" 2>/dev/null && pwd || echo "$ROOT/$PROJECT_ROOT")"; export PROJECT_ROOT ;;
  esac
fi
if [ -n "${PATROL_DEFINES_FILE:-}" ]; then
  f="$PATROL_DEFINES_FILE"
  case "$f" in /*) ;; *) f="$ROOT/$f" ;; esac
  if [ -f "$f" ]; then
    export PATROL_FLAGS="${PATROL_FLAGS:-} --dart-define-from-file=$f"
  fi
fi

export PATH
exec "$@"
