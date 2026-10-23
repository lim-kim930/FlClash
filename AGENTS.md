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
- [.agents/setting-changes.md](.agents/setting-changes.md): whether a changed setting is patched live, re-applies the
  profile, or asks for an Android VPN restart.
- [.agents/surfaces.md](.agents/surfaces.md): fill levels, selection and status colors, and the few borders that
  remain, for any change to how a surface is colored.
- [.agents/agent-config.md](.agents/agent-config.md): how to choose between `AGENTS.md`, `.agents`, skills, Codex config,
  command rules, and hooks.
- [.agents/worktrees.md](.agents/worktrees.md): worktree hygiene across Claude Code, Codex, and Gemini.
- [.agents/flutter-upgrade.md](.agents/flutter-upgrade.md): SDK-pinned workarounds to recheck before changing the
  Flutter version.
- [.agents/skills.md](.agents/skills.md): index of repo-scoped skills in `.agents/skills/`.

## Highest Priority Rules

- When the user explicitly requests a scoped, low-risk change, inspect the relevant context and implement it directly.
  Do not require brainstorming, design documents, implementation plans, multiple-option proposals, or repeated confirmation.
  Ask only when material ambiguity, destructive impact, additional authority, or scope expansion could change the result.
- The request sets the scope. A pre-existing bug, cleanup, or refactor the task did not ask for is a follow-up in the
  summary, not part of the change. Edit a file surgically when a rewrite would give the same result, keep scratch checks
  out of the repository, and commit tests only where the task asks for them or the neighbouring code already keeps them.
- Comments are allowed and sometimes necessary; excess is the problem. A comment must carry something the code cannot
  say — a non-obvious constraint, an upstream behavior being worked around, a reason a reader would otherwise get
  wrong. Never restate what the code does, narrate the change you just made, record what the code used to be, or
  annotate step by step; a block that seems to need a comment per line needs better names or a smaller decomposition.
  Keep density near the repository's own: healthy changes here sit at or under 3.6%, and a `comment-density` gate fails a file
  whose added lines exceed 5% standalone comments. Delete commented-out code and stale notes in files you already
  touch. Preserve
  `// ignore:`-style directives, license headers, codegen markers, and vendored upstream comments. See
  [.agents/rules.md](.agents/rules.md) for what belongs in a test or in `.agents/` instead.
- Start FlClash on the host only as a safe mode build, and end only processes you started, by recorded pid. Never
  kill a FlClash instance by name; the user's own instance is not yours to close. See
  [.agents/rules.md](.agents/rules.md).
- Local builds, packaging, app launches and tests run exclusively in remote CI. Verify locally with syntax checks and
  `flutter analyze --no-fatal-infos`; use `flutter pub get` when needed and run required code generation.
- Run code generation after modifying models, providers, or database schema.
- Do not manually edit generated files.
- Preserve lifecycle ownership: desktop Core process convergence belongs to `lib/core/desktop/`; Android service intent
  arbitration belongs to `ServiceState`. UI/provider code may request a transition but must not become a second source of
  truth.
- Keep start/stop/restart paths latest-intent-safe. Flutter-to-Android service commands are deliberately optimistic, while
  native state serializes the actual work; desktop lifecycle results distinguish applied, coalesced, and superseded
  requests.
- Agent-assisted commits include a `Co-authored-by` trailer naming the actual coding agent. Human co-authors remain
  supported; do not invent an agent attribution for human-only work.
- Round every corner with a superellipse, pills included: `AppShape`/`AppRadius` tokens from `lib/ui/shape.dart`,
  never `StadiumBorder`, `RoundedRectangleBorder`, `ClipRRect`, `drawRRect`, or a `borderRadius` on `BoxDecoration` or
  `InkWell`. `test/lint/superellipse_corners_test.dart` enforces it; see the Corner Radius section of
  [.agents/rules.md](.agents/rules.md).
- Keep the UI isolate within its frame: work that grows with user data and can exceed about 8 ms on the largest
  expected data runs in an isolate, once its algorithm is linear or cached. See the UI Isolate Work section of
  [.agents/rules.md](.agents/rules.md).
- Follow `lint_options.yaml` (included by every `analysis_options.yaml`), especially single quotes, trailing commas, `child:` last, no `print()`, const/final
  preferences, and declared return types.
- Before reporting a change done, run `flutter analyze --no-fatal-infos`. Run tests and packaging only in remote CI,
  and report their actual status separately from local static analysis.

## Repo Skills

Use repo skills from `.agents/skills/` when a task matches their descriptions; `.claude/skills/` symlinks expose the
same skills to Claude Code. Current skills cover localization, UI work, core/platform changes, and pre-commit
structural quality review.

## Fork Workflow

This is a fork of `chen08209/FlClash`. Everything below is fork-specific and has
no upstream counterpart. `AGENTS.md` and `.agents/*` are upstream-maintained;
keep fork-only rules in this file so re-syncs have a single conflict site.

### Core fork maintenance

`core/Clash.Meta` uses our fork [lim-kim930/Clash.Meta](https://github.com/lim-kim930/Clash.Meta),
branch `curate/v0.9.2-routing`, derived from `chen08209/Clash.Meta`. The parent
repository's gitlink pins the exact Core commit; `.gitmodules` records the fork
URL and branch.

The fork adds `tunnel.MatchRoute` in `tunnel/patch.go` for the domain/IP routing
lookup. `core/rule_lookup.go` depends on this API to reuse the live metadata
preprocessing and rule matcher under the Core configuration lock, without
dialing the destination. DNS resolution may still occur. Maintaining this patch
is our responsibility until upstream provides an equivalent API.
Upstream's `ResolveRoute` returns only the proxy, so it does not replace the
matched-rule result that `MatchRoute` provides.

- When syncing a new upstream FlClash release, use the Core commit pinned by
  that release as the new baseline, then reapply/adapt our Core patch. Do not
  advance to an arbitrary Core branch tip or discard the fork during a routine
  submodule update.
- Review changes to metadata preprocessing, rule matching and configuration
  locking for compatibility with `MatchRoute` and `core/rule_lookup.go`. Verify
  routing lookup and platform builds in remote CI; never run local tests or builds.
- Push the patched Core commit to our fork before committing the parent
  repository's updated gitlink or publishing a release. The pinned commit must
  be fetchable by CI; keep `.gitmodules` aligned with the maintained fork branch.
- Switch back to upstream only after it provides equivalent behavior, the
  wrapper is migrated and remote CI passes. Update the submodule URL, gitlink
  and this maintenance note together when retiring the fork.

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

### Branch roles: `dev` vs `release`

- **`dev`**: Pure development branch for features, fixes, and docs. **Never commit `pubspec.yaml` version bumps to `dev`**. Keeping `dev` on upstream's base version ensures re-syncing with upstream never encounters repeated `pubspec.yaml` conflicts.
- **`release`**: Dedicated branch for publishing releases (both stable and beta releases). All `chore(release)` version bump commits and release tags live on `release`. **Never merge `release` back into `dev`**.

### Release process

To cut a new release (stable or beta):

```bash
git checkout release
git reset --hard dev
# Bump version in pubspec.yaml to 100.x.y+YYYYMMDDNN
git commit -am "chore(release): 100.x.y"
# Push only the release branch first; rebuilding it from dev may require a leased force push.
git push --force-with-lease origin release
# Create and push the release tag immediately; the tag workflow runs checks and packaging.
git tag v100.x.y
git push origin v100.x.y
git checkout dev
```

Push the `release` branch first, then create and push the release tag without waiting for branch CI. The tag workflow
runs the required checks and packaging before publishing release assets. If tagged CI fails, fix the cause on `dev`
and prepare a new release version and tag; never move or reuse a pushed tag. Full tests run only in remote CI, never locally.

For beta releases, keep `pubspec.yaml` on the numeric base version (`100.x.y+YYYYMMDDNN`) and put the prerelease suffix only in the tag (`v100.x.y-beta.N`), because native package formats do not share one prerelease syntax. In release notes, use the tag version for the `releases/download/v.../` path and the pubspec base version for artifact file names. Increment the `NN` build portion for every pushed beta attempt so Android `versionCode` keeps increasing. Never move or reuse a pushed tag.

### Fork CI differences

The fork's `.github/workflows/build.yaml` drops upstream's Telegram, Homebrew
and F-Droid publishing and the `Verify changelog` step. Upstream runs
`dart run tool/changelog.dart verify` on every tag push, and it fails for any
reachable `v100.x.y` tag that has no entry in `changelog.json`, which the fork
does not maintain; its tag pattern also only knows `-pre.N`, never `-beta.N`.
Release notes come from `.github/scripts/generate_release_notes.sh`, grouped from commit subjects and bounded by patch
identity after rebases. `.github/scripts/render_release_template.sh` separates the release tag from numeric package
versions. Both scripts have suites explicitly invoked by CI. The upstream changelog trailer renderer is not used for
fork release notes.
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

These host gaps were recorded at 0.8.97. Recheck them against the current baseline; do not broadly exempt other failures.

### Consolidated fork history

The v0.9.1 consolidation maps the previous 36 commits to nine feature commits.
See [.agents/fork-commits-v0.9.1.md](.agents/fork-commits-v0.9.1.md) for the exact source commits, discarded paths,
repairs, and verification limits. The original `dev` history and release tags remain available.
