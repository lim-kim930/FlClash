#!/usr/bin/env bash
set -euo pipefail

dist="${1:?release directory is required}"
manifest="$dist/manifest.json"
version="$(jq -er '.artifacts[0].version' "$manifest")"

jq -r '.artifacts[]
  | select(.os == "android")
  | [.name, "FlClash-\(.version)-android-" +
      {arm64: "arm64-v8a", armv7: "armeabi-v7a", amd64: "x86_64"}[.arch] + ".apk"]
  | @tsv' "$manifest" |
  while IFS=$'\t' read -r name legacy; do
    cp -- "$dist/$name" "$dist/$legacy"
  done

aliases="$(jq -er '.artifacts[]
  | select(.os == "android" or (.os == "windows" and .form == "setup"))
  | [.name, "FlClash-dev-" + (.name | ltrimstr("FlClash-")), .sha256]
  | @tsv' "$manifest")"
checksums="$dist/FlClash-dev-$version-SHA256SUMS"
: > "$checksums"
while IFS=$'\t' read -r name legacy digest; do
  cp -- "$dist/$name" "$dist/$legacy"
  printf '%s  %s\n' "$digest" "$legacy" >> "$checksums"
done <<< "$aliases"
