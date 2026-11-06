import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/properties/properties.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/email/keyword_identifier.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:model/model.dart';
import 'package:tmail_ui_user/features/email/domain/model/mark_read_action.dart';
import 'package:tmail_ui_user/features/email/domain/model/move_action.dart';
import 'package:tmail_ui_user/features/email/domain/state/mark_as_email_read_state.dart';
import 'package:tmail_ui_user/features/email/domain/state/move_to_mailbox_state.dart';
import 'package:tmail_ui_user/features/email/domain/usecases/mark_as_email_read_interactor.dart';
import 'package:tmail_ui_user/features/email/domain/usecases/move_to_mailbox_interactor.dart';
import 'package:tmail_ui_user/features/mailbox/domain/model/get_mailbox_by_role_response.dart';
import 'package:tmail_ui_user/features/mailbox/domain/repository/mailbox_repository.dart';
import 'package:tmail_ui_user/features/thread/domain/repository/thread_repository.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_mail_action_executor.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_notification_actions.dart';
import '../../../../fixtures/account_fixtures.dart';
import '../../../../fixtures/session_fixtures.dart';
import 'numberinbox_mail_action_executor_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ThreadRepository>(),
  MockSpec<MailboxRepository>(),
  MockSpec<MarkAsEmailReadInteractor>(),
  MockSpec<MoveToMailboxInteractor>(),
])
void main() {
  final account = AccountFixtures.aliceAccountId;
  final session = SessionFixtures.aliceSession;
  final id = EmailId(Id('synthetic-mail'));
  final inbox = MailboxId(Id('inbox'));
  final archive = MailboxId(Id('archive'));
  final target = NumberInboxNotificationTarget(
    accountId: account.id.value,
    emailId: id.id.value,
  );
  late MockThreadRepository threads;
  late MockMailboxRepository mailboxes;
  late MockMarkAsEmailReadInteractor mark;
  late MockMoveToMailboxInteractor move;
  late NumberInboxMailActionExecutor executor;
  setUp(() {
    threads = MockThreadRepository();
    mailboxes = MockMailboxRepository();
    mark = MockMarkAsEmailReadInteractor();
    move = MockMoveToMailboxInteractor();
    executor = NumberInboxMailActionExecutor(threads, mailboxes, mark, move);
    when(
      threads.getEmailById(any, any, any, properties: anyNamed('properties')),
    ).thenAnswer(
      (_) async => PresentationEmail(id: id, mailboxIds: {inbox: true}),
    );
    when(
      mailboxes.getMailboxByRole(any, any, any, limit: anyNamed('limit')),
    ).thenAnswer((invocation) async {
      final role = invocation.positionalArguments[2];
      return GetMailboxByRoleResponse(
        mailbox: role == PresentationMailbox.roleInbox
            ? Mailbox(id: inbox, role: PresentationMailbox.roleInbox)
            : Mailbox(id: archive, role: PresentationMailbox.roleArchive),
      );
    });
  });
  Future<bool> run(
    NumberInboxMailAction action, {
    Future<bool> Function()? active,
    void Function(PresentationEmail)? reply,
  }) => executor.perform(
    action: action,
    target: target,
    session: session,
    accountId: account,
    canContinue: active ?? () async => true,
    openReply: reply ?? (_) => fail('unexpected reply'),
  );
  test(
    'reply uses freshly fetched mail once and performs no mutation',
    () async {
      var replies = 0;
      expect(
        await run(
          NumberInboxMailAction.reply,
          reply: (email) {
            expect(email.id, id);
            replies++;
          },
        ),
        isTrue,
      );
      expect(replies, 1);
      verifyNever(mark.execute(any, any, any, any, any, any));
      verifyNever(move.execute(any, any, any, any));
    },
  );
  test('reply fetch asks for the threading headers the composer needs', () async {
    await run(NumberInboxMailAction.reply, reply: (_) {});
    final properties = verify(
      threads.getEmailById(any, any, any, properties: captureAnyNamed('properties')),
    ).captured.single as Properties;
    expect(properties.value, containsAll([EmailProperty.messageId, EmailProperty.references]));
  });
  test('mark read and archive keep the ordinary lightweight fetch', () async {
    when(mark.execute(any, any, any, any, any, any)).thenAnswer(
      (_) => Stream.value(Right<Failure, Success>(
        MarkAsEmailReadSuccess(id, ReadActions.markAsRead, MarkReadAction.tap, inbox))),
    );
    await run(NumberInboxMailAction.markRead);
    final captured = verify(
      threads.getEmailById(any, any, any, properties: captureAnyNamed('properties')),
    ).captured;
    for (final properties in captured) {
      expect((properties as Properties).value, isNot(contains(EmailProperty.references)));
    }
  });
  test('absent Archive reports it so the app can say why', () async {
    when(
      mailboxes.getMailboxByRole(any, any, any, limit: anyNamed('limit')),
    ).thenAnswer((_) async => GetMailboxByRoleResponse());
    var reported = 0;
    expect(
      await executor.perform(
        action: NumberInboxMailAction.archive,
        target: target,
        session: session,
        accountId: account,
        canContinue: () async => true,
        openReply: (_) => fail('unexpected reply'),
        onArchiveUnavailable: () => reported++,
      ),
      isFalse,
    );
    expect(reported, 1);
  });
  test('logout during fetch prevents reply and all mutation', () async {
    var active = true;
    when(
      threads.getEmailById(any, any, any, properties: anyNamed('properties')),
    ).thenAnswer((_) async {
      active = false;
      return PresentationEmail(id: id);
    });
    expect(
      await run(NumberInboxMailAction.reply, active: () async => active),
      isFalse,
    );
    verifyNever(mark.execute(any, any, any, any, any, any));
  });
  test('empty mutation stream cannot be treated as success', () async {
    when(
      mark.execute(any, any, any, any, any, any),
    ).thenAnswer((_) => const Stream.empty());
    await expectLater(run(NumberInboxMailAction.markRead), throwsStateError);
  });
  test(
    'mark read requires exact success then authoritative read-back',
    () async {
      var fetched = 0;
      when(
        threads.getEmailById(any, any, any, properties: anyNamed('properties')),
      ).thenAnswer(
        (_) async => PresentationEmail(
          id: id,
          mailboxIds: {inbox: true},
          keywords: {if (fetched++ > 0) KeyWordIdentifier.emailSeen: true},
        ),
      );
      when(mark.execute(any, any, any, any, any, any)).thenAnswer(
        (_) => Stream.value(
          Right<Failure, Success>(
            MarkAsEmailReadSuccess(
              id,
              ReadActions.markAsRead,
              MarkReadAction.tap,
              inbox,
            ),
          ),
        ),
      );
      expect(await run(NumberInboxMailAction.markRead), isTrue);
      expect(fetched, 2);
    },
  );
  test('partial mark read failure cannot dismiss mail', () async {
    when(mark.execute(any, any, any, any, any, any)).thenAnswer(
      (_) => Stream.value(
        Left<Failure, Success>(MarkAsEmailReadFailure(ReadActions.markAsRead)),
      ),
    );
    expect(await run(NumberInboxMailAction.markRead), isFalse);
  });
  test('absent Archive does not move or delete mail', () async {
    when(
      mailboxes.getMailboxByRole(any, any, any, limit: anyNamed('limit')),
    ).thenAnswer((_) async => GetMailboxByRoleResponse());
    expect(await run(NumberInboxMailAction.archive), isFalse);
    verifyNever(move.execute(any, any, any, any));
  });
  test(
    'archive resolves role, preserves other memberships and verifies move',
    () async {
      final label = MailboxId(Id('label'));
      var fetched = 0;
      when(
        threads.getEmailById(any, any, any, properties: anyNamed('properties')),
      ).thenAnswer(
        (_) async => PresentationEmail(
          id: id,
          mailboxIds: fetched++ == 0
              ? {label: true, inbox: true}
              : {archive: true, label: true},
        ),
      );
      when(move.execute(any, any, any, any)).thenAnswer(
        (_) => Stream.value(
          Right<Failure, Success>(
            MoveToMailboxSuccess(
              id,
              inbox,
              archive,
              MoveAction.moving,
              EmailActionType.moveToMailbox,
              originalMailboxIdsWithEmailIds: {
                inbox: [id],
              },
              emailIdsWithReadStatus: {id: false},
            ),
          ),
        ),
      );
      expect(await run(NumberInboxMailAction.archive), isTrue);
      final request = verify(
        move.execute(any, any, captureAny, any),
      ).captured.single;
      expect(request.currentMailboxes, {
        inbox: [id],
      });
      expect(request.destinationMailboxId, archive);
    },
  );
  test(
    'already archived mail retains its other labels without another move',
    () async {
      final label = MailboxId(Id('label'));
      when(
        threads.getEmailById(any, any, any, properties: anyNamed('properties')),
      ).thenAnswer(
        (_) async =>
            PresentationEmail(id: id, mailboxIds: {archive: true, label: true}),
      );
      expect(await run(NumberInboxMailAction.archive), isTrue);
      verifyNever(move.execute(any, any, any, any));
    },
  );
  test('stale target never fetches or executes effects', () async {
    expect(
      await executor.perform(
        action: NumberInboxMailAction.reply,
        target: const NumberInboxNotificationTarget(
          accountId: 'another',
          emailId: 'mail',
        ),
        session: session,
        accountId: account,
        canContinue: () async => true,
        openReply: (_) => fail('stale'),
      ),
      isFalse,
    );
    verifyNever(
      threads.getEmailById(any, any, any, properties: anyNamed('properties')),
    );
  });
}
