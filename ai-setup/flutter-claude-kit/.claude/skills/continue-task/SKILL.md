---
name: continue-task
description: Resume the previous task from .claude/progress/CURRENT.md after a new session, /clear or context compaction, without redoing what is already done. Use for "continue", "where were we", "resume".
---
1. Read `.claude/progress/CURRENT.md`. If `status: none`, show the newest
   file in `.claude/progress/archive/` and ask what to resume. Read
   `.claude/plans/current-task.md` too if the state file points at it.
2. Reconcile with reality: `git status --porcelain` and
   `git log -5 --oneline`. For each item under `Completed`, grep one symbol
   to confirm the change is really in the tree. Report any discrepancy before
   continuing.
3. If the tree changed since `updated`, re-run the last cheap check from the
   verification log (usually `flutter analyze`).
4. Restate in 5 lines: goal, done, current step, blockers, next action. Then
   do the next action.
5. Keep the state current with `/task-state update`.

Never redo a step recorded as completed. A recorded blocker comes first:
surface it, do not work around it silently. If the state file names files
that no longer exist, report it and ask before re-planning.
