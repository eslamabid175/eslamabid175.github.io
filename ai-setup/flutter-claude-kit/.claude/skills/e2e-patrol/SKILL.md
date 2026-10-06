---
name: e2e-patrol
description: Bootstrap Patrol in a Flutter app, write E2E tests, and run them on an Android emulator through the patrol MCP server, always against a dev/staging API. Use for "E2E test", "patrol", "test this flow on the emulator", "set up patrol".
argument-hint: "[setup | write <flow> | run <patrol_test/file.dart>]"
---
Arguments: $ARGUMENTS

## Safety first
- E2E tests log in and write data. Run them only against a dev/staging API,
  never production. The app must read its base URL from
  `String.fromEnvironment('API_BASE_URL', defaultValue: ...)` and the patrol
  server passes `--dart-define=API_BASE_URL=<YOUR_DEV_API_URL>` (`.mcp.json`).
  The `e2e-guard` hook asks before a run when this is not in place.
- Test accounts come from the user. Keep them in a gitignored
  `.claude/local/e2e-defines.json` (`{"E2E_USER": "...", "E2E_PASS": "..."}`);
  `launch.sh` appends it as `--dart-define-from-file`. Tests read them with
  `String.fromEnvironment`. Never write credentials into test files and never
  print them.
- Emulator only. Every Patrol run clears the app's data on the device.

## setup (once per app)
1. `git status --porcelain -- pubspec.yaml android/` -> stop and ask if those
   files already have unrelated edits.
2. `flutter pub add --dev patrol` (try `--dry-run` first), and activate the
   CLI if missing: `dart pub global activate patrol_cli` (ask first).
3. `pubspec.yaml`, top level:
   ```yaml
   patrol:
     app_name: <App Name>
     test_directory: patrol_test
     android:
       package_name: <com.example.app>
   ```
4. `android/app/build.gradle(.kts)`: in `defaultConfig` set
   `testInstrumentationRunner "pl.leancode.patrol.PatrolJUnitRunner"` and
   `testInstrumentationRunnerArguments clearPackageData: "true"`; add
   `testOptions { execution "ANDROIDX_TEST_ORCHESTRATOR" }` and
   `androidTestUtil "androidx.test:orchestrator:<version>"`. Follow the current
   Patrol docs for exact syntax.
5. `android/app/src/androidTest/java/<package path>/MainActivityTest.java`:
   the Patrol JUnit runner class from the Patrol docs / example app.
6. Make the API base URL overridable (one constant file, behaviour unchanged
   without the define):
   `static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '<YOUR_PROD_API_URL>');`
   Derive every other URL from it.
7. `patrol_test/smoke_test.dart`: start the app the way `main()` does (or via
   a `bootstrap()` function) and wait for the first screen. Read-only.
8. Verify: `flutter analyze`, `patrol build android --target patrol_test/smoke_test.dart`,
   then a real run. List the changed files for the user to commit.

## run
1. Emulator: `emulator -list-avds`, then `emulator -avd <name> -no-snapshot-save`
   (Bash in the background); wait for `adb devices` to list `emulator-5554 device`.
2. `mcp__patrol__run` with the test file (a first build can take 10+ minutes).
   `status` for output, `screenshot` for the screen, `native-tree` for system
   dialogs, `quit` at the end. Shell alternative:
   `patrol test -d emulator-5554 -t patrol_test/<file>.dart`.
3. On failure, read the Dart stack trace first, then the screenshots.

## write
- One flow per file `patrol_test/<flow>_test.dart`; helpers in
  `patrol_test/support/`.
- Find widgets by `Key` first (`$(#loginButton)`), then by text. Add
  `ValueKey`s to the app only where needed.
- Native dialogs: `$.native.grantPermissionWhenInUse()` and friends.
- Tests are independent and re-runnable: create what they need, use unique
  names, never assume fixed ids.

Output: setup -> files changed, analyze/build/run results. run -> file,
device, PASS/FAIL with the failing step and screenshot path.
