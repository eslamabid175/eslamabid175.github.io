// Adversarial review of the uncommitted diff of a Flutter repo.
// Scope agent -> 5 parallel dimension reviewers -> 2 skeptics per finding.
// A finding survives unless BOTH skeptics refute it.
// Needs a Claude Code build with the Workflow tool; run it as the
// "review-changes" workflow, optionally with a path prefix as args.

export const meta = {
  name: 'review-changes',
  description: 'Review the uncommitted diff (correctness, architecture, data/API, UI/l10n, security) and adversarially verify every finding',
  whenToUse: 'Before declaring a change done, or on any uncommitted change set. Optional args: a path prefix to limit the review, e.g. "lib/features/checkout".',
  phases: [
    { title: 'Scope', detail: 'changed files from git, generated files dropped' },
    { title: 'Review', detail: 'one reviewer per dimension' },
    { title: 'Verify', detail: 'two skeptics per finding; dropped when both refute' },
  ],
}

const scope = typeof args === 'string' ? args.trim() : ''

const SCOPE_SCHEMA = {
  type: 'object',
  properties: {
    files: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
  required: ['files', 'summary'],
}

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' },
          line: { type: 'integer' },
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
          title: { type: 'string' },
          detail: { type: 'string', description: 'what is wrong and the concrete failure it causes' },
          fix: { type: 'string' },
        },
        required: ['file', 'line', 'severity', 'title', 'detail', 'fix'],
      },
    },
  },
  required: ['findings'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    refuted: { type: 'boolean' },
    reason: { type: 'string' },
  },
  required: ['refuted', 'reason'],
}

const READ_ONLY = 'Read-only: do not edit files, do not run build_runner, pub get, or git stash/checkout/reset/restore. Skip generated files (*.g.dart, *.freezed.dart, *.config.dart, *.mocks.dart, generated l10n output).'

phase('Scope')
const scoped = await agent(
  `List the files changed in the working tree of this repo${scope ? ` under ${scope}` : ''}: tracked changes from \`git diff --name-only HEAD\` plus untracked files from \`git status --porcelain\`. Drop generated files and build output. Summarise in 3-6 lines what the change set does. ${READ_ONLY}`,
  { label: 'scope', phase: 'Scope', schema: SCOPE_SCHEMA, effort: 'low' },
)
const files = (scoped && scoped.files) || []
if (!files.length) return { files: [], confirmed: [], note: 'nothing changed' }
log(`${files.length} changed files`)

const FILE_LIST = files.map(f => `- ${f}`).join('\n')
const CONTEXT = `Change set summary:\n${scoped.summary}\n\nChanged files:\n${FILE_LIST}\n\nRead the diff with \`git diff HEAD -- <file>\` (untracked files: read them whole). Read CLAUDE.md and .claude/rules/*.md for the project's rules. ${READ_ONLY} Report only real problems introduced or left broken by THIS change, each with file:line and a concrete failure scenario. No style nits. Empty list if clean.`

const DIMENSIONS = [
  { key: 'correctness', prompt: 'Review for correctness bugs: logic errors, null-safety holes (`!` on values that can be null), async races, missing awaits, a cubit/bloc emitting after close, leaked StreamSubscriptions/controllers, setState after dispose, BuildContext used across an async gap without a mounted check, off-by-one in dates/pagination, error paths that swallow failures.' },
  { key: 'architecture', prompt: 'Review against the architecture rules in CLAUDE.md and .claude/rules: layer boundaries (widgets never touch data sources/DTOs; domain has no Flutter/IO imports), repositories return the project result type instead of throwing, DI registration done the same way as neighbours, state classes immutable, no business logic in widgets, no duplicated helpers that already exist in lib/core.' },
  { key: 'data-api', prompt: 'Review data and API safety: local schema changes bump the schema version with a row-preserving migration; JSON models match the API contract (nullable fields, renamed keys, enums with unknown values); API changes stay compatible with builds already installed; generated code regenerated; no N+1 request loops; offline/error handling for network calls; pagination and caching correct.' },
  { key: 'ui-l10n', prompt: 'Review UI: colours/text styles from the theme (no raw Colors.* or hex in features), shared widgets reused, RTL-safe directional widgets, every visible string from l10n and present in every .arb locale with the same placeholders (run `python3 .claude/bin/check_arb_parity.py`), loading/empty/error states, destructive actions confirm, buttons disabled while busy, accessibility (tooltips, 48dp targets, no overflow at text scale 1.3).' },
  { key: 'security', prompt: 'Review security and release hygiene: secrets/API keys/tokens in code or assets, tokens or personal data in logs, an API base URL or flavor switched to a non-production value (or production in tests), debug flags left on, insecure storage of credentials (use secure storage), disabled certificate checks, cleartext HTTP enabled for production, permissions added to AndroidManifest/Info.plist without need.' },
]

phase('Review')
const results = await pipeline(
  DIMENSIONS,
  d => agent(`${d.prompt}\n\n${CONTEXT}`, { label: `review:${d.key}`, phase: 'Review', schema: FINDINGS_SCHEMA }),
  (review, d) => parallel(((review && review.findings) || []).map(f => () =>
    parallel([0, 1].map(i => () => agent(
      `Try to REFUTE this code-review finding (${d.key} dimension). ${i === 0 ? 'Lens: can the failure scenario really happen? Trace the actual code path.' : 'Lens: is this intended behaviour, or did it already exist on HEAD untouched by this change? Check `git show HEAD:<file>`.'} Default to refuted=true if the evidence is weak. ${READ_ONLY}\n\nFinding: ${JSON.stringify(f)}`,
      { label: `verify:${d.key}:${f.file.split('/').pop()}:${i}`, phase: 'Verify', schema: VERDICT_SCHEMA },
    ))).then(votes => {
      const v = votes.filter(Boolean)
      const refutes = v.filter(x => x.refuted).length
      return { ...f, dimension: d.key, survives: v.length > 0 && refutes < 2, disputed: refutes === 1, votes: v }
    }),
  )),
)

const all = results.flat().filter(Boolean)
const order = ['high', 'medium', 'low']
const confirmed = all.filter(f => f.survives).sort((a, b) => order.indexOf(a.severity) - order.indexOf(b.severity))
log(`${all.length} raw findings, ${confirmed.length} survived verification`)
return {
  files,
  summary: scoped.summary,
  confirmed: confirmed.map(({ votes, survives, ...f }) => f),
  refuted: all.filter(f => !f.survives).map(f => ({ file: f.file, line: f.line, title: f.title })),
}
