# Platform release gate fixes — TDD handoff

Date: 2026-10-19. Status: planned; implementation and acceptance are unverified.
Owner: platform agent working in `numberinbox/platform`.
Companion: [Mobile app handoff](./mobile-app-release-gate-fix-plan.md).

## 1. Outcome and current evidence

Close the seven Android release-gate findings, prove the private smoke flow actually
runs, and supply the platform half of the existing push B5 acceptance gate.

Planning baseline: platform HEAD `cf8e16f`; the working tree already contains edits to
Compose, smoke shell scripts, private Patrol drivers and release-gate tests. Preserve
and inspect those edits before implementation. A review observed green committed CI
and Backup runs, plus 84 script tests with one macOS skip. Those results did not prove
the Android flow or the uncommitted fixes. Revalidate the final candidate SHA.

The seed-mail `EmailMessage` import was corrected during review. Keep that fix and
add runtime coverage; it is not a new open implementation ticket. The push Java
implementation was previously reviewed; do not rewrite B1–B4 to repair a test runner.

All seven reviewed defects are in this private repository. Public application
selectors and mobile push behavior belong to the companion agent. This plan stays
private; it is not a document to copy into the public app repository.

Read repository `AGENTS.md`, its required product/policy documents,
[private release design](./private-mobile-ci-release-plan.md),
[API contracts](./09-api-contracts.md), and [push plan](./24-fcm-push-plan.md).
Follow repository action approvals, full verification, exact-SHA CI and deployment
rules. Billing, unrelated workers, mail-storage redesign and backup changes are
outside this fix set.

## 2. Ownership and acceptance mapping

| Review finding | Platform work | Mobile dependency | Required evidence |
|----------------|---------------|-------------------|-------------------|
| R1: Java 25 leaks into Android | P1: restore Java 21 after backend verification | Retain the compatible app wrapper | Ordered workflow test and runtime Java/Gradle versions |
| R2: invalid generated TH numbers | P2: correct generator and private-driver validation | M1: public country validation tests | Generated values pass the app validator |
| R3: encoded E.164 yields HTTP 403 | P3: standard URL query parsing | None; driver keeps correct URL encoding | Encoded-plus HTTP request succeeds; foreign number fails |
| R4: helper resolves Compose in mobile cwd | P4: absolute Compose/env paths | None | Helper reads the disposable challenge from another cwd |
| R5: ADB reverse removed between stages | P5: correct helper/forward lifecycle | None | Three-stage command trace and real deletion-stage OTP |
| R6: mail reader uses composer close key | P6: update private driver | M2: publish reader-back selector | Read mail, return, compose/send through real UI |
| R7: readiness ignores overrides | P7: use configured project and PostgreSQL host port | None | Non-default project/port tests fail and pass correctly |

P8 combines runner acceptance. P9 supplies existing push B5 proof. Completing P1–P8
closes this review's harness fixes; calling push release-ready additionally requires
P9 and the companion mobile acceptance gates.

## 3. Shared contracts — agree before integration

### UI selectors

Existing public controls retain their current names: `otp_country_picker`,
`country_search`, `country_TH`, `otp_phone_field`, `otp_send_cta`, `otp_code_field`,
`otp_verify_cta`, `otp_error`, `composeEmailButton`, `sendEmailButton`,
`closeComposerButton`, `userAvatar`, `setting_delete_account`,
`deletion_phone_field`, `deletion_submit`, and `emptyThreadView`.

The mobile agent adds `UiKeys.emailReaderBackButton = 'email_reader_back_button'`
to the actual Android mail-reader back control. Platform uses that key only after
mobile M2 is tested and committed. `closeComposerButton` remains composer-only.
No user-facing copy or production navigation changes are needed for this selector.

### OTP and disposable environment

- Each account fixture is a canonical E.164 derived from TH country validation.
  Generate seven decimal suffix digits after `+6695` / `+6698`, with leading zeroes
  preserved. Independent accounts use distinct values within the disposable stack.
- Drivers submit the same local representation the app uses: replace leading `+66`
  with `0`, then assert the TH validator normalizes it back to the intended E.164.
- The private helper serves one allowed number per stage, bound to runner loopback.
  Dart continues using `Uri.encodeComponent(e164)`. The server decodes before comparing.
- Valkey records remain `v1|<challengeId>|o|<six-digit-code>`; no raw-code fallback.
- Production/reviewer accounts and real SMS credentials never enter the smoke job.
  Production mail-flow checks continue following the repository's fixed test-mailbox
  rule; generated smoke identities belong only to the isolated disposable stack.

### Push

Keep the existing Basic-auth registration API and version-1 data contract in
`docs/09-api-contracts.md`. `POST /v1/fcm-registrations` accepts
`{token, deviceClientId, type:"email"}` and returns `202` with `registrationId` and
server-owned `expiresAt`. `DELETE /v1/fcm-registrations/{registrationId}` returns
non-disclosing `204`. Authenticate with the current mailbox credential.
Data values are strings: `schemaVersion`, `eventType`,
`deliveryId`, `stalwartAccountId`, `emailId`. Notification title/body are generic.
`emailId` is not a JMAP state token. Native account identity is authoritative.

The ordinary OTP/read/send/delete smoke deliberately has FCM disabled. It cannot
prove push delivery. P9 adds a distinct, explicit push acceptance gate against the
same validated platform/mobile SHAs.

## 4. TDD execution rule

For each ticket: add a failing behavior test, record the failure, make the smallest
fix, then refactor with tests green. A new test that already passes may be useful
characterization, but does not establish that it detects the original defect.
Record commands and RED/GREEN results; never invent a historical RED run.

Extend `scripts/tests/test_mobile_release_gate.py` for workflow relationships. Put
helper and shell-control-flow tests in one focused module such as
`scripts/tests/test_mobile_smoke_runtime.py`. Use standard `unittest`, temporary
folders and PATH stubs. Do not build a reusable orchestration framework. Static
substring checks alone are insufficient for R2–R7.

## 5. Implementation tickets

### P1 — Restore Android Java after backend verification

Files: `.github/workflows/mobile-store-release.yml`; workflow gate tests.

RED: expand/inspect job steps and prove that no compatible JDK selection occurs
between `backend-verify` and Android execution. Test execution order, not just the
presence of `setup-java` somewhere in the job.

GREEN: retain Java 25 for the backend composite. Add/select Java 21 after it and
before Patrol or direct Gradle execution. Keep the app's Gradle 8.13 wrapper for this
fix; Java 25 requires a newer Gradle runtime and is not an Android upgrade ticket.
Capture `java -version` and `(cd android && ./gradlew --version)` in the disposable
checkout without printing the full environment. They must identify Java 21.

### P2 — Generate valid, distinct test numbers

Files: `scripts/mobile-smoke/run-android-smoke.sh`; private drivers; runtime tests.

RED: current eight-digit suffix fails the mobile TH validator. Cover leading-zero
suffixes, both prefixes, canonical/local round-trip and two distinct account fixtures.

GREEN: use seven suffix digits and one existing-runtime random generator. Python
standard-library generation is sufficient; avoid the fragile random-byte shell
pipeline and new dependencies. Validate each number through the real mobile country
validator in the private test before OTP submission. Mobile M1 supplies ordinary
public validation coverage; private run values never enter the public repository.

### P3 — Decode the helper query correctly

File: `scripts/mobile-smoke/otp_helper.py`; runtime helper tests.

RED: request `/otp?e164=%2B...` for the allowed identity returns 403 today. Also cover
foreign numbers, missing/blank/duplicate parameters, wrong path, malformed challenge
record, delayed issuance, timeout, and helper logs containing a secret marker.

GREEN: use `urllib.parse.urlsplit` and `parse_qs`, require one `e164` value, then
compare the decoded value exactly. Preserve 404 for an unknown path, non-success for
malformed input, 403 for a foreign identity, bounded polling and loopback binding.
Never echo challenge records, OTPs, credentials or helper response bodies in logs.
Exercise at least one real local HTTP request with an injected challenge reader.

### P4 — Keep Compose context independent of caller cwd

Files: `common.sh`, `run-android-smoke.sh`, `otp_helper.py`, readiness/teardown users.

RED: run the helper from an empty temporary mobile checkout with a fake Docker
command that checks its Compose/env arguments. Relative platform filenames fail.

GREEN: resolve the platform root once from the script location using `BASH_SOURCE`
before changing directory. Export absolute `COMPOSE_FILE` entries and one absolute
smoke env-file path. Pass that env file explicitly to the helper's Docker invocation;
`ENV_FILE` as an unexported shell local is not sufficient. Use the configured
`SMOKE_COMPOSE_PROJECT` everywhere. The existing helper may gain an `--env-file`
argument; it must not guess `.env` from its caller or fall back to another stack.
Bound the Docker subprocess as well as the outer OTP poll. Treat failed Docker
commands as failure, with a safe message and no configuration-value dump.

### P5 — Repair helper and ADB lifecycle across all stages

Files: `run-android-smoke.sh`; runtime command-trace tests.

RED: execute all three stages using stubbed ADB/Patrol/Gradle/helper commands. Assert
that every stage requiring OTP has an active reverse mapping. The current trace
creates it once and removes it after stage one. Also simulate helper-start failure,
seed failure and stage failure to prove cleanup actually runs.

GREEN: create/verify ADB reverse during every helper start, or keep it until final
job cleanup. Make stop idempotent, terminate and reap the previous helper before
rebinding its port, and register cleanup before starting/seeding can fail. Avoid
leaked background helpers or stale forwards on persistent runners. These are small
changes inside the existing script, not a supervisor service.

### P6 — Use the correct mail-reader control and prove real mail use

Files: private Patrol targets; dependency: companion M2.

RED: after opening seeded mail, the driver cannot find a composer-only close button.
Keep the failing assertion against the actual route rather than mocking navigation.

GREEN: wait for mail-reader readiness, read the seeded message through the renderer's
actual supported finder, tap `email_reader_back_button`, wait for inbox readiness,
open the composer, assert it exists, then send a synthetic message inside the same
stack. Prove submission/delivery through authoritative mail state, not just absence
of OTP fields or a button tap. Reuse the issued session; no extra OTP is permitted.
Keep all backend/helper-specific target code in this private repository.

### P7 — Make readiness inspect the configured stack

Files: `wait-for-backend.sh`, `common.sh`, Compose mapping and runtime tests.

RED: test `SMOKE_POSTGRES_HOST_PORT=15432` with only that port reachable, and a
non-default smoke project. A listener on unrelated 5432 must not satisfy readiness.
Have fake Docker reject the wrong project/env and return no API container.

GREEN: wait on `SMOKE_POSTGRES_HOST_PORT`; use P4's absolute Compose/env configuration
and `SMOKE_COMPOSE_PROJECT` in Python subprocesses. Require successful Docker results,
the intended API container, the correct published API port and an allowed loopback
bind. Do not accept any unrelated published TCP port as proof of API reachability.
Keep waits bounded. Host checks prove publication; actual emulator requests in P8
prove emulator reachability. Add no unsupported port knobs in this fix set.

### P8 — Prove the complete ordinary Android smoke

Preserve and test the corrected `EmailMessage` import in `seed-mail.py`; build and
inspect the outgoing message using a fake SMTP endpoint. Preserve fresh-stack reset,
matching API image identity and local-only configuration. Cleanup/reset failures
must fail clearly rather than silently reuse stale state. Never reset an unrelated
project during tests.

Run these stages against one exact mobile SHA and one exact platform SHA:

1. Fresh login: wrong OTP is visibly rejected; the issued OTP opens the inbox;
   seeded mail is readable; compose/send succeeds using the same credential.
2. New instrumentation invocation after force-stop: session is retained; inbox
   reaches a positive ready state without phone/OTP prompts. Do not reinstall or
   clear data between stages 1 and 2.
3. Independent account: prove its seeded message exists before deletion, delete via
   settings, wait for confirmed completion/logout, start a fresh OTP flow, then
   prove the new native mailbox is ready and the earlier message is absent. Compare
   old/new native account identity privately where available. A fixed sleep followed
   by `findsNothing` alone is insufficient. Do not require random OTP codes to differ.

Fault checks: unavailable backend, missing OTP and pending/failed deletion must fail
within the stage's timeout. Prove a deliberate smoke failure blocks release jobs.
Keep diagnostics private/redacted; align artifact upload paths with `SMOKE_ARTIFACTS`.
Record an actual Android result. Stubs prove script behavior, not UI/device behavior.

### P9 — Existing push B5 integration and release proof

This is the remaining gate from `24-fcm-push-plan.md`, not an eighth reviewed harness
bug. Coordinate after companion M3–M5:

- Add a focused backend integration test in `com.numberinbox.push`: authenticated
  registration, actual Stalwart storage confirmation, transactional outbox, target
  processing and the real FCM serializer sending to a local fake endpoint. Reuse
  injectable test credentials/transports; add no production bypass or fake-state API.
- Match the captured data contract against the mobile parser fixture from the exact
  checked-out mobile SHA. Cover claimed/no-SMS, preserved unclaimed SMS, hold/reviewer
  exclusion, duplicate confirmation, two devices, refresh/revoke, provider failure
  and lease recovery. Gate scheduled wiring separately from direct method calls.
- Use NumberInbox Firebase only for the real-device gate. Configure project and
  credentials through existing protected environments. A server service-account
  key never enters mobile code or the ordinary disposable smoke.
- Capture the device matrix in the companion plan. Keep Android notification-plus-data
  semantics consistent: background system display, one foreground app display, and
  no extra display on tap. HTTP acceptance alone never closes this gate.

## 6. Verification and implementation handoff

From the platform root, run the relevant RED tests during each ticket, then:

```bash
export PATH="/usr/local/bin:$PATH"
(cd apps/api && JAVA_HOME="$HOME/.sdkman/candidates/java/25.0.2-open" ./mvnw -B -ntp verify)
python3 -m unittest discover -s scripts/tests
python3 scripts/check-workflow-syntax.py
./scripts/check-env-keys.sh
for file in scripts/mobile-smoke/*.sh; do bash -n "$file"; done
python3 -m py_compile scripts/mobile-smoke/*.py
git diff --check
```

Also compile embedded Python blocks through the runtime tests and validate touched
JSON fixtures. Follow repository timeout/alarm and Docker PATH rules for long commands.
Run existing mail/routing gates in CI. Full backend verify is required before commit;
selected tests are not a replacement. Watch standalone CI green on the pushed SHA.
Request Code Buddy with a standalone `/review` note on the implementation MR.

Dispatch private smoke through the authorized GitHub MCP workflow path after both
candidate SHAs are committed, their required CI is green and M2's selector is present.
Use smoke mode; store upload requires its separate protected-environment approval.
No production SSH, secret copying, billing activation or unrelated deployment is part
of these fixes.

Update `docs/private-mobile-ci-release-plan.md`, `docs/22-mobile-app-plan.md` and
`docs/24-fcm-push-plan.md` from actual evidence. Mobile registration already exists;
remove stale blanket statements that mobile M5 is wholly not started. Mark receive
work, B5 fake-endpoint proof and real-device proof separately.

Agent completion report must include: files/SHAs, per-ticket RED/GREEN evidence,
regression commands/results, the actual smoke run link, remaining release blockers,
and which P9 items are proved. Never report full launch readiness from P1–P8 alone.
