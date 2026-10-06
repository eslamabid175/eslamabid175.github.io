---
name: plan
description: Plan a non-trivial task. Runs the architect agent, which analyzes the code and writes .claude/plans/current-task.md, then stops for the user's approval. No code is written.
argument-hint: <task description>
disable-model-invocation: true
---
Task from the user: $ARGUMENTS

You are the orchestrator. Do not analyze or design the task yourself; delegate.

1. If the task text is empty, ask for it in one line and stop.
2. Launch the `architect` subagent (foreground). Prompt: the task text
   verbatim, plus any file paths, screenshots, specs or ticket text the user
   gave in this conversation.
3. When it returns, read these sections of `.claude/plans/current-task.md`:
   Goal, Technical Decisions, Data / Persistence Changes, API Contract
   Changes, Files To Modify, Files To Create, Implementation Steps.
4. Reply with: the goal in one sentence, the key decisions as bullets, any
   schema or API change called out explicitly, the files to modify/create,
   and the number of steps. End with one line: "Run /execute to implement, or
   tell me what to change in the plan."
5. Start the task state: `/task-state start <short title>` (status
   in-progress, plan: .claude/plans/current-task.md).
6. Do NOT implement anything and do NOT launch the executor.
