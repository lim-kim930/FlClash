# Upstream v0.9.5 fork sync

## Baselines

- FlClash: `v0.9.5`, `deba70d80d2af509171f9c6465de9d14719f0399`.
- Previous fork base: `v0.9.4`, `89791d7c11978bf9b580ba71bffcb00506a17659`.
- Development branch: `curate/v0.9.5`; `curate/v0.9.4` remains available.
- Core baseline pinned by the release: `fea29264f541cba170bb8b7dda84697aa1dbcc3b`.
- Patched Core: `38faa110505c125845a76dee330cdc22a0427cc0`, pushed to
  `lim-kim930/Clash.Meta`, branch `curate/v0.9.5-routing`, before the parent gitlink.
- Prism UI: `cae9a43572bddb9b20b9350ef7fde3f434a758c7`.
- Flutter: 3.50.1 locally and in CI; the package language bound stays at Dart 3.10.

## Commit decisions

The source commits below are from `curate/v0.9.4`. Equivalent upstream work is
omitted. Features still needed by the fork use the new UI and current owners.

| Source commit | Decision | Reason and resulting implementation |
| --- | --- | --- |
| `d77a389f` | Omit | Upstream contains the same private security-reporting change. |
| `9f2759e2` | Omit | Upstream contains the same issue-title validation change. |
| `c4a88272` | Adapt | Keep fork project/Core links and the smaller About page; retain upstream update badges, spacing and update-channel controls. |
| `31e7680e` | Adapt | Keep fork branch/tag checks, numeric beta package versions and release-note scripts. Adopt upstream package names without a line prefix and check every release lookup. Keep APK aliases and SHA256SUMS for older fork updaters. |
| `17e8fc49` | Rebuild | The separate DNS page and old request buffers were replaced. Add history clearing to the new Requests/DNS menus. Keep active connections and their traffic, replace the poll lineage, and clear held page records immediately. |
| `e0d565e9` | Omit | Upstream ConnectionLog, ConnectionPoller and TrackerSelection already keep detail views live and retain final traffic. Use their timeline, traffic summary and nested-sheet behavior. |
| `33fee599` | Rebuild | Upstream removed the table and has no alternative sorting control. Add sorting to the new list menu using RecordSort and the shared stable index sorter. Compute ordering in an isolate; default ordering retains minute groups. |
| `09736b48` | Keep | Upstream still needs Geo defaults without a subscription and serialized live setting updates before resource downloads. Adapt tests to the new startup state. |
| `7ca1350c` | Keep | Preserve Helper startup waiting, prompt installation and rejection of unprivileged fallbacks. Keep upstream authorization-before-restart and lifecycle launch-epoch changes; the fork guard still covers a Helper handoff that falls back to a direct Core. |
| `668e6105` | Keep | Upstream ResolveRoute still returns only a proxy, not the matched rule. Carry MatchRoute and its pending-writer regression onto the exact pinned Core. Keep the new connection detail UI and adapt the lookup page spacing and chain glyph. |
| `8f20e5a8` | Keep | Preserve fork workflow, agent attribution and local-check limits while accepting upstream guidance and test-scope routing. |
| `a128934f` | Keep | Preserve Loyalsoldier GeoIP/GeoSite defaults. |
| `7c407b9a` | Adapt | Keep log clearing in the new Logs menu beside export and log-level controls; preserve monotonic record revisions. |
| `986e3149` | Keep | Preserve the fork's bundled Geo databases. |
| `d45f82de` | Omit old sync commit | Its old baseline notes and table fixture no longer apply. Reapply the still-needed currentAppLocalizations About fixture fix in the new compatibility commit. |
| `74c7f470` | Keep | Preserve IP/ISP lookup-source selection and cache invalidation. Regenerate AppSettingProps and providers against the current models. |

## UI and data behavior

The Requests page keeps upstream's segments, conditions, minute groups,
connection timelines, app icons and split/nested details. Sorting offers time,
speeds, amounts, total traffic, target, process, network, rule, exit and duration,
with ascending/descending controls. Equal keys keep newest-first order.

An explicit sort computes only detached keys and indexes. Superseded results
and results after disposal are discarded. A pointer over a following desktop
list holds its ordering while traffic continues updating. Filtering and clearing
remove stale row keys before a pending sort completes.

Clearing request history preserves active connections and final known traffic.
It replaces the log lineage so an older poll cannot restore cleared history.
DNS and log clearing empty held page records and preserve later arrivals.

## Verification before the first branch push

- Root and Prism UI static analysis: no issues.
- Format check: 1,159 Dart files, unchanged.
- Focused Flutter tests: 132 sorting/history/routing/release checks, 115 UI
  interaction checks, and 516 Geo/TUN/Core-protocol/IP checks passed.
- Six platform-conditional checks were skipped on Windows: four Unix core-stat
  checks replaced by the Helper probe here, and two macOS authorization checks.
- Lint/localization/Flutter-pin checks: 36 passed directly. Seven Windows path
  failures exactly match an unmodified upstream v0.9.5 source snapshot, at the
  same 16 locations. Temporary path-normalized copies pass all 12 cases in
  those seven files. Repository tests and allowlists are unchanged.
- Issue-gate checks: seven passed using LF copies of Windows-checkout inputs.
- Release-note and release-template script suites passed with LF copies.
- Both Git-hook suites passed with LF fixtures, native jq in binary mode and
  temporary Git line-ending settings. No global Git settings were changed.
- gofmt syntax/format checks passed for the three fork wrapper files and three
  patched tunnel files. Go/Rust execution, platform builds, native-library
  tests, full Flutter suites and coverage remain in remote CI.
- Source models/providers and ARB files were regenerated with both native build
  hooks disabled. Both hooks are restored to true before committing.

Remote branch and tagged workflows are authoritative for native compatibility,
complete suites, coverage and release packaging. Their run links are reported
with the published release; no local application build or launch was performed.

## CI follow-up

The first branch run passed all three desktop builds, Go, Rust, Android and
plugin checks. The full Dart suite found two new upstream workflow assertions
requiring Telegram, Homebrew, F-Droid publishing and prerelease pruning, which
the fork deliberately omits. Adapt those assertions to require all build/check
dependencies, validated release assets and GitHub-only publication. The shared
publishing-library unit tests remain intact.

The shipped v100.0.18 updater downloads Android APKs and installed Windows
setups under the FlClash-dev-VERSION-* names, verified by the matching prefixed
SHA256SUMS file. Preserve those five byte-identical aliases and their checksum
list when publishing the new unprefixed packages, alongside the three older
Android ABI-name aliases. Script fixtures verify copied bytes and checksums,
reject missing artifacts and empty manifests, and exclude non-updater packages.
