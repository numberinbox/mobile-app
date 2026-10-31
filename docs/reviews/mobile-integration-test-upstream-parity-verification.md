# Integration-test parity verification — 2026-10-31

## Public implementation

Started at `df24c3928`, which contains the approved upstream merge. There were no
uncommitted code changes to revert. Preserved the supplied plan and local audit
documents. Used `codex/integration-upstream-parity` rather than starting from an
older local master and losing the merged upstream baseline.

Pinned upstream `9a89aabdf3d05214a676eea3745972e1f0f8b5a9`. The inherited harness
has five approved differing files plus three bookkeeping files. Retained app-grid
identifier-only changes and fail-closed reset behavior. Restored upstream search
scenario formatting while keeping configurable recipients and the original
five-message fallback. Added draft upstream proposals; none was opened/submitted.

The checker validates committed trees in CI, fetches the pinned public commit if
missing without a named remote, rejects unexpected additions/deletions/edits and
stale exceptions, and logs paths rather than contents. `--worktree` also covers
pending/untracked local files for pre-commit verification. Private injected
runtime targets must not be checked as public worktree files.

Existing OTP/country-sheet and reader navigation tests already protected several
keys. Added the required contract comments, a real settings-widget deletion-key
test and an explicit deletion input/action type check. App code was unchanged.
ADR 0117 and the inventory record the allowlist policy.

## Verification

- `./scripts/prebuild.sh`: passed. Generated timestamp-only ARB changes were
  removed; merged localization text was preserved.
- `flutter analyze --no-pub integration_test test/features/starting_page test/features/manage_account/presentation/menu/settings/settings_first_level_view_contract_test.dart`:
  45 inherited deprecation infos; no warnings/errors.
- Focused OTP/startup, deletion, settings selector, reader-back and generic
  integration-harness suites: **114 passed**.
- `node --test scripts/tests/*.test.mjs`: **16 passed**.
- `bash scripts/check-integration-test-drift.sh --worktree`: passed.
- Both actual local negative probes passed: an inherited non-allowlisted edit was
  refused by path; an unchanged added allowlist entry was refused as stale. Each
  probe was reverted in `finally`. Fixture tests also cover committed additions,
  deletions, modifications, invalid bases/paths, a failed public-base fetch without a named remote, and diagnostic content exclusion.
- The checker tests were first run before implementation and failed on absent
  checker behavior; the completed implementation passes. A settings-test setup
  failure required localization delegates; no app change was made to fix it.
- Public web discovery remains `--target integration_test/tests --tags=web`,
  preserving the existing James gate and excluding store-capture binding setup.

Real private Android/backend execution and fault-injection results are recorded
privately. These public unit/static checks do not claim a device-suite pass or
waive any exact-source CI/release gate. No push or review replies are authorized
by this implementation plan.
