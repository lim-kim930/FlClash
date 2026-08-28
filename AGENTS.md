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
- [.agents/skills.md](.agents/skills.md): index of repo-scoped skills in `.agents/skills/`.

## Highest Priority Rules

- When the user explicitly requests a scoped, low-risk change, inspect the relevant context and implement it directly.
  Do not require brainstorming, design documents, implementation plans, multiple-option proposals, or repeated confirmation.
  Ask only when material ambiguity, destructive impact, additional authority, or scope expansion could change the result.
- Do not add code or configuration comments unless the user explicitly asks for comments. This includes explanatory,
  narrative, TODO, and documentation comments. Never annotate line by line; comments belong only at the few key points
  that cannot be understood without one, and there you must propose the exact text and wait for approval. Delete
  commented-out code and stale notes whenever you touch the surrounding code. Put assertable behavior in a test,
  repository-wide invariants in `.agents/`, and keep a comment only for a fact that is local to one call site.
  See [.agents/rules.md](.agents/rules.md) for the full policy.
- Use `flutter test`, not `dart test`, because models pull in Flutter types.
- Run code generation after modifying models, providers, or database schema.
- Do not manually edit generated files.
- Preserve lifecycle ownership: desktop Core process convergence belongs to `lib/core/desktop/`; Android service intent
  arbitration belongs to `ServiceState`. UI/provider code may request a transition but must not become a second source of
  truth.
- Keep start/stop/restart paths latest-intent-safe. Flutter-to-Android service commands are deliberately optimistic, while
  native state serializes the actual work; desktop lifecycle results distinguish applied, coalesced, and superseded
  requests.
- Follow `analysis_options.yaml`, especially single quotes, trailing commas, `child:` last, no `print()`, const/final
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
continuously for weeks to months, freezing it only when an `Update changelog`
commit lands and `main` advances. `upstream/dev` is therefore always `main` plus
one commit whose hash changes without warning. Basing the fork on that tip
orphans its base on every amend.

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
file names. The tag workflow must create a GitHub prerelease for non-stable
tags; Actions artifacts alone are not a published beta. Never move or reuse a
pushed failed beta tag: fix forward and increment the beta sequence. Also
increment the `NN` portion of `+YYYYMMDDNN` for every pushed beta attempt,
because successful matrix jobs retain installable artifacts even when the
final release upload is skipped, and Android versionCode must keep increasing.

The generated Inno Setup script lives under `dist/`, so resource paths in
`windows/packaging/exe/make_config.yaml` are relative to that directory. Inno
Setup 6.7.1 failed while applying the previous single-layer PNG-compressed
`SetupIconFile`, reporting a misleading path error at line 15. Use the dedicated
`windows/packaging/exe/setup_icon.ico` for the installer and uninstaller, and
keep `windows/runner/resources/app_icon.ico` for the application and shortcuts.
Both icons must contain 16, 32, 48, 64, and 256-pixel DIB layers.

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

### Known upstream breakage

`test/common/task_test.dart` asserts `startsWith('/profiles/providers/7/...')`
and fails on Windows because `join()` yields backslashes. It passes on the
Linux CI runner. Verified failing on pure `upstream/main`, so do not treat it as
a fork regression.
