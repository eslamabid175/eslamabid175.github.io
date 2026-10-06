---
name: env-doctor
description: Check (and repair the safe parts of) the local Flutter + Claude Code environment - Flutter/Dart on PATH, pub global tools, Node, adb/emulator, every MCP server in .mcp.json, hooks, generated code freshness. Use when a tool or MCP server fails, after an SDK/OS upgrade, or for "is my environment ok".
---
Run the checks, fix what is safe, report the rest.

| check | command | healthy | safe fix |
|---|---|---|---|
| Flutter SDK | `flutter --version` | >= the version in CLAUDE.md | the SessionStart hook `session-env.sh` adds FVM / common SDK paths; else tell the user where it was not found |
| Dart MCP support | `dart --version` | Dart >= 3.12 (`dart mcp-server --disable`); 3.10/3.11 need `--exclude-tool` instead in `.mcp.json`, 3.9 no flag | upgrade Flutter (ask first) or adjust the `dart` args in `.mcp.json` |
| pub global tools | `dart pub global list` | `patrol_cli`, `patrol_mcp`, `marionette_mcp` if used | `dart pub global activate <pkg>` (ask first) |
| Node / npx | `node --version`, `npx --version` | node >= 20 (context7 needs >= 20.18.1), npx present | install via nvm (ask first) |
| MCP servers | `python3 .claude/bin/mcp_probe.py` (or `... <name>`) | every line `ok` | read the FAIL line: most are PATH (see `.claude/mcp/launch.sh`) or a first slow `npx` download |
| adb / emulator | `adb devices`, `emulator -list-avds` | an AVD exists | create one in Android Studio |
| hooks | `bash -n .claude/hooks/*.sh`; `command -v jq python3` | no syntax errors; one of jq/python3 present | - |
| deps | `flutter pub get` (only if `.dart_tool/` is missing or stale) | resolves | - |
| codegen | `bash .claude/bin/gates.sh --quick` | no `uri_has_not_been_generated` | `dart run build_runner build --delete-conflicting-outputs` |
| l10n | `python3 .claude/bin/check_arb_parity.py` | 0 problems | `/l10n` |

Rules: no global installs, SDK upgrades or `sudo` without asking. MCP and
settings changes load in a NEW session; `mcp_probe.py` tests them now.

Output: the table with actual results, what was fixed, what needs the user.
