# Fork parity and defect verification

## Revisions and scope

- Reviewed mobile baseline: `7294b7b653c6f4636e41d2c81214e01ebff248f0`.
- Pinned upstream comparison: `e1a7587c1ebf6a9cfa90f4fba1017cfec324594e`.
- Merge base: `a63fee331bfec266d577d1545088457579a7042b`.
- This implementation follows that baseline; its commit is discoverable through this report's Git history. No upstream
  merge, dependency upgrade, backend deployment, or store submission is included.
- [Inventory](fork-parity-inventory.csv): all 611 paths changed between merge base
  and reviewed baseline, including assets, native configuration, tests, docs and CI.
  Last-touch hashes locate evidence; they do not mean every line came from that commit.

The inventory is a file-level index, not a claim that a static review proves every
possible runtime behavior. Grouped review below distinguishes approved differences
from defects and inherited code. Current upstream's unmerged changes are not fork
regressions. Local Claude audit inputs remain untracked and are not part of this report.

## Required differences and dispositions

The user-approved implementation plan in this task authorizes A–F below. Existing
requirements are recorded in `docs/mobile-app-release-gate-fix-plan.md`, the About
website plan, the branding/store records, and the associated implementation commits.
The fork policy in `AGENTS.md` remains the boundary for future changes.

| Area | Disposition and evidence | Relevant coverage |
| --- | --- | --- |
| Phone login and session bootstrap | Retain OTP-issued JMAP credentials, origin validation, rollback on partial writes, session-loading state, and disposed-controller guards. Required by NumberInbox login; review baseline commits `9f94cc7af`, `942ff9e51`, `f05b6a352`, `6af2bda8a`. Fix normalization in A. | Welcome controller/view/navigation and credential-persistence tests. |
| Phone recipients and contacts | Retain explicit country resolution, ordinary email recipients, contact permission/limited-access support, deduplication, immediate state refresh and constrained input layout (`bab633a9e`, `08d84a2d6`). Search/recovery callers adapt to the same contact argument type; they do not gain a different search algorithm. | Composer, contact, recipient-identity and parser tests. |
| Account deletion and re-login | Retain signed-in confirmation, account-scoped pending state, request idempotency and teardown (`7e9bd17d3`, `ba396b884`, `4dc8a4021`). Fix national-number matching in A. | Deletion page/client and re-login lifecycle tests. |
| Push registration and receive | Retain platform registration instead of unsupported JMAP registration, generic text, installation identity, account isolation, dedup and completion ordering. Release plan M3–M6; `97f542590`, `6d393ffb3`, `3385cc0e3`, `cab03063d`. Correct logout in B and socket compatibility in C/D. | Push model, registration, receiver, service, pipeline and account-isolation tests. |
| Branding, startup and system bars | Retain palette/gradient, identities, icons, white native/Flutter/web splash, preload/handoff and removal of fixed startup delay. User explicitly requested these differences (`257a511c0`, `75a45ee64`, `2a5362a23`, `ac6088127`). No new artwork/layout changes here. | Branding/asset, splash layout, primary-action and light-system-UI tests. Capture-dependent splash checks remain opt-in. |
| Native application configuration | Retain NumberInbox package/bundle IDs, matching method channels, Firebase/APNs configuration, keychain/app-group identity, sharing, privacy manifests and signing. These support an independently distributed app. Keep existing mail/share functionality. | Platform contract tests and native compilation; physical APNs remains separate. |
| About and website | Retain the user-approved branded website screen and existing source-access website policy (`7294b7b65`, `30beab4ab`); do not revisit license UX in this change. | About widget/website-link tests. |
| Shared navigation and ecosystem lifecycle | Retain OTP/deletion redirect safety and avoiding updates after controller disposal (`cfc2d72c7`, `f2f7a93fd`, `6e795f873`, `dc35622c2`). Existing ecosystem feature behavior is retained; no observer framework added. | Navigation, composer disposal and ecosystem lifecycle tests. |
| Connectivity | Retain stale-startup-probe protection (`cec2c1392`); it prevents an older disconnected probe overriding a newer stream result. It is a documented fork bug correction, not an upstream feature removal. | Network connection controller tests. |
| Cache persistence | Retain existing encrypted credentials and durable writes needed for OTP persistence and release-plan dedup. Preserve inherited IndexedDB recovery (`285e926a0`, ADR 0104) and close-generation checks. No new at-rest mail encryption. Restore upstream initialization in F. | Hive encryption, recovery and persistence; push durability tests. |
| Logging and inbound credential links | Retain secret redaction and refusal of credential-bearing auto-login links; OTP is the explicitly selected login mechanism. Do not restore secret logging merely to match upstream (`7629fa3e6`, `6af2bda8a`, `9b1f6caed`). | Deep-link refusal/redaction and authentication tests. |
| Dependencies/toolchain | Retain phone parser dependency and reproducible compatibility pins. Test libraries remain dev dependencies. No dependency change made here. | Existing resolution and build checks. |
| Localization and shared UI | Retain NumberInbox naming and approved English-first fork screens. Preserve inherited translations and non-brand UI semantics; do not translate/rewrite features as part of this review. | Existing localization/UI tests and unchanged diagnostics baseline. |
| Public CI and test harness | Retain generic tests, platform-selection guard, sanitized fixture reset failures and private-release separation (`cb255ff3b`, `962b3a35c`, `0d03de41b`). Do not expose disposable backend topology or credentials in new artifacts. | Workflow policy/script tests and existing public test commands. |

No new unrelated feature addition or removal was selected during this grouped review.
Unused helpers, broad flush performance claims and localization debt are not proved
product defects; removing them without evidence would expand scope. The device ID
helper is an existing OTP integration, distinct from the persisted push-install ID;
this work does not redesign its semantics. This report does not certify every such
choice optimal or substitute for device and private integration testing.

An older planning note incorrectly attributed the NumberInbox Thailand country
fallback to upstream. That attribution is corrected; picker defaults are unchanged.

## TDD evidence

Commands below ran with existing resolved dependencies; no package upgrade was needed.
Workspace mocks were regenerated with `dart run build_runner build --workspace`.
A first attempt without `--workspace` failed on the multi-package build graph; the
repository's workspace mode succeeded. No hand-maintained generated mock is required.

| Slice | RED evidence against unchanged production behavior | GREEN implementation and coverage |
| --- | --- | --- |
| A: phone | Country regression run: Thai `066 123 4567` became `+661234567`; Indian national input failed validity. | Strict selected-region parser; consistent canonical OTP number; deletion confirmation. New tests cover real Thai/Indian examples, OTP edits, invalid inputs and Thai deletion. Existing recipient tests preserve explicit-country behavior. |
| B: logout | Revised existing BaseController tests failed: actual events stopped after `revoke`, whereas expected local cleanup and success were absent. | Five-second overall revoke deadline, request cancellation, best-effort local logout, bounded API options. Tests cover success ordering, offline/missing bindings, hanging lookup/HTTP stream, cancellation, late completion, and no late request after credential lookup. A real local HTTP test covers cancellation without retry. |
| C: socket auth | Interceptor RED run failed on bare Base64 vs complete `Basic` header and on stale Basic getter after OIDC. Earlier same-baseline real-wire audit probe also received 401 without the scheme. | Complete Basic getter and real local WebSocket upgrade test with actual interceptor, Unicode/clear/OIDC coverage. TLS restrictions retained. |
| D: browser | Actual Chrome request failed in `IOHttpClientAdapter` with `Unsupported operation: Platform._version` in debug and production configurations. | Four actual Chrome checks passed: HTTP for both configurations, ticket WebSocket, and typed no-ticket failure. Conditional native connector and ten-second establishment deadline; no browser credential workaround. |
| E: TLS | Disposable self-signed HTTPS server returned `ok` through the debug trust-all client when the test required rejection; production rejected it. | Normal platform validation. Real TLS tests require a handshake failure for an untrusted certificate and success with an explicitly trusted fixture root. |
| F: key initialization | Revised retained-store test expected a replacement key, received null under the fork's lockout gate. | Upstream missing-key generation restored; existing keys reused and never logged. Disposable real-Hive test records the installed library's empty-box recovery with a replacement key. Encrypted-box validation retained. |

Focused additional coverage supplements the primary RED cases; not every new assertion
was separately run RED. Logs are local temporary verification artifacts, not shipped
with the application. No real credentials or user data were used in these probes.

## Verification and remaining release gates

Local verification completed on 27 October 2026. Results below apply to the implementation following the reviewed baseline. Verification preceded the implementation commit; publication and exact-revision private CI remain separate gates. A local build or
unit test is not a substitute for the exact-revision private Android gate.

- Static analysis: 62 informational diagnostics, zero warnings/errors; same count as
  the reviewed baseline. The command remains nonzero due to existing infos.
- Workspace code generation: passed, 90 outputs written; generated mocks are ignored.
- Browser networking: 4 real Chrome checks passed against the loopback-only fixture.
- Logout/API/TLS focused run: 46 checks passed before the final supplemental tests.
- Root VM command `flutter test --no-pub --reporter expanded test tmail-mcp/test`: 4,374 passed; one existing capture-dependent splash check skipped. The two supplemental socket assertions added after discovery also passed in the focused seven-check socket run.
- Android debug build, Java 21: passed.
- `flutter build web --no-pub`: passed; existing WASM dry-run compatibility warnings remain. This was a normal web build, not a WASM certification.
- `flutter build ios --simulator --debug --no-pub`: passed, unsigned simulator build.
- Workspace VM tests, each run from its package directory: 2,054 passed total
  (core 1,518; model 164; contact 1; forward 12; rule_filter 3; fcm 2;
  email_recovery 3; server_settings 28; scribe 25; labels 25; workplace 273).
  Core retains one documented sanitizer-limitation skip. Cozy has no test directory.
- Chrome-only suites: root 30 passed (including all four real network checks),
  core 90 passed. No browser network probe was skipped in this run.
- Supplemental socket suite: 7 passed, including real ten-second handshake timeout
  and ticket-error sanitization. Final BaseController suite: 41 passed, including
  absent/unreadable registration entries and cancellation/late completion.
- Workflow policy: `node --test scripts/tests/workflow-policy.test.mjs`, 8 passed.
- Python network fixture compiled successfully using a temporary bytecode-cache path.
- `git diff --check`: passed.
- Controlled backend/device OTP, send/receive, deletion/recreation and physical APNs:
  not certified by mocked/local network tests. No production account was exercised.
- Private CI: the last existing private gate was blocked before Android execution;
  it is not a pass for these changes. No workflow was dispatched against the old SHA
  and represented as validation of the new work. The current private validator requires
  a published mobile SHA on master with green public CI. Publish/merge this reviewed
  change and resolve hosted-runner billing before running that exact-revision gate.
  No production test or store upload was initiated.

### Reproduce the opt-in network checks

Start `python3 scripts/testing/network-fixture.py`; it prints a loopback port.
In another terminal run:

```sh
flutter test --no-pub --platform chrome \
  --dart-define=NETWORK_FIXTURE_URL=http://127.0.0.1:<printed-port> \
  test/main/bindings/network/network_browser_test.dart
flutter test --no-pub test/main/bindings/network/network_tls_test.dart
```

Stop the fixture afterward. It has no access to backend accounts or configuration.
The browser suite requires this fixture explicitly; it is not silently counted as
application integration coverage. The existing CI runner does not start the fixture
by default; its opt-in skips must not be reported as a successful network probe.

### Lost-key compatibility limitation

Generating a replacement key cannot decrypt old locally encrypted data. The installed
Hive version can reopen the affected box empty. This explicitly follows the approved
upstream-parity decision; it is not a guarantee of recovering local drafts/credentials.
There is no new reset UI, plaintext fallback or server-side deletion.


### Commands and failures recorded during TDD

| Command / phase | Observed outcome |
| --- | --- |
| `flutter test --no-pub test/features/numberinbox/country_test.dart test/features/caching/hive_cache_config_encryption_key_test.dart` before implementation | 14 passed, 4 failed: Indian validity, Thai validity/canonicalization and absent replacement key. |
| `flutter test --no-pub --reporter expanded test/features/login/data/network/interceptors/authorization_interceptors_test.dart test/features/base/base_controller_test.dart` with revised expectations, before implementation | 34 passed, 6 failed: header/OIDC getter and offline logout expectations. |
| Browser fixture command above, before adapter correction | Both debug/production HTTP checks failed with native `Platform._version` access. |
| TLS fixture before trust-all removal | Debug returned `ok` instead of rejecting the untrusted certificate; production rejection passed. |
| Focused feature regressions | Initial runs caught compile fixes and stale test event lists; subsequent runs passed. These intermediate failures were not counted as defect RED evidence. |
| Root VM suite before certificate-fixture correction | 4,358 passed, two new trusted-fixture checks failed, one existing skip. No production TLS bypass was added to resolve this. |
| Corrected TLS fixture | Proper disposable CA and signed server leaf passed positive/negative checks in both modes. CA-as-leaf fixtures were rejected by this runtime; fixture generation was corrected. |
| Workspace tests initially launched together from the root | One core relative-file fixture failed and a nonexistent cozy test path was selected. Correct per-package CI working directories and discovery were used for the successful runs above. |

Transient logs remain in local temporary storage, not the public repository. The final
analysis, full root/package results, browser results and build results are summarized
above so reviewers do not need access to private operational artifacts.

## Focused audit follow-ups (2026-10-27)

Starting revision: `f2aba326970d55fa943be8578c7ab590fe568da7`.
The pinned upstream comparison remains
`e1a7587c1ebf6a9cfa90f4fba1017cfec324594e`, with merge base
`a63fee331bfec266d577d1545088457579a7042b`. These follow-ups implement the
user-approved three-slice plan, not an upstream merge. The local Claude review
and its verification were reconciled with the dispositions below; neither local
input document is published by this change.

### Changes and upstream boundary

- **JMAP cleanup:** searches for `buildBasicAuthHeader`, `isCredentialError`, and
  `sessionEndpoint` across application/shared code, scripts, integration tests and
  unit tests found definitions and test consumers only. Removed those fork-owned
  helpers, `_jmapPath`, and the unused conversion import. Retained
  `decodeBasicAuth`, strict trusted-origin checks, local-origin injection and the
  OTP response contract. Only helper-specific assertions were removed; origin,
  credential-versus-access-token, persistence and rollback tests remain.
- **Deep-link correction:** incoming names were lowercased but the refusal set
  contained mixed-case `registrationUrl` and `jmapUrl`. Changed only those two
  constants to lowercase. The 64-case behavioral matrix exercises each individual
  name, distinct original/lower/mixed spellings, empty/sentinel values, and both
  signed-in states. It checks rejected/empty parsed credentials, no sign-in or
  credential mutation, no account-switch callback, and secret-safe diagnostics.
  Existing bare-link, harmless metadata and constructed-record guards remain.
- **Push cleanup:** removed the fork-only mapper and its logging call, the
  map-shape-only test, and the private dispatch argument used only by that log.
  Corrected the obsolete dispatch comment. Real listener calls, generated state,
  awaited completion, dedup, shared pending fields and legacy paths are unchanged.
  Strengthened the existing incomplete-processing test with a controllable future:
  the callback stays pending and delivery remains unrecorded until processing
  finishes; failure still permits retry. Ran this against the original push
  implementation before restoring and checking the cleanup.

Comparison with the pinned upstream confirms the removed helpers/mapper and
credential-refusal set are fork additions. This change does not alter inherited
models, handlers, interactors, public callback signatures or legacy dispatch.
The upstream deep-link infrastructure remains, even where OTP guards make its
credential sign-in branch unreachable. No networking, API, dependency, artwork,
notification-content, cache or native configuration change is included.

### TDD and characterization evidence

Commands use the already prepared dependency/generated-source checkout; no package
update or substitute `flutter pub get` was needed. Temporary logs contain synthetic
fixture data and remain outside the repository.

| Phase and command | Result |
| --- | --- |
| Before production edits: `flutter test --no-pub --reporter expanded test/features/numberinbox/jmap_session_manager_test.dart test/features/login/jmap_session_test.dart test/features/starting_page/twake_welcome_controller_test.dart test/main/deep_links test/features/push_notification/presentation/controller/fcm_message_controller_test.dart` | 152 passed. Existing JMAP/OTP, persistence/rollback, deep-link and push behavior characterized GREEN. |
| Before push cleanup: `flutter test --no-pub --reporter expanded test/features/push_notification/presentation/listener/email_change_listener_test.dart test/features/push_notification/presentation/controller/push_base_controller_test.dart` | 21 passed. Includes foreground state/refresh, background processing, failure/retry, overlapping account context and inherited legacy dispatch. |
| RED: `flutter test --no-pub --reporter expanded test/main/deep_links/credential_parameter_matching_test.dart` with production code unchanged | 40 passed, 24 failed: expected `credentialParametersRejected == true`, got false for the URL parameter names. An earlier test-binding setup failure was corrected first and is not counted as defect evidence. |
| GREEN: `flutter test --no-pub --reporter expanded test/main/deep_links` after the two-constant correction | 105 passed, including all 64 new cases and existing guards. |
| Characterization of added pending-callback assertion against original push production code: `flutter test --no-pub --reporter expanded test/features/push_notification/presentation/controller/fcm_message_controller_test.dart` | 28 passed, excluding the removed map-shape-only test. |
| Post-cleanup focused regressions: `flutter test --no-pub --reporter expanded test/features/numberinbox/jmap_session_manager_test.dart test/features/login/jmap_session_test.dart test/features/starting_page/twake_welcome_controller_test.dart test/main/deep_links test/features/push_notification` | 334 passed. Includes native WebSocket establishment/timeout tests. The full suite below additionally reruns the strengthened callback test after cleanup. |

The unused-code slices intentionally use characterize → GREEN → remove → GREEN;
there is no artificial behavioral RED or source-text test for dead-code deletion.

### Complete recommendation dispositions

| Recommendation | Disposition |
| --- | --- |
| Phone normalization | Fixed in the starting revision; retain selected-country, OTP snapshot and deletion/recipient tests. No locale guessing added. |
| Offline logout and timeouts | Fixed in the starting revision; retain deadline, cancellation, cleanup and account-isolation coverage. Do not treat every 404 as successful revocation. |
| Browser HTTP and WebSockets | Fixed in the starting revision. Retain actual Chrome fixture checks; opt-in browser checks are not ordinary VM coverage. |
| Debug certificate bypass | Already removed; retain real TLS rejection/trusted-certificate checks. |
| Missing encryption key | Upstream initialization restored; retain secret-safe logging. A replacement key cannot recover data encrypted with a lost key, as documented above. No recovery feature added. |
| Rich iOS previews | Excluded: generic private notifications are intentional. Physical-device delivery/tap validation is still a release gate. |
| Reduce cache flushes | Deferred until measured, with credential, deletion-state and dedup durability tests. No proven performance regression justifies dropping durable writes here. |
| Move test dependencies | No change: integration_test and yaml are already dev dependencies. |
| Remove inherited deep-link infrastructure | Excluded to minimize upstream conflict. Preserve models/callbacks and OTP-only refusal guards; fix only inconsistent matching. |
| Simplify shared push state | Separate concurrency-focused follow-up. Remove only the proved logging-only mapper here. |
| One global API/auth client | Excluded: a broad auth interceptor could attach mailbox credentials to public OTP requests. Shared finite timeouts already exist. |
| Consolidate parser entrypoints | Deferred: strict selected-country recipients and permissive legacy paths have different policies. The faulty country builder was already corrected. |
| Remove OTP accessToken | Deferred API-contract change. It is not used as the JMAP password; retain contract/credential-mapping tests. |
| Translate fork screens | Deferred under the approved English-first policy. Preserve inherited translations. |
| Remove branding/asset tests | Excluded: these protect demonstrated launcher, clipping, splash and branding defects. |
| Shorten comments | Only obsolete comments in touched code changed. No broad style rewrite. |
| Merge upstream keyboard/security changes | Separate compatibility assessment and integration plan. Distinguish runtime fixes (including TF-4980) from sanitizer test infrastructure and known-XSS-gap tracking; tracking a gap does not fix it. No merge, cherry-pick or dependency upgrade here. |
| Delete .git/ni-fork.bundle | Optional local metadata housekeeping; left untouched and not published in a normal push. |

### Final verification and release limits

Final verification results and focused source revisions are recorded below.
Exact-revision private Android CI and physical-device notification
checks remain release gates. This local cleanup does not authorize deployment or
store submission, and no such action was initiated.

- Full root unit/widget command:
  `flutter test --no-pub --reporter expanded test tmail-mcp/test` — **4,434 passed,
  one existing opt-in cold-start capture skip**, zero failures.
- Final push-controller command:
  `flutter test --no-pub --reporter expanded test/features/push_notification/presentation/controller/fcm_message_controller_test.dart`
  — **28 passed**, including the strengthened pending-callback assertion after cleanup.
- `git diff --check` passed. Caller searches after cleanup found no references to
  the deleted helpers/mapper in application code, scripts or tests.
- Browser runtime checks, native builds, CI and device tests were not rerun for
  this isolated cleanup. Existing browser/TLS tests remain intact; previous
  browser/build evidence above belongs to the earlier implementation, not this
  revision. Exact-source private CI and real iOS delivery/tap checks are still
  outstanding external gates.

- `flutter analyze --no-pub` — **62 existing informational diagnostics, zero
  warnings/errors**, matching the starting revision's recorded baseline. The first
  cleanup run found one unused mapper-only import; it was removed and analysis
  rerun. Its nonzero exit is due to the pre-existing infos, not a new diagnostic.
- Behavioral fix commit: `78f489bb9cbc1108ac62593b9cb53a8e054444ca` (`fix: reject deep-link credential names consistently`).
- Cleanup commit: `31f75a01313bb356384b4d8b9f58f4276bb680b3` (`refactor: remove unused fork session and push helpers`).
  These source revisions contain the code exercised above; the report's own final
  documentation revision is discoverable through Git history. No implementation
  MR was opened or updated, so no MR review-request comment was needed.
