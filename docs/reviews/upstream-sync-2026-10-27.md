# Full upstream sync verification — 2026-10-27

## Source and pending merge

- Fork starting commit: `f9ae1b3bc54c516e3a411473ffe9036197a30e9d` (includes the three audit-follow-up commits).
- Upstream master verified by `ls-remote` and fetched explicitly:
  `9a89aabdf3d05214a676eea3745972e1f0f8b5a9`.
- Merge base: `a63fee331bfec266d577d1545088457579a7042b`.
- Incoming upstream commits: 88.
- Review branch: `codex/upstream-sync-20261027`.
- Merge was invoked with `--no-commit --no-ff`. User approval is required before
  committing. No push, release tag, CI dispatch, deployment or store upload is
  included. The untracked local Claude audit documents are left untouched.

The earlier all-branches fetch encountered a remote-ref update race with the
successful bounded master-only fetch. The merged SHA and MERGE_HEAD were checked
explicitly; this does not substitute an older cached upstream tip.

## Conflict resolutions and required fork behavior

Nine paths conflicted. Resolutions combine compatible changes rather than choosing
one whole side of each conflict:

| Path | Resolution |
| --- | --- |
| `.github/workflows/analyze-test.yaml` | Retain package discovery, Flutter install retry/fallback, JavaScript checks and reporting; adopt upstream action SHA pins. |
| `.github/workflows/image-sentry.yaml` | Retain web E2E dependency, GHCR-only publication and existing protected environment. Adopt action pins and upstream security-scan integration. Do not restore Docker Hub credentials/publication. |
| `.github/workflows/image.yaml` | Retain GHCR-only images; adopt action pins without restoring Docker Hub login. |
| `.github/workflows/release-web-manual.yaml` | Retain validated tag/source handling and GHCR-only publication; adopt pinned actions. |
| `.github/workflows/patrol-integration-test.yaml` | Keep deleted. NumberInbox Android backend integration and store upload orchestration remain private; the public James/web gate remains available. |
| `.gitignore` | Preserve local Firebase/screenshot exclusions and add upstream local security-review exclusion. |
| `AGENTS.md` | Keep the fork policy and prebuild requirement; also retain upstream security-review instructions. |
| `MainActivity.kt` | Combine upstream focused-WebView keyboard dispatch with NumberInbox Android 12+ immediate splash removal, both activity lifecycle overloads, notification grouping and selection handles. |
| `pubspec.yaml` | Keep NumberInbox `1.0.0+2`; bring in upstream dependencies through the merged lockfile, with the design-library pin explained below. |

Automatic merges were also inspected at the composer controller/recipient widget,
mailbox controller, localization and session fixture boundaries. NumberInbox's
phone recipients, validation, constrained layout and refresh fixes coexist with
upstream's always-present recipient input and tap-to-focus behavior. OTP login,
strict origin validation, logout/account isolation, generic notifications, deletion,
brand gradients/assets, native identities and white splash styling remain. The
new SaaS DNS send check defaults to allowed when that capability is absent, so it
does not require a NumberInbox/Stalwart SaaS capability.

Upstream changes include Android keyboard and mailto CC/BCC corrections, sharing
cache-path hardening, thread/search/composer and workplace fixes, HTML document
builder/display-rule coverage, security tooling, ADRs and CI action pins. Imported
security tests and known-gap tracking are not represented as fixes for every XSS
case.

## Small integration adaptations

1. The new upstream HTML display workflow called `scripts/setup-firebase.sh`,
   previously removed from this fork. Its pure HTML tests do not need Firebase.
   Removed those two setup steps and added a public workflow-policy regression
   check. No backend details, test credentials or new secrets are added.
2. Prebuild initially resolved the floating design-library master to 0.4.0, beyond
   upstream's lockfile. Pin `linagora_design_flutter` to upstream's exact
   `38b7be01cdd11e473be6249c4d5ac2f5e8f7cf34` revision (0.3.4), and regenerate
   through `./scripts/prebuild.sh`. This avoids an unrelated UI-library upgrade.
   Keep upstream's sharing-library revision
   `68e961c4a5044c811f54c715fb4736ccc7f04033`.
3. Preserve inherited generated-template/snapshot whitespace. A whole-merge
   `git diff HEAD --check` reports upstream template/HTML fixture whitespace;
   stripping it would change locked documents. Conflict-resolution/workflow/pin
   diffs are checked separately for newly introduced whitespace errors.

## Verification

Dependency preparation uses `./scripts/prebuild.sh` exclusively. Preliminary root
and workspace runs passed before the dependency pin; final runs below supersede
those results and exercise the pinned dependency graph.

Final command results are recorded below. Unit/widget and browser tests
are local tests; they do not replace private backend integration or store gates.

## Known upstream limitations and external gates

- Upstream explicitly skips its tracked `#4956` reply/forward-with-unloaded-original
  sanitizer gap. This merge retains the upstream behavior and gap tracking; it
  does not resolve that security issue.
- Other inherited HTML skips include bare CSS-like text stripped by the sanitizer
  and draft-signature transformer idempotence. Record skip counts with results.
- The existing cold-start frame capture test requires supplied device captures;
  an opt-in skip is not a verified stationary handoff on every device.
- The inherited private security-report path is optional and requires explicit
  report/LLM secrets and configuration. No such secrets are configured or report
  workflow dispatched here. Upstream's optional GitLab recipient lookup targets
  LINAGORA infrastructure; do not configure it for NumberInbox without a separate
  reporting-integration decision.
- Exact-revision public/private CI cannot validate an uncommitted local merge.
  After approval and commit, run public checks and the private 16-target Android
  gate on that commit. Physical iOS push delivery/tap checks remain separate.

### Completed final checks

| Check | Command / result |
| --- | --- |
| Root unit/widget | `flutter test --no-pub --reporter expanded test tmail-mcp/test`: **4,530 passed**, one existing capture-dependent skip. |
| Workspace VM | From each package directory, `flutter test --no-pub --exclude-tags display,mutation --reporter expanded`: **3,107 passed** across the 11 packages with tests; core has four inherited known-gap skips. No cozy test directory exists. |
| Browser root | All six `@TestOn('chrome')` files with `flutter test --no-pub --platform chrome`, including the opt-in loopback HTTP/WebSocket fixture: **30 passed**, no skips. |
| Browser core | All 14 Chrome files: **1,500 passed**, 58 declared skips (56 known display limitations plus two mutation libraries run separately below). |
| Static analysis | `flutter analyze --no-pub`: **75 infos, zero warnings/errors**. Thirteen additional infos are in unchanged upstream HTML viewer/registry files; baseline had 62. Kept upstream code rather than adding unrelated lint-only divergence. |
| JavaScript/public workflow policy | `node --test`: **10 passed**, including the added Firebase-setup guard. |
| YAML and shell | All workflow YAML parsed with duplicate-key detection and local action/workflow paths checked. `bash -n` passed for prebuild/test/security-review and security shell scripts. GitHub-specific hosted validation remains CI work. |
| Android build | Java 21 `flutter build apk --debug --no-pub`: passed. |
| Android keyboard | `:app:connectedDebugAndroidTest` filtered to `com.linagora.android.tmail.WebViewKeyboardTest`: **7 passed, zero skips/failures/errors**, verified in instrumentation XML. Pixel 7 emulator, Android 17 image; this is not the private API-30 mail suite. |
| iOS simulator build | `flutter build ios --simulator --debug --no-pub`: passed. |

The first browser launch overlapped VM startup and hit Flutter's shared test-asset
cleanup race. Stopped that attempt and its local fixture/compiler processes; the
successful browser runs above ran after VM completion. This infrastructure retry
was not counted as an application regression or hidden with a test skip.

Removed only the synthetic `core/applicationDocumentsPath/test_file` left by the
inherited file-utils test after checking its `Hello, World!` contents. Discarded
only generated ARB timestamp churn while preserving all merged localization text.

- HTML mutation proofs: all Chrome files with `--tags mutation --run-skipped` —
  **13 passed**, no skips. These deliberately break mechanisms in the test and
  require detected violations; their diagnostic violations are expected proof,
  not production-test failures.
- Browser skip breakdown: 10 web wide-content cases, 18 iOS EML previewer cases,
  21 attachment preview cases, six print responsiveness cases and one print
  direction case are upstream-declared limitations. Two skipped mutation
  libraries in the ordinary discovery run were explicitly executed above.

- Web release: `flutter build web --release --no-pub` — **passed**. The ordinary
  JavaScript release target builds; Flutter also printed WASM compatibility
  dry-run warnings. No WASM target migration is included.
- Final conflict-resolution/workflow/pin/report whitespace check passed. The
  full upstream import still contains inherited locked-template whitespace as
  explained above; it was not reformatted.
- Stopped the local emulator started for the native tests. Synthetic browser
  fixture processes were stopped by the runner. No runtime credentials, APKs,
  simulator apps, generated reports or diagnostic logs are staged for publication.
- The source remains an **uncommitted merge**. HEAD is the original fork commit,
  MERGE_HEAD is the upstream SHA above, and user approval is still required.

For subsequent syncs, update `integration_test/UPSTREAM_BASE` to the full SHA actually merged and run the drift check described in `integration_test/FORK.md`.
