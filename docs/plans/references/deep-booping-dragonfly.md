# Gmail vs NumberInbox notifications: research and proposed changes

## Context

The new rich push works on a real Android phone (screenshot, 3:06 PM on 6 Nov). It still looks unlike Gmail, and you asked what we're missing before anything is built. This is research plus a proposed order. Nothing has been changed.

## What Gmail does

**Android**
- Header: app name, account, time.
- Title: sender's name. Then subject, then a short snippet.
- Right side: the sender's picture ([Storyboard18](https://www.storyboard18.com/amp/digital/gmail-may-soon-let-you-view-new-attachment-previews-in-android-notifications-84700.htm)).
- Buttons: Reply, plus Archive or Delete (the user picks which), plus Mark as read since 2025 ([9to5Google](https://9to5google.com/2025/08/15/gmail-mark-as-read-android/), [Google Workspace Updates](https://workspaceupdates.googleblog.com/2025/09/better-notifications-gmail-android-ios.html), [Google Help](https://support.google.com/mail/answer/2819492?hl=en)).
- Attachments (reported Nov 2025 as a gradual rollout, current status unverified): paperclip before the subject, image thumbnail replaces the avatar, file name pill for PDFs ([Storyboard18](https://www.storyboard18.com/amp/digital/gmail-may-soon-let-you-view-new-attachment-previews-in-android-notifications-84700.htm)).

**iOS**
- Reply and Archive from the notification since 2015; more actions through long press since 2019 ([TechCrunch](https://techcrunch.com/2015/03/05/gmail-app-now-offers-reply-and-archive-from-notifications-on-ios/amp/), [Google Workspace Updates](https://workspaceupdates.googleblog.com/2019/03/take-action-faster-with-customizable.html)).
- Google announced sender avatars on iOS in Sept 2025, without saying whether they appear in notifications ([Google Workspace Updates](https://workspaceupdates.googleblog.com/2025/09/better-notifications-gmail-android-ios.html)).

**Not confirmed by any source**
- The exact button order: sources disagree on where Mark as read sits.
- No page gives a full layout spec, and I have no fresh Gmail screenshot (the two you sent earlier are no longer on disk). A new Gmail screenshot from your phone, expanded, would settle both.

**Android's own guidance**
- The large icon is "usually used only for contact photos", and the docs say not to use it for the app icon ([Android](https://developer.android.com/develop/ui/compose/notifications)).
- Up to three action buttons ([Android](https://developer.android.com/develop/ui/views/notifications/build-notification)).
- The small icon is drawn from its alpha mask only, so colours are dropped ([OneSignal](https://documentation.onesignal.com/docs/notification-icons), third-party; the Android pages I read don't cover it).

## What we're missing

| # | Gap | Gmail | NumberInbox today | Where in our code |
|---|---|---|---|---|
| 1 | Title | Sender name | Subject | `email_change_listener.dart:381` |
| 2 | Sender position | Title line | Header row via `summaryText`, which truncates the app name to "Numb…" | `local_notification_manager.dart:179` |
| 3 | Body | Subject, then snippet | Preview only; `InboxStyle` cuts each line to one line | `local_notification_manager.dart:172` |
| 4 | Right-side image | Sender's picture | Our app logo, which Android advises against | `local_notification_config.dart:41` |
| 5 | Left icon | Gmail "M" glyph | "N" silhouette with no "@" | `drawable-*/notification_icon.png` |
| 6 | Buttons | Reply, Archive or Delete, Mark as read | None on Android or iOS | `local_notification_config.dart` |
| 7 | Attachment hints | Paperclip, thumbnail | None | Not built |

**About your "@" point:** I read this as "our N has no @ sign". I checked the icon file: it's a plain N shape with no @ cut out. The @ only appears in the full-colour logo on the right. Tell me if you meant something else.

**Correction to my mock:** Gmail's side showed Archive and Reply but left out Mark as read, and I drew it from memory. The buttons are a real gap, listed as #6.

**iOS is mostly fine already:** `NotificationService.swift:217` uses sender as title, subject as subtitle and preview as body, the same order as Gmail. It's only missing buttons and an avatar. This is unverified on a real iPhone.

## Proposed changes, in order

All in `numberinbox/mobile-app`. Each ships only with a new store build. No backend change, and the push payload stays free of mail content.

**Step 1: layout (gaps 1 to 3). Small, and most of the visual difference.**
- Title is the sender. Body is subject then preview. Switch `InboxStyle` to `BigTextStyle` so the preview can wrap.
- Header goes back to "NumberInbox · time", with no sender in `summaryText`.
- Keep the HTML escaping and private lock-screen visibility.
- Tests: extend the existing `LocalNotificationManager` style tests first.

**Step 2: icons (gaps 4 and 5). Small.**
- Right side: a round initials avatar drawn on the device from the sender's name, using the app's existing avatar colours. No network lookups, because fetching a remote picture would tell a third party that the mail arrived.
- Left side: try an N with an @ cut-out, and check it on a real phone. At 24dp the @ may be unreadable, in which case keep the plain N.

**Step 3: buttons (gap 6). The largest piece, and a separate change.**
- Android: Mark as read, Archive, Reply. iOS: the same through notification categories.
- Reuse `mark_as_email_read_interactor.dart` and `move_to_mailbox_interactor.dart`. Reply opens the composer.
- `flutter_local_notifications` 17.2.2 has an action API, but we have no `onDidReceiveBackgroundNotificationResponse` handler today. It runs in a background isolate, so it needs its own session and JMAP setup, like `fcm_receiver.dart`.
- Risks: acting with the app closed needs testing on a device, and the action must check the signed-in account before touching mail.

**Not proposed yet:** attachment hints (gap 7). They need a JMAP attachment fetch and thumbnail download inside the short push budget, and Gmail's own rollout is unconfirmed.

## Decisions for you

1. **Display name or address as the title?** Gmail shows the name. We show the address first on purpose (commit `6f0995c72`) so a spoofed name can't hide it, and we accept mail from any sender. My recommendation: name as the title when there is one, with the address on the first body line when expanded. That looks like Gmail and still exposes spoofing.
2. **Which button set?** Recommendation: Mark as read, Archive, Reply. Delete is left out because it's harder to undo.

## Verification

- `flutter test` for the touched features, then the mobile CI run on master.
- Real Android phone: app closed, app open, and locked. Test mails: with a display name, without one, a long subject, a spoofed name, two mails at once (group summary).
- Real iPhone for the extension and the buttons.
- Check that a test mail produces a normal `push_send_total{status="accepted"}` count and no `invalid_payload`.
- Plan and test notes go in `docs/plans/` in the platform repo, and the fork divergence goes in a new ADR under `mobile-app/docs/adr/`.
