# NumberInbox iOS release record

Last checked: 2026-09-25. This record distinguishes a successful local build from a tested, signed production release. Do not mark a gate complete without recording its build number, environment, and result.

## Current evidence

| Gate | Result | Evidence or next check |
| --- | --- | --- |
| iOS project and minimum version | Pass | Xcode 27 reads the project; all iOS targets use deployment target 15.0. |
| Unsigned device build | Pass | `flutter build ios --release --no-codesign --no-pub` built `build/ios/iphoneos/Runner.app`. This is not installable through TestFlight. |
| Bundle and extensions | Pass locally | Built bundle ID is `com.numberinbox.app`; the share and notification extensions are embedded. Check their IDs again in the signed archive. |
| App Group | Pass locally | Built `AppGroupId` is `group.com.numberinbox.app`, matching the three targets' entitlements. Confirm the capability and provisioning profiles in the Apple team. |
| Required-reason privacy manifests | Pass locally | Runner and notification extension bundle `PrivacyInfo.xcprivacy` for App Group `UserDefaults` (`1C8F.1`); bundled third-party manifests are present. Generate and review Xcode's combined privacy report from the final archive. |
| Distribution signing and TestFlight | Pending | This machine has no valid code-signing identity and no App Store Connect API environment credentials. Run the existing Fastlane release lane with the correct Match repository access and verify the uploaded build. |
| Production backend | Pending | Account-deletion backend commit `29b071c` was pushed to `numberinbox/platform` main. The required GitHub Actions `Deploy` workflow has not been triggered or verified. Do not deploy by SSH. |
| Public privacy and deletion pages | Pending | Site redesign is local. On 2026-09-25, `https://numberinbox.com/privacy` and `/delete-account` failed TLS negotiation (`ERR_SSL_PROTOCOL_ERROR`) from this machine; DNS resolved to `34.215.46.88`. Resolve domain/hosting and recheck from another network after deployment. |
| Privacy contact | Pending | Verify `privacy@numberinbox.com` receives a message and can reply. An MX response was not confirmed from this machine. |
| 30-day backup retention | Pending | Verify actual backup expiry and restore handling before publishing the promise below. |
| Clean-device production flow | Pending | Record device, iOS version, build, and results for OTP login, receive/send mail, push, account deletion, failure/retry, and a fresh empty mailbox after deletion. The account deletion test is reserved for the owner's post-deployment run. |
| Reviewer access | Pending | Provision a dedicated real phone number and populated mailbox. Test the exact OTP instructions on a clean iPhone without a private team phone; keep the account available throughout review. |
| App Store Connect | Pending | Confirm app record, bundle/capabilities, signed build, product-page metadata, actual-app screenshots, support/privacy URLs, age rating, App Privacy answers, encryption/export answers, availability, and reviewer contact. Submit only the tested build. |

## Unpublished 30-day policy draft

Use this text on both public pages **only after** production backup expiry and restore procedures have been verified:

> Backup copies are not removed immediately when you delete an account. They expire within 30 days. If a backup is restored during that period, we reapply completed deletion requests so deleted account data does not return to active service storage.

The restore sentence is part of the promise: verify it before use. If the actual procedure differs, revise the copy to match the deployed behavior rather than publishing it unchanged.

## Submission record

| Item | Value |
| --- | --- |
| Git commit and app version/build | Pending |
| TestFlight build and install date | Pending |
| Production API and JMAP URLs tested | Pending |
| Privacy and deletion URLs tested | Pending |
| Reviewer mailbox and access instructions | Pending; keep credentials out of this file |
| Production smoke-test result | Pending |
| Account deletion and fresh-mailbox result | Pending |
| Backup expiry and restore verification | Pending |
| App Store Connect submission ID/date | Pending |
