import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/properties/properties.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:model/model.dart';
import 'package:tmail_ui_user/features/email/domain/model/mark_read_action.dart';
import 'package:tmail_ui_user/features/email/domain/model/move_action.dart';
import 'package:tmail_ui_user/features/email/domain/model/move_to_mailbox_request.dart';
import 'package:tmail_ui_user/features/email/domain/state/mark_as_email_read_state.dart';
import 'package:tmail_ui_user/features/email/domain/state/move_to_mailbox_state.dart';
import 'package:tmail_ui_user/features/email/domain/usecases/mark_as_email_read_interactor.dart';
import 'package:tmail_ui_user/features/email/domain/usecases/move_to_mailbox_interactor.dart';
import 'package:tmail_ui_user/features/email/presentation/utils/email_utils.dart';
import 'package:tmail_ui_user/features/mailbox/domain/repository/mailbox_repository.dart';
import 'package:tmail_ui_user/features/thread/domain/repository/thread_repository.dart';
import 'numberinbox_notification_actions.dart';

/// Reuses the application's repositories and mutation interactors, with fresh
/// JMAP reads rather than the mobile cache used by ordinary email navigation.
class NumberInboxMailActionExecutor {
  NumberInboxMailActionExecutor(
    this.threads,
    this.mailboxes,
    this.markRead,
    this.move,
  );
  final ThreadRepository threads;
  final MailboxRepository mailboxes;
  final MarkAsEmailReadInteractor markRead;
  final MoveToMailboxInteractor move;

  Future<bool> perform({
    required NumberInboxMailAction action,
    required NumberInboxNotificationTarget target,
    required Session session,
    required AccountId accountId,
    required Future<bool> Function() canContinue,
    required void Function(PresentationEmail email) openReply,
    void Function()? onArchiveUnavailable,
  }) async {
    if (accountId.id.value != target.accountId || !await canContinue()) {
      return false;
    }
    final id = EmailId(Id(target.emailId));
    // A reply must carry Message-ID and References so the answer threads with
    // the original; the other actions only need the ordinary list properties.
    final properties = action == NumberInboxMailAction.reply
        ? EmailUtils.getPropertiesForEmailGetMethod(session, accountId) +
              Properties({EmailProperty.messageId, EmailProperty.references})
        : EmailUtils.getPropertiesForEmailGetMethod(session, accountId);
    Future<PresentationEmail> fetch() =>
        threads.getEmailById(session, accountId, id, properties: properties);
    final email = await fetch();
    if (email.id != id || !await canContinue()) return false;
    switch (action) {
      case NumberInboxMailAction.reply:
        openReply(email);
        return true;
      case NumberInboxMailAction.markRead:
        if (email.hasRead) return true;
        final state = await markRead
            .execute(
              session,
              accountId,
              id,
              ReadActions.markAsRead,
              MarkReadAction.tap,
              email.mailboxIds?.keys.firstOrNull,
            )
            .last;
        if (!state.fold(
              (_) => false,
              (value) => value is MarkAsEmailReadSuccess && value.emailId == id,
            ) ||
            !await canContinue()) {
          return false;
        }
        final updated = await fetch();
        return await canContinue() && updated.id == id && updated.hasRead;
      case NumberInboxMailAction.archive:
        final archive = (await mailboxes.getMailboxByRole(
          session,
          accountId,
          PresentationMailbox.roleArchive,
        )).mailbox;
        if (archive?.id == null || archive?.role != PresentationMailbox.roleArchive) {
          if (await canContinue()) onArchiveUnavailable?.call();
          return false;
        }
        if (!await canContinue()) return false;
        final archiveId = archive!.id!;
        final current =
            email.mailboxIds?.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList() ??
            [];
        final inbox = (await mailboxes.getMailboxByRole(
          session,
          accountId,
          PresentationMailbox.roleInbox,
        )).mailbox;
        if (!await canContinue() ||
            (inbox != null && inbox.role != PresentationMailbox.roleInbox)) {
          return false;
        }
        // JMAP memberships are unordered. Prefer Inbox over labels; a message
        // already in Archive (and not Inbox) needs no further move.
        final inInbox = inbox?.id != null && current.contains(inbox!.id);
        if (current.contains(archiveId) && !inInbox) return true;
        final source = inInbox
            ? inbox.id
            : current.where((id) => id != archiveId).firstOrNull;
        if (source == null) return false;
        final state = await move.execute(
          session,
          accountId,
          MoveToMailboxRequest(
            {
              source: [id],
            },
            archiveId,
            MoveAction.moving,
            EmailActionType.moveToMailbox,
          ),
          {id: email.hasRead},
        ).last;
        if (!state.fold(
              (_) => false,
              (value) => value is MoveToMailboxSuccess && value.emailId == id,
            ) ||
            !await canContinue()) {
          return false;
        }
        final updated = await fetch();
        return await canContinue() &&
            updated.id == id &&
            updated.mailboxIds?[archiveId] == true &&
            updated.mailboxIds?[source] != true;
    }
  }
}
