---
name: investigate
description: Read-only investigation before any fix - trace a bug or a feature path end to end (route -> page -> state -> repository -> data source/API), check git history, reproduce, and report the root cause with path:line evidence. Use for "why does X happen", "where is Y", "what breaks if I change Z".
argument-hint: <question or bug description>
---
Question: $ARGUMENTS

Read-only. Do not edit files while investigating.

1. **Orient**: CLAUDE.md, the matching `.claude/rules/*.md`, and any doc in
   `docs/`/`design/` that covers the area.
2. **Locate**: grep for the visible string, l10n key, route path, endpoint
   or class name. Read only the line ranges you need.
3. **Trace the path end to end** and write it as a hop table
   (`hop | path:line | what happens`):
   route -> page/widget -> cubit/bloc/notifier -> use case -> repository ->
   data source (API client / local DB) -> backend endpoint or table.
4. **Wide sweeps** (many call sites, several packages): delegate to the
   `flutter-investigator` agent, in parallel for independent questions.
5. **History**: `git log -S '<symbol>' --oneline -- <path>` and
   `git log -L` on the suspicious function when "since when / why" matters.
6. **Reproduce** when it is a bug: the smallest test, or `run-app` on an
   emulator. Never against production data.

Output:
- **Findings** (2 to 6 bullets)
- **Files** (`path:line`)
- **Root cause** (or best hypothesis + what would confirm it)
- **Evidence** (the hop table, log lines, test output)
- **Risks / blast radius** of fixing it
- **Next action**: small fix -> implement + `/verify-change`; large -> `/plan`.
