# Mobile integration tests: upstream parity with one OTP seam

## Context

`numberinbox/mobile-app` is a fork of `linagora/tmail-flutter` (remote `upstream`). The fork's product difference for testing is **login**: users sign in with phone + OTP (`lib/features/starting_page/presentation/twake_welcome/`), not James basic auth / "Use company server".

Today:
- `integration_test/` is almost identical to upstream (last upstream merge: `9a89aabdf`, recorded in `docs/reviews/upstream-sync-2026-10-27.md`). Drift is 5 files: `base/app_constants.dart`, `robots/mobile/mobile_app_grid_robot.dart`, `scenarios/search_email_by_date_time_and_sort_order_relevance_scenario.dart`, `utils/backend_reset_client.dart`, `store_capture/store_capture_test.dart` (all listed in `docs/reviews/fork-parity-inventory.csv`).
- Commit `962b3a35c` deleted the public Android Patrol job (`patrol-integration-test.yaml`, `scripts/patrol-integration-test-with-docker.sh`). Its replacement is the **private** Android smoke in `../platform` (`.github/workflows/mobile-store-release.yml` → `scripts/mobile-smoke/run-android-smoke.sh`), which runs only 3 private OTP targets (`scripts/mobile-smoke/patrol/numberinbox_{login,relaunch,deletion}_test.dart`). Design doc: `../platform/docs/private-mobile-ci-release-plan.md`.
- Result: the ~40 inherited upstream tests tagged `android`/`ios` run nowhere. Only the web/James job (`patrol-web-integration-test.yaml`) runs them.
- No CI check stops new drift in `integration_test/`.

**Key fact the plan relies on.** After OTP verify, `TwakeWelcomeController._onOtpVerified` / `_persistCredentials` save: `saveBaseUrl(origin)`, `storeAuthenticationInfo(AuthenticationInfoCache(username, credential))`, `setCurrentAccount(PersonalAccount(username, AuthenticationType.basic))`. That is **exactly** what upstream's `BaseTestScenario._seedTestCredentials` (`integration_test/base/base_test_scenario.dart`) seeds from `BASIC_AUTH_URL` / `BASIC_AUTH_EMAIL` / `PASSWORD`. Every upstream scenario except `LoginWithBasicAuthScenario` goes through that seed and never touches the login UI. Email provisioning (`ScenarioUtilsMixin.provisionEmail`, `CommonRobot`) sends through the app's own JMAP interactors, so it is backend-agnostic.

So the upstream suite can run **unmodified** against the NumberInbox/Stalwart backend once it is given an OTP-issued credential.

**Goal:** keep `integration_test/` byte-identical to upstream except for a small, explicit, CI-enforced allowlist. Run the inherited upstream suite on Android in the private smoke using an OTP-minted account. OTP login UI coverage stays in the private targets. Upstream test changes then arrive by plain merge.

**Constraints (from AGENTS.md and the private CI plan, do not violate):**
- Fork policy: no product feature changes. This plan is test and CI only.
- No private drivers, OTP values, test numbers, backend config or tunnels in the public repo. `workflow-policy.test.mjs` already enforces that the public Android job and the bore script stay deleted.
- Never log the OTP, the `/v1/otp/verify` response, the JMAP credential, or the full dart-define set.
- Run `./scripts/prebuild.sh` instead of `flutter pub get`.
- The agent does not push or post review replies. The user does that.

---

## Part A — mobile-app (public repo)

Branch from `master`, e.g. `test/integration-upstream-parity`.

### A0. Keep this plan with the code
- Copy this plan to `docs/plans/mobile-integration-test-upstream-parity.md` in the first commit, so the next agent and reviewers have it in the repo.
- Parts A and B are independent and can run as two parallel tasks. Part B's first run (B6) needs Part A merged only for the drift check, not for the tests themselves.

### A1. Record the upstream base
- Add `integration_test/UPSTREAM_BASE`, containing one line: the full SHA of the last merged upstream commit (`git rev-parse 9a89aabdf`).
- The upstream-sync procedure must bump it. Add one line to whichever doc describes upstream syncs (see `docs/reviews/upstream-sync-2026-10-27.md` for the current practice; add a short "Upgrading" note to `integration_test/FORK.md`, A2).

### A2. Allowlist and fork notes
- Add `integration_test/FORK_ALLOWLIST` with one path per line, relative to the repo root. Lines starting with `#` are comments; each path gets a one-line reason comment. Initial content (after A3–A5):
  ```
  # app/package id is com.numberinbox.app
  integration_test/base/app_constants.dart
  # stalwart rejects example.com recipients; use ADDITIONAL_MAIL_RECIPIENT
  integration_test/scenarios/search_email_by_date_time_and_sort_order_relevance_scenario.dart
  # teardown fails loudly and redacts dio errors (offer upstream, then drop)
  integration_test/utils/backend_reset_client.dart
  # store screenshots via otp login (fork-only file)
  integration_test/store_capture/store_capture_test.dart
  # fork bookkeeping
  integration_test/UPSTREAM_BASE
  integration_test/FORK_ALLOWLIST
  integration_test/FORK.md
  ```
- Add a short `integration_test/FORK.md` covering:
  - the rule: no edits outside the allowlist;
  - fork-only tests go in new files, never as edits to upstream files;
  - OTP login tests are private (`../platform/scripts/mobile-smoke/patrol/`);
  - the upstream suite runs in the private smoke via credential seeding;
  - how to bump `UPSTREAM_BASE`.

### A3. App-id drift in the app grid robot
- `integration_test/robots/mobile/mobile_app_grid_robot.dart` hard-codes the Android package id and the iOS bundle id. Upstream does too (`com.linagora.android.teammail`, `com.linagora.ios.teammail`).
- Keep the fork edit for now and add the file to `FORK_ALLOWLIST` with the reason "app grid package id; upstream pr pending".
- Draft (do not open) an upstream PR that makes the robot read `AppConstants.appId` plus a new `AppConstants.iosBundleId`. Once upstream merges it, the fork only overrides `app_constants.dart`. The robot then matches upstream, and the stale-entry check (A6) forces its removal from the allowlist.
- Do **not** add other indirection in the fork.

### A4. Reduce the search scenario drift to logic only
- In `search_email_by_date_time_and_sort_order_relevance_scenario.dart`, revert everything that is reformatting: the `dart format` line wrapping, the removed leading blank line, and the constructor/`if (dart.library.html)` indentation.
- Keep only the `_additionalRecipient` / `resolveRecipients` change and its use. The result should be a minimal `git diff $(cat integration_test/UPSTREAM_BASE) -- <file>`.
- Check for a unit test of `resolveRecipients` (`grep -rn resolveRecipients test`). If one exists, it must still pass.

### A5. backend_reset_client.dart
- Keep the fork version: it fails the teardown and redacts errors, and it is a security improvement.
- Draft an upstream PR description for the user. When upstream takes it, the file drops off the allowlist automatically, because the checker (A6) flags stale entries.

### A6. Drift checker script + node test
- New `scripts/check-integration-test-drift.sh` (bash, `set -euo pipefail`; follow the style of existing `scripts/*.sh`). It:
  1. Reads `BASE=$(cat integration_test/UPSTREAM_BASE)`.
  2. Ensures `BASE` exists locally. If not: `git fetch --no-tags --depth=1 https://github.com/linagora/tmail-flutter.git "$BASE"`. This is a public repo, so no credentials are needed. Do not rely on a named `upstream` remote in CI.
  3. Runs `git diff --name-only "$BASE" HEAD -- integration_test/`. This includes added and deleted files (also use `--diff-filter=ACDMRT`).
  4. Fails, listing the paths, if any changed path is not in `FORK_ALLOWLIST`.
  5. Fails if an allowlisted path (excluding the three bookkeeping files) has **no** diff against `BASE`. That entry is stale and must be removed.
  6. Prints only paths, never file contents.
- Wire it into CI. `analyze-test.yaml` ignores `.github/**` and `docs/**` but not `integration_test/**`, so the existing `node --test` job (around `analyze-test.yaml:135`) is the right home. Either:
  - add a step before `node --test`: `bash scripts/check-integration-test-drift.sh`, with `actions/checkout` set to `fetch-depth: 0`, or let the script's shallow fetch handle it; or
  - add a node test in `scripts/tests/integration-test-drift.test.mjs` that spawns the script. This matches the `workflow-policy.test.mjs` pattern of static guards in the fast job.
  - Recommended: the separate step. It gives clear CI output, and a small node test can assert that the allowlist and `UPSTREAM_BASE` files exist and are well-formed.
- Extend `scripts/tests/workflow-policy.test.mjs` with one assertion: `analyze-test.yaml` contains the drift-check step, so nobody silently removes it.

### A7. Contract test for the private-driver widget keys
- An OTP key contract test already exists: `test/features/starting_page/twake_welcome_screen_contract_test.dart`. It checks `otp_country_picker`, `otp_phone_field`, `otp_code_field`, `otp_send_cta`, `otp_verify_cta` and `otp_error`. Extend it, or add a sibling test, so every key used by the private Patrol targets is covered:
  - `country_search` and `country_<code>`: the country sheet in `twake_welcome_view.dart` around lines 255–272; assert `country_TH` exists after opening the picker.
  - Deletion and settings keys: `setting_delete_account`, `deletion_phone_field` and `deletion_submit` (in `lib/features/numberinbox/account_deletion_page.dart` and the settings menu), and `email_reader_back_button`. Find each with `grep -rn "Key('<name>')" lib`. Put them in the existing test for that widget if there is one, otherwise in a new small widget test.
- Add a top comment: "private android smoke patrol targets depend on these keys; renaming one breaks the release gate."
- Do **not** reference the platform repo path or any private detail beyond that sentence.

### A8. Docs
- Add `docs/adr/0117-mobile-integration-test-upstream-parity.md`. Check the latest ADR number first: `0116` is currently the highest, and `0114` is duplicated. Follow the ADR template in `0001`. The ADR records the decision, the allowlist mechanism, and that OTP UI tests are private.
- Update the `integration_test/` rows in `docs/reviews/fork-parity-inventory.csv` if A3/A4 change their status. Add rows for the new bookkeeping files if the inventory tracks every fork file.

### A9. Verify Part A
```bash
./scripts/prebuild.sh
```
```bash
flutter analyze integration_test test/features/starting_page
```
```bash
flutter test test/features/starting_page
```
```bash
bash scripts/check-integration-test-drift.sh
```
```bash
node --test scripts/tests
```
- Negative checks (then revert each):
  - Touch a non-allowlisted upstream file under `integration_test/`: the checker must fail and name it.
  - Add an allowlisted file with no diff: the checker must report it as stale.
- `git diff "$(cat integration_test/UPSTREAM_BASE)" --stat -- integration_test/` must list only allowlisted files.
- Confirm the web job still builds its targets. `scripts/patrol-web-integration-test-with-docker.sh` uses `--target integration_test/tests`, so nothing in A should affect it.

---

## Part B — platform (private repo, `../platform`)

### B1. Mint an OTP account outside the app (runner side)
- Add a loopback-only helper step, `scripts/mobile-smoke/mint_session.py`. Reuse `otp_helper.py`'s `read_challenge` and its redaction rules instead of duplicating them. The step:
  1. Calls `POST {API}/v1/otp/start` with `{"e164": N}`, where N is a fresh number from `gen_test_numbers.py`, distinct from stage 1–3 numbers.
  2. Reads the code via `read_challenge` (Valkey, bounded poll).
  3. Calls `POST {API}/v1/otp/verify` with the same payload shape as `NumberInboxAuthClient.verify` (`lib/features/numberinbox/auth/numberinbox_auth_client.dart`, around line 38). Read that file for the exact fields.
  4. Extracts `jmap.username`, `jmap.credential` and `jmap.sessionUrl`. Asserts the origin of `sessionUrl` equals `SMOKE_JMAP_ORIGIN`, mirroring `JmapSessionManager.baseUrlFromSession`.
  5. Writes `username`, `credential` and the origin to a `0600` file under `$RUNNER_TEMP`, read by the runner. Never prints them and never puts them in artifacts.
- Seed mail for that number with the existing `seed_mail` if any upstream scenario expects inbound mail. Most provision their own mail through JMAP.
- Mint a second number if `ADDITIONAL_MAIL_RECIPIENT` must be a real deliverable address on the disposable domain. Its address is `<local>@${SMOKE_DOMAIN}`; read how `seed-mail.py` builds addresses.

### B2. Backend reset between upstream tests
- `TestBase._tearDown` calls `BackendResetClient.reset()`, which POSTs `${RESET_SERVER_URL}/reset` and now **fails** the test on non-200 responses. An empty URL is a no-op.
- Implement a loopback reset endpoint in platform, `scripts/mobile-smoke/reset_server.py`, following `otp_helper.py`'s server shape: 127.0.0.1 only, reached through `adb reverse`. Its `/reset` empties the test account's mailboxes, identities, labels and filters. Use the Stalwart admin API, or delete and re-create the account with the same credential (see the platform's Stalwart provisioning code). The account and credential must stay valid across resets; otherwise re-mint and re-seed per test file.
- The old upstream equivalent was `mobile-app/scripts/backend-reset-server.py`, which reset James. Read it for the contract (POST `/reset` → 200 when done).
- Bounded timeout. Any failure returns non-200 with no body detail.

### B3. New smoke stage: upstream suite
- In `run-android-smoke.sh`, add **stage 0** "upstream suite", before stage 1. It has its own `clear_app_data`, its own reverse ports, and an EXIT trap that stops the helpers (copy the stage 1 trap pattern exactly: trap registered before the helpers start).
- Build the target list from `integration_test/tests/**/*_test.dart` in the mobile checkout, minus `scripts/mobile-smoke/upstream-skip.txt`.
- Run with the same flags as `run_stage`, but **without** `ORG_GRADLE_PROJECT_clearPackageData=false`, so the default `true` gives each test a clean app. Pass:
  ```
  --tags=android
  --dart-define=BASIC_AUTH_URL=<jmap origin>
  --dart-define=BASIC_AUTH_EMAIL=<username>
  --dart-define=PASSWORD=<credential>
  --dart-define=USERNAME=<username>
  --dart-define=ADDITIONAL_MAIL_RECIPIENT=<second account address>
  --dart-define=RESET_SERVER_URL=http://127.0.0.1:<reset port>
  --dart-define=API_BASE_URL=... --dart-define=JMAP_BASE_URL=...
  ```
- Check `patrol test --help` (patrol_cli 4.3.1) for how to pass several targets: repeated `--target` or comma-separated. Also check whether `--exclude-tags` exists.
- Do not echo the command line. `patrol -v` may print dart-defines, so run without `-v`, or check that the defines are not in output and redact them in captured logs.
- `install-drivers.sh` copies private targets into `integration_test/` top level. Make sure stage 0's target glob covers only `integration_test/tests/` so private targets don't run twice.

### B4. Skip list
- `scripts/mobile-smoke/upstream-skip.txt`: one test path per line, each with a reason comment. Initial entries:
  - `integration_test/tests/login/login_with_basic_auth_test.dart`: the fork has no basic-auth login UI. OTP is covered by the private stage 1.
  - Any test that needs James-only capabilities. Find them by running stage 0 once (B6). Likely candidates are email rules/filters, forward, calendar, labels, and `app_grid` if `APP_GRID_AVAILABLE` differs. Do not guess: add a test only after it fails for a backend-capability reason, and note the capability in its comment.
- A skip is never an edit to a test file in mobile-app.

### B5. Script tests
- The smoke script has cleanup tests that stub docker and adb (see `SMOKE_SKIP_BACKEND` and the existing test files under platform `scripts/mobile-smoke` or `tests`). Extend them:
  - stage 0 registers its EXIT trap before starting helpers;
  - skip-list entries are excluded from targets;
  - credentials never appear in captured stdout or stderr;
  - a reset-server failure fails the stage.
- Add unit tests for `mint_session.py` (origin mismatch refused, malformed verify body refused, no secrets in exceptions). Mirror the existing `otp_helper.py` tests if present.

### B6. Verify Part B
- Run the smoke locally or with `workflow_dispatch` `mode=smoke` on an exact mobile `master` SHA. Smoke mode never touches store credentials.
- First run: triage each stage-0 failure as one of three cases:
  1. **Backend capability gap:** add it to the skip list with the reason.
  2. **Fork product difference:** add it to the skip list and note it in the mobile ADR.
  3. **Real app bug:** report it to the user; do not skip.
- Prove that failures surface:
  - stop the reset server mid-run → the stage fails promptly;
  - remove a skip entry for a known-failing test → the stage fails.
- Inspect run logs and artifacts: no OTP, credential, username or verify body.
- Update `docs/private-mobile-ci-release-plan.md` with the new stage and the skip-list policy.

---

## Ongoing workflow after this lands
- Upstream sync: merge upstream, then bump `integration_test/UPSTREAM_BASE` to the merged upstream SHA. The drift check then shows only allowlisted files. If upstream edited an allowlisted file, resolve the conflict, keeping the fork delta minimal.
- New fork-specific test needs: add a **new file**, private in platform if it needs OTP or a backend, otherwise in mobile-app with an allowlist entry. Never edit an upstream test.
- New upstream tests are picked up by stage 0 automatically. If one fails for a backend reason, add it to the skip list.

## Critical files
- mobile-app:
  - `integration_test/{UPSTREAM_BASE,FORK_ALLOWLIST,FORK.md}` (new)
  - `scripts/check-integration-test-drift.sh` (new)
  - `.github/workflows/analyze-test.yaml`
  - `scripts/tests/workflow-policy.test.mjs`
  - `integration_test/scenarios/search_email_by_date_time_and_sort_order_relevance_scenario.dart`
  - `integration_test/robots/mobile/mobile_app_grid_robot.dart`
  - `test/features/starting_page/twake_welcome_screen_contract_test.dart`
  - `docs/adr/0117-*.md`
  - `docs/reviews/fork-parity-inventory.csv`
- platform:
  - `scripts/mobile-smoke/run-android-smoke.sh`
  - `scripts/mobile-smoke/{mint_session.py,reset_server.py,upstream-skip.txt}` (new)
  - `scripts/mobile-smoke/install-drivers.sh` (target-glob check only)
  - `docs/private-mobile-ci-release-plan.md`
- Reuse:
  - `otp_helper.py:read_challenge` and its redaction rules
  - `gen_test_numbers.py`
  - `seed_mail`, `clear_app_data`, `wait_for_device_api` and the trap pattern in `run-android-smoke.sh`
  - the `BackendResetRequest` contract in `integration_test/utils/backend_reset_client.dart`

## Security notes for the implementer
- The credential reaches the test only via dart-define on a disposable backend. Keep it out of logs, artifacts and `set -x` (no tracing in these scripts).
- The reset and mint helpers bind 127.0.0.1 only, are reached through `adb reverse`, and serve only the generated test numbers.
- Assert the `sessionUrl` origin equals the configured JMAP origin. Do not weaken the app's origin validation to make tests pass.
- Nothing from Part B goes into the public repo. `workflow-policy.test.mjs` must stay green.
