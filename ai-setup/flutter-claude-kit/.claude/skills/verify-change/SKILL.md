---
name: verify-change
description: Evidence-based verification of a code change before calling it done - codegen freshness, flutter analyze (new issues only), the smallest relevant tests, l10n parity, a git diff check for unrelated files, and a scan for secrets/debug leftovers. Use after any edit, or for "verify this", "run the relevant tests".
argument-hint: "[files or package]"
---
Scope: $ARGUMENTS (empty = everything in `git status --porcelain`).

1. **Changed set**: `git status --porcelain` and `git diff --stat`. Compare
   with the pre-task snapshot (in CURRENT.md or the executor report); files
   that were already dirty are the user's.
2. **Codegen**: if a `part '*.g.dart'` / freezed / json_serializable /
   retrofit / drift / injectable input changed, run
   `dart run build_runner build --delete-conflicting-outputs` and confirm the
   generated files changed as expected.
3. **l10n**: if an `.arb` changed -> `flutter gen-l10n` and
   `python3 .claude/bin/check_arb_parity.py`.
4. **Analyze**: `bash .claude/bin/gates.sh --quick` (fails only on issues that
   are not in the baseline) or `flutter analyze`, reporting issues in changed
   files plus the total.
5. **Tests**: the closest test file first (`flutter test test/<x>_test.dart`),
   then the package. In a monorepo, analyze every package that depends on a
   changed shared package. Long runs go to the `test-runner` agent.
6. **Diff scan**: secrets/tokens/keys, `print`/`debugPrint` leftovers, a
   changed API base URL or flavor, a hard-coded string that should be l10n,
   whole-file reformatting, edited generated files, TODOs added.
7. Optional second opinion: the `review-changes` workflow (if your Claude Code
   has the Workflow tool) for an adversarial multi-dimension review.

Output:

| check | command | result |
|---|---|---|

then **Not verified** (each with the reason, e.g. no emulator) and
**Unrelated changes** (or "none").

A failing check: show the trimmed failing output; do not re-run hoping for a
different result.
