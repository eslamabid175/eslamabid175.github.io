# <PROJECT_NAME>

<!--
  Template from flutter-claude-kit. Replace every <PLACEHOLDER>, delete what
  does not apply, keep it SHORT (under ~120 lines). This file is loaded in
  every session: it is a map, not an encyclopedia. Detailed conventions go in
  .claude/rules/*.md (loaded only for matching paths) and docs/.
-->

<ONE_PARAGRAPH: what the app does, who uses it, platforms (Android / iOS / web), offline or online-first.>

## Stack
- Flutter <FLUTTER_VERSION> (Dart <DART_VERSION>), pinned with <FVM | none>
- State management: <flutter_bloc cubits | riverpod | provider>
- DI: <get_it + injectable | riverpod>
- Navigation: <go_router>
- Networking: <dio + retrofit>, base URL from `--dart-define=API_BASE_URL`
- Local storage: <drift | hive | shared_preferences | none>
- Backend: <YOUR_BACKEND> at <YOUR_API_URL> (dev: <YOUR_DEV_API_URL>)
- l10n: <locales, e.g. en (template), ar (RTL)>

## Layout
```
lib/
  core/          shared: theme, widgets, network, errors, DI, l10n
  features/<f>/  data/ (DTOs, data sources, repo impl) · domain/ (entities, repos, use cases) · presentation/ (state, pages, widgets)
  main.dart      -> bootstrap()
test/            unit + widget tests
patrol_test/     E2E (emulator + dev API only)
```

## Architecture rules (non-negotiable)
1. `presentation -> domain <- data`. Widgets never import data sources or DTOs.
2. Repositories return `<RESULT_TYPE>`; nothing throws across a layer.
3. One <cubit/notifier> per screen/flow; immutable states; no logic in widgets.
4. Colours/text styles from the theme only; shared widgets from `lib/core/widgets`.
5. Every user-facing string is an l10n key in EVERY locale.
6. API changes stay backward compatible with builds already in the stores.
7. Local schema changes keep every existing row (see the db-migration skill).
8. When code and a doc disagree, the code wins: fix the doc in the same change.

## Commands (verified <YYYY-MM-DD>)
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after model/DI/API changes
flutter gen-l10n                                          # after .arb changes
flutter analyze                                           # must have no NEW issues
bash .claude/bin/gates.sh                                 # analyze vs baseline + arb parity + tests
flutter test
flutter run -d <device> --dart-define=API_BASE_URL=<YOUR_DEV_API_URL>
```

## How to work here
1. Small change (one file, obvious fix): edit directly, then `/verify-change`.
2. Anything bigger (new feature, more than one layer, schema or API change):
   `/plan <task>` -> review the plan -> `/execute`. Or `/feature <task>` to run
   plan -> execute -> review without stopping.
3. Unknown code or a bug: `/investigate` first; wide searches go to the
   `flutter-investigator` agent.
4. Multi-step work: keep `.claude/progress/CURRENT.md` current with
   `/task-state`; after /clear or compaction use `/continue-task`.
5. See it running: `/run-app` (web via Playwright, Android via mobile/Marionette MCP).
   E2E: `/e2e-patrol` (emulator + dev API only).
6. Nothing is "done" until `/verify-change` shows real command output.

## MCP servers (.mcp.json, all started via .claude/mcp/launch.sh)
dart (analyze, LSP, pub, hot reload, widget inspector), marionette (drive a
debug build), patrol (E2E), mobile (emulator control), context7 (package docs).
playwright and firebase are off: remove them from `disabledMcpjsonServers` in
.claude/settings.json to use them (new session needed).
Test servers: `python3 .claude/bin/mcp_probe.py`.

## Never do
- Never commit, push, tag or release unless asked in this conversation.
- Never discard or reformat the user's uncommitted changes; never `dart format` a whole folder.
- Never hand-edit generated files (`*.g.dart`, `*.freezed.dart`, l10n output).
- Never run tests, E2E or write actions against production (<YOUR_API_URL>).
- Never read or print secrets: `.env*`, `key.properties`, keystores, service-account JSON, `.claude/local/`.
- Never add a package without saying why; never upgrade the Flutter SDK unasked.
- <PROJECT_SPECIFIC_RULE>
