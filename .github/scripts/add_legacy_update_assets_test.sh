#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
generator="$script_dir/add_legacy_update_assets.sh"
temp_root="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
temp_dir="$(mktemp -d "$temp_root/flclash-legacy.XXXXXX")"
case "$(cd "$temp_dir" && pwd -P)" in
  "$temp_root"/flclash-legacy.*) ;;
  *) exit 1 ;;
esac
trap 'rm -rf -- "$temp_dir"' EXIT

fixture="$temp_dir/valid"
mkdir "$fixture"
printf '{"artifacts":[]}\n' > "$fixture/manifest.json"
version=100.2.3
for spec in \
  android:arm64:apk android:armv7:apk android:amd64:apk \
  windows:amd64:setup.exe windows:arm64:setup.exe \
  windows:amd64:portable.zip linux:amd64:deb macos:arm64:dmg; do
  IFS=: read -r os arch kind <<< "$spec"
  form=""
  name="FlClash-$version-$os-$arch"
  if [[ "$os" == windows ]]; then
    form="${kind%%.*}"
    name+="-$kind"
  else
    name+=".$kind"
  fi
  printf '%s\n' "$name" > "$fixture/$name"
  digest="$(sha256sum "$fixture/$name" | cut -d' ' -f1)"
  jq --arg name "$name" --arg version "$version" --arg os "$os" \
    --arg arch "$arch" --arg form "$form" --arg digest "$digest" \
    '.artifacts += [{name: $name, version: $version, os: $os, arch: $arch,
      form: (if $form == "" then null else $form end), sha256: $digest}]' \
    "$fixture/manifest.json" > "$fixture/manifest.tmp"
  mv -- "$fixture/manifest.tmp" "$fixture/manifest.json"
done

bash "$generator" "$fixture"
checksums="FlClash-dev-$version-SHA256SUMS"
test "$(wc -l < "$fixture/$checksums")" -eq 5
(
  cd "$fixture"
  sha256sum -c "$checksums"
)
for suffix in \
  android-arm64.apk android-armv7.apk android-amd64.apk \
  windows-amd64-setup.exe windows-arm64-setup.exe; do
  cmp "$fixture/FlClash-$version-$suffix" "$fixture/FlClash-dev-$version-$suffix"
done
cmp "$fixture/FlClash-$version-android-arm64.apk" "$fixture/FlClash-$version-android-arm64-v8a.apk"
cmp "$fixture/FlClash-$version-android-armv7.apk" "$fixture/FlClash-$version-android-armeabi-v7a.apk"
cmp "$fixture/FlClash-$version-android-amd64.apk" "$fixture/FlClash-$version-android-x86_64.apk"
test ! -e "$fixture/FlClash-dev-$version-windows-amd64-portable.zip"
test ! -e "$fixture/FlClash-dev-$version-linux-amd64.deb"
test ! -e "$fixture/FlClash-dev-$version-macos-arm64.dmg"

missing="$temp_dir/missing"
mkdir "$missing"
cp -- "$fixture"/* "$missing/"
rm -- "$missing/FlClash-$version-windows-arm64-setup.exe"
if bash "$generator" "$missing" > /dev/null 2>&1; then
  exit 1
fi

empty="$temp_dir/empty"
mkdir "$empty"
printf '{"artifacts":[]}\n' > "$empty/manifest.json"
if bash "$generator" "$empty" > /dev/null 2>&1; then
  exit 1
fi
