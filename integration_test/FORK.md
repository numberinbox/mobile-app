# Integration-test upstream parity

Keep inherited files byte-identical to the commit in `UPSTREAM_BASE`, except for
paths in `FORK_ALLOWLIST`. Every exception needs a reason; identical entries must
be removed. A trailing `/` allows only descendants of that exact folder, and a
folder exception becomes stale when none of its descendants differs from upstream.

Fork-only tests live in `integration_test/numberinbox/`. Add new files there;
never rewrite inherited scenarios to match NumberInbox. This folder owns the OTP
login, cold-relaunch, phone-recipient and deletion flows, plus the separate store-capture helper.
Runtime numbers, OTPs, credentials, service URLs and private backend configuration
must not be committed. Tests receive disposable inputs through dart-defines (or
the capture helper's existing externally supplied environment inputs).

Private CI owns device orchestration, fixture setup, the backend test-stack pin,
and store signing. It runs the inherited suite through its existing credential-
seeding seam and runs the NumberInbox OTP targets against that pinned disposable
test stack. It contains no Dart tests. Public CI analyzes the test code and retains
the web/James gate; it has no token for dispatching private device jobs.

The OTP targets are separate instrumentation stages. Invoke each explicit
`numberinbox_*_test.dart` target, preserving app data for the cold-relaunch stage.
Do not recursively bundle `numberinbox/`: the nested store-capture helper uses a
different test binding and is run only by its capture workflow. The OTP targets
are not selected by the inherited suite's `--tags=android` filter.

The app-grid and fail-closed reset improvements have draft upstream proposals in
`docs/reviews/integration-test-upstream-proposals.md`; none has been submitted.

## Upgrading

Merge upstream, set `UPSTREAM_BASE` to the **full SHA actually merged**, and run:

```sh
bash scripts/check-integration-test-drift.sh --worktree
```

Review each remaining difference and remove stale allowlist entries. Keep changes
minimal, including inherited formatting. After committing, run the checker without
`--worktree`, as CI does. The checker fetches the public pinned commit if missing;
no named remote or private authentication is required. Never bump the base to an
unmerged commit to conceal drift.
