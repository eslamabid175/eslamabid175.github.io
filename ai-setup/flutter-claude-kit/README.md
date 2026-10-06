# Flutter Claude Code Kit

A drop-in [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) environment for Flutter repos:
MCP servers that let Claude analyze, run and drive your app, a
**plan → execute → review** agent pipeline, verification skills, safety hooks,
and task state that survives `/clear` and context compaction.

It is generic. Nothing in it is tied to a company or a backend. You fill in a
handful of `<PLACEHOLDERS>` and keep only the parts you want.

> Distilled from the setups Eslam Aped uses on production Flutter + Django apps — https://eslamabid175.github.io/ai-environment.html

---

## What's inside

```
flutter-claude-kit/
├── CLAUDE.md                     project map + rules template (<PLACEHOLDERS>)
├── .mcp.json                     dart, marionette, patrol, mobile, playwright, firebase, context7
└── .claude/
    ├── settings.json             permissions (allow/deny) + hook wiring
    ├── .gitignore                keeps per-machine/per-task state out of git
    ├── mcp/launch.sh             PATH-fixing launcher every MCP server goes through
    ├── hooks/
    │   ├── session-env.sh        SessionStart: Flutter/FVM, pub-cache, Node, adb on PATH
    │   ├── session-start.sh      SessionStart: re-injects CURRENT.md, open plan, git status
    │   ├── guard.sh              PreToolUse(Bash): ask before push/reset/rm -rf/deploy/...
    │   ├── e2e-guard.sh          PreToolUse(patrol run): ask unless E2E targets a dev API
    │   └── after-edit.sh         PostToolUse: dart format + analyze the edited file, reminders
    ├── agents/                   architect, executor, reviewer, test-runner,
    │                             flutter-investigator, ui-auditor
    ├── skills/<name>/SKILL.md    plan, execute, feature, investigate, verify-change,
    │                             flutter-check, task-state, continue-task, e2e-patrol,
    │                             run-app, ui-audit, l10n, db-migration, release, env-doctor
    ├── rules/mobile.md           path-scoped Flutter conventions (loads for lib/**, test/**)
    ├── progress/TEMPLATE.md      task-state template (+ CURRENT.md stub)
    ├── plans/                    architect writes current-task.md here
    ├── bin/
    │   ├── mcp_probe.py          talk to MCP servers from the shell, no restart needed
    │   ├── gates.sh              analyze vs baseline + arb parity + tests
    │   └── check_arb_parity.py   every locale has every key and placeholder
    ├── baseline/analyze.txt      known analyzer issues (gates fail only on NEW ones)
    └── workflows/review-changes.js  adversarial multi-agent review (Workflow tool)
```

## Prerequisites

| Tool | Needed for | Check |
|---|---|---|
| Claude Code | everything | `claude --version` |
| Flutter SDK with **Dart ≥ 3.12** | `dart mcp-server` (the official Dart/Flutter MCP server). The `--disable` flag in `.mcp.json` needs Dart 3.12+; on Dart 3.10/3.11 change it to `--exclude-tool create_project`, on 3.9 drop the two args | `dart --version` |
| Node.js ≥ 20 with npm/npx | mobile, playwright, firebase, context7 servers (context7 needs ≥ 20.18.1) | `node --version`, `npx --version` |
| Android SDK + an emulator (AVD) | patrol, mobile, run-app | `adb devices`, `emulator -list-avds` |
| python3 | probe, parity check, hook JSON fallback | `python3 --version` |
| jq (optional) | hooks use it when present, python3 otherwise | `jq --version` |
| Patrol CLI + MCP (optional) | E2E | `dart pub global activate patrol_cli` and `dart pub global activate patrol_mcp` |
| marionette_mcp (optional) | driving a debug build | `dart pub global activate marionette_mcp` + `marionette_flutter` dev dependency in the app |

## Install

1. **Copy** the kit into the root of your Flutter repo:
   ```bash
   unzip flutter-claude-kit.zip
   cd flutter-claude-kit
   cp -Rn CLAUDE.md .mcp.json .claude /path/to/your_app/   # -n: never overwrite your files
   chmod +x /path/to/your_app/.claude/hooks/*.sh /path/to/your_app/.claude/mcp/launch.sh /path/to/your_app/.claude/bin/*
   ```
   This leaves this README out of your repo. `-n` skips files you already
   have, so if you already have a `CLAUDE.md`, `.mcp.json` or
   `.claude/settings.json`, merge the kit's version into yours by hand.
   Start `claude` from the repo root: `.mcp.json` launches the servers with a
   path relative to it.
2. **Fill in the placeholders**:
   ```bash
   grep -rn '<[A-Z_]*>' CLAUDE.md .mcp.json .claude
   ```
   - `CLAUDE.md`: project name, stack, commands, `<YOUR_API_URL>`.
   - `.mcp.json` → `patrol.env.PATROL_FLAGS`: your **dev** API (`<YOUR_DEV_API_URL>`).
     Monorepo? Duplicate the `patrol` entry per app with its own `PROJECT_ROOT`.
   - `.claude/rules/mobile.md`: your architecture, state management, result type.
   - `.claude/hooks/e2e-guard.sh`: `KIT_API_CONFIG_FILE` (the Dart file with your base URL).
3. **Make the API URL overridable** (needed for safe E2E):
   ```dart
   static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '<YOUR_PROD_API_URL>');
   ```
4. **Snapshot today's analyzer issues** so gates only fail on new ones:
   `bash .claude/bin/gates.sh --update-baseline`
5. **Verify**: start `claude` in the repo, approve the project MCP servers, run
   `/mcp` and check every server is connected. From a shell, without a restart:
   `python3 .claude/bin/mcp_probe.py` (one `ok` line per server).
   `/env-doctor` checks the rest (SDK, adb, hooks, parity).
6. Commit the kit (except what `.claude/.gitignore` excludes) so your team gets it too.

## MCP servers (`.mcp.json`)

Every server starts through `.claude/mcp/launch.sh`. Claude Code launches stdio
servers with a minimal PATH, so IDE-installed Flutter, FVM, `~/.pub-cache/bin`,
nvm Node and adb are often "not found". The launcher resolves them (FVM project
pin → FVM default → `$FLUTTER_ROOT` → common install dirs), supports
`--cd <dir>` for monorepos, makes a relative `PROJECT_ROOT` absolute, and
optionally appends a gitignored `--dart-define-from-file` with test accounts.
SDK somewhere else? Export `FLUTTER_ROOT` (or add the path to the list in
`launch.sh` and `session-env.sh`).

| Server | What Claude gets |
|---|---|
| **dart** (`dart mcp-server`) | analyze files (with fixes), LSP (definition, references, hover, symbols), pub + pub.dev search, read/grep dependency sources, connect to a running app (DTD / VM service): hot reload/restart, widget inspector, runtime errors. Since Dart 3.12 the CLI-style tools (`run_tests`, `dart_format`, `launch_app`, ...) are off by default and Claude uses the `flutter` CLI for them; turn them back on with `--enable cli` / `--enable flutter_app_lifecycle`. `create_project` disabled. |
| **marionette** | drives a running **debug** build over the VM service: `connect`, `get_interactive_elements`, `tap`, `enter_text`, `scroll_to`, screenshots, logs, hot reload. Needs `marionette_flutter` + `MarionetteBinding.ensureInitialized()` behind `kDebugMode`. |
| **patrol** (`patrol_mcp`) | runs `patrol_test/` E2E tests on a device: run, status, screenshot, native tree, quit. |
| **mobile** (`@mobilenext/mobile-mcp`) | emulator/device control: list elements, tap, type, swipe, screenshots, system dialogs, logs. |
| **playwright** (`@playwright/mcp`) | Flutter **web** in a real browser. Tip: click `flt-semantics-placeholder` to turn on the semantics tree. Disabled by default. |
| **firebase** (`firebase-tools mcp`) | Firestore/Auth/FCM/Crashlytics tooling. Disabled by default: it talks to a live project. |
| **context7** | current docs for pub.dev packages and other libraries. |

`firebase` and `playwright` are listed in `disabledMcpjsonServers` in
`.claude/settings.json`. To turn one on, remove it from that list (setting
arrays merge across settings files, so a `settings.local.json` cannot take an
entry back out). To turn off another server just for you, add its name to
`disabledMcpjsonServers` in `.claude/settings.local.json`, or toggle it in `/mcp`.
Every server needs a new session after a config change; `mcp_probe.py` tests
it right away.

## Agents (`.claude/agents/`)

| Agent | Role | Tools | Model |
|---|---|---|---|
| **architect** | reads code + rules, makes every decision, writes `.claude/plans/current-task.md` (Goal, Decisions with rejected alternatives, Files To Modify / NOT To Touch, Steps, Verification, Acceptance Criteria...). Never implements. | read + Write (plan file only) | opus |
| **executor** | implements the plan exactly, snapshots `git status` first, runs verification, STOPs on architectural contradictions, fixed completion report. | read + Edit/Write/Bash | inherit |
| **reviewer** | read-only; checks the real `git diff` against the acceptance criteria; starts with `VERDICT: APPROVED` or `VERDICT: CHANGES REQUIRED` + a "Fix List For Executor". | read-only | opus |
| **test-runner** | runs given analyze/test commands, returns only summaries and failures (keeps logs out of context). | Bash, Read | sonnet |
| **flutter-investigator** | read-only wide sweeps (who calls this endpoint, where is this cubit used), `path:line` evidence, under 60 lines. | read-only, plan mode | inherit |
| **ui-auditor** | read-only design-system audit: theme/dark mode, RTL, l10n, states, feedback, accessibility, shared widgets. | read-only | sonnet |

Model routing: the stronger reasoning model decides and reviews; the executor
inherits your session model; cheap, mechanical work goes to a smaller model.
Change the `model:` lines to suit your plan and budget.

## Skills (`.claude/skills/`)

| Skill | Use it for |
|---|---|
| `/plan <task>` | architect writes the plan; stops for your approval. Manual only. |
| `/execute` | executor → reviewer → fix list back to executor verbatim, max 2 rounds. Manual only. |
| `/feature <task>` | plan + execute + review in one go (stops only for destructive data changes). Manual only. |
| `investigate` | read-only root-cause trace: route → page → state → repo → data source, git history, reproduce. |
| `verify-change` | codegen, analyze (new issues only), closest tests, arb parity, unrelated-file check, secrets/debug scan → evidence table. |
| `flutter-check` | per-package build_runner / analyze / test, plus dependents in a monorepo. |
| `task-state` | `start` / `update` / `done` for `.claude/progress/CURRENT.md`; archives finished tasks. |
| `continue-task` | resume after `/clear` or compaction: read state, reconcile with git, re-run the last check, continue. |
| `run-app` | launch web (Playwright) or Android (mobile MCP / Marionette) and look at the change. |
| `e2e-patrol` | bootstrap Patrol, write tests, run them on an emulator against a dev API. |
| `ui-audit` | one ui-auditor per feature folder in parallel; `--fix` applies high/medium findings. |
| `l10n` | add/rename copy in every `.arb` locale, gen-l10n, parity. |
| `db-migration` | drift schema change with a replayed, row-preserving `onUpgrade` step. |
| `release` | verify → version bump → obfuscated build + symbols → hand-off/upload after an explicit yes. Manual only. |
| `env-doctor` | check SDK, Dart MCP support, pub tools, Node, adb, every MCP server, hooks. |

Skills without `disable-model-invocation` are picked up automatically when the
request matches their description; all of them can be typed as `/name`.

## Hooks (`.claude/settings.json`)

| Event | Script | What it does |
|---|---|---|
| SessionStart | `session-env.sh` | writes PATH exports to `$CLAUDE_ENV_FILE` so every Bash call finds Flutter (FVM aware), pub-cache tools, Node and adb. |
| SessionStart (startup, resume, compact, clear) | `session-start.sh` | prints the active `CURRENT.md`, an open plan, branch + number of uncommitted files ("the user's work, never discard it"). |
| PreToolUse `Bash` | `guard.sh` | **deny** printing keystores/`key.properties`/`.env`/service accounts; **ask** before `git push`, `reset --hard`, `clean -f`, `checkout --`, `rebase`, `commit --amend`, `rm -rf`, `scp/rsync`, `firebase deploy`, `flutterfire configure`, `shorebird release/patch`, `fastlane`, `adb uninstall`/`pm clear`, `patrol test` without `-d emulator-N`, `dart format .`. |
| PreToolUse `mcp__patrol__run` | `e2e-guard.sh` | **ask** if the dev-API placeholder is unfilled, the API config does not use `String.fromEnvironment`, patrol is not in pubspec, or a physical phone is connected. |
| PostToolUse `Edit\|Write\|MultiEdit` | `after-edit.sh` | `dart format` + `dart analyze` the ONE edited file (errors go back to Claude as context); once-per-session reminders for build_runner, `.arb` parity + gen-l10n, drift schema bumps, `pub get`, MCP reloads. |

Tuning:
- Repo not `dart format`-clean? `export KIT_FORMAT_ON_EDIT=0` before starting
  Claude (or change the default in `after-edit.sh`). Otherwise the first edit of
  a file reformats all of it and buries the real diff.
- `ask` prompts also appear in auto mode. If they slow you down, remove the
  categories you do not need from `guard.sh`; the `deny` rules in
  `settings.json` still apply.

## The work loop

```
            ┌──────────── small change ────────────┐
request ──► investigate ──►                         ├─► verify-change ──► task-state update
            └── big change ──► /plan ──► (you approve) ──► /execute ─┘
                                 │                        │
                          architect writes         executor implements
                     .claude/plans/current-task.md   reviewer: VERDICT
                                                     CHANGES REQUIRED → fix list
                                                     back to executor (max 2 rounds)
```

1. **Plan**: `/plan add offline favourites`. The architect writes the plan with
   decisions, files, steps and acceptance criteria. You read the summary and
   approve or ask for changes (`/feature` skips this stop).
2. **Execute**: `/execute`. The executor implements and runs the plan's
   verification commands. The reviewer checks the real diff. A "CHANGES
   REQUIRED" fix list goes back to the executor word for word, at most twice.
   An architectural blocker goes back to the architect, which amends the plan.
3. **Verify**: nothing is "done" without `/verify-change` output: a table of
   `check | command | result`, plus "Not verified" with reasons. Optional:
   `/run-app` to see it, `/e2e-patrol` for a flow, the `review-changes` workflow
   for an adversarial second opinion (5 reviewers, 2 skeptics per finding; a
   finding survives unless both skeptics refute it).
4. **Progress**: `.claude/progress/CURRENT.md` holds the goal, completed steps
   with the command that proved them, decisions with the reason, blockers, a
   verification log and next actions. The SessionStart hook re-injects it after
   startup, resume, `/clear` and compaction; `/continue-task` checks it against
   git and carries on. `/task-state done` archives it.

## Extend it

- **More rules**: add `.claude/rules/<area>.md` with `paths:` frontmatter
  (e.g. `lib/features/payments/**`); they load only when Claude touches those files.
- **Backend in the same workspace**: add a `backend.md` rule, a Django/FastAPI
  test skill, and extend `verify-change`. The same plan/execute loop works across repos.
- **A code graph**: a small standard-library script that indexes
  routes → pages → cubits → API calls lets agents answer "what breaks if I change X"
  without reading the whole repo. Worth building once a project passes a few hundred files.
- **Shareable snapshot**: copy `CLAUDE.md`, `.mcp.json` and `.claude/` (minus
  `settings.local.json`, `local/`, `progress/`, `plans/`) to share the setup with a colleague.

## Safety notes

- `.claude/local/` (test accounts), `settings.local.json`, `CURRENT.md`, the
  progress archive and plans are gitignored by `.claude/.gitignore`.
- Firebase and Playwright servers are off by default (`disabledMcpjsonServers`).
- Agents never commit or push; releases and deploys are manual-only skills.
- E2E runs only on an emulator, only against a dev API.

---

Distilled from the setups Eslam Aped uses on production Flutter + Django apps — https://eslamabid175.github.io/ai-environment.html

Use it, fork it, adapt it.
