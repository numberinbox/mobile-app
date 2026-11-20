# Upstream synchronization verification

## Revisions and scope

- NumberInbox baseline is `1222fa0cb4fac27e03e281fc8b3973941556ba8f`.
- Upstream target is `c7dbf069255d2a44a7797dd4ac58afb4234cc71e`.
- The target includes 172 upstream commits beyond the NumberInbox baseline, including the previously prepared November 15 sync.
- The Stalwart raw-header fix is upstream commit `420d0db43d` from PR #5146. Mailbox, update, calendar, detail, cache, and mailing-list paths use the upstream implementation.
- Upstream's delegation package, Settings and account-switcher changes, Android Workplace browser sign-out, and web focus workaround are incorporated.

## Merge resolutions

- Retained NumberInbox OTP, recipient handling, account deletion, account isolation, notification delivery and presentation, source-link policy, branding assets, and primary-action palette.
- Settings retains About and Delete account alongside upstream's new capability-controlled delegation entry.
- Main retains the light system-bar region around upstream's FocusScope and state-owned SmartDialog builder. Removed the superseded duplicate top-level builder.
- Kept NumberInbox release identity. Existing checkout release-version edits were restored after applying the merge and compared against the saved patch.
- Pinned `linagora_design_flutter` to `bdc3dc62e885805fd352b259c0f2c59a7dfc5701`, the upstream `feature/ds-4-empty-card` branch revision required by its new delegation UI. The prior pin produced four undefined-member analyzer errors.
- Applied the established teal accent to the new delegation Settings SVG. The existing settings-accent test failed before this correction and passes in the final suite.
- Retained the public Android tunnel runner's deletion, as required by fork commit `962b3a35c0`, ADR 0117, and workflow-policy tests. The public web/James runner remains available.
- Updated integration_test/UPSTREAM_BASE to the exact upstream target. Inherited integration-test targets match that target. Existing documented fork exceptions remain.
- Adapted new upstream OIDC tests to the NumberInbox callback scheme and the existing fork Settings test to the new menu-controller dependency. Assertions remain enforced.

## Verification

Preparation used Flutter 3.47.9 / Dart 3.13.7 through `./scripts/prebuild.sh`.

| Check | Result |
| --- | --- |
| Root `flutter test --no-pub --reporter expanded` | 5,904 passed, one opt-in capture test skipped |
| Core package suite | 2,695 passed, one skipped |
| Model package suite | 182 passed |
| Delegation package suite | Six passed |
| Chrome raw-header, cache and unsubscribe suites | 16 passed |
| Node script and workflow-policy suites | 19 passed |
| Python script suites | 47 passed with localhost access |
| Notification icon tooling | One passed |
| Integration drift check against target | Passed |
| `flutter analyze --no-pub` | Zero errors. Same 90 diagnostics as the previously verified sync, comprising one legacy-plugin warning and 89 informational diagnostics |
| iOS debug simulator build | Passed |
| Android debug build | Passed |
| Web build | Passed |
| Whitespace and conflict checks | Passed |

Verification logs are under `/private/tmp/ni-sync-nov20-*.log` on the review machine.

## Remaining release verification

- The private mobile-ci Android and iOS workflows still pin Flutter 3.38.9. They need the synchronized app's compatible SDK before exact-revision integration validation.
- These local checks do not verify a live Stalwart 1.1.1 upgrade. Before rollout, complete the tracked mailbox, refresh, mailing-list, normal submission, and read-receipt submission checks in `docs/plans/stalwart-1x-upgrade-blocker.md`.
- Physical-device notifications, signed store builds, and production rollout were not exercised by this synchronization.

The reviewed tree was applied to the main checkout as an uncommitted merge with MERGE_HEAD at the upstream target. The existing release-version changes remain unstaged, and the pre-existing incident document is retained.
