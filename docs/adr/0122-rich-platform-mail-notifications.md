# ADR 0122: Restore rich notifications for platform mail pushes

Date: 2026-11-05
Status: Accepted by owner; mobile implementation pending device verification

The owner requested sender, subject and preview in new-mail notifications, including
when the app is closed. This supersedes M5's generic-only display policy, not its
account isolation, awaited processing, deduplication or notification-tap safeguards.

Mail content never travels through FCM/APNs. The version-1 event keeps its existing
five opaque data fields. The device obtains content through authenticated JMAP and
uses the inherited rich display, including mailbox exclusions and Android HTML
escaping/sender-first expanded metadata. Android lock-screen visibility stays private;
iOS continues to respect system preview settings.

Android displays a local notification only for data-only platform pushes. With the
old backend's notification+data payload it updates the real cursor silently. Display
precedes persistence; failed work stays retriable. A failed data-only background
pipeline gets a fixed generic fallback with the same email notification ID and tap
payload, bounded by a 20-second processing deadline. Deliberately dropped pushes do
not get a fallback. Foreground sync refreshes the real delivery cursor without display.
On iOS that cursor is shared with the extension through the existing keychain session.
Logout clears delivered notifications without allowing plugin failure to block logout.

The iOS notification extension recognizes the same versioned event. Missing sessions,
fetch failures and expiry retain the original generic alert. Email/changes supplies
the cursor and paging flag; Email/get supplies content. Legacy state-change pushes
keep their existing path. No new credential store, dependency or settings toggle.

The backend payload migration is a separate gated rollout: first distribute the
compatible mobile build, then obtain owner confirmation that no relevant older
Android builds remain. Only then change Android to high-priority data-only FCM and
add the iOS mutable-content generic APNs alert. Never deploy that change first.

A push is dropped without a fallback only on evidence of sign-out or an account
change. A storage or lookup error counts as a failure, so the user still gets the
generic text. A delivery cursor older than the server's change history
(`cannotCalculateChanges`) moves to the current server state on both platforms: that
push stays generic and later pushes return to rich display.

Limitations: force-stop and OS process termination can prevent data-only display.
Physical-device checks must cover cold/background/foreground delivery, grouping,
network fallback, tap navigation, mailbox exclusion, logout, hidden lock-screen
content and Samsung battery saver. Empty iOS extension output requires device
verification; use a generic alert instead if iOS displays a blank notification.
