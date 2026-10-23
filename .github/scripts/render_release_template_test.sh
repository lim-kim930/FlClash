#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
generator="$script_dir/render_release_template.sh"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

for tag in v100.2.3 v100.2.3-beta.4; do
  bash "$generator" "$tag" 100.2.3 > "$temp_dir/notes.md"
  grep -qF "/releases/download/$tag/FlClash-100.2.3-android-arm64-v8a.apk" "$temp_dir/notes.md"
  grep -qF "/releases/download/$tag/FlClash-100.2.3-windows-amd64.zip" "$temp_dir/notes.md"
  if grep -qE 'TAG_VERSION|PACKAGE_VERSION|FlClash-100.2.3-beta' "$temp_dir/notes.md"; then
    exit 1
  fi
done

if bash "$generator" v100.2.4 100.2.3 > /dev/null 2>&1; then
  exit 1
fi
if bash "$generator" v100.2.3-beta.4 100.2.3-beta.4 > /dev/null 2>&1; then
  exit 1
fi
