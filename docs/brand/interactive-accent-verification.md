# Interactive accent migration verification

Baseline `319d2ffeca8b166ac843ad8c2bf892e9f3cff270`. Implementation is in the
working tree. The baseline inventory in the appendix records the original
locations and values. Its line numbers refer to that revision.

## Coverage checklist

| Source group | Disposition | Regression coverage |
|---|---|---|
| Palette, AppColor aliases, both theme builders, home progress | Shared solid teal; alpha and mint selection preserved | interactive_accent_test |
| Create identity, Add rule, vacation Save, recovery Restore, storage Upgrade | Primary gradient and white foreground | remaining_primary_actions_test |
| Rule create/save and positive folder/label modal actions | Primary gradient; gray unavailable and progressing behavior retained | remaining_primary_actions_test, existing folder/label suites |
| Yes, log out and default positive confirmations | Primary gradient; explicit neutral/destructive fills retain precedence | remaining_primary_actions_test |
| Identity create/edit form | Primary gradient; standalone loading indicator uses teal | additional_primary_actions_test |
| Advanced Search, forwarding Add recipient, positive Edit dialog | Primary gradient; original filtering/validation/callback behavior | additional_primary_actions_test |
| Address Compose, desktop Edit email, empty-mailbox overlay | Primary gradient; original callbacks and sizes | remaining_primary_actions_test, additional_primary_actions_test |
| Legacy Sign in, Next, retry, loading button | Primary gradient; existing entrypoints, keys, and state handling retained | remaining_primary_actions_test, legacy login tests |
| Color picker Apply and reusable web helpers | Optional gradient; explicit Cancel/Reset fills retained | gradient_controls_test |
| OTP, deletion Continue, Compose, contact Done, native Send | Existing shared gradient retained | existing branding, OTP/deletion/contact/composer suites |
| Responsive web Send circle | Shared Send widget and gradient; availability behavior retained | mobile_composer_send_button_test |
| 111 SVGs with embedded green | Exact RGB replacement; other bytes verified against baseline fingerprints | interactive_accent_test, legacy_green_svg_manifest.json |
| Settings rows, wide account menu, profile popover | Teal glyphs; explicit gray popover override retained | settings_accent_test |
| Other literal/alias color consumers in appendix | Solid teal through existing aliases, including transparent variants | interactive_accent_test, affected feature suites |
| Save/send/template/print progress tracks | Solid teal; these are status indicators | alias assertions and existing composer suites |
| Sending queue Edit/Resend and cancellation toast | Teal text/icons and existing opacity/toast treatment | existing sending-queue tests and alias assertions |
| Android activated-control resources | Solid teal through existing colorPrimary resource | interactive_accent_test |
| Web worker Open action | Solid teal | interactive_accent_test, web_smart_banner_contract_test |
| Attachment-card HTML | Palette-derived teal via existing toHexTriplet; escaping retained | interactive_accent_test, core HTML tests |
| Historical docs and test fixture baselines | Retained as historical evidence | Final runtime source search excludes them |

All named new tests live in `test/branding/`, except the Send test under
`test/features/composer/presentation/widgets/`. The asset manifest records
baseline content fingerprints for the complete 111-file asset set. It adds no
production dependency.

## TDD evidence

- The initial palette/resource and action run failed on the expected old color
  and missing gradient assertions. Unchanged gradient contrast and explicit
  destructive/neutral styles passed.
- The real logout-confirmation test also failed in isolation against the old
  dialog fill. A following test in the initial batch encountered stale overlay
  state after the expected failure; that cascade is excluded from RED evidence.
- Legacy Sign in initially exposed a test-double lifecycle setup error. After
  correcting that setup, its test was rerun against the baseline Sign in widget
  and failed on the missing gradient. Legacy loading failed on its solid fill.
- Identity forms, advanced search, forwarding, edit, empty-mailbox, and color
  picker tests were run against their baseline widget sources with the common
  test infrastructure available. The six action tests and color-picker test
  failed on absent gradients. Updated sources were restored automatically.
- Rendered previews exposed the translucent default background multiplying the
  alpha of TMail gradients. A rendered-pixel test failed against that behavior.
  The solid background color now applies only to the solid rendering path.
  Supplying a gradient gives it ownership of the fill.
- The responsive web Send test failed on its solid circle after providing the
  required Riverpod test scope, then passed with the shared Send widget.
- Final commands and results are recorded below after verification.

## Final verification

Verification date 2026-11-05. Results refer to the implementation working tree
based on the revision above.

| Check | Result |
|---|---|
| `./scripts/prebuild.sh` | Passed; generated missing mocks. Two generated localization timestamps were restored to avoid unrelated changes. Dependency locks have no changes. |
| `flutter test --no-pub --reporter expanded` | 4,720 passed. One existing opt-in splash-frame capture skipped because device capture inputs were absent. |
| Focused branding, Send, core theme and HTML tests | 72 passed before the final Next test addition. The subsequent changed-control and core run passed 42, including Next and the gradient pixel check. |
| `flutter test --no-pub --platform chrome test/branding/gradient_controls_test.dart --reporter expanded` | Seven passed in headless Chrome, including keyboard activation, focus, and gradient pixels. |
| `flutter analyze --no-pub` | Baseline and implementation both report 75 existing diagnostics. The normalized diagnostic multisets match; no additions or removals. The command retains its existing nonzero exit status for informational diagnostics. |
| `git diff --check` | Passed. |
| `git grep -in '047857' -- lib core/lib assets android ios web` | No runtime source matches. Historical documentation and test expectations are intentionally excluded. |
| SVG comparison | All 111 assets match baseline content after reversing the exact RGB replacement. |
| Rendered preview checks | Eight temporary preview cases passed using the actual controls and bundled TwakeInter fonts at phone, landscape, wide, and RTL/200% sizes. Temporary test files were removed. |

The first full run passed 4,656 tests but could not load four existing suites
because their generated mocks were absent. It is superseded by the prepared
run above. The initial analysis before preparation also included those missing
mocks and new unused-import diagnostics; it is superseded by the baseline
comparison after preparation.

The previews cover Settings glyphs, identity/rule actions, contact Done/Clear
Filter, Send, vacation controls, advanced search, folder/label action rows,
and confirmation dialogs. Default-scale controls show the shared opaque
gradient and teal glyphs. At 200% text scaling, the existing fixed-height
contact footer clips labels and identity/vacation actions truncate labels.
Narrow intrinsic confirmation layouts can also truncate the positive label.
Those geometry limits are recorded separately from the styling work, which
preserves the existing dimensions. Native-device and full-route acceptance
checks remain external validation; these captures use real widgets in the
Flutter test renderer.

Preview files are local temporary artifacts, including
`/tmp/ni-accent-final-phone.png`, `/tmp/ni-accent-final-large-rtl.png`,
`/tmp/ni-accent-final-wide.png`, and the `/tmp/ni-accent-dialog-*.png` files.


## Review recheck

A second review compared all 111 SVGs directly with the baseline content after
only the requested RGB replacement. No other asset differences were found.
The runtime search also covered alpha hex values and decimal RGB forms.

The review found that the shared TMail gradient path put `Ink` border padding
outside the button's size constraints. A new test first failed with a larger
content area, then passed after moving width, height, and min/max constraints
outside the ink layer. Fixed-width and minimum-width variants now assert equal
outer size, content size, and relative content position against the solid path.
The solid rendering path retains its original decoration, alignment, and padding.

The affected-control rerun passed 64 tests. The expanded shared-control suite
passed nine tests locally. Analysis of the corrected helper and its tests
reported no issues. The final review full-suite run passed 4,722 tests, with
the same one existing opt-in device-capture skip. All nine shared-control tests
also passed in headless Chrome. `git diff --check` passed.

A read-only cross-repository check found one website follow-up.
`python3 ../site/scripts/check_brand.py --require-sources` fails because the
website checker expects a literal `actionGreen = Color(0xFF047857)`.
The approved mobile alias now resolves to `interactiveAccent` (`#0B7A94`).
The website palette/checker needs a coordinated update. The sibling website
is outside this mobile-only migration and was not edited during the review.

## Additional review

A subsequent rendered-color check found duplicate outline painting when a
`ConfirmDialogButton` supplied both a gradient and a translucent border.
The outer `DecoratedBox` and the Material button shape both painted the border.
The new pixel regression failed against that rendering. Removing the redundant
decoration border lets the existing Material shape paint the outline once.
The affected controls passed 66 focused tests, ten Chrome shared-control tests,
and analysis of the changed helper/test reported no issues.

The contrast review also found a remaining policy exception. The selected teal
`#0B7A94` on mint `#DDF7EC` has approximately 4.40:1 contrast. The 15px
Mark as read/unread and Archive swipe labels in `thread_view.dart` use that
combination through `AppColor.primaryColor`. It falls below the 4.5:1 normal-text
target. The icon treatment meets the lower icon contrast threshold, and teal
text on white and ice remains above 4.5:1. These swipe labels need an approved
darker foreground on tinted surfaces. The explicit selected accent has not
been silently changed during a review-only request.

The website checker mismatch, existing large-text clipping, and native-device
QA remain as recorded above. No remaining runtime legacy-green literals were
found in this recheck.

## Baseline inventory appendix

The following is the pre-migration static inventory. Old expressions shown here
are historical values, and occurrence counts refer to the baseline.

### Original inventory

Source revision `319d2ffec`. Scope is the mobile-app repository, including native resources and the web client. The target is exact RGB `#047857` (4, 120, 87), including alpha variants and aliases. The current primary-action gradient uses different stops.

## Confirmed UI paths

- **Settings → Sign out.** The settings landing row uses the green `ic_sign_out.svg` as supplied. The wider account menu applies `AppColor.primaryLinShare` to the leading SVG, also `#047857`. The profile popover uses a separate `ic_logout.svg` with an embedded green fill and applies a gray tint (`#686E76`) at render time. See [account_menu_item.dart:46](../../lib/features/manage_account/presentation/model/account_menu_item.dart:46), [account_menu_item_tile_builder.dart:51](../../lib/features/manage_account/presentation/menu/widgets/account_menu_item_tile_builder.dart:51), and [profile_setting_action_type.dart:22](../../lib/features/mailbox_dashboard/presentation/model/profile_setting/profile_setting_action_type.dart:22).
- **Yes, log out.** The native logout dialog uses the generic confirmation button fallback, `AppColor.primaryMain`. See [logout_mixin.dart:14](../../lib/features/base/mixin/logout_mixin.dart:14) and [confirmation_dialog_builder.dart:368](../../core/lib/presentation/views/dialog/confirmation_dialog_builder.dart:368).
- **Create new identity.** The button explicitly uses `AppColor.primaryMain` as the fill with white text and glyph. See [create_new_identity_button_widget.dart:28](../../lib/features/manage_account/presentation/identities/widgets/create_new_identity_button_widget.dart:28).
- **Other green-filled actions.** Advanced search, email recovery Restore, identity and rule creation/saves, Add a rule, vacation Save changes, forwarding Add recipient, Upgrade storage, Compose email from address details, positive folder and label modal actions, and some default dialog confirms. Legacy login and retry, selected composer dialogs, and desktop Edit email also have green-filled actions. See the `AppColor.primaryMain` and `AppColor.primaryColor` references below for the exact widgets, including platform-specific callers.
- **Settings glyphs.** Profile, Language & Region, Preferences, Email Rules, Forwarding, Vacation, Mailbox Visibility, Notifications, Storage, Help, Keyboard Shortcuts, and Sign out map to SVGs containing the green. About NumberInbox uses a Material glyph tinted by `AppColor.primaryColor`. See [account_menu_item.dart:22](../../lib/features/manage_account/presentation/model/account_menu_item.dart:22).
- **Other roles.** Theme defaults, focused fields and selection handles, mailbox selection and unread accents, checkboxes and toggles, composer and mail action glyphs, calendar accents, progress and status UI, and embedded HTML. These are tracked independently of the primary button fills.
- **Previously migrated.** Native composer Send and contact picker Done use the shared gradient. The older Send SVG is still referenced by responsive web composer. The contact picker Clear Filter label still uses solid green.

## Dart tokens and references

38 literal or directly resolved static tokens and 234 qualified source-line references. A declaration with zero references is listed for review. Callers can override style defaults and SVG colors.

### `AppBarSendingQueueWidgetStyle.iconColor`

[app_bar_sending_queue_widget_style.dart:14](../../lib/features/sending_queue/presentation/styles/app_bar_sending_queue_widget_style.dart:14) · `AppColor.colorTextButton` · 2 reference lines

- [app_bar_sending_queue_widget.dart:44](../../lib/features/sending_queue/presentation/widgets/app_bar_sending_queue_widget.dart:44) · `iconColor: AppBarSendingQueueWidgetStyle.iconColor,`
- [app_bar_sending_queue_widget.dart:66](../../lib/features/sending_queue/presentation/widgets/app_bar_sending_queue_widget.dart:66) · `colorFilter: AppBarSendingQueueWidgetStyle.iconColor.asFilter(),`

### `AppColor.appColor`

[color_extension.dart:21](../../core/lib/presentation/extensions/color_extension.dart:21) · `Color(0xFF047857)` · 1 reference lines

- [downloading_file_dialog_builder.dart:66](../../core/lib/presentation/views/dialog/downloading_file_dialog_builder.dart:66) · `child: Text(_actionText, style: ThemeUtils.defaultTextStyleInterFont.copyWith(fontSize: 17.0, color: AppColor.appColor)),`

### `AppColor.avatarTextColor`

[color_extension.dart:50](../../core/lib/presentation/extensions/color_extension.dart:50) · `Color(0xFF047857)` · 1 reference lines

- [avatar_builder.dart:106](../../core/lib/presentation/views/image/avatar_builder.dart:106) · `style: _textStyle ?? ThemeUtils.defaultTextStyleInterFont.copyWith(fontSize: 20, color: _textColor ?? AppColor.avatarTextColor, fontWeight: FontWeight.w500)`

### `AppColor.colorActionCancelDialog`

[color_extension.dart:88](../../core/lib/presentation/extensions/color_extension.dart:88) · `Color(0xFF047857)` · 0 reference lines


### `AppColor.colorComposeButton`

[color_extension.dart:230](../../core/lib/presentation/extensions/color_extension.dart:230) · `NumberInboxPalette.actionGreen` · 0 reference lines


### `AppColor.colorExpandMailbox`

[color_extension.dart:75](../../core/lib/presentation/extensions/color_extension.dart:75) · `Color(0xFF047857)` · 0 reference lines


### `AppColor.colorFilterMessageEnabled`

[color_extension.dart:78](../../core/lib/presentation/extensions/color_extension.dart:78) · `Color(0xFF047857)` · 2 reference lines

- [default_web_app_bar_thread_widget_style.dart:35](../../lib/features/thread/presentation/styles/app_bar/default_web_app_bar_thread_widget_style.dart:35) · `: AppColor.colorFilterMessageEnabled;`
- [mobile_app_bar_thread_widget_style.dart:45](../../lib/features/thread/presentation/styles/app_bar/mobile_app_bar_thread_widget_style.dart:45) · `: AppColor.colorFilterMessageEnabled;`

### `AppColor.colorInvitedEventActionText`

[color_extension.dart:173](../../core/lib/presentation/extensions/color_extension.dart:173) · `Color(0xFF047857)` · 0 reference lines


### `AppColor.colorShadowComposerButton`

[color_extension.dart:117](../../core/lib/presentation/extensions/color_extension.dart:117) · `Color(0x99047857)` · 0 reference lines


### `AppColor.colorTextButton`

[color_extension.dart:68](../../core/lib/presentation/extensions/color_extension.dart:68) · `Color(0xFF047857)` · 29 reference lines

- [icon_button_web.dart:99](../../core/lib/presentation/views/button/icon_button_web.dart:99) · `backgroundColor: WidgetStateProperty.resolveWith((states) => backgroundColor ?? AppColor.colorTextButton),`
- [icon_button_web.dart:136](../../core/lib/presentation/views/button/icon_button_web.dart:136) · `(Set<WidgetState> states) => bgColor ?? AppColor.colorTextButton),`
- [icon_button_web.dart:141](../../core/lib/presentation/views/button/icon_button_web.dart:141) · `color: borderColor ?? bgColor ?? AppColor.colorTextButton))),`
- [edit_text_modal_sheet_builder.dart:152](../../core/lib/presentation/views/modal_sheets/edit_text_modal_sheet_builder.dart:152) · `child: Text(_cancelText.toUpperCase(), style: ThemeUtils.defaultTextStyleInterFont.copyWith(color: AppColor.colorTextButton)),`
- [edit_text_modal_sheet_builder.dart:159](../../core/lib/presentation/views/modal_sheets/edit_text_modal_sheet_builder.dart:159) · `? AppColor.colorTextButton`
- [popup_context_menu_action_mixin.dart:116](../../lib/features/base/mixin/popup_context_menu_action_mixin.dart:116) · `color: AppColor.colorTextButton,`
- [material_text_button.dart:54](../../lib/features/base/widget/material_text_button.dart:54) · `color: labelColor ?? AppColor.colorTextButton,`
- [material_text_icon_button.dart:47](../../lib/features/base/widget/material_text_icon_button.dart:47) · `colorFilter: (iconColor ?? AppColor.colorTextButton).asFilter(),`
- [material_text_icon_button.dart:53](../../lib/features/base/widget/material_text_icon_button.dart:53) · `color: labelColor ?? AppColor.colorTextButton,`
- [material_text_icon_button.dart:58](../../lib/features/base/widget/material_text_icon_button.dart:58) · `foregroundColor: labelColor ?? AppColor.colorTextButton,`
- [text_input_decoration_builder.dart:19](../../lib/features/base/widget/text_input_decoration_builder.dart:19) · `color: AppColor.colorTextButton)),`
- [destination_picker_view.dart:220](../../lib/features/destination_picker/presentation/destination_picker_view.dart:220) · `cursorColor: AppColor.colorTextButton,`
- [destination_picker_view.dart:608](../../lib/features/destination_picker/presentation/destination_picker_view.dart:608) · `colorFilter: AppColor.colorTextButton.asFilter(),`
- [create_mailbox_name_input_decoration_builder.dart:15](../../lib/features/destination_picker/presentation/widgets/create_mailbox_name_input_decoration_builder.dart:15) · `borderSide: BorderSide(width: 1, color: AppColor.colorTextButton)),`
- [top_bar_destination_picker_builder.dart:108](../../lib/features/destination_picker/presentation/widgets/top_bar_destination_picker_builder.dart:108) · `color: AppColor.colorTextButton,`
- [identity_input_decoration_builder.dart:15](../../lib/features/identity_creator/presentation/widgets/identity_input_decoration_builder.dart:15) · `borderSide: BorderSide(width: 1, color: AppColor.colorTextButton)),`
- [bottom_bar_selection_mailbox_widget.dart:57](../../lib/features/mailbox/presentation/widgets/bottom_bar_selection_mailbox_widget.dart:57) · `color: AppColor.colorTextButton,`
- [user_information_widget.dart:72](../../lib/features/mailbox/presentation/widgets/user_information_widget.dart:72) · `color: AppColor.colorTextButton,`
- [vacation_input_decoration_builder.dart:15](../../lib/features/manage_account/presentation/vacation/widgets/vacation_input_decoration_builder.dart:15) · `borderSide: BorderSide(width: 1, color: AppColor.colorTextButton)),`
- [vacation_notification_message_widget.dart:89](../../lib/features/manage_account/presentation/vacation/widgets/vacation_notification_message_widget.dart:89) · `color: AppColor.colorTextButton),`
- [vacation_notification_message_widget.dart:104](../../lib/features/manage_account/presentation/vacation/widgets/vacation_notification_message_widget.dart:104) · `color: AppColor.colorTextButton),`
- [vacation_notification_message_widget.dart:145](../../lib/features/manage_account/presentation/vacation/widgets/vacation_notification_message_widget.dart:145) · `color: AppColor.colorTextButton),`
- [vacation_notification_message_widget.dart:162](../../lib/features/manage_account/presentation/vacation/widgets/vacation_notification_message_widget.dart:162) · `color: AppColor.colorTextButton),`
- [search_email_view.dart:284](../../lib/features/search/email/presentation/search_email_view.dart:284) · `colorFilter: AppColor.colorTextButton.asFilter(),`
- [app_bar_sending_queue_widget_style.dart:14](../../lib/features/sending_queue/presentation/styles/app_bar_sending_queue_widget_style.dart:14) · `static const Color iconColor = AppColor.colorTextButton;`
- [app_bar_sending_queue_widget_style.dart:29](../../lib/features/sending_queue/presentation/styles/app_bar_sending_queue_widget_style.dart:29) · `color: AppColor.colorTextButton`
- [thread_view.dart:776](../../lib/features/thread/presentation/thread_view.dart:776) · `color: AppColor.colorTextButton,`
- [search_app_bar_widget.dart:109](../../lib/features/thread/presentation/widgets/search_app_bar_widget.dart:109) · `colorFilter: AppColor.colorTextButton.asFilter(),`
- [search_app_bar_widget.dart:125](../../lib/features/thread/presentation/widgets/search_app_bar_widget.dart:125) · `cursorColor: AppColor.colorTextButton,`

### `AppColor.counterMailboxColor`

[color_extension.dart:40](../../core/lib/presentation/extensions/color_extension.dart:40) · `Color(0xFF047857)` · 0 reference lines


### `AppColor.enableSendEmailButtonColor`

[color_extension.dart:56](../../core/lib/presentation/extensions/color_extension.dart:56) · `Color(0xFF047857)` · 0 reference lines


### `AppColor.loginTextFieldFocusedBorder`

[color_extension.dart:18](../../core/lib/presentation/extensions/color_extension.dart:18) · `Color(0xFF047857)` · 2 reference lines

- [privacy_link_widget.dart:31](../../lib/features/login/presentation/privacy_link_widget.dart:31) · `color: AppColor.loginTextFieldFocusedBorder,`
- [login_text_input_builder.dart:106](../../lib/features/login/presentation/widgets/login_text_input_builder.dart:106) · `color: AppColor.loginTextFieldFocusedBorder`

### `AppColor.m3Primary`

[color_extension.dart:277](../../core/lib/presentation/extensions/color_extension.dart:277) · `Color(0xFF047857)` · 1 reference lines

- [bottom_bar_composer_widget_style.dart:20](../../lib/features/composer/presentation/styles/web/bottom_bar_composer_widget_style.dart:20) · `static const Color selectedIconColor = AppColor.m3Primary;`

### `AppColor.mailboxSelectedIconColor`

[color_extension.dart:32](../../core/lib/presentation/extensions/color_extension.dart:32) · `Color(0xFF047857)` · 0 reference lines


### `AppColor.mailboxSelectedTextColor`

[color_extension.dart:28](../../core/lib/presentation/extensions/color_extension.dart:28) · `Color(0xFF047857)` · 0 reference lines


### `AppColor.primaryColor`

[color_extension.dart:5](../../core/lib/presentation/extensions/color_extension.dart:5) · `Color(0xFF047857)` · 105 reference lines

- [app_toast.dart:176](../../core/lib/presentation/utils/app_toast.dart:176) · `color: textColor ?? AppColor.primaryColor`
- [app_toast.dart:294](../../core/lib/presentation/utils/app_toast.dart:294) · `color: textColor ?? AppColor.primaryColor`
- [theme_utils.dart:395](../../core/lib/presentation/utils/theme_utils.dart:395) · `cursorColor: AppColor.primaryColor,`
- [theme_utils.dart:396](../../core/lib/presentation/utils/theme_utils.dart:396) · `selectionHandleColor: AppColor.primaryColor,`
- [custom_icon_labeled_checkbox.dart:46](../../core/lib/presentation/views/checkbox/custom_icon_labeled_checkbox.dart:46) · `colorFilter: AppColor.primaryColor.asFilter(),`
- [custom_icon_labeled_checkbox.dart:62](../../core/lib/presentation/views/checkbox/custom_icon_labeled_checkbox.dart:62) · `colorFilter: AppColor.primaryColor.asFilter(),`
- [color_picker_modal.dart:213](../../core/lib/presentation/views/color/color_picker_modal.dart:213) · `cursorColor: AppColor.primaryColor,`
- [text_field_builder.dart:38](../../core/lib/presentation/views/text/text_field_builder.dart:38) · `this.cursorColor = AppColor.primaryColor,`
- [text_form_field_builder.dart:34](../../core/lib/presentation/views/text/text_form_field_builder.dart:34) · `this.cursorColor = AppColor.primaryColor,`
- [type_ahead_form_field_builder.dart:52](../../core/lib/presentation/views/text/type_ahead_form_field_builder.dart:52) · `this.cursorColor = AppColor.primaryColor,`
- [app_loader_mixin.dart:19](../../lib/features/base/mixin/app_loader_mixin.dart:19) · `color: AppColor.primaryColor,`
- [app_loader_mixin.dart:31](../../lib/features/base/mixin/app_loader_mixin.dart:31) · `progressColor: AppColor.primaryColor,`
- [circle_loading_widget_styles.dart:5](../../lib/features/base/styles/circle_loading_widget_styles.dart:5) · `static const Color progressColor = AppColor.primaryColor;`
- [hyper_link_widget_styles.dart:5](../../lib/features/base/styles/hyper_link_widget_styles.dart:5) · `static const Color textColor = AppColor.primaryColor;`
- [default_autocomplete_input_field_widget.dart:118](../../lib/features/base/widget/default_field/default_autocomplete_input_field_widget.dart:118) · `cursorColor: AppColor.primaryColor,`
- [default_autocomplete_input_field_widget.dart:139](../../lib/features/base/widget/default_field/default_autocomplete_input_field_widget.dart:139) · `focusedBorderColor: AppColor.primaryColor,`
- [default_autocomplete_input_field_widget.dart:142](../../lib/features/base/widget/default_field/default_autocomplete_input_field_widget.dart:142) · `_isDragging ? AppColor.primaryColor : AppColor.m3Neutral90,`
- [default_autocomplete_tag_item_widget.dart:156](../../lib/features/base/widget/default_field/default_autocomplete_tag_item_widget.dart:156) · `return const BorderSide(width: 1, color: AppColor.primaryColor);`
- [default_draggable_tag_widget_style.dart:12](../../lib/features/base/widget/default_field/default_draggable_tag_widget_style.dart:12) · `static const Color backgroundColor = AppColor.primaryColor;`
- [default_input_field_widget.dart:90](../../lib/features/base/widget/default_field/default_input_field_widget.dart:90) · `borderSide: BorderSide(width: 1, color: AppColor.primaryColor),`
- [date_time_dialog_picker.dart:34](../../lib/features/base/widget/dialog_picker/date_time_dialog_picker.dart:34) · `primary: AppColor.primaryColor,`
- [date_time_dialog_picker.dart:40](../../lib/features/base/widget/dialog_picker/date_time_dialog_picker.dart:40) · `foregroundColor: AppColor.primaryColor,`
- [date_time_dialog_picker.dart:85](../../lib/features/base/widget/dialog_picker/date_time_dialog_picker.dart:85) · `primary: AppColor.primaryColor,`
- [date_time_dialog_picker.dart:91](../../lib/features/base/widget/dialog_picker/date_time_dialog_picker.dart:91) · `foregroundColor: AppColor.primaryColor,`
- [attachment_header_composer_widget_style.dart:11](../../lib/features/composer/presentation/styles/attachment_header_composer_widget_style.dart:11) · `static const Color sizeLabelBackground = AppColor.primaryColor;`
- [attachment_progress_loading_composer_widget_style.dart:9](../../lib/features/composer/presentation/styles/attachment_progress_loading_composer_widget_style.dart:9) · `static const Color progressColor = AppColor.primaryColor;`
- [tablet_bottom_bar_composer_widget_style.dart:17](../../lib/features/composer/presentation/styles/mobile/tablet_bottom_bar_composer_widget_style.dart:17) · `static const Color selectedIconColor = AppColor.primaryColor;`
- [recipient_composer_widget_style.dart:25](../../lib/features/composer/presentation/styles/recipient_composer_widget_style.dart:25) · `static const Color enableBorderColor = AppColor.primaryColor;`
- [recipient_composer_widget_style.dart:27](../../lib/features/composer/presentation/styles/recipient_composer_widget_style.dart:27) · `static const Color cursorColor = AppColor.primaryColor;`
- [subject_composer_widget_style.dart:9](../../lib/features/composer/presentation/styles/subject_composer_widget_style.dart:9) · `static const Color cursorColor = AppColor.primaryColor;`
- [draggable_recipient_tag_widget.dart:30](../../lib/features/composer/presentation/widgets/draggable_recipient_tag_widget.dart:30) · `color: AppColor.primaryColor,`
- [insert_image_loading_bar_widget.dart:29](../../lib/features/composer/presentation/widgets/insert_image_loading_bar_widget.dart:29) · `color: AppColor.primaryColor,`
- [insert_image_loading_bar_widget.dart:51](../../lib/features/composer/presentation/widgets/insert_image_loading_bar_widget.dart:51) · `color: AppColor.primaryColor,`
- [mobile_attachment_composer_widget.dart:99](../../lib/features/composer/presentation/widgets/mobile/mobile_attachment_composer_widget.dart:99) · `iconColor: AppColor.primaryColor,`
- [mobile_attachment_composer_widget.dart:103](../../lib/features/composer/presentation/widgets/mobile/mobile_attachment_composer_widget.dart:103) · `color: AppColor.primaryColor`
- [mobile_attachment_composer_widget.dart:117](../../lib/features/composer/presentation/widgets/mobile/mobile_attachment_composer_widget.dart:117) · `color: AppColor.primaryColor`
- [mobile_attachment_composer_widget.dart:169](../../lib/features/composer/presentation/widgets/mobile/mobile_attachment_composer_widget.dart:169) · `iconColor: AppColor.primaryColor,`
- [mobile_attachment_composer_widget.dart:173](../../lib/features/composer/presentation/widgets/mobile/mobile_attachment_composer_widget.dart:173) · `color: AppColor.primaryColor`
- [mobile_attachment_composer_widget.dart:185](../../lib/features/composer/presentation/widgets/mobile/mobile_attachment_composer_widget.dart:185) · `color: AppColor.primaryColor`
- [recipient_tag_item_widget.dart:237](../../lib/features/composer/presentation/widgets/recipient_tag_item_widget.dart:237) · `color: AppColor.primaryColor,`
- [saving_message_dialog_view.dart:195](../../lib/features/composer/presentation/widgets/saving_message_dialog_view.dart:195) · `backgroundColor: AppColor.primaryColor,`
- [saving_template_dialog_view.dart:184](../../lib/features/composer/presentation/widgets/saving_template_dialog_view.dart:184) · `backgroundColor: AppColor.primaryColor,`
- [sending_message_dialog_view.dart:177](../../lib/features/composer/presentation/widgets/sending_message_dialog_view.dart:177) · `backgroundColor: AppColor.primaryColor,`
- [print_draft_dialog_view.dart:173](../../lib/features/composer/presentation/widgets/web/print_draft_dialog_view.dart:173) · `backgroundColor: AppColor.primaryColor,`
- [contact_input_tag_item.dart:111](../../lib/features/contact/presentation/widgets/contact_input_tag_item.dart:111) · `color: AppColor.primaryColor);`
- [contact_item_widget.dart:83](../../lib/features/contact/presentation/widgets/contact_item_widget.dart:83) · `? AppColor.primaryColor.asFilter()`
- [contact_list_action_widget.dart:41](../../lib/features/contact/presentation/widgets/contact_list_action_widget.dart:41) · `color: AppColor.primaryColor`
- [destination_picker_view.dart:149](../../lib/features/destination_picker/presentation/destination_picker_view.dart:149) · `color: AppColor.primaryColor,`
- [destination_picker_view.dart:166](../../lib/features/destination_picker/presentation/destination_picker_view.dart:166) · `color: AppColor.primaryColor,`
- [destination_picker_view.dart:175](../../lib/features/destination_picker/presentation/destination_picker_view.dart:175) · `color: AppColor.primaryColor,`
- [destination_picker_view.dart:192](../../lib/features/destination_picker/presentation/destination_picker_view.dart:192) · `color: AppColor.primaryColor,`
- [top_bar_destination_picker_builder.dart:97](../../lib/features/destination_picker/presentation/widgets/top_bar_destination_picker_builder.dart:97) · `colorFilter: AppColor.primaryColor.asFilter(),`
- [download_controller.dart:128](../../lib/features/download/presentation/controllers/download_controller.dart:128) · `leadingSVGIconColor: AppColor.primaryColor,`
- [single_email_controller.dart:1327](../../lib/features/email/presentation/controller/single_email_controller.dart:1327) · `leadingSVGIconColor: AppColor.primaryColor,`
- [attachment_list_styles.dart:49](../../lib/features/email/presentation/styles/attachment/attachment_list_styles.dart:49) · `static const Color cancelButtonTextColor = AppColor.primaryColor;`
- [attachment_item_widget.dart:92](../../lib/features/email/presentation/widgets/attachment_item_widget.dart:92) · `iconColor: AppColor.primaryColor,`
- [pdf_viewer.dart:196](../../lib/features/email/presentation/widgets/pdf_viewer/pdf_viewer.dart:196) · `progressColor: AppColor.primaryColor,`
- [view_entire_message_with_message_clipped_widget.dart:40](../../lib/features/email/presentation/widgets/view_entire_message_with_message_clipped_widget.dart:40) · `color: AppColor.primaryColor,`
- [download_attachment_loading_bar.dart:17](../../lib/features/email_previewer/download_attachment_loading_bar.dart:17) · `color: AppColor.primaryColor,`
- [download_attachment_loading_bar.dart:27](../../lib/features/email_previewer/download_attachment_loading_bar.dart:27) · `progressColor: AppColor.primaryColor);`
- [identity_creator_form_bottom_view.dart:68](../../lib/features/identity_creator/presentation/widgets/identity_creator_form_bottom_view.dart:68) · `color: AppColor.primaryColor,`
- [insert_image_loading_indicator.dart:20](../../lib/features/identity_creator/presentation/widgets/insert_image_loading_indicator.dart:20) · `color: AppColor.primaryColor`
- [set_default_identity_checkbox_builder.dart:40](../../lib/features/identity_creator/presentation/widgets/set_default_identity_checkbox_builder.dart:40) · `border: Border.all(color: AppColor.primaryColor, width: 2.0),`
- [set_default_identity_checkbox_builder.dart:41](../../lib/features/identity_creator/presentation/widgets/set_default_identity_checkbox_builder.dart:41) · `color: isCheck ? AppColor.primaryColor : Colors.white,`
- [base_login_view.dart:25](../../lib/features/login/presentation/base_login_view.dart:25) · `backgroundColor: AppColor.primaryColor,`
- [base_login_view.dart:28](../../lib/features/login/presentation/base_login_view.dart:28) · `side: const BorderSide(width: 0, color: AppColor.primaryColor)`
- [base_login_view.dart:107](../../lib/features/login/presentation/base_login_view.dart:107) · `child: CircularProgressIndicator(color: AppColor.primaryColor));`
- [login_view.dart:194](../../lib/features/login/presentation/login_view.dart:194) · `backgroundColor: AppColor.primaryColor,`
- [login_view.dart:197](../../lib/features/login/presentation/login_view.dart:197) · `side: const BorderSide(width: 0, color: AppColor.primaryColor)`
- [horizontal_progress_loading_button.dart:16](../../lib/features/login/presentation/widgets/horizontal_progress_loading_button.dart:16) · `backgroundColor: AppColor.primaryColor,`
- [horizontal_progress_loading_button.dart:17](../../lib/features/login/presentation/widgets/horizontal_progress_loading_button.dart:17) · `disabledBackgroundColor: AppColor.primaryColor,`
- [horizontal_progress_loading_button.dart:25](../../lib/features/login/presentation/widgets/horizontal_progress_loading_button.dart:25) · `backgroundColor: AppColor.primaryColor`
- [login_back_button.dart:25](../../lib/features/login/presentation/widgets/login_back_button.dart:25) · `colorFilter: AppColor.primaryColor.asFilter()`
- [try_again_button.dart:38](../../lib/features/login/presentation/widgets/try_again_button.dart:38) · `backgroundColor: AppColor.primaryColor,`
- [mailbox_view.dart:32](../../lib/features/mailbox/presentation/mailbox_view.dart:32) · `color: AppColor.primaryColor,`
- [mailbox_view_web.dart:68](../../lib/features/mailbox/presentation/mailbox_view_web.dart:68) · `color: AppColor.primaryColor,`
- [empty_mailbox_dialog_overlay_styles.dart:23](../../lib/features/mailbox/presentation/styles/empty_mailbox_dialog_overlay_styles.dart:23) · `static const Color emptyButtonColor = AppColor.primaryColor;`
- [mailbox_dashboard_controller.dart:3266](../../lib/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart:3266) · `backgroundColor: AppColor.primaryColor,`
- [mailbox_dashboard_view_web.dart:780](../../lib/features/mailbox_dashboard/presentation/mailbox_dashboard_view_web.dart:780) · `color: AppColor.primaryColor,`
- [mailbox_dashboard_view_web.dart:847](../../lib/features/mailbox_dashboard/presentation/mailbox_dashboard_view_web.dart:847) · `? AppColor.primaryColor.withValues(alpha: 0.06)`
- [quick_search_filter.dart:107](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:107) · `return AppColor.primaryColor.withValues(alpha: 0.06);`
- [quick_search_filter.dart:115](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:115) · `return AppColor.primaryColor.withValues(alpha: 0.06);`
- [quick_search_filter.dart:123](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:123) · `return AppColor.primaryColor.withValues(alpha: 0.06);`
- [quick_search_filter.dart:131](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:131) · `return AppColor.primaryColor;`
- [download_task_item_widget.dart:53](../../lib/features/mailbox_dashboard/presentation/widgets/download/download_task_item_widget.dart:53) · `progressColor: AppColor.primaryColor,`
- [recover_deleted_message_loading_banner_widget.dart:49](../../lib/features/mailbox_dashboard/presentation/widgets/recover_deleted_message_loading_banner_widget.dart:49) · `color: AppColor.primaryColor,`
- [search_input_form_widget.dart:268](../../lib/features/mailbox_dashboard/presentation/widgets/search_input_form_widget.dart:268) · `cursorColor: AppColor.primaryColor,`
- [list_identity_item_actions_widget.dart:38](../../lib/features/manage_account/presentation/identities/widgets/list_identity_item_actions_widget.dart:38) · `iconColor: AppColor.primaryColor,`
- [list_identity_item_actions_widget.dart:43](../../lib/features/manage_account/presentation/identities/widgets/list_identity_item_actions_widget.dart:43) · `color: AppColor.primaryColor,`
- [list_identity_item_actions_widget.dart:61](../../lib/features/manage_account/presentation/identities/widgets/list_identity_item_actions_widget.dart:61) · `iconColor: AppColor.primaryColor,`
- [list_identity_item_actions_widget.dart:66](../../lib/features/manage_account/presentation/identities/widgets/list_identity_item_actions_widget.dart:66) · `color: AppColor.primaryColor,`
- [settings_first_level_view.dart:243](../../lib/features/manage_account/presentation/menu/settings/settings_first_level_view.dart:243) · `leading: const Icon(Icons.info_outline, color: AppColor.primaryColor),`
- [clear_search_filter_button.dart:28](../../lib/features/search/email/presentation/riverpod_widgets/clear_search_filter_button.dart:28) · `color: AppColor.primaryColor,`
- [sending_email_action_type.dart:45](../../lib/features/sending_queue/presentation/model/sending_email_action_type.dart:45) · `return AppColor.primaryColor.withValues(alpha: buttonState.opacity);`
- [sending_email_action_type.dart:57](../../lib/features/sending_queue/presentation/model/sending_email_action_type.dart:57) · `return AppColor.primaryColor.withValues(alpha: buttonState.opacity);`
- [sending_queue_view.dart:61](../../lib/features/sending_queue/presentation/sending_queue_view.dart:61) · `color: AppColor.primaryColor,`
- [filter_message_option_style_extension.dart:61](../../lib/features/thread/presentation/extensions/filter_message_option_style_extension.dart:61) · `_isAll ? AppColor.colorFilterMessageIcon : AppColor.primaryColor;`
- [filter_message_option_style_extension.dart:64](../../lib/features/thread/presentation/extensions/filter_message_option_style_extension.dart:64) · `? AppColor.primaryColor.withValues(alpha: 0.06)`
- [filter_message_option_style_extension.dart:70](../../lib/features/thread/presentation/extensions/filter_message_option_style_extension.dart:70) · `color: _isAll ? AppColor.colorFilterMessageTitle : AppColor.primaryColor,`
- [spam_report_banner_button_styles.dart:12](../../lib/features/thread/presentation/styles/spam_banner/spam_report_banner_button_styles.dart:12) · `static const Color positiveButtonTextColor = AppColor.primaryColor;`
- [spam_report_banner_label_styles.dart:10](../../lib/features/thread/presentation/styles/spam_banner/spam_report_banner_label_styles.dart:10) · `static const Color highlightLabelTextColor = AppColor.primaryColor;`
- [thread_view.dart:711](../../lib/features/thread/presentation/thread_view.dart:711) · `colorFilter: AppColor.primaryColor.asFilter(),`
- [thread_view.dart:721](../../lib/features/thread/presentation/thread_view.dart:721) · `color: AppColor.primaryColor,`
- [thread_view.dart:751](../../lib/features/thread/presentation/thread_view.dart:751) · `color: AppColor.primaryColor,`
- [email_tile_web_builder.dart:235](../../lib/features/thread/presentation/widgets/email_tile_web_builder.dart:235) · `? AppColor.primaryColor`

### `AppColor.primaryLinShare`

[color_extension.dart:273](../../core/lib/presentation/extensions/color_extension.dart:273) · `Color(0xFF047857)` · 14 reference lines

- [handle_insert_link_composer_extension.dart:34](../../lib/features/composer/presentation/extensions/handle_insert_link_composer_extension.dart:34) · `iconColor: AppColor.primaryLinShare,`
- [destination_picker_folder_item.dart:35](../../lib/features/destination_picker/presentation/widgets/destination_picker_folder_item.dart:35) · `colorFilter: AppColor.primaryLinShare.asFilter(),`
- [destination_picker_search_mailbox_item_builder.dart:91](../../lib/features/destination_picker/presentation/widgets/destination_picker_search_mailbox_item_builder.dart:91) · `colorFilter: AppColor.primaryLinShare.asFilter(),`
- [folder_item_widget.dart:43](../../lib/features/mailbox/presentation/widgets/folder_item_widget.dart:43) · `iconColor?.asFilter() ?? AppColor.primaryLinShare.asFilter(),`
- [mailbox_category_widget.dart:65](../../lib/features/mailbox/presentation/widgets/mailbox_category_widget.dart:65) · `colorFilter: (widget.iconColor ?? AppColor.primaryLinShare).asFilter(),`
- [mailbox_icon_widget.dart:29](../../lib/features/mailbox/presentation/widgets/mailbox_icon_widget.dart:29) · `colorFilter: (color ?? AppColor.primaryLinShare).asFilter(),`
- [email_forward_item_widget.dart:103](../../lib/features/manage_account/presentation/forward/widgets/email_forward_item_widget.dart:103) · `iconColor: AppColor.primaryLinShare,`
- [keyboard_shortcuts_tab_view_widget.dart:92](../../lib/features/manage_account/presentation/keyboard_shortcuts/widgets/keyboard_shortcuts_tab_view_widget.dart:92) · `color: AppColor.primaryLinShare,`
- [mailbox_subscribe_button.dart:34](../../lib/features/manage_account/presentation/mailbox_visibility/widgets/mailbox_subscribe_button.dart:34) · `color: AppColor.primaryLinShare,`
- [mailbox_subscribe_button.dart:42](../../lib/features/manage_account/presentation/mailbox_visibility/widgets/mailbox_subscribe_button.dart:42) · `iconColor: AppColor.primaryLinShare,`
- [manage_account_menu_view.dart:46](../../lib/features/manage_account/presentation/menu/manage_account_menu_view.dart:46) · `iconColor: AppColor.primaryLinShare,`
- [account_menu_item_tile_builder.dart:56](../../lib/features/manage_account/presentation/menu/widgets/account_menu_item_tile_builder.dart:56) · `colorFilter: AppColor.primaryLinShare.asFilter(),`
- [mailbox_searched_item_builder.dart:209](../../lib/features/search/mailbox/presentation/widgets/mailbox_searched_item_builder.dart:209) · `? AppColor.primaryLinShare.asFilter()`
- [thread_view.dart:744](../../lib/features/thread/presentation/thread_view.dart:744) · `child: SvgPicture.asset(imagePaths.icMailboxArchivedAction, colorFilter: AppColor.primaryLinShare.asFilter(), fit: BoxFit.fill),`

### `AppColor.primaryMain`

[color_extension.dart:249](../../core/lib/presentation/extensions/color_extension.dart:249) · `Color(0xFF047857)` · 54 reference lines

- [theme_utils.dart:302](../../core/lib/presentation/utils/theme_utils.dart:302) · `color: color ?? AppColor.primaryMain,`
- [confirm_dialog_button.dart:72](../../core/lib/presentation/views/dialog/confirm_dialog_button.dart:72) · `: iconColor?.asFilter() ?? AppColor.primaryMain.asFilter(),`
- [confirmation_dialog_builder.dart:331](../../core/lib/presentation/views/dialog/confirmation_dialog_builder.dart:331) · `?? AppColor.primaryMain,`
- [confirmation_dialog_builder.dart:369](../../core/lib/presentation/views/dialog/confirmation_dialog_builder.dart:369) · `?? AppColor.primaryMain,`
- [edit_text_dialog_builder.dart:147](../../core/lib/presentation/views/dialog/edit_text_dialog_builder.dart:147) · `focusedBorder: _buildBorder(AppColor.primaryMain),`
- [edit_text_dialog_builder.dart:187](../../core/lib/presentation/views/dialog/edit_text_dialog_builder.dart:187) · `backgroundColor: AppColor.primaryMain,`
- [modal_list_action_button_widget.dart:49](../../core/lib/presentation/views/dialog/modal_list_action_button_widget.dart:49) · `? AppColor.primaryMain`
- [modal_list_action_button_widget.dart:64](../../core/lib/presentation/views/dialog/modal_list_action_button_widget.dart:64) · `backgroundColor: AppColor.primaryMain,`
- [label_extension.dart:20](../../labels/lib/extensions/label_extension.dart:20) · `return color?.value.toColor() ?? AppColor.primaryMain;`
- [popup_menu_item_action.dart:45](../../lib/features/base/model/popup_menu_item_action.dart:45) · `Color get selectedIconColor => AppColor.primaryMain;`
- [context_menu_item_action.dart:33](../../lib/features/base/widget/context_menu/context_menu_item_action.dart:33) · `Color get selectedIconColor => AppColor.primaryMain;`
- [handle_insert_link_composer_extension.dart:29](../../lib/features/composer/presentation/extensions/handle_insert_link_composer_extension.dart:29) · `color: AppColor.primaryMain,`
- [handle_insert_link_composer_extension.dart:51](../../lib/features/composer/presentation/extensions/handle_insert_link_composer_extension.dart:51) · `color: isEnabled ? AppColor.primaryMain : AppColor.gray400,`
- [handle_insert_link_composer_extension.dart:84](../../lib/features/composer/presentation/extensions/handle_insert_link_composer_extension.dart:84) · `color: AppColor.primaryMain,`
- [desktop_edit_recipients_view.dart:126](../../lib/features/composer/presentation/view/web/desktop_edit_recipients_view.dart:126) · `backgroundColor: AppColor.primaryMain,`
- [desktop_edit_recipients_view.dart:139](../../lib/features/composer/presentation/view/web/desktop_edit_recipients_view.dart:139) · `textColor: AppColor.primaryMain,`
- [desktop_edit_recipients_view.dart:140](../../lib/features/composer/presentation/view/web/desktop_edit_recipients_view.dart:140) · `borderColor: AppColor.primaryMain,`
- [email_address_detail_widget.dart:83](../../lib/features/email/presentation/widgets/email_address_detail_widget.dart:83) · `textColor: AppColor.primaryMain,`
- [email_address_detail_widget.dart:84](../../lib/features/email/presentation/widgets/email_address_detail_widget.dart:84) · `borderColor: AppColor.primaryMain,`
- [email_address_detail_widget.dart:95](../../lib/features/email/presentation/widgets/email_address_detail_widget.dart:95) · `backgroundColor: AppColor.primaryMain,`
- [list_button_widget.dart:39](../../lib/features/email_recovery/presentation/widgets/list_button_widget.dart:39) · `backgroundColor: AppColor.primaryMain,`
- [identity_creator_form_bottom_view.dart:77](../../lib/features/identity_creator/presentation/widgets/identity_creator_form_bottom_view.dart:77) · `backgroundColor: AppColor.primaryMain,`
- [add_label_to_email_modal.dart:130](../../lib/features/labels/presentation/widgets/add_label_to_email_modal.dart:130) · `iconColor: AppColor.primaryMain,`
- [add_label_to_email_modal.dart:141](../../lib/features/labels/presentation/widgets/add_label_to_email_modal.dart:141) · `color: AppColor.primaryMain,`
- [label_item_context_menu.dart:43](../../lib/features/labels/presentation/widgets/label_item_context_menu.dart:43) · `? AppColor.primaryMain.asFilter()`
- [list_label_with_action_modal.dart:90](../../lib/features/labels/presentation/widgets/list_label_with_action_modal.dart:90) · `textColor: AppColor.primaryMain,`
- [no_label_yet_widget.dart:57](../../lib/features/labels/presentation/widgets/no_label_yet_widget.dart:57) · `textColor: AppColor.primaryMain,`
- [no_label_yet_widget.dart:58](../../lib/features/labels/presentation/widgets/no_label_yet_widget.dart:58) · `borderColor: AppColor.primaryMain,`
- [label_list_item.dart:131](../../lib/features/mailbox/presentation/widgets/labels/label_list_item.dart:131) · `? AppColor.primaryMain`
- [advanced_search_filter_form_bottom_view.dart:88](../../lib/features/mailbox_dashboard/presentation/widgets/advanced_search/advanced_search_filter_form_bottom_view.dart:88) · `backgroundColor: AppColor.primaryMain,`
- [icon_open_advanced_search_widget.dart:33](../../lib/features/mailbox_dashboard/presentation/widgets/advanced_search/icon_open_advanced_search_widget.dart:33) · `? AppColor.primaryMain`
- [add_rule_button_widget.dart:29](../../lib/features/manage_account/presentation/email_rules/widgets/add_rule_button_widget.dart:29) · `backgroundColor: AppColor.primaryMain,`
- [no_rules_widget.dart:73](../../lib/features/manage_account/presentation/email_rules/widgets/no_rules_widget.dart:73) · `textColor: AppColor.primaryMain,`
- [no_rules_widget.dart:74](../../lib/features/manage_account/presentation/email_rules/widgets/no_rules_widget.dart:74) · `borderColor: AppColor.primaryMain,`
- [autocomplete_contact_text_field_with_tags.dart:94](../../lib/features/manage_account/presentation/forward/widgets/autocomplete_contact_text_field_with_tags.dart:94) · `focusedBorderColor: AppColor.primaryMain,`
- [autocomplete_contact_text_field_with_tags.dart:96](../../lib/features/manage_account/presentation/forward/widgets/autocomplete_contact_text_field_with_tags.dart:96) · `cursorColor: AppColor.primaryMain,`
- [autocomplete_contact_text_field_with_tags.dart:279](../../lib/features/manage_account/presentation/forward/widgets/autocomplete_contact_text_field_with_tags.dart:279) · `backgroundColor: AppColor.primaryMain,`
- [create_new_identity_button_widget.dart:28](../../lib/features/manage_account/presentation/identities/widgets/create_new_identity_button_widget.dart:28) · `backgroundColor: AppColor.primaryMain,`
- [setting_user_info_widget.dart:89](../../lib/features/manage_account/presentation/menu/settings/setting_user_info_widget.dart:89) · `textColor: AppColor.primaryMain,`
- [setting_user_info_widget.dart:90](../../lib/features/manage_account/presentation/menu/settings/setting_user_info_widget.dart:90) · `borderColor: AppColor.primaryMain,`
- [upgrade_storage_widget.dart:90](../../lib/features/manage_account/presentation/storage/widgets/upgrade_storage_widget.dart:90) · `backgroundColor: AppColor.primaryMain,`
- [vacation_list_action_widget.dart:39](../../lib/features/manage_account/presentation/vacation/widgets/vacation_list_action_widget.dart:39) · `backgroundColor: AppColor.primaryMain,`
- [rules_filter_creator_view.dart:295](../../lib/features/rules_filter_creator/presentation/rules_filter_creator_view.dart:295) · `textColor: AppColor.primaryMain,`
- [rules_filter_creator_view.dart:296](../../lib/features/rules_filter_creator/presentation/rules_filter_creator_view.dart:296) · `borderColor: AppColor.primaryMain,`
- [rules_filter_creator_view.dart:407](../../lib/features/rules_filter_creator/presentation/rules_filter_creator_view.dart:407) · `textColor: AppColor.primaryMain,`
- [rules_filter_creator_view.dart:408](../../lib/features/rules_filter_creator/presentation/rules_filter_creator_view.dart:408) · `borderColor: AppColor.primaryMain,`
- [rule_filter_list_action_widget.dart:39](../../lib/features/rules_filter_creator/presentation/widgets/rule_filter_list_action_widget.dart:39) · `backgroundColor: AppColor.primaryMain,`
- [rule_filter_title_with_preview_button.dart:45](../../lib/features/rules_filter_creator/presentation/widgets/rule_filter_title_with_preview_button.dart:45) · `iconColor: AppColor.primaryMain,`
- [rule_filter_title_with_preview_button.dart:52](../../lib/features/rules_filter_creator/presentation/widgets/rule_filter_title_with_preview_button.dart:52) · `color: AppColor.primaryMain,`
- [mobile_app_bar_thread_widget_style.dart:16](../../lib/features/thread/presentation/styles/app_bar/mobile_app_bar_thread_widget_style.dart:16) · `static const Color actionIconActiveColor = AppColor.primaryMain;`
- [ai_scribe_styles.dart:13](../../scribe/lib/scribe/ai/presentation/styles/ai_scribe_styles.dart:13) · `static const Color scribeIcon = AppColor.primaryMain;`
- [ai_scribe_styles.dart:14](../../scribe/lib/scribe/ai/presentation/styles/ai_scribe_styles.dart:14) · `static const Color aiAssistantIcon = AppColor.primaryMain;`
- [ai_scribe_suggestion_success_actions.dart:52](../../scribe/lib/scribe/ai/presentation/widgets/modal/suggestion/ai_scribe_suggestion_success_actions.dart:52) · `textColor: AppColor.primaryMain,`
- [ai_scribe_suggestion_success_actions.dart:93](../../scribe/lib/scribe/ai/presentation/widgets/modal/suggestion/ai_scribe_suggestion_success_actions.dart:93) · `backgroundColor: AppColor.primaryMain,`

### `AppColor.subjectEmailTextColorUnRead`

[color_extension.dart:52](../../core/lib/presentation/extensions/color_extension.dart:52) · `Color(0xFF047857)` · 0 reference lines


### `AppColor.textFieldFocusedBorderColor`

[color_extension.dart:14](../../core/lib/presentation/extensions/color_extension.dart:14) · `Color(0xFF047857)` · 1 reference lines

- [login_input_decoration_builder.dart:15](../../lib/features/login/presentation/widgets/login_input_decoration_builder.dart:15) · `borderSide: BorderSide(width: 2, color: AppColor.textFieldFocusedBorderColor)),`

### `AttachmentHeaderComposerWidgetStyle.sizeLabelBackground`

[attachment_header_composer_widget_style.dart:11](../../lib/features/composer/presentation/styles/attachment_header_composer_widget_style.dart:11) · `AppColor.primaryColor` · 1 reference lines

- [attachment_header_composer_widget.dart:68](../../lib/features/composer/presentation/widgets/attachment_header_composer_widget.dart:68) · `color: AttachmentHeaderComposerWidgetStyle.sizeLabelBackground,`

### `AttachmentListStyles.cancelButtonTextColor`

[attachment_list_styles.dart:49](../../lib/features/email/presentation/styles/attachment/attachment_list_styles.dart:49) · `AppColor.primaryColor` · 0 reference lines


### `AttachmentProgressLoadingComposerWidgetStyle.progressColor`

[attachment_progress_loading_composer_widget_style.dart:9](../../lib/features/composer/presentation/styles/attachment_progress_loading_composer_widget_style.dart:9) · `AppColor.primaryColor` · 2 reference lines

- [attachment_progress_loading_composer_widget.dart:25](../../lib/features/composer/presentation/widgets/attachment_progress_loading_composer_widget.dart:25) · `color: AttachmentProgressLoadingComposerWidgetStyle.progressColor,`
- [attachment_progress_loading_composer_widget.dart:41](../../lib/features/composer/presentation/widgets/attachment_progress_loading_composer_widget.dart:41) · `progressColor: AttachmentProgressLoadingComposerWidgetStyle.progressColor,`

### `BottomBarComposerWidgetStyle.selectedIconColor`

[bottom_bar_composer_widget_style.dart:20](../../lib/features/composer/presentation/styles/web/bottom_bar_composer_widget_style.dart:20) · `AppColor.m3Primary` · 1 reference lines

- [bottom_bar_composer_widget.dart:89](../../lib/features/composer/presentation/widgets/web/bottom_bar_composer_widget.dart:89) · `? BottomBarComposerWidgetStyle.selectedIconColor`

### `CircleLoadingWidgetStyles.progressColor`

[circle_loading_widget_styles.dart:5](../../lib/features/base/styles/circle_loading_widget_styles.dart:5) · `AppColor.primaryColor` · 1 reference lines

- [circle_loading_widget.dart:27](../../lib/features/base/widget/circle_loading_widget.dart:27) · `color: CircleLoadingWidgetStyles.progressColor,`

### `DefaultDraggableTagWidgetStyle.backgroundColor`

[default_draggable_tag_widget_style.dart:12](../../lib/features/base/widget/default_field/default_draggable_tag_widget_style.dart:12) · `AppColor.primaryColor` · 1 reference lines

- [default_draggable_tag_widget.dart:34](../../lib/features/base/widget/default_field/default_draggable_tag_widget.dart:34) · `color: DefaultDraggableTagWidgetStyle.backgroundColor,`

### `EmptyMailboxDialogOverlayStyles.emptyButtonColor`

[empty_mailbox_dialog_overlay_styles.dart:23](../../lib/features/mailbox/presentation/styles/empty_mailbox_dialog_overlay_styles.dart:23) · `AppColor.primaryColor` · 1 reference lines

- [empty_mailbox_dialog_overlay.dart:91](../../lib/features/mailbox/presentation/widgets/empty_mailbox_dialog_overlay.dart:91) · `backgroundColor: EmptyMailboxDialogOverlayStyles.emptyButtonColor,`

### `HyperLinkWidgetStyles.textColor`

[hyper_link_widget_styles.dart:5](../../lib/features/base/styles/hyper_link_widget_styles.dart:5) · `AppColor.primaryColor` · 1 reference lines

- [hyper_link_widget.dart:19](../../lib/features/base/widget/hyper_link_widget.dart:19) · `color: HyperLinkWidgetStyles.textColor,`

### `MobileAppBarThreadWidgetStyle.actionIconActiveColor`

[mobile_app_bar_thread_widget_style.dart:16](../../lib/features/thread/presentation/styles/app_bar/mobile_app_bar_thread_widget_style.dart:16) · `AppColor.primaryMain` · 0 reference lines


### `NumberInboxColors.primary`

[numberinbox_colors.dart:8](../../lib/features/numberinbox/theme/numberinbox_colors.dart:8) · `NumberInboxPalette.actionGreen` · 0 reference lines


### `NumberInboxPalette.actionGreen`

[numberinbox_palette.dart:12](../../core/lib/presentation/resources/numberinbox_palette.dart:12) · `Color(0xFF047857)` · 8 reference lines

- [color_extension.dart:230](../../core/lib/presentation/extensions/color_extension.dart:230) · `static const colorComposeButton = NumberInboxPalette.actionGreen;`
- [theme_utils.dart:17](../../core/lib/presentation/utils/theme_utils.dart:17) · `primary: NumberInboxPalette.actionGreen,`
- [theme_utils.dart:31](../../core/lib/presentation/utils/theme_utils.dart:31) · `hoverColor: NumberInboxPalette.actionGreen.withValues(alpha: 0.08),`
- [theme_utils.dart:34](../../core/lib/presentation/utils/theme_utils.dart:34) · `backgroundColor: NumberInboxPalette.actionGreen,`
- [theme_utils.dart:41](../../core/lib/presentation/utils/theme_utils.dart:41) · `backgroundColor: NumberInboxPalette.actionGreen,`
- [theme_utils.dart:55](../../core/lib/presentation/utils/theme_utils.dart:55) · `borderSide: const BorderSide(color: NumberInboxPalette.actionGreen, width: 2),`
- [home_view.dart:73](../../lib/features/home/presentation/home_view.dart:73) · `color: NumberInboxPalette.actionGreen,`
- [numberinbox_colors.dart:8](../../lib/features/numberinbox/theme/numberinbox_colors.dart:8) · `static const primary = NumberInboxPalette.actionGreen;`

### `RecipientComposerWidgetStyle.cursorColor`

[recipient_composer_widget_style.dart:27](../../lib/features/composer/presentation/styles/recipient_composer_widget_style.dart:27) · `AppColor.primaryColor` · 1 reference lines

- [recipient_composer_widget.dart:241](../../lib/features/composer/presentation/widgets/recipient_composer_widget.dart:241) · `cursorColor: RecipientComposerWidgetStyle.cursorColor,`

### `RecipientComposerWidgetStyle.enableBorderColor`

[recipient_composer_widget_style.dart:25](../../lib/features/composer/presentation/styles/recipient_composer_widget_style.dart:25) · `AppColor.primaryColor` · 2 reference lines

- [recipient_composer_widget.dart:222](../../lib/features/composer/presentation/widgets/recipient_composer_widget.dart:222) · `enableBorderColor: RecipientComposerWidgetStyle.enableBorderColor,`
- [recipient_composer_widget.dart:224](../../lib/features/composer/presentation/widgets/recipient_composer_widget.dart:224) · `? RecipientComposerWidgetStyle.enableBorderColor`

### `SpamReportBannerButtonStyles.positiveButtonTextColor`

[spam_report_banner_button_styles.dart:12](../../lib/features/thread/presentation/styles/spam_banner/spam_report_banner_button_styles.dart:12) · `AppColor.primaryColor` · 0 reference lines


### `SpamReportBannerLabelStyles.highlightLabelTextColor`

[spam_report_banner_label_styles.dart:10](../../lib/features/thread/presentation/styles/spam_banner/spam_report_banner_label_styles.dart:10) · `AppColor.primaryColor` · 0 reference lines


### `SubjectComposerWidgetStyle.cursorColor`

[subject_composer_widget_style.dart:9](../../lib/features/composer/presentation/styles/subject_composer_widget_style.dart:9) · `AppColor.primaryColor` · 1 reference lines

- [subject_composer_widget.dart:38](../../lib/features/composer/presentation/widgets/subject_composer_widget.dart:38) · `cursorColor: SubjectComposerWidgetStyle.cursorColor,`

### `TabletBottomBarComposerWidgetStyle.selectedIconColor`

[tablet_bottom_bar_composer_widget_style.dart:17](../../lib/features/composer/presentation/styles/mobile/tablet_bottom_bar_composer_widget_style.dart:17) · `AppColor.primaryColor` · 2 reference lines

- [tablet_bottom_bar_composer_widget.dart:70](../../lib/features/composer/presentation/widgets/mobile/tablet_bottom_bar_composer_widget.dart:70) · `? TabletBottomBarComposerWidgetStyle.selectedIconColor`
- [tablet_bottom_bar_composer_widget.dart:84](../../lib/features/composer/presentation/widgets/mobile/tablet_bottom_bar_composer_widget.dart:84) · `? TabletBottomBarComposerWidgetStyle.selectedIconColor`

## Theme-dependent controls

The root uses [main.dart:60](../../lib/main.dart:60) and [theme_utils.dart:11](../../core/lib/presentation/utils/theme_utils.dart:11). The following sites either read its primary color explicitly or instantiate a button that can inherit its default fill. Explicit button styles take precedence.

- [icon_button_web.dart:96](../../core/lib/presentation/views/button/icon_button_web.dart:96) · `child: ElevatedButton(`
- [icon_button_web.dart:131](../../core/lib/presentation/views/button/icon_button_web.dart:131) · `child: ElevatedButton(`
- [material_text_icon_button.dart:40](../../lib/features/base/widget/material_text_icon_button.dart:40) · `return ElevatedButton.icon(`
- [base_login_view.dart:21](../../lib/features/login/presentation/base_login_view.dart:21) · `child: ElevatedButton(`
- [login_view.dart:190](../../lib/features/login/presentation/login_view.dart:190) · `child: ElevatedButton(`
- [horizontal_progress_loading_button.dart:14](../../lib/features/login/presentation/widgets/horizontal_progress_loading_button.dart:14) · `child: ElevatedButton(`
- [mailbox_dashboard_view_web.dart:453](../../lib/features/mailbox_dashboard/presentation/mailbox_dashboard_view_web.dart:453) · `child: ElevatedButton.icon(`
- [country_picker_sheet.dart:115](../../lib/features/numberinbox/country_picker_sheet.dart:115) · `? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)`
- [twake_welcome_view.dart:277](../../lib/features/starting_page/presentation/twake_welcome/twake_welcome_view.dart:277) · `? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)`
- [branded_action_button.dart:58](../../lib/features/starting_page/presentation/twake_welcome/widgets/branded_action_button.dart:58) · `child: FilledButton(`

## Theme and renderer indirection

- The main Material theme sets green for the primary role, default filled and elevated buttons, focus outlines, text selection cursor and handles, and a translucent hover color. Individual widgets may override these defaults.
- [NumberInboxColors.theme](../../lib/features/numberinbox/theme/numberinbox_colors.dart:21) uses its local `primary` alias for the color scheme, app bar, filled buttons, and field focus. No qualified app call site for this theme factory was found.
- [ConfirmationDialogBuilder](../../core/lib/presentation/views/dialog/confirmation_dialog_builder.dart:368) defaults its positive action fill to green when the caller supplies no override. [ModalListActionButtonWidget](../../core/lib/presentation/views/dialog/modal_list_action_button_widget.dart:49) supplies the same color to enabled and progressing positive actions. Its callers include the folder creator and label dialogs.
- [Profile popover action tint](../../lib/features/mailbox_dashboard/presentation/model/profile_setting/popup_menu_item_profile_setting_type_action.dart:25) illustrates how an asset containing green can render in another color.

## SVG assets

111 assets embed the RGB value. The links in the last column are static references to the asset name or its image getter. A reference can override the original color. An empty reference cell means no direct Dart call was found.

| SVG | Image getter | Dart reference lines |
|---|---|---|
| [ic_all_email.svg](../../assets/images/ic_all_email.svg) | [icAllEmail](../../core/lib/presentation/resources/image_paths.dart:289) | [destination_picker_view.dart:514](../../lib/features/destination_picker/presentation/destination_picker_view.dart:514) |
| [ic_app_dashboard.svg](../../assets/images/ic_app_dashboard.svg) | [icAppDashboard](../../core/lib/presentation/resources/image_paths.dart:163) | [mailbox_app_bar.dart:50](../../lib/features/mailbox/presentation/widgets/mailbox_app_bar.dart:50), [app_grid_dashboard_icon.dart:60](../../lib/features/mailbox_dashboard/presentation/widgets/app_dashboard/app_grid_dashboard_icon.dart:60) |
| [ic_arrow_bottom.svg](../../assets/images/ic_arrow_bottom.svg) | [icArrowBottom](../../core/lib/presentation/resources/image_paths.dart:204) | [attachment_header_composer_widget.dart:51](../../lib/features/composer/presentation/widgets/attachment_header_composer_widget.dart:51), [expand_mode_extension.dart:13](../../lib/features/mailbox/presentation/extensions/expand_mode_extension.dart:13) |
| [ic_arrow_down.svg](../../assets/images/ic_arrow_down.svg) | [icArrowDown](../../core/lib/presentation/resources/image_paths.dart:72) | — |
| [ic_arrow_left.svg](../../assets/images/ic_arrow_left.svg) | [icArrowLeft](../../core/lib/presentation/resources/image_paths.dart:205) | [expand_mode_extension.dart:15](../../lib/features/mailbox/presentation/extensions/expand_mode_extension.dart:15) |
| [ic_arrow_right.svg](../../assets/images/ic_arrow_right.svg) | [icArrowRight](../../core/lib/presentation/resources/image_paths.dart:206) | [attachment_header_composer_widget.dart:50](../../lib/features/composer/presentation/widgets/attachment_header_composer_widget.dart:50), [email_view_back_button.dart:34](../../lib/features/email/presentation/widgets/email_view_back_button.dart:34), [email_view_back_button.dart:53](../../lib/features/email/presentation/widgets/email_view_back_button.dart:53), [expand_mode_extension.dart:15](../../lib/features/mailbox/presentation/extensions/expand_mode_extension.dart:15), [manage_account_menu_view.dart:41](../../lib/features/manage_account/presentation/menu/manage_account_menu_view.dart:41), [ai_scribe_menu_submenu_icon.dart:16](../../scribe/lib/scribe/ai/presentation/widgets/items/ai_scribe_menu_submenu_icon.dart:16) |
| [ic_attachment_sb.svg](../../assets/images/ic_attachment_sb.svg) | [icAttachmentSB](../../core/lib/presentation/resources/image_paths.dart:106) | [quick_search_filter.dart:79](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:79) |
| [ic_avatar_group.svg](../../assets/images/ic_avatar_group.svg) | [icAvatarGroup](../../core/lib/presentation/resources/image_paths.dart:195) | [sending_state.dart:47](../../lib/features/offline_mode/model/sending_state.dart:47) |
| [ic_avatar_personal.svg](../../assets/images/ic_avatar_personal.svg) | [icAvatarPersonal](../../core/lib/presentation/resources/image_paths.dart:197) | [sending_state.dart:59](../../lib/features/offline_mode/model/sending_state.dart:59) |
| [ic_back.svg](../../assets/images/ic_back.svg) | [icBack](../../core/lib/presentation/resources/image_paths.dart:8) | [destination_picker_view.dart:607](../../lib/features/destination_picker/presentation/destination_picker_view.dart:607), [top_bar_destination_picker_builder.dart:94](../../lib/features/destination_picker/presentation/widgets/top_bar_destination_picker_builder.dart:94), [email_view_back_button.dart:35](../../lib/features/email/presentation/widgets/email_view_back_button.dart:35), [email_view_back_button.dart:54](../../lib/features/email/presentation/widgets/email_view_back_button.dart:54), [login_back_button.dart:23](../../lib/features/login/presentation/widgets/login_back_button.dart:23), [manage_account_menu_view.dart:42](../../lib/features/manage_account/presentation/menu/manage_account_menu_view.dart:42), [setting_first_level_tile_builder.dart:98](../../lib/features/manage_account/presentation/menu/widgets/setting_first_level_tile_builder.dart:98), [search_email_view.dart:283](../../lib/features/search/email/presentation/search_email_view.dart:283), [search_mailbox_view.dart:96](../../lib/features/search/mailbox/presentation/search_mailbox_view.dart:96), [app_bar_sending_queue_widget.dart:65](../../lib/features/sending_queue/presentation/widgets/app_bar_sending_queue_widget.dart:65), [search_app_bar_widget.dart:108](../../lib/features/thread/presentation/widgets/search_app_bar_widget.dart:108) |
| [ic_calendar_sb.svg](../../assets/images/ic_calendar_sb.svg) | [icCalendarSB](../../core/lib/presentation/resources/image_paths.dart:107) | [default_date_drop_down_field_widget.dart:59](../../lib/features/base/widget/default_field/default_date_drop_down_field_widget.dart:59), [quick_search_filter.dart:81](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:81), [quick_search_filter.dart:87](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:87) |
| [ic_cancel_selection.svg](../../assets/images/ic_cancel_selection.svg) | [icCancelSelection](../../core/lib/presentation/resources/image_paths.dart:169) | — |
| [ic_check.svg](../../assets/images/ic_check.svg) | [icCheck](../../core/lib/presentation/resources/image_paths.dart:251) | [color_circle_widget.dart:37](../../core/lib/presentation/views/color/color_circle_widget.dart:37), [folder_item_widget.dart:66](../../lib/features/mailbox/presentation/widgets/folder_item_widget.dart:66), [mailbox_item_widget.dart:306](../../lib/features/mailbox/presentation/widgets/mailbox_item_widget.dart:306), [email_forward_item_widget.dart:101](../../lib/features/manage_account/presentation/forward/widgets/email_forward_item_widget.dart:101), [rule_preview_banner.dart:41](../../lib/features/rules_filter_creator/presentation/widgets/rule_preview_banner.dart:41) |
| [ic_checkbox_selected.svg](../../assets/images/ic_checkbox_selected.svg) | [icCheckboxSelected](../../core/lib/presentation/resources/image_paths.dart:231) | [contact_item_widget.dart:78](../../lib/features/contact/presentation/widgets/contact_item_widget.dart:78), [email_recovery_form_desktop_builder.dart:233](../../lib/features/email_recovery/presentation/widgets/email_recovery_form/email_recovery_form_desktop_builder.dart:233), [email_recovery_form_mobile_builder.dart:158](../../lib/features/email_recovery/presentation/widgets/email_recovery_form/email_recovery_form_mobile_builder.dart:158), [identity_creator_form_bottom_view.dart:31](../../lib/features/identity_creator/presentation/widgets/identity_creator_form_bottom_view.dart:31), [label_item_context_menu.dart:38](../../lib/features/labels/presentation/widgets/label_item_context_menu.dart:38), [label_list_item.dart:128](../../lib/features/mailbox/presentation/widgets/labels/label_list_item.dart:128), [advanced_search_filter_form_bottom_view.dart:109](../../lib/features/mailbox_dashboard/presentation/widgets/advanced_search/advanced_search_filter_form_bottom_view.dart:109), [advanced_search_filter_form_bottom_view.dart:128](../../lib/features/mailbox_dashboard/presentation/widgets/advanced_search/advanced_search_filter_form_bottom_view.dart:128), [advanced_search_filter_form_bottom_view.dart:147](../../lib/features/mailbox_dashboard/presentation/widgets/advanced_search/advanced_search_filter_form_bottom_view.dart:147), [advanced_search_filter_form_bottom_view.dart:166](../../lib/features/mailbox_dashboard/presentation/widgets/advanced_search/advanced_search_filter_form_bottom_view.dart:166), [email_selection_action_type.dart:55](../../lib/features/thread/presentation/model/email_selection_action_type.dart:55), [email_tile_web_builder.dart:232](../../lib/features/thread/presentation/widgets/email_tile_web_builder.dart:232) |
| [ic_checkbox_unselected.svg](../../assets/images/ic_checkbox_unselected.svg) | [icCheckboxUnselected](../../core/lib/presentation/resources/image_paths.dart:230) | [contact_item_widget.dart:79](../../lib/features/contact/presentation/widgets/contact_item_widget.dart:79), [email_recovery_form_desktop_builder.dart:232](../../lib/features/email_recovery/presentation/widgets/email_recovery_form/email_recovery_form_desktop_builder.dart:232), [email_recovery_form_mobile_builder.dart:157](../../lib/features/email_recovery/presentation/widgets/email_recovery_form/email_recovery_form_mobile_builder.dart:157), [identity_creator_form_bottom_view.dart:30](../../lib/features/identity_creator/presentation/widgets/identity_creator_form_bottom_view.dart:30), [label_item_context_menu.dart:39](../../lib/features/labels/presentation/widgets/label_item_context_menu.dart:39), [label_list_item.dart:129](../../lib/features/mailbox/presentation/widgets/labels/label_list_item.dart:129), [advanced_search_filter_form_bottom_view.dart:108](../../lib/features/mailbox_dashboard/presentation/widgets/advanced_search/advanced_search_filter_form_bottom_view.dart:108), [advanced_search_filter_form_bottom_view.dart:127](../../lib/features/mailbox_dashboard/presentation/widgets/advanced_search/advanced_search_filter_form_bottom_view.dart:127), [advanced_search_filter_form_bottom_view.dart:146](../../lib/features/mailbox_dashboard/presentation/widgets/advanced_search/advanced_search_filter_form_bottom_view.dart:146), [advanced_search_filter_form_bottom_view.dart:165](../../lib/features/mailbox_dashboard/presentation/widgets/advanced_search/advanced_search_filter_form_bottom_view.dart:165), [email_tile_web_builder.dart:233](../../lib/features/thread/presentation/widgets/email_tile_web_builder.dart:233) |
| [ic_checked.svg](../../assets/images/ic_checked.svg) | [icChecked](../../core/lib/presentation/resources/image_paths.dart:128) | [default_date_drop_down_button.dart:129](../../lib/features/base/widget/default_field/default_date_drop_down_button.dart:129), [default_email_address_drop_down_button.dart:141](../../lib/features/base/widget/default_field/default_email_address_drop_down_button.dart:141), [drop_down_button_widget.dart:102](../../lib/features/base/widget/drop_down_button_widget.dart:102), [bottom_modal_folder_tree_list_widget.dart:44](../../lib/features/mailbox_creator/presentation/widgets/bottom_modal/bottom_modal_folder_tree_list_widget.dart:44), [bottom_modal_folder_tree_list_widget.dart:123](../../lib/features/mailbox_creator/presentation/widgets/bottom_modal/bottom_modal_folder_tree_list_widget.dart:123), [bottom_modal_folder_tree_list_widget.dart:146](../../lib/features/mailbox_creator/presentation/widgets/bottom_modal/bottom_modal_folder_tree_list_widget.dart:146), [label_drop_down_button.dart:121](../../lib/features/mailbox_dashboard/presentation/widgets/advanced_search/label_drop_down_button.dart:121), [sort_by_drop_down_button.dart:48](../../lib/features/mailbox_dashboard/presentation/widgets/advanced_search/sort_by_drop_down_button.dart:48), [lanuage_item_widget.dart:51](../../lib/features/manage_account/presentation/language_and_region/widgets/lanuage_item_widget.dart:51) |
| [ic_chevron_down.svg](../../assets/images/ic_chevron_down.svg) | [icChevronDown](../../core/lib/presentation/resources/image_paths.dart:20) | [ai_scribe_improve_button.dart:34](../../scribe/lib/scribe/ai/presentation/widgets/modal/suggestion/ai_scribe_improve_button.dart:34) |
| [ic_collapse_attachment.svg](../../assets/images/ic_collapse_attachment.svg) | — | — |
| [ic_collapse_folder.svg](../../assets/images/ic_collapse_folder.svg) | [icCollapseFolder](../../core/lib/presentation/resources/image_paths.dart:7) | [setting_first_level_tile_builder.dart:99](../../lib/features/manage_account/presentation/menu/widgets/setting_first_level_tile_builder.dart:99), [search_email_view.dart:283](../../lib/features/search/email/presentation/search_email_view.dart:283), [app_bar_sending_queue_widget.dart:64](../../lib/features/sending_queue/presentation/widgets/app_bar_sending_queue_widget.dart:64) |
| [ic_compose.svg](../../assets/images/ic_compose.svg) | [icCompose](../../core/lib/presentation/resources/image_paths.dart:24) | [list_identity_item_actions_widget.dart:34](../../lib/features/manage_account/presentation/identities/widgets/list_identity_item_actions_widget.dart:34) |
| [ic_copy.svg](../../assets/images/ic_copy.svg) | [icCopy](../../core/lib/presentation/resources/image_paths.dart:238) | [email_address_action_type.dart:24](../../lib/features/composer/presentation/model/email_address_action_type.dart:24), [desktop_edit_recipients_view.dart:101](../../lib/features/composer/presentation/view/web/desktop_edit_recipients_view.dart:101), [email_address_detail_widget.dart:72](../../lib/features/email/presentation/widgets/email_address_detail_widget.dart:72), [mailbox_actions.dart:102](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:102), [copy_subaddress_widget.dart:41](../../lib/features/mailbox/presentation/widgets/copy_subaddress_widget.dart:41), [profile_setting_menu_overlay.dart:66](../../lib/features/mailbox_dashboard/presentation/widgets/profile_setting/profile_setting_menu_overlay.dart:66), [ai_scribe_suggestion_success_toolbar.dart:29](../../scribe/lib/scribe/ai/presentation/widgets/modal/suggestion/ai_scribe_suggestion_success_toolbar.dart:29) |
| [ic_create_new_folder.svg](../../assets/images/ic_create_new_folder.svg) | [icCreateNewFolder](../../core/lib/presentation/resources/image_paths.dart:166) | — |
| [ic_delete.svg](../../assets/images/ic_delete.svg) | [icDelete](../../core/lib/presentation/resources/image_paths.dart:29) | — |
| [ic_delete_dialog_identity.svg](../../assets/images/ic_delete_dialog_identity.svg) | [icDeleteDialogIdentity](../../core/lib/presentation/resources/image_paths.dart:95) | — |
| [ic_delete_rule.svg](../../assets/images/ic_delete_rule.svg) | [icDeleteRule](../../core/lib/presentation/resources/image_paths.dart:149) | [list_identity_item_actions_widget.dart:57](../../lib/features/manage_account/presentation/identities/widgets/list_identity_item_actions_widget.dart:57) |
| [ic_download_attachment.svg](../../assets/images/ic_download_attachment.svg) | [icDownloadAttachment](../../core/lib/presentation/resources/image_paths.dart:162) | [email_action_type_extension.dart:174](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:174), [attachment_item_widget.dart:89](../../lib/features/email/presentation/widgets/attachment_item_widget.dart:89), [attachments_info.dart:75](../../lib/features/email/presentation/widgets/attachments_info.dart:75) |
| [ic_drop_zone_icon.svg](../../assets/images/ic_drop_zone_icon.svg) | [icDropZoneIcon](../../core/lib/presentation/resources/image_paths.dart:221) | [attachment_drop_zone_widget.dart:52](../../lib/features/composer/presentation/widgets/web/attachment_drop_zone_widget.dart:52), [local_file_drop_zone_widget.dart:54](../../lib/features/composer/presentation/widgets/web/local_file_drop_zone_widget.dart:54) |
| [ic_edit_rule_mobile.svg](../../assets/images/ic_edit_rule_mobile.svg) | [icEditRuleMobile](../../core/lib/presentation/resources/image_paths.dart:151) | — |
| [ic_email.svg](../../assets/images/ic_email.svg) | [icEmail](../../core/lib/presentation/resources/image_paths.dart:92) | [mailbox_dashboard_controller.dart:2725](../../lib/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart:2725), [mailbox_dashboard_controller.dart:2736](../../lib/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart:2736) |
| [ic_email_rules.svg](../../assets/images/ic_email_rules.svg) | [icEmailRules](../../core/lib/presentation/resources/image_paths.dart:146) | [account_menu_item.dart:31](../../lib/features/manage_account/presentation/model/account_menu_item.dart:31) |
| [ic_encrypted.svg](../../assets/images/ic_encrypted.svg) | [icEncrypted](../../core/lib/presentation/resources/image_paths.dart:102) | [login_view_web.dart:135](../../lib/features/login/presentation/login_view_web.dart:135) |
| [ic_expand_folder.svg](../../assets/images/ic_expand_folder.svg) | [icExpandFolder](../../core/lib/presentation/resources/image_paths.dart:6) | — |
| [ic_filter_message_all.svg](../../assets/images/ic_filter_message_all.svg) | [icFilterMessageAll](../../core/lib/presentation/resources/image_paths.dart:55) | [filter_message_option_style_extension.dart:17](../../lib/features/thread/presentation/extensions/filter_message_option_style_extension.dart:17), [thread_view.dart:782](../../lib/features/thread/presentation/thread_view.dart:782) |
| [ic_filter_message_attachments.svg](../../assets/images/ic_filter_message_attachments.svg) | [icFilterMessageAttachments](../../core/lib/presentation/resources/image_paths.dart:56) | [filter_message_option_style_extension.dart:21](../../lib/features/thread/presentation/extensions/filter_message_option_style_extension.dart:21) |
| [ic_filter_sb.svg](../../assets/images/ic_filter_sb.svg) | [icFilterSB](../../core/lib/presentation/resources/image_paths.dart:223) | [quick_search_filter.dart:85](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:85) |
| [ic_filter_selected.svg](../../assets/images/ic_filter_selected.svg) | [icFilterSelected](../../core/lib/presentation/resources/image_paths.dart:54) | [popup_menu_item_composer_type_action.dart:33](../../lib/features/composer/presentation/model/popup_menu_item_composer_type_action.dart:33), [recipient_suggestion_item_widget.dart:132](../../lib/features/composer/presentation/widgets/recipient_suggestion_item_widget.dart:132), [bottom_bar_composer_widget.dart:183](../../lib/features/composer/presentation/widgets/web/bottom_bar_composer_widget.dart:183), [bottom_bar_composer_widget.dart:196](../../lib/features/composer/presentation/widgets/web/bottom_bar_composer_widget.dart:196), [bottom_bar_composer_widget.dart:209](../../lib/features/composer/presentation/widgets/web/bottom_bar_composer_widget.dart:209), [mobile_responsive_app_bar_composer_widget.dart:166](../../lib/features/composer/presentation/widgets/web/mobile_responsive_app_bar_composer_widget.dart:166), [mobile_responsive_app_bar_composer_widget.dart:179](../../lib/features/composer/presentation/widgets/web/mobile_responsive_app_bar_composer_widget.dart:179), [mobile_responsive_app_bar_composer_widget.dart:192](../../lib/features/composer/presentation/widgets/web/mobile_responsive_app_bar_composer_widget.dart:192), [contact_suggestion_box_item.dart:74](../../lib/features/contact/presentation/widgets/contact_suggestion_box_item.dart:74), [context_item_language_action.dart:23](../../lib/features/manage_account/presentation/model/language/context_item_language_action.dart:23), [context_item_condition_combiner_action.dart:23](../../lib/features/rules_filter_creator/presentation/model/context_menu/context_item_condition_combiner_action.dart:23), [context_item_rule_condition_comparator_action.dart:23](../../lib/features/rules_filter_creator/presentation/model/context_menu/context_item_rule_condition_comparator_action.dart:23), [context_item_rule_condition_field_action.dart:23](../../lib/features/rules_filter_creator/presentation/model/context_menu/context_item_rule_condition_field_action.dart:23), [context_item_rule_filter_action.dart:22](../../lib/features/rules_filter_creator/presentation/model/context_menu/context_item_rule_filter_action.dart:22), [context_item_all_labels_action.dart:20](../../lib/features/search/email/presentation/model/context_item_all_labels_action.dart:20), [context_item_label_type_action.dart:19](../../lib/features/search/email/presentation/model/context_item_label_type_action.dart:19), [context_item_receive_time_type_action.dart:22](../../lib/features/search/email/presentation/model/context_item_receive_time_type_action.dart:22), [context_item_sort_order_type_action.dart:22](../../lib/features/search/email/presentation/model/context_item_sort_order_type_action.dart:22), [popup_menu_item_all_labels_action.dart:20](../../lib/features/search/email/presentation/model/popup_menu_item_all_labels_action.dart:20), [popup_menu_item_date_filter_action.dart:22](../../lib/features/search/email/presentation/model/popup_menu_item_date_filter_action.dart:22), [popup_menu_item_label_type_action.dart:20](../../lib/features/search/email/presentation/model/popup_menu_item_label_type_action.dart:20), [popup_menu_item_sort_order_type_action.dart:22](../../lib/features/search/email/presentation/model/popup_menu_item_sort_order_type_action.dart:22), [email_receive_time_action_tile_widget.dart:45](../../lib/features/search/email/presentation/widgets/email_receive_time_action_tile_widget.dart:45), [email_sort_by_action_tile_widget.dart:44](../../lib/features/search/email/presentation/widgets/email_sort_by_action_tile_widget.dart:44), [context_item_filter_message_option_action.dart:27](../../lib/features/thread/presentation/model/context_item_filter_message_option_action.dart:27), [popup_menu_item_filter_message_action.dart:26](../../lib/features/thread/presentation/model/popup_menu_item_filter_message_action.dart:26) |
| [ic_forward.svg](../../assets/images/ic_forward.svg) | [icForward](../../core/lib/presentation/resources/image_paths.dart:36) | [email_action_type_extension.dart:184](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:184), [email_view_bottom_bar_widget.dart:139](../../lib/features/email/presentation/widgets/email_view_bottom_bar_widget.dart:139), [account_menu_item.dart:33](../../lib/features/manage_account/presentation/model/account_menu_item.dart:33) |
| [ic_forwarded.svg](../../assets/images/ic_forwarded.svg) | [icForwarded](../../core/lib/presentation/resources/image_paths.dart:191) | [base_email_item_tile.dart:309](../../lib/features/thread/presentation/mixin/base_email_item_tile.dart:309) |
| [ic_help.svg](../../assets/images/ic_help.svg) | [icHelp](../../core/lib/presentation/resources/image_paths.dart:236) | [mailbox_app_bar.dart:44](../../lib/features/mailbox/presentation/widgets/mailbox_app_bar.dart:44), [navigation_bar_widget.dart:83](../../lib/features/mailbox_dashboard/presentation/widgets/navigation_bar/navigation_bar_widget.dart:83), [navigation_bar_widget.dart:116](../../lib/features/mailbox_dashboard/presentation/widgets/navigation_bar/navigation_bar_widget.dart:116), [account_menu_item.dart:41](../../lib/features/manage_account/presentation/model/account_menu_item.dart:41) |
| [ic_hide_mailbox.svg](../../assets/images/ic_hide_mailbox.svg) | [icHideMailbox](../../core/lib/presentation/resources/image_paths.dart:187) | [mailbox_actions.dart:122](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:122), [mailbox_subscribe_button.dart:37](../../lib/features/manage_account/presentation/mailbox_visibility/widgets/mailbox_subscribe_button.dart:37) |
| [ic_info_circle_outline.svg](../../assets/images/ic_info_circle_outline.svg) | [icInfoCircleOutline](../../core/lib/presentation/resources/image_paths.dart:179) | [app_toast.dart:72](../../core/lib/presentation/utils/app_toast.dart:72), [report_message_banner.dart:51](../../lib/features/base/widget/report_message_banner.dart:51), [report_message_banner.dart:94](../../lib/features/base/widget/report_message_banner.dart:94), [email_forward_item_widget.dart:102](../../lib/features/manage_account/presentation/forward/widgets/email_forward_item_widget.dart:102), [forward_warning_banner.dart:37](../../lib/features/manage_account/presentation/forward/widgets/forward_warning_banner.dart:37), [rule_preview_banner.dart:41](../../lib/features/rules_filter_creator/presentation/widgets/rule_preview_banner.dart:41) |
| [ic_integration.svg](../../assets/images/ic_integration.svg) | [icIntegration](../../core/lib/presentation/resources/image_paths.dart:103) | [login_view_web.dart:165](../../lib/features/login/presentation/login_view_web.dart:165) |
| [ic_jmap_standard.svg](../../assets/images/ic_jmap_standard.svg) | [icJMAPStandard](../../core/lib/presentation/resources/image_paths.dart:101) | [login_view_web.dart:120](../../lib/features/login/presentation/login_view_web.dart:120) |
| [ic_keyboard.svg](../../assets/images/ic_keyboard.svg) | [icKeyboard](../../core/lib/presentation/resources/image_paths.dart:263) | [account_menu_item.dart:45](../../lib/features/manage_account/presentation/model/account_menu_item.dart:45) |
| [ic_language.svg](../../assets/images/ic_language.svg) | [icLanguage](../../core/lib/presentation/resources/image_paths.dart:127) | [account_menu_item.dart:27](../../lib/features/manage_account/presentation/model/account_menu_item.dart:27) |
| [ic_login_graphic.svg](../../assets/images/ic_login_graphic.svg) | [icLoginGraphic](../../core/lib/presentation/resources/image_paths.dart:213) | — |
| [ic_logout.svg](../../assets/images/ic_logout.svg) | [icLogout](../../core/lib/presentation/resources/image_paths.dart:86) | [profile_setting_action_type.dart:23](../../lib/features/mailbox_dashboard/presentation/model/profile_setting/profile_setting_action_type.dart:23) |
| [ic_mailbox_sending_queue.svg](../../assets/images/ic_mailbox_sending_queue.svg) | [icMailboxSendingQueue](../../core/lib/presentation/resources/image_paths.dart:193) | [sending_queue_mailbox_widget.dart:31](../../lib/features/mailbox/presentation/widgets/sending_queue_mailbox_widget.dart:31), [banner_message_sending_queue_widget.dart:31](../../lib/features/sending_queue/presentation/widgets/banner_message_sending_queue_widget.dart:31) |
| [ic_mailbox_visibility.svg](../../assets/images/ic_mailbox_visibility.svg) | [icMailboxVisibility](../../core/lib/presentation/resources/image_paths.dart:189) | [account_menu_item.dart:37](../../lib/features/manage_account/presentation/model/account_menu_item.dart:37) |
| [ic_mark_all_as_read.svg](../../assets/images/ic_mark_all_as_read.svg) | [icMarkAllAsRead](../../core/lib/presentation/resources/image_paths.dart:74) | — |
| [ic_mark_as_read.svg](../../assets/images/ic_mark_as_read.svg) | [icMarkAsRead](../../core/lib/presentation/resources/image_paths.dart:185) | [mailbox_actions.dart:112](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:112), [mailbox_actions.dart:130](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:130), [thread_view.dart:707](../../lib/features/thread/presentation/thread_view.dart:707) |
| [ic_menu_mailbox.svg](../../assets/images/ic_menu_mailbox.svg) | [icMenuMailbox](../../core/lib/presentation/resources/image_paths.dart:200) | [app_bar_sending_queue_widget.dart:42](../../lib/features/sending_queue/presentation/widgets/app_bar_sending_queue_widget.dart:42) |
| [ic_move.svg](../../assets/images/ic_move.svg) | [icMove](../../core/lib/presentation/resources/image_paths.dart:31) | [desktop_list_email_action_hover_widget.dart:84](../../lib/features/thread/presentation/widgets/desktop_list_email_action_hover_widget.dart:84), [web_tablet_body_email_item_widget.dart:226](../../lib/features/thread/presentation/widgets/web_tablet_body_email_item_widget.dart:226) |
| [ic_move_mailbox.svg](../../assets/images/ic_move_mailbox.svg) | [icMoveMailbox](../../core/lib/presentation/resources/image_paths.dart:184) | [mailbox_actions.dart:114](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:114), [top_bar_thread_selection.dart:99](../../lib/features/mailbox_dashboard/presentation/widgets/top_bar_thread_selection.dart:99), [email_selection_action_type.dart:65](../../lib/features/thread/presentation/model/email_selection_action_type.dart:65) |
| [ic_new_message.svg](../../assets/images/ic_new_message.svg) | [icNewMessage](../../core/lib/presentation/resources/image_paths.dart:63) | — |
| [ic_newer.svg](../../assets/images/ic_newer.svg) | [icNewer](../../core/lib/presentation/resources/image_paths.dart:168) | [thread_detail_view.dart:58](../../lib/features/thread_detail/presentation/thread_detail_view.dart:58) |
| [ic_not_spam.svg](../../assets/images/ic_not_spam.svg) | — | — |
| [ic_notification.svg](../../assets/images/ic_notification.svg) | [icNotification](../../core/lib/presentation/resources/image_paths.dart:228) | [account_menu_item.dart:39](../../lib/features/manage_account/presentation/model/account_menu_item.dart:39) |
| [ic_older.svg](../../assets/images/ic_older.svg) | [icOlder](../../core/lib/presentation/resources/image_paths.dart:167) | [thread_detail_view.dart:67](../../lib/features/thread_detail/presentation/thread_detail_view.dart:67) |
| [ic_open_in_new_tab.svg](../../assets/images/ic_open_in_new_tab.svg) | [icOpenInNewTab](../../core/lib/presentation/resources/image_paths.dart:178) | [email_action_type_extension.dart:178](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:178), [mailbox_actions.dart:100](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:100), [desktop_list_email_action_hover_widget.dart:50](../../lib/features/thread/presentation/widgets/desktop_list_email_action_hover_widget.dart:50), [web_tablet_body_email_item_widget.dart:190](../../lib/features/thread/presentation/widgets/web_tablet_body_email_item_widget.dart:190) |
| [ic_preferences.svg](../../assets/images/ic_preferences.svg) | [icPreferences](../../core/lib/presentation/resources/image_paths.dart:227) | [account_menu_item.dart:29](../../lib/features/manage_account/presentation/model/account_menu_item.dart:29) |
| [ic_printer.svg](../../assets/images/ic_printer.svg) | [icPrinter](../../core/lib/presentation/resources/image_paths.dart:226) | [email_action_type_extension.dart:180](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:180), [bottom_bar_composer_widget.dart:218](../../lib/features/composer/presentation/widgets/web/bottom_bar_composer_widget.dart:218), [mobile_responsive_app_bar_composer_widget.dart:201](../../lib/features/composer/presentation/widgets/web/mobile_responsive_app_bar_composer_widget.dart:201), [single_email_controller.dart:1328](../../lib/features/email/presentation/controller/single_email_controller.dart:1328), [email_view_app_bar_widget.dart:152](../../lib/features/email/presentation/widgets/email_view_app_bar_widget.dart:152) |
| [ic_profiles.svg](../../assets/images/ic_profiles.svg) | [icProfiles](../../core/lib/presentation/resources/image_paths.dart:88) | [account_menu_item.dart:25](../../lib/features/manage_account/presentation/model/account_menu_item.dart:25), [account_menu_item.dart:49](../../lib/features/manage_account/presentation/model/account_menu_item.dart:49) |
| [ic_quick_creating_rule.svg](../../assets/images/ic_quick_creating_rule.svg) | [icQuickCreatingRule](../../core/lib/presentation/resources/image_paths.dart:175) | [email_action_type_extension.dart:168](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:168), [email_address_action_type.dart:28](../../lib/features/composer/presentation/model/email_address_action_type.dart:28) |
| [ic_quotas.svg](../../assets/images/ic_quotas.svg) | [icQuotas](../../core/lib/presentation/resources/image_paths.dart:172) | [mailbox_sidebar_footer.dart:83](../../lib/features/mailbox/presentation/widgets/sidebar/mailbox_sidebar_footer.dart:83) |
| [ic_quotas_out_of_storage.svg](../../assets/images/ic_quotas_out_of_storage.svg) | [icQuotasOutOfStorage](../../core/lib/presentation/resources/image_paths.dart:174) | — |
| [ic_quotas_warning.svg](../../assets/images/ic_quotas_warning.svg) | [icQuotasWarning](../../core/lib/presentation/resources/image_paths.dart:173) | [attachment_header_composer_widget.dart:79](../../lib/features/composer/presentation/widgets/attachment_header_composer_widget.dart:79) |
| [ic_radio_selected.svg](../../assets/images/ic_radio_selected.svg) | [icRadioSelected](../../core/lib/presentation/resources/image_paths.dart:250) | [identity_list_tile_builder.dart:55](../../lib/features/manage_account/presentation/identities/widgets/identity_list_tile_builder.dart:55) |
| [ic_read.svg](../../assets/images/ic_read.svg) | [icRead](../../core/lib/presentation/resources/image_paths.dart:25) | [email_action_type_extension.dart:160](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:160), [top_bar_thread_selection.dart:65](../../lib/features/mailbox_dashboard/presentation/widgets/top_bar_thread_selection.dart:65), [email_selection_action_type.dart:57](../../lib/features/thread/presentation/model/email_selection_action_type.dart:57), [desktop_list_email_action_hover_widget.dart:65](../../lib/features/thread/presentation/widgets/desktop_list_email_action_hover_widget.dart:65), [web_tablet_body_email_item_widget.dart:207](../../lib/features/thread/presentation/widgets/web_tablet_body_email_item_widget.dart:207) |
| [ic_read_receipt.svg](../../assets/images/ic_read_receipt.svg) | [icReadReceipt](../../core/lib/presentation/resources/image_paths.dart:220) | [composer_action_type.dart:34](../../lib/features/composer/presentation/model/composer_action_type.dart:34), [tablet_bottom_bar_composer_widget.dart:79](../../lib/features/composer/presentation/widgets/mobile/tablet_bottom_bar_composer_widget.dart:79), [bottom_bar_composer_widget.dart:204](../../lib/features/composer/presentation/widgets/web/bottom_bar_composer_widget.dart:204), [mobile_responsive_app_bar_composer_widget.dart:187](../../lib/features/composer/presentation/widgets/web/mobile_responsive_app_bar_composer_widget.dart:187) |
| [ic_read_receipt_message.svg](../../assets/images/ic_read_receipt_message.svg) | [icReadReceiptMessage](../../core/lib/presentation/resources/image_paths.dart:165) | [single_email_controller.dart:1088](../../lib/features/email/presentation/controller/single_email_controller.dart:1088) |
| [ic_read_toast.svg](../../assets/images/ic_read_toast.svg) | [icReadToast](../../core/lib/presentation/resources/image_paths.dart:32) | [mailbox_dashboard_controller.dart:1289](../../lib/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart:1289), [mailbox_dashboard_controller.dart:2012](../../lib/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart:2012), [mailbox_dashboard_controller.dart:2019](../../lib/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart:2019) |
| [ic_recover_deleted_messages.svg](../../assets/images/ic_recover_deleted_messages.svg) | [icRecoverDeletedMessages](../../core/lib/presentation/resources/image_paths.dart:225) | [presentation_mailbox_extension.dart:31](../../lib/features/mailbox/presentation/extensions/presentation_mailbox_extension.dart:31), [mailbox_actions.dart:132](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:132), [mailbox_dashboard_controller.dart:3241](../../lib/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart:3241), [mailbox_dashboard_controller.dart:3264](../../lib/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart:3264), [mailbox_dashboard_view_web.dart:522](../../lib/features/mailbox_dashboard/presentation/mailbox_dashboard_view_web.dart:522) |
| [ic_refresh.svg](../../assets/images/ic_refresh.svg) | [icRefresh](../../core/lib/presentation/resources/image_paths.dart:75) | [mailbox_dashboard_view_web.dart:437](../../lib/features/mailbox_dashboard/presentation/mailbox_dashboard_view_web.dart:437), [bottom_bar_sending_queue_widget.dart:70](../../lib/features/sending_queue/presentation/widgets/bottom_bar_sending_queue_widget.dart:70), [ai_scribe_suggestion_success_toolbar.dart:43](../../scribe/lib/scribe/ai/presentation/widgets/modal/suggestion/ai_scribe_suggestion_success_toolbar.dart:43) |
| [ic_remove_link.svg](../../assets/images/ic_remove_link.svg) | [icRemoveLink](../../core/lib/presentation/resources/image_paths.dart:269) | [handle_insert_link_composer_extension.dart:32](../../lib/features/composer/presentation/extensions/handle_insert_link_composer_extension.dart:32) |
| [ic_rename_mailbox.svg](../../assets/images/ic_rename_mailbox.svg) | [icRenameMailbox](../../core/lib/presentation/resources/image_paths.dart:60) | [label_action_type.dart:71](../../lib/features/labels/presentation/models/label_action_type.dart:71), [mailbox_actions.dart:118](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:118) |
| [ic_reply.svg](../../assets/images/ic_reply.svg) | [icReply](../../core/lib/presentation/resources/image_paths.dart:35) | [email_action_type_extension.dart:182](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:182), [email_action_type_extension.dart:188](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:188), [email_view_app_bar_widget.dart:136](../../lib/features/email/presentation/widgets/email_view_app_bar_widget.dart:136), [email_view_bottom_bar_widget.dart:93](../../lib/features/email/presentation/widgets/email_view_bottom_bar_widget.dart:93), [email_view_bottom_bar_widget.dart:116](../../lib/features/email/presentation/widgets/email_view_bottom_bar_widget.dart:116), [base_email_item_tile.dart:303](../../lib/features/thread/presentation/mixin/base_email_item_tile.dart:303) |
| [ic_reply_all.svg](../../assets/images/ic_reply_all.svg) | [icReplyAll](../../core/lib/presentation/resources/image_paths.dart:34) | [email_action_type_extension.dart:186](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:186), [email_view_bottom_bar_widget.dart:69](../../lib/features/email/presentation/widgets/email_view_bottom_bar_widget.dart:69) |
| [ic_reply_and_forward.svg](../../assets/images/ic_reply_and_forward.svg) | [icReplyAndForward](../../core/lib/presentation/resources/image_paths.dart:192) | [base_email_item_tile.dart:297](../../lib/features/thread/presentation/mixin/base_email_item_tile.dart:297) |
| [ic_reply_to.svg](../../assets/images/ic_reply_to.svg) | [icReplyTo](../../core/lib/presentation/resources/image_paths.dart:93) | — |
| [ic_rich_toolbar.svg](../../assets/images/ic_rich_toolbar.svg) | [icRichToolbar](../../core/lib/presentation/resources/image_paths.dart:215) | [app_bar_composer_widget.dart:67](../../lib/features/composer/presentation/widgets/mobile/app_bar_composer_widget.dart:67), [landscape_app_bar_composer_widget.dart:69](../../lib/features/composer/presentation/widgets/mobile/landscape_app_bar_composer_widget.dart:69), [bottom_bar_composer_widget.dart:79](../../lib/features/composer/presentation/widgets/web/bottom_bar_composer_widget.dart:79), [mobile_responsive_app_bar_composer_widget.dart:95](../../lib/features/composer/presentation/widgets/web/mobile_responsive_app_bar_composer_widget.dart:95) |
| [ic_save_to_draft.svg](../../assets/images/ic_save_to_draft.svg) | [icSaveToDraft](../../core/lib/presentation/resources/image_paths.dart:216) | [composer_action_type.dart:36](../../lib/features/composer/presentation/model/composer_action_type.dart:36), [composer_action_type.dart:38](../../lib/features/composer/presentation/model/composer_action_type.dart:38), [tablet_bottom_bar_composer_widget.dart:93](../../lib/features/composer/presentation/widgets/mobile/tablet_bottom_bar_composer_widget.dart:93), [bottom_bar_composer_widget.dart:230](../../lib/features/composer/presentation/widgets/web/bottom_bar_composer_widget.dart:230), [bottom_bar_composer_widget.dart:259](../../lib/features/composer/presentation/widgets/web/bottom_bar_composer_widget.dart:259), [mobile_responsive_app_bar_composer_widget.dart:213](../../lib/features/composer/presentation/widgets/web/mobile_responsive_app_bar_composer_widget.dart:213), [mobile_responsive_app_bar_composer_widget.dart:225](../../lib/features/composer/presentation/widgets/web/mobile_responsive_app_bar_composer_widget.dart:225) |
| [ic_search_bar.svg](../../assets/images/ic_search_bar.svg) | [icSearchBar](../../core/lib/presentation/resources/image_paths.dart:22) | [search_bar_view.dart:47](../../core/lib/presentation/views/search/search_bar_view.dart:47), [from_composer_bottom_sheet_builder.dart:107](../../lib/features/composer/presentation/widgets/mobile/from_composer_bottom_sheet_builder.dart:107), [sidebar_section_header_icons_extension.dart:7](../../lib/features/mailbox/presentation/extensions/sidebar_section_header_icons_extension.dart:7), [search_input_form_widget.dart:285](../../lib/features/mailbox_dashboard/presentation/widgets/search_input_form_widget.dart:285), [search_mailbox_view.dart:116](../../lib/features/search/mailbox/presentation/search_mailbox_view.dart:116), [search_app_bar_widget.dart:80](../../lib/features/thread/presentation/widgets/search_app_bar_widget.dart:80), [drive_attachment_context_menu_tile.dart:41](../../workplace/lib/presentation/widget/drive_attachment_context_menu_tile.dart:41), [drive_attachment_picker_button.dart:43](../../workplace/lib/presentation/widget/drive_attachment_picker_button.dart:43) |
| [ic_select_all.svg](../../assets/images/ic_select_all.svg) | [icSelectAll](../../core/lib/presentation/resources/image_paths.dart:76) | [mailbox_dashboard_view_web.dart:456](../../lib/features/mailbox_dashboard/presentation/mailbox_dashboard_view_web.dart:456) |
| [ic_selected.svg](../../assets/images/ic_selected.svg) | [icSelected](../../core/lib/presentation/resources/image_paths.dart:27) | [sending_email_tile_widget.dart:68](../../lib/features/sending_queue/presentation/widgets/sending_email_tile_widget.dart:68), [base_email_item_tile.dart:274](../../lib/features/thread/presentation/mixin/base_email_item_tile.dart:274), [base_email_item_tile.dart:284](../../lib/features/thread/presentation/mixin/base_email_item_tile.dart:284) |
| [ic_selected_recipient.svg](../../assets/images/ic_selected_recipient.svg) | [icSelectedRecipient](../../core/lib/presentation/resources/image_paths.dart:170) | [email_forward_item_widget.dart:186](../../lib/features/manage_account/presentation/forward/widgets/email_forward_item_widget.dart:186) |
| [ic_selected_sb.svg](../../assets/images/ic_selected_sb.svg) | [icSelectedSB](../../core/lib/presentation/resources/image_paths.dart:109) | [item_menu_font_size_widget.dart:40](../../lib/features/composer/presentation/widgets/web/item_menu_font_size_widget.dart:40), [destination_picker_view.dart:524](../../lib/features/destination_picker/presentation/destination_picker_view.dart:524), [destination_picker_view.dart:547](../../lib/features/destination_picker/presentation/destination_picker_view.dart:547), [destination_picker_search_mailbox_item_builder.dart:147](../../lib/features/destination_picker/presentation/widgets/destination_picker_search_mailbox_item_builder.dart:147), [set_default_identity_checkbox_builder.dart:44](../../lib/features/identity_creator/presentation/widgets/set_default_identity_checkbox_builder.dart:44), [mailbox_item_widget.dart:307](../../lib/features/mailbox/presentation/widgets/mailbox_item_widget.dart:307), [quick_search_filter.dart:79](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:79), [quick_search_filter.dart:81](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:81), [quick_search_filter.dart:83](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:83), [quick_search_filter.dart:95](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:95), [quick_search_filter.dart:97](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:97), [filter_message_option_style_extension.dart:58](../../lib/features/thread/presentation/extensions/filter_message_option_style_extension.dart:58) |
| [ic_send_mobile.svg](../../assets/images/ic_send_mobile.svg) | [icSendMobile](../../core/lib/presentation/resources/image_paths.dart:69) | [mobile_responsive_app_bar_composer_widget.dart:142](../../lib/features/composer/presentation/widgets/web/mobile_responsive_app_bar_composer_widget.dart:142) |
| [ic_send_success_toast.svg](../../assets/images/ic_send_success_toast.svg) | [icSendSuccessToast](../../core/lib/presentation/resources/image_paths.dart:58) | [mailbox_dashboard_controller.dart:2588](../../lib/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart:2588), [mailbox_dashboard_controller.dart:2965](../../lib/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart:2965) |
| [ic_send_toast.svg](../../assets/images/ic_send_toast.svg) | [icSendToast](../../core/lib/presentation/resources/image_paths.dart:57) | [mailbox_dashboard_controller.dart:485](../../lib/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart:485) |
| [ic_send_toast_error.svg](../../assets/images/ic_send_toast_error.svg) | [icSendToastError](../../core/lib/presentation/resources/image_paths.dart:80) | — |
| [ic_setting.svg](../../assets/images/ic_setting.svg) | [icSetting](../../core/lib/presentation/resources/image_paths.dart:87) | [profile_setting_action_type.dart:21](../../lib/features/mailbox_dashboard/presentation/model/profile_setting/profile_setting_action_type.dart:21), [profile_setting_icon.dart:82](../../lib/features/mailbox_dashboard/presentation/widgets/profile_setting/profile_setting_icon.dart:82) |
| [ic_show_mailbox.svg](../../assets/images/ic_show_mailbox.svg) | [icShowMailbox](../../core/lib/presentation/resources/image_paths.dart:188) | [mailbox_actions.dart:124](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:124), [mailbox_subscribe_button.dart:38](../../lib/features/manage_account/presentation/mailbox_visibility/widgets/mailbox_subscribe_button.dart:38) |
| [ic_sign_out.svg](../../assets/images/ic_sign_out.svg) | [icSignOut](../../core/lib/presentation/resources/image_paths.dart:155) | [account_menu_item.dart:47](../../lib/features/manage_account/presentation/model/account_menu_item.dart:47) |
| [ic_spam.svg](../../assets/images/ic_spam.svg) | [icSpam](../../core/lib/presentation/resources/image_paths.dart:30) | [email_action_type_extension.dart:166](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:166), [top_bar_thread_selection.dart:122](../../lib/features/mailbox_dashboard/presentation/widgets/top_bar_thread_selection.dart:122), [email_selection_action_type.dart:70](../../lib/features/thread/presentation/model/email_selection_action_type.dart:70) |
| [ic_spam_report_disable.svg](../../assets/images/ic_spam_report_disable.svg) | [icSpamReportDisable](../../core/lib/presentation/resources/image_paths.dart:180) | [mailbox_actions.dart:108](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:108) |
| [ic_spam_report_enable.svg](../../assets/images/ic_spam_report_enable.svg) | [icSpamReportEnable](../../core/lib/presentation/resources/image_paths.dart:181) | [mailbox_actions.dart:110](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:110) |
| [ic_storage.svg](../../assets/images/ic_storage.svg) | [icStorage](../../core/lib/presentation/resources/image_paths.dart:261) | [account_menu_item.dart:43](../../lib/features/manage_account/presentation/model/account_menu_item.dart:43) |
| [ic_subaddressing_allow.svg](../../assets/images/ic_subaddressing_allow.svg) | [icSubaddressingAllow](../../core/lib/presentation/resources/image_paths.dart:239) | [mailbox_actions.dart:134](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:134) |
| [ic_subaddressing_disallow.svg](../../assets/images/ic_subaddressing_disallow.svg) | [icSubaddressingDisallow](../../core/lib/presentation/resources/image_paths.dart:240) | [mailbox_actions.dart:136](../../lib/features/mailbox/presentation/model/mailbox_actions.dart:136) |
| [ic_switch_on.svg](../../assets/images/ic_switch_on.svg) | [icSwitchOn](../../core/lib/presentation/resources/image_paths.dart:156) | [default_switch_icon_widget.dart:21](../../lib/features/base/widget/default_switch_icon_widget.dart:21) |
| [ic_tag.svg](../../assets/images/ic_tag.svg) | [icTag](../../core/lib/presentation/resources/image_paths.dart:285) | [email_action_type_extension.dart:199](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:199), [quick_search_filter.dart:99](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:99), [top_bar_thread_selection.dart:111](../../lib/features/mailbox_dashboard/presentation/widgets/top_bar_thread_selection.dart:111), [email_selection_action_type.dart:78](../../lib/features/thread/presentation/model/email_selection_action_type.dart:78) |
| [ic_team.svg](../../assets/images/ic_team.svg) | [icTeam](../../core/lib/presentation/resources/image_paths.dart:104) | [login_view_web.dart:150](../../lib/features/login/presentation/login_view_web.dart:150) |
| [ic_unread.svg](../../assets/images/ic_unread.svg) | [icUnread](../../core/lib/presentation/resources/image_paths.dart:26) | [quick_search_filter.dart:97](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:97), [top_bar_thread_selection.dart:64](../../lib/features/mailbox_dashboard/presentation/widgets/top_bar_thread_selection.dart:64), [filter_message_option_style_extension.dart:19](../../lib/features/thread/presentation/extensions/filter_message_option_style_extension.dart:19), [email_selection_action_type.dart:59](../../lib/features/thread/presentation/model/email_selection_action_type.dart:59), [desktop_list_email_action_hover_widget.dart:64](../../lib/features/thread/presentation/widgets/desktop_list_email_action_hover_widget.dart:64), [web_tablet_body_email_item_widget.dart:206](../../lib/features/thread/presentation/widgets/web_tablet_body_email_item_widget.dart:206) |
| [ic_unread_status.svg](../../assets/images/ic_unread_status.svg) | [icUnreadStatus](../../core/lib/presentation/resources/image_paths.dart:64) | [information_sender_and_receiver_builder.dart:117](../../lib/features/email/presentation/widgets/information_sender_and_receiver_builder.dart:117), [information_sender_and_receiver_builder.dart:183](../../lib/features/email/presentation/widgets/information_sender_and_receiver_builder.dart:183), [base_email_item_tile.dart:211](../../lib/features/thread/presentation/mixin/base_email_item_tile.dart:211) |
| [ic_unread_toast.svg](../../assets/images/ic_unread_toast.svg) | [icUnreadToast](../../core/lib/presentation/resources/image_paths.dart:33) | [mailbox_dashboard_controller.dart:1288](../../lib/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart:1288), [filter_message_option_style_extension.dart:19](../../lib/features/thread/presentation/extensions/filter_message_option_style_extension.dart:19) |
| [ic_unspam.svg](../../assets/images/ic_unspam.svg) | [icNotSpam](../../core/lib/presentation/resources/image_paths.dart:85) | [email_action_type_extension.dart:164](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:164), [top_bar_thread_selection.dart:122](../../lib/features/mailbox_dashboard/presentation/widgets/top_bar_thread_selection.dart:122), [email_selection_action_type.dart:72](../../lib/features/thread/presentation/model/email_selection_action_type.dart:72) |
| [ic_unsubscribe.svg](../../assets/images/ic_unsubscribe.svg) | [icUnsubscribe](../../core/lib/presentation/resources/image_paths.dart:224) | [email_action_type_extension.dart:170](../../lib/features/composer/presentation/extensions/email_action_type_extension.dart:170) |
| [ic_user.svg](../../assets/images/ic_user.svg) | [icUser](../../core/lib/presentation/resources/image_paths.dart:271) | [setting_user_info_widget.dart:91](../../lib/features/manage_account/presentation/menu/settings/setting_user_info_widget.dart:91) |
| [ic_user_sb.svg](../../assets/images/ic_user_sb.svg) | [icUserSB](../../core/lib/presentation/resources/image_paths.dart:110) | [quick_search_filter.dart:83](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:83), [quick_search_filter.dart:89](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:89), [quick_search_filter.dart:91](../../lib/features/mailbox_dashboard/presentation/model/search/quick_search_filter.dart:91) |
| [ic_vacation.svg](../../assets/images/ic_vacation.svg) | [icVacation](../../core/lib/presentation/resources/image_paths.dart:154) | [account_menu_item.dart:35](../../lib/features/manage_account/presentation/model/account_menu_item.dart:35) |

## Other exact matches

- [colors.xml:4](../../android/app/src/main/res/values/colors.xml:4) · `<color name="colorPrimary">#047857</color>`
- [color_extension.dart:5](../../core/lib/presentation/extensions/color_extension.dart:5) · `static const primaryColor = Color(0xFF047857);`
- [color_extension.dart:14](../../core/lib/presentation/extensions/color_extension.dart:14) · `static const textFieldFocusedBorderColor = Color(0xFF047857);`
- [color_extension.dart:18](../../core/lib/presentation/extensions/color_extension.dart:18) · `static const loginTextFieldFocusedBorder = Color(0xFF047857);`
- [color_extension.dart:21](../../core/lib/presentation/extensions/color_extension.dart:21) · `static const appColor = Color(0xFF047857);`
- [color_extension.dart:28](../../core/lib/presentation/extensions/color_extension.dart:28) · `static const mailboxSelectedTextColor = Color(0xFF047857);`
- [color_extension.dart:32](../../core/lib/presentation/extensions/color_extension.dart:32) · `static const mailboxSelectedIconColor = Color(0xFF047857);`
- [color_extension.dart:40](../../core/lib/presentation/extensions/color_extension.dart:40) · `static const counterMailboxColor = Color(0xFF047857);`
- [color_extension.dart:50](../../core/lib/presentation/extensions/color_extension.dart:50) · `static const avatarTextColor = Color(0xFF047857);`
- [color_extension.dart:52](../../core/lib/presentation/extensions/color_extension.dart:52) · `static const subjectEmailTextColorUnRead = Color(0xFF047857);`
- [color_extension.dart:56](../../core/lib/presentation/extensions/color_extension.dart:56) · `static const enableSendEmailButtonColor = Color(0xFF047857);`
- [color_extension.dart:68](../../core/lib/presentation/extensions/color_extension.dart:68) · `static const colorTextButton = Color(0xFF047857);`
- [color_extension.dart:75](../../core/lib/presentation/extensions/color_extension.dart:75) · `static const colorExpandMailbox = Color(0xFF047857);`
- [color_extension.dart:78](../../core/lib/presentation/extensions/color_extension.dart:78) · `static const colorFilterMessageEnabled = Color(0xFF047857);`
- [color_extension.dart:88](../../core/lib/presentation/extensions/color_extension.dart:88) · `static const colorActionCancelDialog = Color(0xFF047857);`
- [color_extension.dart:117](../../core/lib/presentation/extensions/color_extension.dart:117) · `static const colorShadowComposerButton = Color(0x99047857);`
- [color_extension.dart:173](../../core/lib/presentation/extensions/color_extension.dart:173) · `static const colorInvitedEventActionText = Color(0xFF047857);`
- [color_extension.dart:249](../../core/lib/presentation/extensions/color_extension.dart:249) · `static const primaryMain = Color(0xFF047857);`
- [color_extension.dart:273](../../core/lib/presentation/extensions/color_extension.dart:273) · `static const primaryLinShare = Color(0xFF047857);`
- [color_extension.dart:277](../../core/lib/presentation/extensions/color_extension.dart:277) · `static const m3Primary = Color(0xFF047857);`
- [numberinbox_palette.dart:12](../../core/lib/presentation/resources/numberinbox_palette.dart:12) · `static const actionGreen = Color(0xFF047857);`
- [file_link_card_html_builder.dart:55](../../core/lib/utils/html/file_link_card_html_builder.dart:55) · `'color:#047857;white-space:nowrap;overflow:hidden;'`
- [0121-accessible-primary-action-gradient.md:24](../../docs/adr/0121-accessible-primary-action-gradient.md:24) · `cyan, 4.4:1 on blue) and the previous '#047857' → '#0369A1' gradient (5.5:1 to`
- [compose-gradient-splash-alignment-plan.md:7](../../docs/brand/compose-gradient-splash-alignment-plan.md:7) · `The shared 'NumberInboxPalette' defines 'actionGreen' ('#047857') and 'actionBlue' ('#0369A1'), but not a gradient token. 'BrandedActionButton' assembles the gradient locally; the mobile floating Compose action and desktop sidebar Compose action use the solid 'AppColor.colorComposeButton' ('#047857'). 'ScrollingFloatingButtonAnimated' accepts only a 'Color'. 'HomeView' already centers its 120 dp image independently of the wordmark/spinner; its current widget test proves only Flutter-internal centering, not alignment with the preceding native frame. The native and Flutter assets have approximately 100 dp visible marks by design, so measure the live transition before changing padding or scale.`
- [primary-action-consistency-plan.md:21](../../docs/brand/primary-action-consistency-plan.md:21) · `Use the established contrast-safe action colors 'NumberInboxPalette.actionGreen' ('#047857') and 'NumberInboxPalette.actionBlue' ('#0369A1') for the login gradient. These are deliberately darker than the logo's emerald/cyan ('#10B981'/'#06B6D4') so white control text remains legible. Use 'AppColor.colorComposeButton' ('#047857') for light-mode mobile Compose, matching the existing light sidebar Compose control. Keep the blue color for the current dark-mode floating button until the later dark-mode phase, or verify an existing dark-mode requirement before changing it.`
- [primary-action-consistency-plan.md:40](../../docs/brand/primary-action-consistency-plan.md:40) · `6. Restyle the web banner in 'web/worker_service/style.css' with the existing light palette: ice '#F5F7EB' or white surface, navy '#0F172A' text, cool-gray '#E5E7EB' border, and contrast-safe action green '#047857' for Open. Use the established tagline “Email, reimagined with your number.” in the English banner source and fallback. Translate that meaning in 'fr', 'de', and 'vi' instead of silently replacing those locales with English. Apply translations after the fetch resolves, retaining English when the locale file is unavailable. Keep the existing NumberInbox mark and banner close behavior. Make Open a keyboard-focusable control if the markup is touched, without changing its visual size or click handler.`
- [web_smart_banner_contract_test.dart:97](../../test/branding/web_smart_banner_contract_test.dart:97) · `expect(css.toUpperCase(), contains('#047857'),`
- [style.css:59](../../web/worker_service/style.css:59) · `color: #047857;`

## Android theme references

- [styles.xml:5](../../android/app/src/main/res/values-night-v31/styles.xml:5) · `<item name="android:colorControlActivated">@color/colorPrimary</item>`
- [styles.xml:28](../../android/app/src/main/res/values-night-v31/styles.xml:28) · `<item name="android:colorControlActivated">@color/colorPrimary</item>`
- [styles.xml:8](../../android/app/src/main/res/values-night/styles.xml:8) · `<item name="android:colorControlActivated">@color/colorPrimary</item>`
- [styles.xml:25](../../android/app/src/main/res/values-night/styles.xml:25) · `<item name="android:colorControlActivated">@color/colorPrimary</item>`
- [styles.xml:5](../../android/app/src/main/res/values-v31/styles.xml:5) · `<item name="android:colorControlActivated">@color/colorPrimary</item>`
- [styles.xml:30](../../android/app/src/main/res/values-v31/styles.xml:30) · `<item name="android:colorControlActivated">@color/colorPrimary</item>`
- [styles.xml:8](../../android/app/src/main/res/values/styles.xml:8) · `<item name="android:colorControlActivated">@color/colorPrimary</item>`
- [styles.xml:25](../../android/app/src/main/res/values/styles.xml:25) · `<item name="android:colorControlActivated">@color/colorPrimary</item>`

## Verification boundary

This is a static source inventory. The SVG table distinguishes embedded color from call sites that may tint it. Runtime themes, capability-dependent settings, dynamic asset lookup, and pixels in raster images were not visually enumerated. That baseline inventory step made no application changes.
