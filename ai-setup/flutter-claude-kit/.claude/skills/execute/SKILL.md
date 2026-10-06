---
name: execute
description: Implement .claude/plans/current-task.md with the executor agent, then verify it with the reviewer agent. A CHANGES REQUIRED fix list loops back to the executor verbatim (max 2 review rounds), then a short report.
argument-hint: "[extra notes for the executor]"
disable-model-invocation: true
---
Extra notes from the user (may be empty): $ARGUMENTS

You are the orchestrator. Do not write production code yourself in this flow;
route work to the agents and relay between them.

Precondition: `.claude/plans/current-task.md` exists and is not empty.
Otherwise tell the user to run `/plan <task>` first and stop.

Loop, at most 2 review rounds:

1. Launch `executor` (foreground).
   - Round 1: "Implement .claude/plans/current-task.md." plus the user's notes.
   - Later rounds: the reviewer's "Fix List For Executor" VERBATIM, plus
     "Apply only these fixes, then re-run verification and report."
2. If the executor STOPPED on an architectural problem, do not decide it
   yourself. Launch `architect` with the executor's report and ask it to
   amend the plan (as a "Revision N" section at the top), then go back to
   step 1. This counts as a round.
3. Launch `reviewer` (foreground) with the executor's full completion report
   plus "Review against .claude/plans/current-task.md."
4. `VERDICT: APPROVED` -> done. `VERDICT: CHANGES REQUIRED` with rounds left
   -> step 1. No rounds left -> stop and report the open findings.

Then update the task state (`/task-state update`, or `done` if approved and
nothing is left).

Final message, short: what was implemented, files changed, verification
results (PASS/FAIL per command), the reviewer's verdict, open items, and the
docs the plan said to update (confirm they were). Do not paste full reports.
Do not commit.
