# 117. Keep inherited integration tests at upstream parity

Date: 2026-10-31

## Status

Accepted

## Context

NumberInbox uses OTP login while upstream uses basic-auth login UI. After OTP,
the ordinary JMAP credential storage contract is the same. Rewriting inherited
scenarios adds avoidable merge conflicts and can weaken their assertions.

## Decision

Pin the full last-merged upstream SHA in `integration_test/UPSTREAM_BASE`.
Enforce an explicit, reasoned `FORK_ALLOWLIST` in public CI, rejecting unknown
differences and stale exceptions. Keep inherited formatting. New fork tests belong
in new files; backend/OTP UI drivers remain private. Run inherited scenarios
through their unchanged credential-seeding seam against a disposable private
backend using OTP-issued credentials. Retain the public web/James gate.

Keep only package identity, configurable deliverable recipients, fail-closed reset,
store capture and bookkeeping exceptions. Draft generic improvements for upstream
without opening PRs automatically. Document demonstrated backend capability gaps
in a private skip list; never skip an actual app defect or silently edit assertions.

## Consequences

Upstream syncs must update the base to the commit actually merged and recheck
minimal differences. The default checker validates committed trees; `--worktree`
also validates local edits and new files before committing. Public contract tests
protect stable widget keys without exposing private drivers or runtime values.
Real private Android execution remains a separate release gate; unit tests do not
stand in for an unexecuted or failed device suite.
