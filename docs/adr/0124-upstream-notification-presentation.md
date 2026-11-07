# ADR 0124: Upstream notification presentation with NumberInbox branding

Date: 2026-11-06. Status: implemented for review; device acceptance pending.
Supersedes ADR 0123's presentation and action decision.

The owner chose upstream notification design to reduce maintenance and upstream
conflicts. Android uses the existing InboxStyleInformation path: subject title,
JMAP preview body, escaped preview and sender summary, fixed branded large icon.
iOS retains its sender title, subject subtitle and preview body. Small Android
notification artwork is a monochrome N/@ mask; app labels and artwork remain
NumberInbox. Final layout, tinting and truncation are controlled by the OS.

There are no custom notification buttons, generated sender avatars, custom
collapsed fallbacks, or separate preview formatter. Archive, Reply and Mark as
read inside the app remain unchanged. New iOS notifications have no mail-action
category. Old button requests are refused rather than treated as ordinary taps.

Stalwart integration and account-safe taps remain intentional differences: local
metadata carries only version/account/email IDs; it is not authentication. Body
taps require matching authenticated account and session, including after async
lookups. Startup buffering, malformed-target refusal, display-before-cursor,
deduplication, private visibility, generic fallback and logout cleanup remain.
The remote push contract and backend are unchanged.

Use the existing notification-icon resource references and density exports. N/@
legibility requires actual-size status-bar/shade inspection on Samsung and stock
Android; image geometry tests alone are insufficient. No change to launcher,
splash, iOS icon or full-color large-icon artwork is authorized here.

Historical design mockups, implementation reports and preview-spacing verification
remain as history, not descriptions of the restored presentation.
