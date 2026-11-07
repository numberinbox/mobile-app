# ADR 0123: NumberInbox mail notification presentation and actions

Date: 2026-11-06. Status: superseded by ADR 0124.

The custom sender-first layout, initials avatars, and notification action buttons
below describe historical behavior. The owner selected upstream presentation with
NumberInbox branding instead. Account-safe taps and platform delivery remain.

The owner authorized the complete notification-design plan, including its later
avatar/action phases, on the default branch with no commit. This is an explicit
NumberInbox presentation and feature divergence; inherited shared defaults remain.

Android rich mail opts into an address-first BigText layout: sender title, subject
collapsed text, and optional display name/subject/preview in expanded text. Sender
HTML is escaped, directional controls are removed using the existing display helper,
and no sender summary competes with the system app-name header. Generic fallback
text, account/group identifiers, dedup, cursor ordering, privacy and sound rules stay.

A local 96px initials avatar uses the existing solid brand accent and white foreground.
It needs neither contacts nor network access. Unicode graphemes are preserved; empty
or failed rendering omits the large icon. Rendering is bounded by a 150ms optional
budget inside the existing push deadline. Group summaries and generic fallback have
no large image. The shared helper still defaults to its inherited icon/style unless
explicitly overridden. The current monochrome N remains: adopting a denser N/@ mask
is conditional on real Samsung/status-bar legibility evidence, not an automatic swap.

All three actions—Mark as read, Archive, Reply—use the plan's **foreground/unlock**
option. Android opens the app; iOS categories require foreground and authentication.
There is no background action isolate, new authentication implementation or retry queue.
This choice minimizes conflicts and avoids a native Android authentication-required
API fork in the pinned notification plugin. Actions are localized through existing
labels. Button labels use the app's loaded locale; a notification built while the app
is started headless by a push has no loaded locale and shows English, as the existing
group summary already does. Unknown sender has an English fallback through the existing
localization tool. When an account has no Archive folder, the Archive button says so
instead of failing generically.

Only a versioned local account/email target is attached to rich mail notifications.
The remote push contract is unchanged. Action IDs are allowlisted; malformed or stale
account-bound requests do not fall through to legacy mail opening. Cold iOS responses
are buffered until the authenticated dashboard is ready; Android retains its existing
launch-details path, with a small startup buffer for early local responses.

The active account is checked before processing and after async operations. Fresh
JMAP reads use existing repositories, and mutations use existing read/move interactors.
Mark as read requires exact success plus read-back. Archive resolves standard roles,
removes Inbox preferentially, preserves other memberships, and treats already-archived
labelled mail as a no-op. Reply uses the existing composer, which fetches original
content through its existing flow; it never sends automatically.

Android mutation actions retain the notification until confirmed success. Dismissal
and a silent group-summary update follow success. iOS delivered remote notifications
are removed by matching their local account/email metadata. The OS may itself dismiss
an iOS alert when its action is chosen; we do not promise Android-style retention on
iOS failures. Foreground failure uses existing generic error feedback. No mutation is
automatically retried after a timeout; already-submitted server operations cannot be
recalled, and a user retry starts from fresh state. Repeated in-flight/completed taps
are bounded/deduplicated in the dashboard's memory, without storing credentials.

Native spacing, icon tint, truncation, action visibility and lock-screen behavior stay
OS-controlled. Real-device delivery, unlock/cold-start actions and headless avatar
rendering remain release checks. Attachment thumbnails, inline reply sending, remote
photos, backend changes, dependency upgrades and upstream sync are excluded.
