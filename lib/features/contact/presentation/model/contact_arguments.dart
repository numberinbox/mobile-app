
import 'package:equatable/equatable.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';

class ContactArguments with EquatableMixin {
  final AccountId accountId;
  final Session session;
  final List<EmailAddress> selectedContactList;
  final String? contactViewTitle;

  ContactArguments({
    required this.accountId,
    required this.session,
    required this.selectedContactList,
    this.contactViewTitle
  });

  @override
  List<Object?> get props => [
    accountId,
    session,
    selectedContactList,
    contactViewTitle,
  ];
}