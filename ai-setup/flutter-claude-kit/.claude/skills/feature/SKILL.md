---
name: feature
description: Full pipeline in one go for a non-trivial task - architect plans, executor implements, reviewer verifies, fixes loop back (max 2 rounds). No approval stop between plan and execution. Stops only for destructive data changes.
argument-hint: <task description>
disable-model-invocation: true
---
Task: $ARGUMENTS

You are the orchestrator. Do not design or code the task yourself.

1. Empty task text -> ask for it in one line and stop.
2. PLAN: launch `architect` with the task verbatim plus any context from the
   conversation. Print a 5-line plan summary (goal, key decisions, schema/API
   changes, files) and continue immediately. Exception: if the plan drops or
   rewrites stored user data, or touches production, stop and ask.
3. `/task-state start <short title>`.
4. EXECUTE: launch `executor` with "Implement .claude/plans/current-task.md."
   If it stops on an architectural problem, launch `architect` with its
   report to amend the plan, then relaunch the executor.
5. REVIEW: launch `reviewer` with the executor's full report plus "Review
   against .claude/plans/current-task.md."
6. On `VERDICT: CHANGES REQUIRED`: relaunch `executor` with the Fix List
   VERBATIM plus "Apply only these fixes, then re-run verification and
   report.", then review again. At most 2 review rounds in total.
7. If the plan's Verification asks for E2E or a visual check, run the
   `e2e-patrol` or `run-app` skill on an emulator.
8. `/task-state update` (or `done`).

Final message, short: implemented, files changed, verification results,
verdict, open items. No full reports. Do not commit.
