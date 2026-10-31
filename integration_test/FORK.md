# Integration-test upstream parity

Keep inherited files byte-identical to the commit in `UPSTREAM_BASE`, except for
paths in `FORK_ALLOWLIST`. Every exception needs a reason; identical entries must
be removed. Fork-specific tests belong in new allowlisted files, never edits to
inherited tests. Prefer unit/widget tests outside this directory for public
contracts. No credentials, OTP values, backend configuration or private drivers
belong here.

OTP UI tests stay private. The inherited suite runs in private Android smoke
through its existing credential-seeding seam, using disposable OTP-issued JMAP
credentials. Public CI retains the web/James suite. The app-grid and fail-closed
reset improvements have draft upstream proposals in
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
unmerged commit to conceal drift. Do not run the working-tree check after a private
runner has copied its private targets into a temporary checkout.
