#!/usr/bin/env bash
set -euo pipefail

tag="${1:?release tag is required}"
version="${2:?package version is required}"
line="${3:-dev}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo 'Package version must be numeric.' >&2
  exit 1
}
[[ "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)(-[[:alnum:].]+)?$ && "${BASH_REMATCH[1]}" == "$version" ]] || {
  echo 'Release tag must match the package version.' >&2
  exit 1
}
[[ "$line" == dev || "$line" == rs ]] || {
  echo 'Release line must be dev or rs.' >&2
  exit 1
}
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sed -e "s|TAG_VERSION|$tag|g" -e "s|PACKAGE_VERSION|$version|g" -e "s|RELEASE_LINE|$line|g" \
  "$script_dir/../release_template.md"
