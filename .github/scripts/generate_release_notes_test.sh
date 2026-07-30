#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
generator="$script_dir/generate_release_notes.sh"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

repo="$temp_dir/repo"
git init --quiet --initial-branch=main "$repo"
git -C "$repo" config user.email "release-notes-test@example.com"
git -C "$repo" config user.name "Release notes test"

# Links are opt-in via the Actions environment; keep them out of the fixtures
# that assert exact output.
unset GITHUB_SERVER_URL GITHUB_REPOSITORY

commit() {
  local message="$1"
  local date="$2"

  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
    git -C "$repo" commit --allow-empty --quiet --message "$message"
}

short() {
  git -C "$repo" rev-parse --short=7 "$1"
}

commit "Initial release" "2025-01-01T00:00:00Z"
git -C "$repo" tag v1.0.0

commit "First release change" "2025-01-02T00:00:00Z"
commit "Update changelog" "2025-01-03T00:00:00Z"
git -C "$repo" tag v1.1.0

git -C "$repo" branch feature
git -C "$repo" checkout --quiet feature
commit $'feat(geo): add a silent update toggle\n\nFeature detail' "2025-01-04T00:00:00Z"
feat_geo="$(short HEAD)"
commit "fix(connection): stabilize sort order" "2025-01-05T00:00:00Z"
fix_connection="$(short HEAD)"
commit "perf: cache resolved routes" "2025-01-06T00:00:00Z"
perf_plain="$(short HEAD)"
commit "feat(api)!: drop the legacy endpoint" "2025-01-07T00:00:00Z"
breaking="$(short HEAD)"
commit "chore(ci): disable upstream publishing" "2025-01-08T00:00:00Z"
chore_ci="$(short HEAD)"
git -C "$repo" checkout --quiet main
GIT_AUTHOR_DATE="2025-01-09T00:00:00Z" \
  GIT_COMMITTER_DATE="2025-01-09T00:00:00Z" \
  git -C "$repo" merge --no-ff --quiet --message "Merge feature" feature
git -C "$repo" tag v1.2.0

first_change="$(short v1.1.0~1)"

expected="$temp_dir/expected.md"
actual="$temp_dir/actual.md"

# Sections ordered breaking > feat > fix > perf > other; entries sorted by scope
# then subject so the output does not depend on commit order.
printf '%s\n' \
  "### BREAKING CHANGES" \
  "" \
  "- **api:** drop the legacy endpoint ($breaking)" \
  "" \
  "### Features" \
  "" \
  "- **geo:** add a silent update toggle ($feat_geo)" \
  "" \
  "### Bug Fixes" \
  "" \
  "- **connection:** stabilize sort order ($fix_connection)" \
  "" \
  "### Performance Improvements" \
  "" \
  "- cache resolved routes ($perf_plain)" \
  "" \
  "### Other Changes" \
  "" \
  "- **ci:** disable upstream publishing ($chore_ci)" \
  "- First release change ($first_change)" \
  "" > "$expected"

(
  cd "$repo"
  bash "$generator" v1.0.0 "$actual"
)
diff -u "$expected" "$actual"

# A commit body must not leak into the notes.
! grep -q "Feature detail" "$actual"

# Nothing to report leaves an empty file rather than a stray heading.
printf '%s\n' "stale content" > "$actual"
(
  cd "$repo"
  bash "$generator" v1.2.0 "$actual"
)
[[ ! -s "$actual" ]]

# No previous release: still bounded by the caller, never a bare heading.
(
  cd "$repo"
  bash "$generator" "" "$actual"
)
grep -q -- "- Initial release" "$actual"

# Links appear only when the Actions environment provides the repository.
(
  cd "$repo"
  GITHUB_SERVER_URL="https://github.com" GITHUB_REPOSITORY="owner/name" \
    bash "$generator" v1.0.0 "$actual"
)
grep -qF -- "- **geo:** add a silent update toggle ([$feat_geo](https://github.com/owner/name/commit/" "$actual"
