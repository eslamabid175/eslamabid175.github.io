---
name: flutter-check
description: Analyze, test and regenerate code for one Flutter app or package - build_runner when generated inputs changed, flutter analyze filtered to changed files, flutter test, and dependents of shared packages. Use after Dart changes, when asked to run analyze/tests, or when generated code is stale.
argument-hint: "[package dir]"
---
Package: $ARGUMENTS (default: the project root, or the package that owns the
changed files).

Preconditions: run from the package directory. `flutter pub get` only if
`pubspec.yaml` changed or `.dart_tool/` is missing. If `flutter` is not
found, run the `env-doctor` skill.

1. **Codegen**: any `@JsonSerializable`, `@freezed`, `@RestApi`,
   `@DriftDatabase`, `@injectable`, or `part '*.g.dart'` input changed ->
   `dart run build_runner build --delete-conflicting-outputs`. Check with
   `git status` that the expected `.g.dart` files changed.
2. **Analyze**: `flutter analyze 2>&1 | tee "${TMPDIR:-/tmp}/analyze.log" | tail -n 3`,
   then `grep -E '<changed file names>' "${TMPDIR:-/tmp}/analyze.log"`. Report new issues
   in changed files plus the total count. The Dart MCP `analyze_files` tool
   is an alternative for a few files.
3. **Tests**: `flutter test test/<file>_test.dart` for the closest test, then
   `flutter test` for the package. Hand long suites to `test-runner`.
4. **Monorepo**: a shared package changed -> repeat analyze for every app
   that depends on it (`grep -l '<package name>:' */pubspec.yaml`).
5. Format only the files you changed (`dart format <file>`), never a whole
   folder, unless the repo is already fully formatted.

Output: package, commands run, analyze (new issues | total), tests (summary
line), generated files touched.
