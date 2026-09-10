import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:model/extensions/email_address_extension.dart';

/// Filters already-loaded device contacts by display name or email.
/// Pure function so the contact search behavior is unit-testable without
/// spinning up the GetX controller.
List<EmailAddress> filterLocalContacts(
  String query,
  List<EmailAddress> contacts,
) {
  final q = query.toLowerCase();
  return contacts
      .where((contact) {
        final name = contact.displayName.toLowerCase();
        final email = contact.emailAddress.toLowerCase();
        return name.contains(q) || email.contains(q);
      })
      .toList();
}

/// Merges locally-filtered device contacts with server-side autocomplete
/// results. Local matches come first; duplicates (by email) and raw-email
/// echo follow the same rules as the server path.
List<EmailAddress> mergeContactResults({
  required List<EmailAddress> localMatches,
  required List<EmailAddress> serverResults,
  required String query,
}) {
  final all = <EmailAddress>[...localMatches];
  for (final contact in serverResults) {
    if (!all.any((existing) => existing.emailAddress == contact.emailAddress)) {
      all.add(contact);
    }
  }
  if (GetUtils.isEmail(query) &&
      !all.any((existing) => existing.emailAddress == query)) {
    all.add(EmailAddress(null, query));
  }
  return all;
}
