# Mobile app release gate fixes — TDD handoff

Date: 2026-10-19. Status: planned; completion requires the evidence below.
Owner: mobile agent working in public `numberinbox/mobile-app`.
Companion: [Platform handoff](./platform-release-gate-fix-plan.md).

This handoff stays in the private platform docs folder. Public mobile changes contain
normal app code, neutral unit/widget fixtures and generic UI selectors. Runtime OTP
helpers, disposable infrastructure, per-run phone values, private Patrol drivers and
private workflow links stay in the platform repository.

## 1. Start from the current implementation

Inspected mobile HEAD: `97f542590` (platform FCM registration), following `5fd459e5f`
(NumberInbox Firebase project). Registration is already implemented. Receive-path
changes are uncommitted in the current checkout, including `base_controller.dart`,
FCM receiver/service/controller/listener/repository code, a versioned message model
and their tests. Inspect `git status` and the complete diff before touching them;
preserve the other agent's work and retain behavior that already passes.

The old platform documents saying mobile M5 is wholly not started are stale. The
remaining task is to verify and finish registration/receiving/display/tap/logout
behavior and provide mobile evidence for B5. Do not replace the existing push feature
with a second architecture or reimplement the seven private-runner fixes here.

Read this repository's `AGENTS.md` (dependency changes use `./scripts/prebuild.sh`),
its current CI workflow, and the platform's product rules, API contracts and push
plan. Android is the initial release gate. Keep existing AGPL/source attribution and
app identifiers. Billing, iOS release expansion, branding redesign and unrelated
features are outside this fix set.

## 2. Ownership and shared contracts

| Item | Mobile responsibility | Platform responsibility |
|------|-----------------------|-------------------------|
| Android Java/Gradle runtime | Keep compatible wrapper/build; report required runtime | P1 selects Java 21 after Java 25 backend verification |
| TH number validation | M1 proves public country validation behavior | P2 generates/validates private run values |
| OTP helper parsing, Compose cwd, ADB and readiness | Use ordinary app OTP client unchanged | P3–P5/P7 repair private transport |
| Reader navigation | M2 publishes and tests the real back selector | P6 uses it in the private driver |
| FCM registration and receiving | M3–M5 finish existing application behavior | B1–B4 API remains the existing contract |
| Whole-path/device proof | M6 supplies app/device evidence | P8/P9 run the private integration gate |

### UI contract to publish

Add `UiKeys.emailReaderBackButton = 'email_reader_back_button'` to
`lib/features/base/model/ui_keys.dart` and place `Key(UiKeys.emailReaderBackButton)` on
the actual back control for the Android phone mail-reader route. Start from
`features/email/presentation/widgets/email_view_back_button.dart`; check the thread
reader route as well so the control the smoke actually opens is covered.

Keep these current keys stable: OTP/country controls, `composeEmailButton`,
`sendEmailButton`, `closeComposerButton`, `userAvatar`, settings/deletion controls
and `emptyThreadView`. `closeComposerButton` stays composer-only. Use a generic key,
not a test-only navigation route or a hidden production bypass. Mobile M2 must land
before platform P6 can use the new selector on a validated SHA.

### Registration contract

Basic auth uses the current OTP-issued mailbox username/credential, never a privileged
server credential. `POST /v1/fcm-registrations` sends:

```json
{"token":"<device-token>","deviceClientId":"<stable-installation-uuid>","type":"email"}
```

`202` returns `registrationId` and server-owned `expiresAt` (30 days by default).
`DELETE /v1/fcm-registrations/{registrationId}` returns non-disclosing `204` for owned,
absent or foreign IDs. No app-side lookup/renewal uses unsupported Stalwart
`FirebaseRegistration/get` or `/set`. Existing DTOs may remain as local adapters.

One installation registers its active account. Identity survives token rotation and
logout/login, and changes on a fresh installation as defined by local persistence.
A server-expired record is renewed by authenticated POST. Do not derive identity
from token hash or caller-selected E.164/native account values.

### Receive contract

```json
{
  "schemaVersion":"1",
  "eventType":"mail.delivered",
  "deliveryId":"11111111-2222-4333-8444-555555555555",
  "stalwartAccountId":"account-fixture",
  "emailId":"email-fixture"
}
```

These are opaque strings, not a JMAP StateChange. Compare the native account ID with
the active authenticated account; fetch authoritative mail over authenticated JMAP.
No subject, sender, body, OTP, phone number or credential is transported in this
payload. Generic visible text is `NumberInbox` / `You have new mail`.

| Receive context | Expected behavior |
|-----------------|-------------------|
| Foreground | Authenticated synchronization and at most one generic app notification |
| Normal background/termination, notification-plus-data | Android owns system display; any app background synchronization is silent |
| Tap / cold-start intent | Validate active account, synchronize/open the intended mail; create no second notification |
| Permission denied | Mail remains usable through ordinary authenticated synchronization |
| Logged out or different native account | Drop account-specific processing/navigation |

FCM acceptance is not delivery. An already in-flight notification cannot reliably be
recalled after logout. Generic text and authenticated account checks are required;
no exactly-once promise or force-stop delivery guarantee is part of acceptance.

## 3. TDD agreement

Write a failing behavior test for each uncovered requirement, record RED, implement
the smallest correction, then refactor with GREEN. Extend existing tests and feature
boundaries. Characterization tests that already pass verify retained work; they do
not prove a missing historical RED run. Do not rewrite passing registration code to
make the plan look newly implemented.

Keep new classes/files in the existing push feature and NumberInbox test areas.
Reuse the present HTTP client, account/session services, storage and notification
manager. Add no service, broker, generic event framework or new persistence engine.

## 4. Mobile implementation tickets

### M1 — Verify the public phone-validation contract

Files/tests: `features/numberinbox/country.dart`, existing
`test/features/numberinbox/country_test.dart`, and welcome-controller/view tests.

RED/characterize: TH-valid canonical/local round trips, leading-zero suffixes and
both mobile prefixes used by the private generator; an extra national digit is
invalid. Test the representation actually submitted to `Country.isValidPhone`:
local input with a leading `0`. Passing a `+66` string to a local-input builder is
not an equivalent test. Invalid input must not call `startOtp`.

Retain correct production validation. Fix the platform generator, not country rules,
when the fixture is invalid. Public tests use neutral ordinary validation examples;
the private driver additionally validates its actual generated runtime values.

### M2 — Publish and prove mail-reader navigation

Files: `ui_keys.dart`, the real reader back widget/route and focused widget tests.

RED: open a real reader widget, require exactly the reader-back selector, tap it and
prove navigation returns to an inbox-ready state. The composer close selector must
not be used as reader navigation. Also cover existing composer open/close/send keys
so the platform agent can test actual submission rather than missing OTP fields.

GREEN: add the one generic selector described above without changing back behavior.
Check the Android phone route used by the private Pixel smoke, not only an isolated
unused widget. Supply the validated mobile commit SHA and selector names to the
platform agent. Private Patrol tests themselves stay in platform.

### M3 — Finish and verify the existing registration lifecycle

Reuse `FcmRegistrationApi`, `FcmInstallIdProvider`,
`RegisterPlatformFcmTokenInteractor`, `RevokePlatformFcmRegistrationInteractor`,
`FcmTokenController` and existing bindings/tests.

Required tests, fixing only failures found:

- Correct endpoint/body/Basic auth; parse server registration ID/expiry; map errors
  without leaking response bodies, auth headers or device tokens.
- Concurrent install-ID requests yield one persisted UUID; a false/failed persistence
  result does not send a registration using an identity that cannot be recovered.
- Startup, token refresh, same-token renewal and expiry recovery call the platform
  path. Test that app flows issue no FirebaseRegistration JMAP methods.
- The current account's credentials are used. Logout/account switch cannot allow an
  earlier in-flight registration response to overwrite the next account's state.
- Revoke while credentials are still available. Online revocation is bounded;
  offline failure still clears local account data and prevents stale mail handling.
  Reopening/authenticating renews registration. Do not retain a plaintext password
  merely to retry revocation after logout.
- Preserve install identity across ordinary logout; clear account-scoped registration
  and push dedup state on logout/deletion. Account recreation with the same E.164 but
  a different native ID must not inherit old processing rights.
- Capture actual logs: token markers, Basic credentials and registration objects
  must not appear. Current token logging in `fcm_receiver.dart` and
  `fcm_token_controller.dart` is part of the cleanup to test and remove.

Remove provably unused NumberInbox registration bindings after tests pin the active
path. Keep shared legacy types needed by other active paths; do not delete the
mixed-purpose FCM repository or websocket machinery wholesale.

### M4 — Complete the versioned receive path safely

Current uncommitted entry points include `NumberInboxPushMessage`,
`FcmMessageController.handlePushPayload`, `FcmReceiver` background handling,
`EmailChangeListener` and the email-changes interactor/repository. Extend their
existing tests rather than building a second receive pipeline.

Required RED/characterization cases:

1. All required fields are non-empty strings; unknown schema/event, malformed or
   incomplete data is ignored safely. Use one neutral version-1 JSON test fixture
   for contract comparison with platform P9.
2. Logged-out/account mismatch paths make no mail fetch, notification or navigation.
   Recheck the active account after asynchronous session/mail fetches; a logout or
   account change during a fetch invalidates the old result.
3. Valid hints use authenticated JMAP. Delivery cursors come from native
   `Email/changes.newState`, not `Email/get.state` ahead of unprocessed changes.
   Missing/stale cursors recover through the existing safe synchronization path.
4. The existing synthetic internal refresh marker, if retained, is never sent as
   `sinceState` and never stored as a native JMAP state. Assert actual outbound
   requests and cursor writes, not only helper return values. Use an explicit refresh
   path if that invariant cannot be maintained with the current adapter.
5. The top-level annotated background callback awaits all required work. A delayed
   account/session/JMAP future must not be abandoned when the callback completes.
   Optional telemetry failure cannot discard the push or hang its time budget.
6. Two overlapping hints with reversed fetch completion do not overwrite another
   account's pending work or advance a cursor past unprocessed changes. Preserve
   ordinary websocket/legacy state-change behavior.

### M5 — Enforce notification, tap and dedup semantics

Follow the context table in section 2. Carry foreground/background/tap context and
`RemoteMessage.notification` metadata through the SDK entry points; a data map alone
cannot establish whether Android already displayed a notification.

Tests must prove:

- At most one app-generated generic notification for a foreground event, no extra
  local display for a system-displayed background event, and no display on tap.
- No sender/subject/body/OTP leaks through the legacy rich-notification path, even
  though authenticated JMAP has fetched that content.
- Repeated `(native account ID, deliveryId)` events across callbacks/restart do not
  repeat app-controlled effects. Bound and expire dedup storage using existing
  persistence, with named limits tested; acknowledge OS/FCM at-least-once behavior.
- A successful earlier background sync does not suppress the user's later tap intent.
  Display/sync dedup and authenticated navigation are distinct decisions.
- Only completed effects are recorded as processed. A failed fetch can retry; cursor
  and dedup persistence failures cannot silently mark unseen mail complete.
- Background and foreground storage access uses existing supported mechanisms. Every
  `HiveCacheClient` write is awaited and flushed, including new dedup writes.
- Permission denial, unavailable token, revoked credential, deleted email or offline
  tap yields bounded ordinary UI behavior; successful mail use requires no extra OTP.

### M6 — Verification and coordinated device proof

Use the repository's pinned Flutter version and required JDK 21. When dependencies
or generated sources need refresh, run the required prebuild entry point:

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-21.jdk/Contents/Home
./scripts/prebuild.sh
flutter analyze
flutter test
flutter build apk --debug
```

Run focused NumberInbox/push/widget tests during RED/GREEN and the existing complete
required mobile CI gate before handoff. Use current CI's analysis options and test
commands if they differ; report any failure explicitly rather than weakening them.
Check touched Dart formatting and the merged release manifest. Cleartext access stays
debug-only. Keep public release triggers disabled; preserve existing web/James gates.

Handoff to platform P8/P9 includes the committed mobile SHA, public CI run link,
reader selector and contract fixture, focused/full test results, and any device-only
items that remain unverified. Do not put private platform run URLs in public statuses.

Platform owns the private Android smoke. Coordinate a real NumberInbox Firebase
Android device run for: initial registration, refresh, foreground, background, normal
termination, notification tap, cold-start tap, permission denial, logout/account
switch, account deletion/recreation and reinstall. Inspect generic display text,
active-account validation, actual JMAP fetch/open and absence of duplicate local
notifications. Android Settings force-stop requires reopening and is recorded
separately from normal termination. Emulator data injection does not prove FCM/OS
delivery. iOS acceptance remains a separate later gate.

## 5. Completion audit and reporting

M1/M2 provide the public UI contract required by platform harness fixes. M3–M5 finish
and verify existing mobile push work. M6 plus platform P9 close the device release
gate; ordinary OTP smoke alone does not.

Report per-ticket RED/GREEN evidence, changed files, exact mobile SHA, public CI link,
contract/selector handoff, device results and remaining blockers. Mark each checklist
item proved only by evidence that exercises it. Update stale platform M5/B5 status
through the platform agent after the evidence is available. No store upload or
production deployment is implied by a passing unit test or by this handoff.

## 6. Post-audit security follow-ups (M7–M11)

A security review of the M3–M5 work raised these; each was fixed TDD-first with a
RED captured before the change. A proposed at-rest encryption item was dropped: it
diverges from upstream and is out of scope for this fork (see the Fork policy in
`AGENTS.md`).

### M7 — Verify the WebSocket TLS path (T1)

RED: `web_socket_datasource_impl_test.dart` proved the socket trusted a self-signed
certificate and read the Basic credentials before connecting. GREEN: `badCertificate
Callback` removed, one verified `WebSocket.connect`, `WebSocketInsecureSchemeException`
for non-loopback `ws://` (loopback kept for local/test servers). Commit `ddd563cd3`.

### M8 — Report platform push completion only after success (T2)

RED: a failed cursor lookup, `Email/changes`, or cursor write still recorded the
delivery as processed, so FCM redelivery was permanently deduplicated. GREEN: the
listener chain returns `Future<bool>` and the controller records the delivery only on
a fully successful dispatch; a controller-level test proves no record when the
pipeline reports incomplete. Commit `3385cc0e3`.

### M9 — Scope deletion state to the signed-in account (T3)

RED: pending deletion request id, status token, and idempotency key were device-wide,
so switching accounts could resume another account's request. GREEN: keys are scoped
by normalized username and legacy unscoped keys are deleted on restore. Commit
`ba396b884`.

### M10 — Redact the FCM device token from logs (T5)

RED: `FcmService::handleToken` logged the raw token to every sink. GREEN: only token
presence is logged, matching `FcmReceiver`. Commit `9b1f6caed`.

### M11 — Remove the retired JMAP registration path (T6)

RED: no test could prove the path was dead while it stayed bound. GREEN: the four
registration interactors, `FcmApi`, the network datasource, request models, states and
their bindings are deleted; the cache and platform register/revoke paths are kept.
Commit `cab03063d`.
