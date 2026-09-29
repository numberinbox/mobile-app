# Fix composer recipient state regressions with TDD

## Summary

Fix the three confirmed regressions caused by changing composer recipient getters to return snapshots: initial To addresses are discarded, unfinished typed addresses are not committed, and picker changes leave the Send button state stale. Keep the reactive recipient lists and the contact deduplication and layout work already completed.

## Implementation

- **Initial recipients:** In `setup_email_recipients_extension.dart`, replace both `listToEmailAddress.addAll(...)` calls with assignments through the setter, combining existing and incoming addresses. The method's existing final `updateStatusEmailSendButton()` remains responsible for Send state during setup.
- **Typed recipients:** In `auto_create_tag_for_recipients_extension.dart`, pass the combined existing and parsed addresses to `updateListEmailAddress(type, ...)` instead of mutating the getter result. Remove the now-redundant Send-state update. Preserve address filtering, deduplication, tag-editor reset, and suggestion closing.
- **Picker results:** In `applyContactPickerResult`, commit both empty and nonempty results through `updateListEmailAddress(prefix, ...)`. Preserve `null` as cancel, authoritative replacement on Done, and existing display-name retention. This updates the recipient list, observer, and Send state through one path.
- Audit all composer recipient getter usages for other in-place mutations. Convert any remaining mutation of a snapshot to an explicit controller update; leave read-only uses intact.

## TDD and verification

1. Add failing controller tests before changing production code:
   - `ComposerArguments.fromEmailAddress` and `fromMailtoUri` populate To; mailto Cc/Bcc remain intact.
   - Auto-tagging a valid address still in the To input commits it and enables Send. Cover adding it beside an existing recipient and the equivalent Cc/Bcc/Reply-To path.
   - Picker Done adding the first To recipient enables Send; Clear removing the last To recipient disables it; clearing To while Cc remains populated keeps Send enabled.
   - Picker cancel changes neither recipients nor Send state. Assert each committed picker result produces one recipient-state notification.
2. Implement the three changes, rerun those tests, then run the focused composer controller, recipient widget, contact, and identity tests.
3. Run `flutter analyze --no-pub` and the repository's full Flutter test script. Report pre-existing analyzer findings separately from findings in changed files. On Android and iOS, smoke-test compose-from-address, `mailto:`, typing an address then pressing Send, and picker Done/Clear without another screen tap.

## Assumptions

The existing getter-as-snapshot API and canonical recipient deduplication remain. An address typed but not yet converted to a chip must be committed before sending. Send is enabled when at least one To, Cc, or Bcc recipient exists; Reply-To alone does not enable it.
