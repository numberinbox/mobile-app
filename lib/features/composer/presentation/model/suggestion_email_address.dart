import 'package:equatable/equatable.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';

class SuggestionEmailAddress with EquatableMixin {
  final EmailAddress emailAddress;
  final SuggestionEmailState state;
  final String? rawPhone;

  SuggestionEmailAddress(this.emailAddress, {this.state = SuggestionEmailState.valid, this.rawPhone});

  @override
  List<Object?> get props => [emailAddress, state, rawPhone];
}

enum SuggestionEmailState {
  valid,
  duplicated,
  invalidPhone,
}