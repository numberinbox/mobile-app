# ADR 0127: Visible OTP sign-in failures after the code is accepted

Date: 2026-11-14. Status: implemented for review; device verification pending.

A user entered a valid OTP and stayed on the Verify screen with no message while
on an unstable network. After the OTP request succeeds, `TwakeWelcomeController`
keeps Verify loading until the JMAP session fetch finishes. A session failure
caused by an urgent exception (no network, connection error, bad credentials) is
routed by the inherited `BaseController` straight to `handleUrgentException`,
bypassing the controller's failure handler, so no message was set and no rebuild
was triggered. The shared network client also sets no timeout, so a stalled
session request never ended.

Change (NumberInbox-owned `TwakeWelcomeController` only): every
`GetSessionFailure` now clears loading, sets a fixed retryable message and
rebuilds; connection problems say "No connection. Check your network and try
again." and others keep "Failed to sign in. Please try again."; urgent failures
are logged once as an error event with the failure category only; a 30 second
controller-local timer ends a stalled session fetch with the same message. The
inherited urgent handling still runs, and a late successful session still
navigates to the inbox.

Not changed: `BaseController`, `ReloadableController`, the shared network client
and Sentry initialisation.

## Deferred (not approved)

Mobile Sentry starts only after sign-in, from the server ecosystem config in
`MailboxDashboardController`, so pre-login errors, including OTP failures, are
probably not reported. Initialising Sentry before sign-in would touch inherited
initialisation and consent logic, and needs explicit approval, its own ADR, and
an upstream proposal first.
