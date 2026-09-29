import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:model/contact/device_contact.dart';
import 'package:tmail_ui_user/features/numberinbox/phone_number_parser.dart';

/// Canonical recipient identity shared by device contacts, autocomplete,
/// picker selection, and composer merging.
///
/// One deliverable address is one logical recipient, no matter how many
/// platform records, casings, or phone formats name it.
const _numberinboxDomain = 'numberinbox.com';

/// Canonical key for [address]: trimmed, lowercased, with `@numberinbox.com`
/// phone local parts normalized to `+E164@numberinbox.com`.
String canonicalRecipientKey(String address) {
  final lowered = address.trim().toLowerCase();
  final parts = lowered.split('@');
  if (parts.length == 2 && parts[1] == _numberinboxDomain) {
    final e164 = PhoneNumberParser().parseToE164(parts[0]);
    if (e164 != null) return '$e164@$_numberinboxDomain';
  }
  return lowered;
}

/// Removes duplicate recipients, keeping first-seen order.
///
/// The first nonempty display name wins; a later duplicate with a useful
/// name upgrades an empty one. Entries are never merged by display name.
List<EmailAddress> deduplicateRecipients(Iterable<EmailAddress> recipients) {
  final result = <EmailAddress>[];
  final indexByKey = <String, int>{};
  for (final recipient in recipients) {
    final key = canonicalRecipientKey(recipient.email ?? '');
    final existingIndex = indexByKey[key];
    if (existingIndex == null) {
      indexByKey[key] = result.length;
      result.add(recipient);
    } else if ((result[existingIndex].name ?? '').trim().isEmpty &&
        (recipient.name ?? '').trim().isNotEmpty) {
      result[existingIndex] = recipient;
    }
  }
  return result;
}

/// Removes duplicate device contacts with the same recipient rules.
List<DeviceContact> deduplicateContacts(Iterable<DeviceContact> contacts) {
  final indexByKey = <String, int>{};
  final result = <DeviceContact>[];
  for (final contact in contacts) {
    final key = canonicalRecipientKey(contact.email);
    final existingIndex = indexByKey[key];
    if (existingIndex == null) {
      indexByKey[key] = result.length;
      result.add(contact);
    } else if (result[existingIndex].displayName.trim().isEmpty &&
        contact.displayName.trim().isNotEmpty) {
      result[existingIndex] = contact;
    }
  }
  return result;
}
