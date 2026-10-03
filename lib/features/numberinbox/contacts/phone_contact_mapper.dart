/// Maps raw device contacts to NumberInbox recipient values.
///
/// Explicit international numbers become canonical `+E164@numberinbox.com`
/// addresses via the strict recipient parser (no region, no device locale,
/// no fallback). Phone-shaped local or invalid numbers are preserved as
/// the trimmed raw string with no domain: an intentionally invalid,
/// editable value that must pass explicit country selection before it can
/// become deliverable. Empty or non-phone content maps to null and is
/// omitted. Ordinary email addresses never flow through this mapper.
import '../phone_number_parser.dart';
import '../recipient_identity.dart';

class PhoneContactMapper {
  const PhoneContactMapper();

  /// Maps [raw] per the contract above.
  String? mapRecipientPhoneNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || !isPhoneShaped(trimmed)) return null;
    final e164 = PhoneNumberParser().parseRecipientToE164(trimmed);
    if (e164 != null) return '$e164@numberinbox.com';
    return trimmed;
  }

  /// Maps a single contact's phone numbers to [MappedContact] entries.
  /// Returns a list because one contact may have multiple numbers, each
  /// kept with the contact's display name whether resolved or raw.
  List<MappedContact>? mapContact({
    required String displayName,
    required List<String> phoneNumbers,
  }) {
    final results = <MappedContact>[];
    for (final raw in phoneNumbers) {
      final email = mapRecipientPhoneNumber(raw);
      if (email != null) {
        results.add(MappedContact(displayName: displayName, email: email));
      }
    }
    return results.isEmpty ? null : results;
  }

  /// Maps a list of raw contacts to a flat list of [MappedContact] entries.
  List<MappedContact> mapContacts(List<RawContact> contacts) {
    final results = <MappedContact>[];
    for (final contact in contacts) {
      final mapped = mapContact(
        displayName: contact.displayName,
        phoneNumbers: contact.phoneNumbers,
      );
      if (mapped != null) results.addAll(mapped);
    }
    return results;
  }
}

/// A contact entry as it comes from the device contact directory.
class RawContact {
  const RawContact({required this.displayName, required this.phoneNumbers});

  final String displayName;
  final List<String> phoneNumbers;
}

/// A mapped contact with a recipient value: either a canonical
/// `+E164@numberinbox.com` address or an unresolved raw phone string.
class MappedContact {
  const MappedContact({required this.displayName, required this.email});

  final String displayName;
  final String email;
}
