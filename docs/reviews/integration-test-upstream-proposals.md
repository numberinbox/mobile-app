# Draft upstream proposals (not submitted)

## Parameterize mobile app-grid identifiers

The mobile app-grid robot embeds Android/iOS identifiers, preventing branded
forks from reusing it unchanged. Add `AppConstants.iosBundleId` with upstream's
existing iOS identifier, and read `AppConstants.appId` / `iosBundleId` in the
robot. Keep upstream defaults and all navigation assertions unchanged. Verify
Android/iOS app-grid return-to-app behavior. The NumberInbox fork keeps its small
identifier-only exception until an upstream implementation is merged.

## Fail integration teardown when backend reset fails

A failed fixture reset currently risks cross-test contamination with a green
teardown. Keep unset `RESET_SERVER_URL` as a no-op and require HTTP 200 when enabled.
Propagate one sanitized failure on HTTP, connection and timeout errors; never
retain response bodies, headers, credentials or URLs. Close the owned Dio client
in `finally`. Preserve the reset signature. Cover disabled reset, success, non-200,
connection failure and timeout through the small request boundary; retain the
existing James reset endpoint contract. Remove the fork exception after upstream
accepts equivalent behavior and the stale-entry checker identifies parity.
