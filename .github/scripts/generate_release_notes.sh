#!/usr/bin/env bash

set -euo pipefail

previous_tag="${1:-}"
output="${2:-release.md}"

# Set in Actions; empty elsewhere, in which case bullets carry a bare short hash.
repo_url=""
if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
  repo_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY"
fi

# Syncing with upstream rebases this fork's patches, which detaches the previous
# release tag from HEAD - an ancestry range would then walk straight past it and
# dump the whole history. The symmetric difference with --cherry-pick compares
# patch ids rather than hashes, so already shipped patches drop out even after a
# rewrite. An empty previous_tag means the caller could not bound the range.
range="${previous_tag:+$previous_tag...}HEAD"

# %s, not %B: a commit body would otherwise land in the notes one line per
# bullet, trailers included. US (\x1f) separates the fields because a subject
# can contain anything else. tformat: terminates the last record, which format:
# would hand to awk without a newline.
#
# Conventional Commits: "type(scope)!: subject". Anything that does not parse
# keeps its subject verbatim and lands in Other Changes, which is what upstream
# commits do - they predate the convention.
git log --no-merges --cherry-pick --right-only \
  --pretty=tformat:'%H%x1f%s' "$range" |
  awk -F'\037' -v repo="$repo_url" '
  NF < 2 || $2 ~ /Update changelog/ { next }
  {
    short = substr($1, 1, 7)
    link = repo == "" ? "(" short ")" : "([" short "](" repo "/commit/" $1 "))"

    type = ""; scope = ""; breaking = 0; text = $2
    if (match($2, /^[a-z]+(\([^)]*\))?!?: /)) {
      head = substr($2, 1, RLENGTH - 2)
      text = substr($2, RLENGTH + 1)
      if (head ~ /!$/) { breaking = 1; sub(/!$/, "", head) }
      if (match(head, /\([^)]*\)$/)) {
        scope = substr(head, RSTART + 1, RLENGTH - 2)
        type = substr(head, 1, RSTART - 1)
      } else {
        type = head
      }
    }

    if (breaking)            { ord = 0; section = "BREAKING CHANGES" }
    else if (type == "feat") { ord = 1; section = "Features" }
    else if (type == "fix")  { ord = 2; section = "Bug Fixes" }
    else if (type == "perf") { ord = 3; section = "Performance Improvements" }
    else                     { ord = 4; section = "Other Changes" }

    bullet = scope == "" ? "- " text " " link : "- **" scope ":** " text " " link
    # Scoped entries first so the unscoped ones - upstream commits, mostly -
    # collect at the end of their section instead of leading it.
    printf "%d\t%s\t%d\037%s\037%s\t%s\n", ord, section, (scope == "" ? 1 : 0), scope, text, bullet
  }
' |
  sort -t"$(printf '\t')" -k1,1n -k3,3 |
  awk -F'\t' '
    $2 != previous { if (NR > 1) print ""; print "### " $2; print ""; previous = $2 }
    { print $4 }
    END { if (NR > 0) print "" }
  ' > "$output"
