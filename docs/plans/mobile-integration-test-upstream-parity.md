# Mobile integration tests: upstream parity with one OTP seam

## Repository ownership update

The repo-split decision amends this earlier plan: parameterized NumberInbox OTP
tests now live in `integration_test/numberinbox/`, and private CI owns only
infrastructure. Runtime values and backend configuration remain private. The
original implementation steps below are historical; ADR 0117 and
`integration_test/FORK.md` describe the current ownership and folder allowlist.

## Context

`numberinbox/mobile-app` is a fork of `linagora/tmail-flutter` (remote `upstream`). The fork's product difference for testing is **login**: users sign in with phone + OTP (`lib/features/starting_page/presentation/twake_welcome/`), not James basic auth / "Use company server".

Today:
- `integration_test/` is almost identical to upstream (last upstream merge: `9a89aabdf`, recorded in `docs/reviews/upstream-sync-2026-10-27.md`). Drift is 5 files: `base/app_constants.dart`, `robots/mobile/mobile_app_grid_robot.dart`, `scenarios/search_email_by_date_time_and_sort_order_relevance_scenario.dart`, `utils/backend_reset_client.dart`, `store_capture/store_capture_test.dart` (all listed in `docs/reviews/fork-parity-inventory.csv`).
- Commit `962b3a35c` deleted the public Android Patrol job (`patrol-integration-test.yaml`, `scripts/patrol-integration-test-with-docker.sh`). Its replacement is a **private** Android smoke that runs only the OTP login, relaunch and deletion flows.
- Result: the ~40 inherited upstream tests tagged `android`/`ios` run nowhere. Only the web/James job (`patrol-web-integration-test.yaml`) runs them.
- No CI check stops new drift in `integration_test/`.

**Key fact the plan relies on.** After OTP verify, `TwakeWelcomeController._onOtpVerified` / `_persistCredentials` save: `saveBaseUrl(origin)`, `storeAuthenticationInfo(AuthenticationInfoCache(username, credential))`, `setCurrentAccount(PersonalAccount(username, AuthenticationType.basic))`. That is **exactly** what upstream's `BaseTestScenario._seedTestCredentials` (`integration_test/base/base_test_scenario.dart`) seeds from `BASIC_AUTH_URL` / `BASIC_AUTH_EMAIL` / `PASSWORD`. Every upstream scenario except `LoginWithBasicAuthScenario` goes through that seed and never touches the login UI. Email provisioning (`ScenarioUtilsMixin.provisionEmail`, `CommonRobot`) sends through the app's own JMAP interactors, so it is backend-agnostic.

So the upstream suite can run **unmodified** against the NumberInbox/Stalwart backend once it is given an OTP-issued credential.

**Goal:** keep `integration_test/` byte-identical to upstream except for a small, explicit, CI-enforced allowlist. Run the inherited upstream suite on Android in the private smoke using an OTP-minted account. OTP login UI coverage lives in the fork-only NumberInbox folder and runs in private CI. Upstream test changes then arrive by plain merge.

**Constraints (from AGENTS.md and the private CI plan, do not violate):**
- Fork policy: no product feature changes. This plan is test and CI only.
- No runtime OTP values, test numbers, backend config or tunnels in the public repo. Parameterized NumberInbox test code is public. `workflow-policy.test.mjs` already enforces that the public Android job and the bore script stay deleted.
- Never log the OTP, the `/v1/otp/verify` response, the JMAP credential, or the full dart-define set.
- Run `./scripts/prebuild.sh` instead of `flutter pub get`.
- The agent does not push or post review replies. The user does that.

---

## Part A — mobile-app (public repo)

Branch from `master`, e.g. `test/integration-upstream-parity`.

### A0. Keep this plan with the code
- Copy this plan to `docs/plans/mobile-integration-test-upstream-parity.md` in the first commit, so the next agent and reviewers have it in the repo.
- Part A is independent of the private CI work.

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
  integration_test/numberinbox/
  # fork bookkeeping
  integration_test/UPSTREAM_BASE
  integration_test/FORK_ALLOWLIST
  integration_test/FORK.md
  ```
- Add a short `integration_test/FORK.md` covering:
  - the rule: no edits outside the allowlist;
  - fork-only tests go in new files, never as edits to upstream files;
  - OTP login tests are run by private CI;
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
- Add a top comment: "integration_test/numberinbox depends on these keys; renaming one breaks the release gate."
- Do **not** reference any private repository path or detail beyond that sentence.

### A8. Docs
- Add `docs/adr/0117-mobile-integration-test-upstream-parity.md`. Check the latest ADR number first: `0116` is currently the highest, and `0114` is duplicated. Follow the ADR template in `0001`. The ADR records the decision, the folder allowlist mechanism, and public parameterized OTP tests with private runtime inputs.
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

## Part B — private CI

Private CI runs the inherited Android-tagged suite against a disposable backend, seeding OTP-issued credentials through `BASIC_AUTH_URL` / `BASIC_AUTH_EMAIL` / `PASSWORD`. Its design lives in the private CI repository and is intentionally not described here.

---

## Ongoing workflow after this lands
- Upstream sync: merge upstream, then bump `integration_test/UPSTREAM_BASE` to the merged upstream SHA. The drift check then shows only allowlisted files. If upstream edited an allowlisted file, resolve the conflict, keeping the fork delta minimal.
- New fork-specific tests go in **new files** with an allowlist entry. Never edit an upstream test.
- New upstream tests are picked up by private CI automatically.

## Critical files
  - `integration_test/{UPSTREAM_BASE,FORK_ALLOWLIST,FORK.md}` (new)
  - `scripts/check-integration-test-drift.sh` (new)
  - `.github/workflows/analyze-test.yaml`
  - `scripts/tests/workflow-policy.test.mjs`
  - `integration_test/scenarios/search_email_by_date_time_and_sort_order_relevance_scenario.dart`
  - `integration_test/robots/mobile/mobile_app_grid_robot.dart`
  - `test/features/starting_page/twake_welcome_screen_contract_test.dart`
  - `docs/adr/0117-*.md`
  - `docs/reviews/fork-parity-inventory.csv`
  - Reuse: the `BackendResetRequest` contract in `integration_test/utils/backend_reset_client.dart`

## Security notes for the implementer
- Credentials reach tests only via dart-define on a disposable backend. Keep them out of logs, artifacts and shell tracing.
- Assert the `sessionUrl` origin equals the configured JMAP origin. Do not weaken the app's origin validation to make tests pass.
- No private CI details, backend configuration or credentials belong in this repository. `workflow-policy.test.mjs` must stay green.
