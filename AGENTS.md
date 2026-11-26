# AGENTS.md

This file is the entry point for AI coding agents working in this repository. Keep it small: each rule below is the
one-line form, and its explanation lives in the linked `.agents/` file.

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
- [.agents/ios-measurements.md](.agents/ios-measurements.md): measured iOS values the iOS-style surfaces and motion
  follow, and the deliberate deviations from them.
- [.agents/agent-config.md](.agents/agent-config.md): where agent guidance belongs, the repo skills in
  `.agents/skills/`, and worktree hygiene.
- [.agents/flutter-upgrade.md](.agents/flutter-upgrade.md): SDK-pinned workarounds to recheck before changing the
  Flutter version.

## Highest Priority Rules

- Implement an explicitly requested, scoped, low-risk change directly. Do not require brainstorming, design documents,
  implementation plans, multiple-option proposals, or repeated confirmation; ask only when ambiguity, destructive
  impact, extra authority, or scope expansion could change the result.
- The request sets the scope: an unrequested fix, cleanup, or refactor is a follow-up in the summary. Edit surgically,
  keep scratch checks out of the repository, and commit tests only where the task or the neighbouring code keeps them.
- A comment carries only what the code cannot say; never restate, narrate the change, or keep commented-out code. The
  `comment-density` gate fails a file whose added lines exceed 5% standalone comments. See Comments in
  [rules.md](.agents/rules.md).
- Start FlClash on the host only as a safe mode build, and end only processes you started, by recorded pid; never kill
  by name. See Running the App Locally in [rules.md](.agents/rules.md).
- Builds, packaging, app launches, native-library tests, full suites and coverage runs stay in remote CI. Locally run
  format and syntax checks, `flutter analyze --no-fatal-infos`, and affected Dart, provider, widget and lint tests that
  need no native libraries. Temporarily disable both native build hooks and restore `pubspec.yaml` afterwards; see
  [local preflight](.agents/commands.md#local-preflight-without-go-or-rust). Use `flutter pub get` when needed.
- Use `flutter test`, not `dart test`. Run code generation after changing models, providers, or the database schema,
  and never edit generated files.
- Desktop Core process convergence belongs to `lib/core/desktop/` and Android service intent arbitration to
  `ServiceState`; UI and providers request transitions, never own them. Keep start/stop/restart latest-intent-safe.
  See Lifecycle Rules in [rules.md](.agents/rules.md).
- Commits follow Conventional Commits and land follow-ups as regular commits. Agent-assisted commits include a
  `Co-authored-by` trailer naming the actual coding agent; human co-authors remain supported. See Commit Messages in
  [rules.md](.agents/rules.md).
- Never write machine-local identifiers into the repository: the home directory or user name, an absolute checkout
  path, the host name, or a personal email. Use `$HOME`, a repository-relative path, or a placeholder.
- Round every corner with a superellipse from `prism_ui/lib/shape.dart`; `test/lint/superellipse_corners_test.dart`
  enforces it. See Corner Radius in [rules.md](.agents/rules.md).
- Anything that moves drops no frame while it moves and at most one as it starts (8 ms of UI work at 120 Hz). See UI
  Frame Budget in [rules.md](.agents/rules.md).
- Follow `lint_options.yaml`: single quotes, trailing commas, `child:` last, no `print()`, const/final, declared return
  types.
- Before reporting done, run `flutter analyze --no-fatal-infos` and the applicable local checks above. Report local
  static analysis, local tests and remote CI results separately, naming skipped checks and their reasons. Scope checks
  with [.agents/skills/test-scope/SKILL.md](.agents/skills/test-scope/SKILL.md); the local limits above take precedence.

## Repo Skills

Use the skills in `.agents/skills/` when a task matches their descriptions; `.claude/skills/` symlinks expose them to
Claude Code. They cover localization, UI work, UI performance, core/platform changes, test scope, and pre-commit structural review.

## Fork Workflow

This is a fork of `chen08209/FlClash`. Everything below is fork-specific and has
no upstream counterpart. `AGENTS.md` and `.agents/*` are upstream-maintained;
keep fork-only rules in this file so re-syncs have a single conflict site.

### Core fork maintenance

`core/Clash.Meta` uses our fork [lim-kim930/Clash.Meta](https://github.com/lim-kim930/Clash.Meta),
branch `curate/v0.9.5-routing`, derived from `chen08209/Clash.Meta`. The parent
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
  native routing lookup and platform builds in remote CI. Local Dart routing tests use a mock Core with both native
  build hooks disabled.
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

An active `curate/v*` branch carries the development role below. At 0.9.5 this is
`curate/v0.9.5`; keep historical `dev` and earlier `curate` branches available.

- **`dev`**: Pure development branch for features, fixes, and docs. **Never commit `pubspec.yaml` version bumps to `dev`**. Keeping `dev` on upstream's base version ensures re-syncing with upstream never encounters repeated `pubspec.yaml` conflicts.
- **`release`**: Dedicated branch for publishing releases (both stable and beta releases). All `chore(release)` version bump commits and release tags live on `release`. **Never merge `release` back into `dev`**.

### Release process

To cut a new release (stable or beta):

```bash
development_branch="$(git branch --show-current)"
git checkout release
git reset --hard "$development_branch"
# Bump version in pubspec.yaml to 100.x.y+YYYYMMDDNN
git commit -am "chore(release): 100.x.y"
# Push only the release branch first; rebuilding it from dev may require a leased force push.
git push --force-with-lease origin release
# Create and push the release tag immediately; the tag workflow runs checks and packaging.
git tag v100.x.y
git push origin v100.x.y
git checkout "$development_branch"
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

At 0.9.5, these local checks fail on Windows because native paths use
backslashes while their prefixes and allowlists use forward slashes:

- `test/common/task_test.dart` asserts `startsWith('/profiles/providers/7/...')`
  and `join()` yields backslashes.
- `test/lint/disposable_field_test.dart`, `platform_layering_test.dart`,
  `prism_list_test.dart`, `reorder_proxy_decorator_test.dart`,
  `sheet_scroll_controller_test.dart`, `text_field_suggestions_test.dart` and
  `typography_test.dart` miss their existing path exemptions.

The seven lint failures reproduce against an unmodified `upstream/main` source
snapshot with the same 16 reported locations. The provider-path test also
remains identical to upstream. Temporary local copies with normalized paths
pass these checks; preserve the CI tests and do not exempt unrelated failures.

### Consolidated fork history

The v0.9.1 consolidation maps the previous 36 commits to nine feature commits.
See [.agents/fork-commits-v0.9.1.md](.agents/fork-commits-v0.9.1.md) for the exact source commits, discarded paths,
repairs, and verification limits. The original `dev` history and release tags remain available.

The 0.9.5 sync records each old commit kept, adapted or omitted in
[.agents/fork-commits-v0.9.5.md](.agents/fork-commits-v0.9.5.md), including the
upstream connection-detail replacement and the controls rebuilt for its new UI.
