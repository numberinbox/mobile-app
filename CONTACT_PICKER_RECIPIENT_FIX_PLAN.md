# Fix contact duplication, picker synchronization, and composer recipient layout

## Summary

Correct the three mobile composer regressions as one recipient-state improvement:

- Show one contact row per canonical deliverable address.
- Apply contact-picker changes immediately, including deselection and clearing.
- Keep the recipient input and chips inside their available space without overlapping Contacts or expand controls.
- Preserve existing mail behavior, autocomplete, search filters, To/Cc/Bcc/Reply-To semantics, routes, package IDs, and native contact permissions.
- Keep `super_tag_editor` unchanged, using the selected app-level layout workaround.

## Implementation

### 1. Canonical recipient identity and contact deduplication

Add a shared internal recipient identity utility used by device contacts, autocomplete, picker selection, and composer merging.

- Expose:
  - `canonicalRecipientKey(String address)`
  - `deduplicateRecipients(Iterable<EmailAddress>)`
  - An equivalent helper for `Contact`/`DeviceContact` before conversion where needed.
- Trim surrounding whitespace and compare email addresses case-insensitively, matching the repository's existing normalized-email behavior.
- For `@numberinbox.com` addresses, normalize a valid phone local part through the existing phone-number parser and use canonical `+E164@numberinbox.com`.
- Preserve first-seen ordering.
- Retain one entry per canonical address:
  - Keep the first nonempty display name.
  - Replace an empty name when a later duplicate has a useful name.
  - Never deduplicate by display name; one contact with two different numbers remains two rows.
- Apply deduplication:
  - After flattening platform contacts in `lib/features/composer/data/datasource_impl/contact_datasource_impl.dart`.
  - When combining server and device autocomplete results.
  - When loading `allDeviceContacts` and test-injected contact lists.
  - Before returning or applying picker selections.
- Use the canonical key for picker checkbox state, select, delete, list item keys, and composer duplicate detection. This removes repeated rows and ensures one logical checkbox represents one recipient.

### 2. Make picker results authoritative and reactive

Replace the current plain-list update path in `lib/features/composer/presentation/composer_controller.dart` with reactive storage while preserving its public `List<EmailAddress>` getter/setter interface.

- Store To, Cc, Bcc, and Reply-To internally as private `RxList<EmailAddress>` values.
- Keep existing public list getters returning growable snapshots, so current widgets, tests, and generated mocks remain compatible.
- Keep setters, but implement them with canonical deduplication followed by `assignAll`.
- Route all initialization, draft restoration, identity-based Bcc changes, manual edits, autocomplete additions, and picker results through those setters.
- Ensure each composer `Obx` reads the reactive recipient list and passes a fresh mutable snapshot to `RecipientComposerWidget`.
- In `didUpdateWidget`, synchronize the widget's local working list from the new snapshot before rendering. Local tag edits continue to call `onUpdateListEmailAddressAction`, which updates the controller's reactive source.

Change the contact dialog argument from address-only `Set<String>` data to a deduplicated `List<EmailAddress>`:

- Composer callers pass complete recipient objects so display names survive opening and closing the picker.
- Search-filter callers convert their address sets to `EmailAddress(null, address)` and continue converting the returned list back to sets.
- The picker initializes `selectedContactList` from an independent snapshot.
- Done and Clear return `List.unmodifiable(selectedContactList)` so picker lifecycle changes cannot mutate the returned value.

Make dialog result semantics explicit:

- `null`: dialog was dismissed; retain the current recipients.
- `List<EmailAddress>`: complete authoritative selection; replace the current list.
- Empty list: valid result that clears that recipient field.
- Do not union the result with the old list.
- Before replacement, canonicalize and deduplicate it.
- When the returned entry has no display name but the same canonical address already exists, retain the existing nonempty display name.

Extract result application into a testable controller method, used by `openContactPicker`, so null, empty, replacement, and deduplication behavior can be tested without opening a real route.

### 3. Constrain the recipient editor and trailing actions

Restructure `lib/features/composer/presentation/widgets/recipient_composer_widget.dart` without modifying `super_tag_editor`.

- Keep the prefix label first.
- Place `TagEditor` in an `Expanded` region whose width comes from a `LayoutBuilder`.
- Build Contacts and expand/collapse controls inside one trailing action row outside the editor.
- Add an 8-pixel gap between the editor and action row.
- Give every visible action a 48x48 minimum tap target with its 24-pixel icon centered.
- Remove the existing top-only button padding that allows the editor border/focus area to touch the Contacts icon.
- Keep the action row width deterministic:
  - 48 pixels for one visible action.
  - 96 pixels for two visible actions.
- Allow chips and the unfinished recipient input to wrap vertically within the editor's constrained width.
- Keep action controls anchored at the top as the recipient row grows.
- Do not use overlay positioning or clipping as the layout mechanism.
- Preserve To/Cc/Bcc visibility rules and the existing expand/collapse behavior.
- Retain the current `super_tag_editor: 1.1.0` dependency. The application layout and regression tests become the protection against its stale-layout limitation.

## TDD and verification

Implement red-green-refactor in this order.

### Canonical identity tests

- Equivalent formatted phone numbers map to one `+E164@numberinbox.com` entry.
- Three platform records with the same canonical number produce one picker row.
- Duplicate email addresses with whitespace or capitalization differences produce one entry.
- Same display name with different phone numbers remains multiple entries.
- An empty display name is upgraded from a later duplicate with a nonempty name.
- Server and device autocomplete results with the same address appear once.
- Deduplication preserves first-seen order.

### Picker and controller tests

- Selecting one formerly duplicated contact checks exactly one visible row.
- Initial recipients retain their display names through picker Done.
- Done replaces the current selection.
- Deselecting an initial recipient removes it from the composer.
- Clear returns an empty list and clears the composer field.
- Closing the dialog returns `null` and leaves recipients unchanged.
- Same canonical address with different display names does not create duplicate chips.
- To, Cc, and Bcc use identical picker behavior.
- Existing search-filter contact selection still returns the expected address sets.
- Reactive recipient setters notify their composer observer once per committed selection.

### Widget integration and layout tests

- Select a contact, press Done, pump one frame, and verify the recipient chip is immediately visible without tapping elsewhere.
- Run the same assertion for To, Cc, and Bcc.
- Pump widths of 320, 360, 400, and tablet width with zero, one, and several recipients.
- Assert the editor's right edge is at least 8 pixels before the trailing action row.
- Assert the input, chips, Contacts button, and expand button have nonintersecting rectangles.
- Assert each action has a minimum 48x48 hit target.
- Verify long names and addresses wrap or ellipsize without Flutter overflow exceptions.
- Verify text scales 1.0, 1.3, and 2.0.
- Verify RTL reverses directional placement correctly without overlap.
- Restore meaningful recipient sizing and wrapping coverage that was removed when the contact-button tests were introduced.

### Commands and device acceptance

- Run the focused contact datasource, contact controller, contact view, composer controller, and recipient widget tests.
- Run `flutter analyze`.
- Run the complete Flutter test suite through the repository test script.
- Use `./scripts/prebuild.sh` only if generated mocks or workspace-generated files require regeneration.
- Test on Android and iOS:
  - Open a contact book containing linked duplicate records.
  - Confirm one row per number.
  - Select, deselect, clear, and cancel.
  - Confirm chips update immediately.
  - Add multiple manual and picker recipients.
  - Rotate the device and enable large system text.
  - Confirm no action overlap or recipient loss.

## Assumptions

- The same deliverable address represents one logical recipient even when the device stores it under multiple contacts or account sources.
- Email identity comparison is case-insensitive for this UI, consistent with existing repository normalization.
- The first useful device display name is acceptable when duplicates contain different names; an existing composer display name takes priority.
- The app-only layout workaround is intentional: this change will not fork, vendor, upgrade, or patch `super_tag_editor`.
- No backend, Stalwart, package identifier, route, permission, or mail-delivery changes are required.
