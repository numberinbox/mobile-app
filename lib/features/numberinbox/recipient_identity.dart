import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:model/contact/device_contact.dart';
import 'package:tmail_ui_user/features/numberinbox/phone_number_parser.dart';

/// Canonical recipient identity shared by device contacts, autocomplete,
/// picker selection, and composer merging.
///
/// One deliverable address is one logical recipient, no matter how many
/// platform records, casings, or phone formats name it.
///
/// Unresolved phone numbers (local or invalid input that no country has
/// validated yet) are intentionally NOT deliverable: they keep the raw
/// trimmed string as the address value with no domain, and share a
/// `phone:`-prefixed key by formatting-normalized digits. No caller may
/// treat an unresolved value as a routing address; resolution must go
/// through explicit country selection first.
const numberinboxDomain = 'numberinbox.com';

/// Key prefix for unresolved phone numbers. Keeps them distinct from both
/// ordinary emails and resolved `+E164@numberinbox.com` addresses.
const _unresolvedPhonePrefix = 'phone:';

/// True when [raw] is phone-shaped: trimmed, nonempty, containing only
/// digits with an optional single leading `+` plus phone formatting
/// (spaces, dashes, parentheses, dots), with at least one digit.
bool isPhoneShaped(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  if (!RegExp(r'^\+?[\d\s\-.()]+$').hasMatch(trimmed)) return false;
  return RegExp(r'\d').hasMatch(trimmed);
}

/// Formatting-normalized digits for an unresolved phone number: surrounding
/// whitespace and in-number formatting removed, a single leading `+` kept
/// because it is semantic rather than formatting.
String normalizeUnresolvedPhone(String raw) {
  final trimmed = raw.trim();
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
  return hasPlus ? '+$digits' : digits;
}

/// True for intentionally-invalid unresolved phone values: nonempty,
/// phone-shaped, and carrying no domain. Such values must pass explicit
/// country selection before they can become deliverable.
bool isUnresolvedPhoneValue(String address) {
  final trimmed = address.trim();
  if (trimmed.isEmpty || trimmed.contains('@')) return false;
  return isPhoneShaped(trimmed);
}

/// Prepares one phone recipient for commitment, shared by widget phone
/// commits and controller auto-tagging. For phone-shaped input it returns a
/// canonical NumberInbox address when strict international parsing succeeds;
/// otherwise the trimmed raw number with the name retained, still
/// unresolved. Non-phone input passes through with whitespace trimmed and
/// the name retained. Performs no navigation or country inference.
EmailAddress preparePhoneRecipient(EmailAddress candidate) {
  final raw = (candidate.email ?? '').trim();
  final name = (candidate.name ?? '').trim().isEmpty ? null : candidate.name;
  if (!isPhoneShaped(raw)) return EmailAddress(name, raw);
  final e164 = PhoneNumberParser().parseRecipientToE164(raw);
  if (e164 != null) return EmailAddress(name, '$e164@numberinbox.com');
  return EmailAddress(name, raw);
}

/// Canonical key for [address]: trimmed, lowercased, with explicit
/// international `@numberinbox.com` phone local parts normalized to
/// `+E164@numberinbox.com` via the strict recipient parser (no region, no
/// device locale, no fallback). Unresolved phone values — raw or carrying
/// our domain — share a `phone:` key by normalized digits and stay distinct
/// from resolved addresses until the user resolves them.
String canonicalRecipientKey(String address) {
  final trimmed = address.trim();
  if (trimmed.isEmpty) return '';
  final lowered = trimmed.toLowerCase();
  final parts = lowered.split('@');
  if (parts.length == 2 && parts[1] == numberinboxDomain) {
    final local = parts[0];
    if (local.startsWith('+')) {
      final e164 = PhoneNumberParser().parseRecipientToE164(local);
      if (e164 != null) return '$e164@$numberinboxDomain';
      return '$_unresolvedPhonePrefix${normalizeUnresolvedPhone(local)}';
    }
    if (isPhoneShaped(local)) {
      return '$_unresolvedPhonePrefix${normalizeUnresolvedPhone(local)}';
    }
  } else if (!lowered.contains('@') && isPhoneShaped(lowered)) {
    return '$_unresolvedPhonePrefix${normalizeUnresolvedPhone(lowered)}';
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
