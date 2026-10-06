---
name: release
description: Prepare an Android/iOS release - verify, bump the pubspec version, build an obfuscated appbundle/ipa with split debug info, and hand the upload to the user (or run the upload tool only after an explicit yes). Manual only because it is outward-facing.
argument-hint: "[android|ios|both] [--bump patch|minor|major] [--track internal]"
disable-model-invocation: true
---
Arguments: $ARGUMENTS

Releasing reaches real users. Every outward step needs the user's explicit
"yes" in this conversation.

1. **Gate**: `/verify-change` on the whole app (analyze, tests, l10n parity).
   Any FAIL -> stop and report. Never ship a red build.
2. **State check**: `git status --porcelain` must be clean or only contain
   the release changes; show the user the branch and last commit.
3. **Version**: read `version: x.y.z+n` from `pubspec.yaml`, propose the bump
   (patch by default; build number always +1), and apply it after the user
   agrees.
4. **Build** (production flavor / dart-defines as documented in CLAUDE.md):
   - Android: `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/<version>`
   - iOS: `flutter build ipa --release --obfuscate --split-debug-info=build/symbols/<version>`
   Confirm the API base URL baked into the build is production
   (`--dart-define` values) and that no debug flags are on.
5. **Symbols**: tell the user to archive `build/symbols/<version>/` (and
   upload to their crash reporter). Without them obfuscated stack traces are
   unreadable.
6. **Upload**: by default hand off - the artifact path and the console steps.
   If the project has an upload tool (fastlane, a script), run its dry-run
   first, show the plan, and run the real upload only after an explicit yes.
   Default to an internal/testing track; production only if the user typed it.
7. **Record**: changelog / release notes draft, and `/task-state update`.

Never commit or tag unless asked. Report: platform, old -> new version,
artifact path, symbols path, upload status.
