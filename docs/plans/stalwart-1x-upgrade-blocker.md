# Stalwart 1.x upgrade blocker

Recorded November 17, 2026. Revisit the production upgrade to Stalwart 1.1.1 or a later release after the Twake Mail fix lands and the candidate app passes the checks below.

Updated November 20, 2026. Upstream merged [PR #5146](https://github.com/linagora/tmail-flutter/pull/5146) on November 19, 2026. It uses raw List-Unsubscribe and List-Post headers and retains compatibility with older cached values. The upstream sync prepared on November 20 includes the merged fix through upstream revision c7dbf069255d2a44a7797dd4ac58afb4234cc71e. Complete the checks below on the distributed NumberInbox build before retrying the backend upgrade.

## Known issue

Twake Mail requests `header:List-Unsubscribe:asText` in the Inbox's `Email/get` call. Stalwart 1.x rejects that form with `invalidArguments`. The mailbox count comes from a separate call and can succeed while the message list is empty. In the local Stalwart 1.1.1 reproduction, the raw and `asURLs` forms returned both test messages.

- [Twake Mail issue #5129](https://github.com/linagora/tmail-flutter/issues/5129) documents the same failure on Stalwart 1.0.3.
- [Twake Mail PR #5146](https://github.com/linagora/tmail-flutter/pull/5146) is the merged upstream fix. The earlier alternative [PR #5123](https://github.com/linagora/tmail-flutter/pull/5123) remains open as of November 20.
- The composer also writes `Return-Path:asText` when requesting a read receipt. The local reproduction confirmed rejection of this form on reads. The actual composer write and submission still need verification. This path is outside PR #5123.

## Before retrying the upgrade

1. Confirm the upstream fix has merged and is included in the exact NumberInbox build being tested.
2. Against the intended Stalwart version in a disposable environment, use the candidate app to load an Inbox seeded with two messages. Verify the count and both rows, then refresh after new delivery and after changing a message.
3. Open a mailing-list message and verify the unsubscribe and Reply to list controls still work.
4. Test normal sending and sending with a read receipt requested. Check the actual JMAP `Email/set` and `EmailSubmission/set` results and verify delivery. Investigate any remaining `Return-Path` failure before upgrading.
5. Verify that app versions already distributed to users can load mail against the candidate server, or plan the client rollout before upgrading the shared backend.
6. Record the app revision, Stalwart version, and test results before scheduling production rollout.
