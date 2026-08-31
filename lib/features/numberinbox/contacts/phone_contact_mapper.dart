/// Maps raw device contacts to NumberInbox email addresses.
///
/// Takes phone numbers from the device contact directory, normalizes them
/// to E.164 format, and appends `@numberinbox.com` to create email addresses.
class PhoneContactMapper {
  const PhoneContactMapper();

  static const _emailDomain = 'numberinbox.com';

  /// Normalizes a raw phone number string and returns a NumberInbox email
  /// address, or `null` if the number is invalid/too-short.
  String? mapPhoneNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s\-().]'), '');
    if (cleaned.isEmpty) return null;

    String digits;
    if (cleaned.startsWith('+')) {
      digits = cleaned.substring(1);
    } else if (cleaned.startsWith('0')) {
      digits = '66${cleaned.substring(1)}';
    } else {
      return null;
    }

    if (!RegExp(r'^\d{8,15}$').hasMatch(digits)) return null;

    return '+$digits @$_emailDomain'.replaceAll(' ', '');
  }

  /// Maps a single contact's phone numbers to [MappedContact] entries.
  /// Returns a list because one contact may have multiple valid numbers.
  List<MappedContact>? mapContact({
    required String displayName,
    required List<String> phoneNumbers,
  }) {
    final results = <MappedContact>[];
    for (final raw in phoneNumbers) {
      final email = mapPhoneNumber(raw);
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

/// A mapped contact with a NumberInbox email address.
class MappedContact {
  const MappedContact({required this.displayName, required this.email});

  final String displayName;
  final String email;
}
