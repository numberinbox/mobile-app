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
| Production backend | Pending | Account-deletion backend commit `29b071c` was pushed to `numberinbox/platform` main. The documented direct-IP `/health` returned `{"status":"ok"}`, but the required GitHub Actions `Deploy` workflow has not been triggered or verified. Do not deploy by SSH. |
| Public privacy and deletion pages | Pending | Site redesign commit `00be5ba` was pushed to `numberinbox/site` main. This network redirects the domain to a Zscaler block page, causing DNS/TLS failures; it cannot verify whether the hosting integration published the pages. Recheck HTTPS and both routes from an unblocked network. |
| Privacy contact | Pending | Verify `privacy@numberinbox.com` receives a message and can reply. This network's DNS interception prevents an authoritative MX check. |
| 30-day backup retention | Pending | Verify actual backup expiry and restore handling before publishing the promise below. |
| Clean-device production flow | Pending | Record device, iOS version, build, and results for OTP login, receive/send mail, push, account deletion, failure/retry, and a fresh empty mailbox after deletion. The account deletion test is reserved for the owner's post-deployment run. |
| Reviewer access | Pending | Provision a dedicated real phone number and populated mailbox. Test the exact OTP instructions on a clean iPhone without a private team phone; keep the account available throughout review. |
| App Store Connect | Pending | Confirm app record, bundle/capabilities, signed build, product-page metadata, actual-app screenshots, support/privacy URLs, age rating, App Privacy answers, encryption/export answers, availability, and reviewer contact. Submit only the tested build. |

## Unpublished 30-day policy draft

Use this text on both public pages **only after** production backup expiry and restore procedures have been verified:

> Backup copies are not removed immediately when you delete an account. They expire within 30 days. If a backup is restored during that period, we reapply completed deletion requests so deleted account data does not return to active service storage.

The restore sentence is part of the promise: verify it before use. If the actual procedure differs, revise the copy to match the deployed behavior rather than publishing it unchanged.

## App Store Connect copy draft

These fields are ready for review but must be entered and checked against the final TestFlight build:

- **Name:** NumberInbox
- **Subtitle:** Email with your number
- **Primary category:** Productivity
- **Privacy Policy URL:** `https://numberinbox.com/privacy`
- **Support URL:** `https://numberinbox.com/privacy#choices` (contains the public privacy contact; verify it resolves for reviewers)
- **Description:** “NumberInbox gives your phone number an email mailbox. Sign in with a one-time code, read and manage your mail, get notifications when enabled, and delete your account from Settings. Your NumberInbox address uses your number, so people can reach your inbox without a new username.” Verify every claim in the production build before publishing.
- **Screenshots:** Capture the real TestFlight app on the required iPhone sizes after the production login and mail flows pass. Do not submit the brand-board mockups as app screenshots.
- **Review notes:** Explain the dedicated reviewer number, how the reviewer receives its live OTP without team assistance, the populated test mailbox, and where to find Settings → Delete account. Do not put credentials or OTPs in this repository.

Complete the current age-rating questionnaire, App Privacy responses (including the app and its third-party SDKs), encryption/export questions, pricing/availability, and reviewer contact in App Store Connect. These answers require the final production configuration; the draft does not pre-answer them.

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
