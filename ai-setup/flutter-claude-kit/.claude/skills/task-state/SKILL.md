---
name: task-state
description: Create, update or archive the task state file .claude/progress/CURRENT.md so a multi-step task survives context compaction, /clear and new sessions. Use at the start of any multi-step task, after each milestone, before a risky step, when the user says "save progress", and when a task is finished.
argument-hint: "[start <title> | update | done]"
---
Request: $ARGUMENTS

Rules: facts and file paths, not narration. Absolute dates. No secrets. No
command output longer than a few lines. Do not restate CLAUDE.md. Keep
CURRENT.md under ~120 lines.

1. **start <title>**: if CURRENT.md already holds a different `in-progress`
   task, ask whether to archive it or continue it; never overwrite it
   silently. Otherwise copy `.claude/progress/TEMPLATE.md` to
   `.claude/progress/CURRENT.md` and fill in the title, `status: in-progress`,
   `started`, `updated`, `plan` and `Goal`. Record the pre-task
   `git status --porcelain` list under "Pre-existing changes".
2. **update** (after each milestone): append to `Completed` with how it was
   verified (`command` -> result), replace `Current step`, add `Decisions`
   with the why and the rejected alternative, refresh `Next actions` (ordered
   and concrete), log gate runs in the table, bump `updated`.
3. **done**: set `status: done`, move the file to
   `.claude/progress/archive/YYYY-MM-DD-<slug>.md`, delete
   `.claude/plans/current-task.md` if it belongs to this task, and reset
   CURRENT.md to the stub (`status: none`). Durable lessons (not progress) go
   to memory / CLAUDE.md as one short line.

`status` is one of: in-progress | blocked | done | none. The SessionStart
hook prints CURRENT.md into every new, resumed, cleared or compacted session
while status is not `none`.

Output: one line saying what changed in the state file.
