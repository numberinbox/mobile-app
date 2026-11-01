# 118. Enable Sentry crash reporting for NumberInbox

Date: 2026-11-01

## Status

Accepted. This is a deliberate divergence from upstream, which ships Sentry switched off.

## Context

- The app already contains the Sentry SDK, the consent gate and the release steps that upload debug symbols. Upstream ships them disabled in `env.file`.
- Release builds are obfuscated, so crash stack traces are unreadable without uploaded symbols.
- NumberInbox now has its own Sentry project in the EU region.

## Decision

- Set `SENTRY_ENABLED=true`, the project DSN and `SENTRY_ENVIRONMENT=production` in `env.file`.
- Change no code. The consent gate is unchanged: on iOS and Android reporting stays denied until the user opts in under Preferences.
- Debug-symbol upload in the private release workflow is configured with `SENTRY_ORG`, `SENTRY_PROJECT` and `SENTRY_AUTH_TOKEN`.

## Consequences

- The DSN is public inside the app and in this repository. It only accepts events; it cannot read them. Anyone could send junk events, so use Sentry's inbound filters and rate limits if that happens.
- A web build would report by default (`isReportingAllowed` is true on web). The fork ships iOS and Android only; revisit this before shipping a web build.
- Merging upstream changes to `env.file` conflicts on these three lines. Keep this decision.
