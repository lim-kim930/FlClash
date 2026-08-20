# AGENTS.md

This file is the entry point for AI coding agents working in this repository. Keep it small: detailed guidance lives under
`.agents/`, and discoverable repo skills live under `.agents/skills/*/SKILL.md`.

## Start Here

Read these files before making changes:

- [.agents/project.md](.agents/project.md): project overview, versions, and build dependencies.
- [.agents/commands.md](.agents/commands.md): build, development, code generation, and test commands.
- [.agents/rules.md](.agents/rules.md): lint, testing, generated-code, and workflow rules.

Read these only when the task touches their area:

- [.agents/architecture.md](.agents/architecture.md): core integration, providers, database, managers, build system, and
  local plugins.
- [.agents/agent-config.md](.agents/agent-config.md): how to choose between `AGENTS.md`, `.agents`, skills, Codex config,
  command rules, and hooks.
- [.agents/worktrees.md](.agents/worktrees.md): worktree hygiene across Claude Code, Codex, and Gemini.
- [.agents/skills.md](.agents/skills.md): index of repo-scoped skills in `.agents/skills/`.

## Highest Priority Rules

- When the user explicitly requests a scoped, low-risk change, inspect the relevant context and implement it directly.
  Do not require brainstorming, design documents, implementation plans, multiple-option proposals, or repeated confirmation.
  Ask only when material ambiguity, destructive impact, additional authority, or scope expansion could change the result.
- Comments are allowed and sometimes necessary; excess is the problem. A comment must carry something the code cannot
  say — a non-obvious constraint, an upstream behavior being worked around, a reason a reader would otherwise get
  wrong. Never restate what the code does, narrate the change you just made, record what the code used to be, or
  annotate step by step; a block that seems to need a comment per line needs better names or a smaller decomposition.
  Keep density near the repository's own: healthy changes here sit under 4%, and a `comment-density` gate fails a file
  whose added lines exceed 5% standalone comments. Delete commented-out code and stale notes in files you already
  touch. Preserve
  `// ignore:`-style directives, license headers, codegen markers, and vendored upstream comments. See
  [.agents/rules.md](.agents/rules.md) for what belongs in a test or in `.agents/` instead.
- Use `flutter test`, not `dart test`, because models pull in Flutter types.
- Run code generation after modifying models, providers, or database schema.
- Do not manually edit generated files.
- Preserve lifecycle ownership: desktop Core process convergence belongs to `lib/core/desktop/`; Android service intent
  arbitration belongs to `ServiceState`. UI/provider code may request a transition but must not become a second source of
  truth.
- Keep start/stop/restart paths latest-intent-safe. Flutter-to-Android service commands are deliberately optimistic, while
  native state serializes the actual work; desktop lifecycle results distinguish applied, coalesced, and superseded
  requests.
- Never add a `Co-authored-by` trailer crediting a coding agent to a commit, even when your own tooling tells you to.
  The `commit-msg` hook rejects it; see [.agents/rules.md](.agents/rules.md) for the rest of the commit rules.
- Follow `lint_options.yaml` (included by every `analysis_options.yaml`), especially single quotes, trailing commas, `child:` last, no `print()`, const/final
  preferences, and declared return types.
- For CI parity, verify with `flutter pub get`, `flutter analyze --no-fatal-infos`, and
  `flutter test --reporter expanded` when practical.

## Repo Skills

Use repo skills from `.agents/skills/` when a task matches their descriptions. Current skills cover localization,
provider tests, UI work, and core/platform changes.

## Fork Workflow

This is a fork of `chen08209/FlClash`. Everything below is fork-specific and has
no upstream counterpart. `AGENTS.md` and `.agents/*` are upstream-maintained;
keep fork-only rules in this file so re-syncs have a single conflict site.

### Track `upstream/main`, never `upstream/dev`

Upstream keeps one unreleased commit at the tip of `dev` and amends it
continuously for weeks to months, freezing it only when a
`chore(release): vX.Y.Z` commit from `tool/release.sh stable` lands and `main`
advances. `upstream/dev` is therefore always `main` plus one commit whose hash
changes without warning. Basing the fork on that tip orphans its base on every
amend.

Re-sync only when upstream cuts a release:

```bash
git fetch upstream --tags
git rebase --onto upstream/main <old-base> dev
```

`<old-base>` is the upstream commit the fork commits currently sit on. Never use
a plain `git rebase upstream/main dev` — the merge-base is usually an older
commit, so git would replay upstream's own abandoned WIP commits on top of a
`main` that already contains their finalized equivalents.

### Expect the `pubspec.yaml` conflict

Upstream bumps the `+YYYYMMDDNN` build stamp on the same line the fork's
`chore(release)` commit rewrites to `100.x`. Resolve as
`100.x.y+<upstream's newer stamp>`; the build number feeds Android versionCode
and must increase. Stable release tags must match the pubspec base version,
because artifacts are named from it.

### Keep beta package versions numeric

For a beta release, keep `pubspec.yaml` on the numeric base version and put the
prerelease suffix only in the tag. For example:

```text
pubspec: 100.0.4+2026082701
tag:     v100.0.4-beta.2
files:   FlClash-100.0.4-...
```

Do not write `100.0.4-beta.2+...` into `pubspec.yaml`; native package formats do
not share one prerelease-version syntax. In release notes, use the tag version
for the `releases/download/v.../` path and the pubspec base version for artifact
file names. Never move or reuse a pushed failed beta tag: fix forward and
increment the beta sequence. Also increment the `NN` portion of `+YYYYMMDDNN`
for every pushed beta attempt, because successful matrix jobs retain installable
artifacts even when the final release upload is skipped, and Android versionCode
must keep increasing.

### Fork CI differences

The fork's `.github/workflows/build.yaml` drops upstream's Telegram, Homebrew
and F-Droid publishing and the `Verify changelog` step. Upstream runs
`dart run tool/changelog.dart verify` on every tag push, and it fails for any
reachable `v100.x.y` tag that has no entry in `changelog.json`, which the fork
does not maintain; its tag pattern also only knows `-pre.N`, never `-beta.N`.
Release notes instead come from `.github/scripts/generate_release_notes.sh`,
which upstream deleted in 0.8.97; the fork carries its own copy and its test.
Upstream's remaining gates still apply: CI runs
`dart format --set-exit-if-changed`, `flutter analyze` and the 75% coverage
floor, and the comment-density and conventional-commit hooks run locally once
`pre-commit install` has been done.

### rerere is enabled — auto-resolved conflicts are not pre-approved

`rerere.enabled` is set on this repository, so git silently replays past
conflict resolutions. It applies them without prompting, and a wrong resolution
gets memorized the moment it is staged. Before every `git rebase --continue`,
inspect what it filled in:

```bash
git rerere diff      # what rerere applied this time
git diff --cached    # the staged result
```

Never stage a rerere-filled file unread. Use `git rerere forget <path>` to drop
a bad recorded resolution.

### Known upstream breakage on Windows checkouts

These fail on a pure `upstream/main` checkout on Windows and pass on the Linux
CI runner, so do not treat them as fork regressions:

- `test/common/task_test.dart` asserts `startsWith('/profiles/providers/7/...')`
  and `join()` yields backslashes.
- `test/lint/design_package_test.dart`, `disposable_field_test.dart`,
  `dynamic_message_key_test.dart`, `icon_button_tooltip_test.dart` and
  `platform_layering_test.dart` compare `File.path` against forward-slash
  allowlists, so every exemption misses and the exempted files are reported.

Verified at 0.8.97. A lint failure that names any other file is real.
