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

if grep -q "Feature detail" "$actual"; then
  exit 1
fi

printf '%s\n' "stale content" > "$actual"
(
  cd "$repo"
  bash "$generator" v1.2.0 "$actual"
)
[[ ! -s "$actual" ]]

(
  cd "$repo"
  bash "$generator" "" "$actual"
)
grep -q -- "- Initial release" "$actual"

(
  cd "$repo"
  GITHUB_SERVER_URL="https://github.com" GITHUB_REPOSITORY="owner/name" \
    bash "$generator" v1.0.0 "$actual"
)
grep -qF -- "- **geo:** add a silent update toggle ([$feat_geo](https://github.com/owner/name/commit/" "$actual"

rebase_repo="$temp_dir/rebase"
git init --quiet --initial-branch=main "$rebase_repo"
git -C "$rebase_repo" config user.email "release-notes-test@example.com"
git -C "$rebase_repo" config user.name "Release notes test"
git -C "$rebase_repo" config core.autocrlf false

rebase_commit() {
  local file="$1"
  local content="$2"
  local message="$3"
  local date="$4"

  printf '%s\n' "$content" > "$rebase_repo/$file"
  git -C "$rebase_repo" add "$file"
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
    git -C "$rebase_repo" commit --quiet --message "$message"
}

rebase_commit upstream.txt "0.8.95" "Update changelog" "2025-02-01T00:00:00Z"
upstream_base="$(git -C "$rebase_repo" rev-parse HEAD)"
rebase_commit geo.txt "toggle" "feat(geo): add a silent update toggle" "2025-02-02T00:00:00Z"
rebase_commit sort.txt "stable" "fix(connection): stabilize sort order" "2025-02-03T00:00:00Z"
git -C "$rebase_repo" tag v100.0.1

git -C "$rebase_repo" checkout --quiet -b upstream "$upstream_base"
rebase_commit upstream.txt "0.8.96" "Optimize commented policy" "2025-02-04T00:00:00Z"
git -C "$rebase_repo" checkout --quiet main
git -C "$rebase_repo" rebase --quiet --onto upstream "$upstream_base" main

printf '%s\n' "stable, reworked against upstream" > "$rebase_repo/sort.txt"
git -C "$rebase_repo" add sort.txt
git -C "$rebase_repo" commit --quiet --amend --no-edit

if git -C "$rebase_repo" merge-base --is-ancestor v100.0.1 main; then
  exit 1
fi

(
  cd "$rebase_repo"
  bash "$generator" v100.0.1 "$actual"
)
if grep -q "add a silent update toggle" "$actual"; then
  exit 1
fi
grep -qF -- "- **connection:** stabilize sort order (" "$actual"
grep -qF -- "- Optimize commented policy (" "$actual"
