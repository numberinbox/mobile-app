# Upstream sync verification, November 21, 2026

Baseline is `ff05ae556aa376c52a9c0a4429ea8a52471014a0`. Upstream target is `a8472b30ca8079c4b0ccc53511a7880617394941`.

The four upstream commits add account-switch dialog accessibility, the Delegate/get and Delegate/set data layer, a James fixture image update, and the decisions log. The merge is clean. Integration-test parity is pinned to the new target.

The CI alignment approved in this session enables analysis pushes and device dispatch for main alongside master. A duplicate concurrency block from the prior merge is removed, using pull-request number or branch ref for isolation. Device validation is aligned to the app's branch and SDK while retaining exact-commit checks. Existing NumberInbox version edits and the incident note are excluded from the sync commit.

## Local checks

| Check | Result |
| --- | --- |
| Full root Flutter suite | 5,931 passed, one opt-in test skipped |
| Delegation package suite | 14 passed |
| Analysis | Same 90 diagnostics as the prior sync, zero errors |
| Node script and policy tests | 19 passed |
| Integration-test drift | Passed |
| All workflow syntax, actionlint 1.7.12 | Passed |
| Whitespace checks | Passed |

Preparation used the repository prebuild script with Flutter 3.47.9 / Dart 3.13.7. Logs are under `/private/tmp/ni-sync-nov21-*.log` on the verification machine. Remote CI results must be checked on the exact published commit before claiming device validation or release readiness.
