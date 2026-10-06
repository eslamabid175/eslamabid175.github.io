---
name: ui-audit
description: Audit Flutter UI against the design system with the ui-auditor agent (theme/dark mode, RTL, l10n, states, feedback, accessibility, shared widgets). Runs one auditor per feature folder in parallel for a whole app; --fix applies high and medium findings, then verifies.
argument-hint: "<feature folder | file list | all> [--fix]"
---
Target: $ARGUMENTS

1. Resolve the target:
   - a file list or folder -> one `ui-auditor` run;
   - `all` -> one `ui-auditor` per `lib/features/*` folder (or the repo's
     equivalent), launched in parallel, at most 3 at a time;
   - empty -> the UI files changed in `git status --porcelain`.
2. Each auditor gets the file list and "Audit against the design system;
   report only verified findings with path:line and the exact fix."
3. Merge the results: dedupe, sort by severity, count per severity.
4. Without `--fix`: report the findings and stop.
5. With `--fix`: apply high and medium findings (small, local edits; no
   redesign), add any missing l10n keys to every locale, then run
   `/verify-change`. Low findings are listed, not applied.

Output: findings table (severity | path:line | problem | fix), counts, and
with --fix the verification table.
