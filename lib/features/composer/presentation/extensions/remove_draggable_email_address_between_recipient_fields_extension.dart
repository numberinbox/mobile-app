
import 'package:model/email/prefix_email_address.dart';
import 'package:model/extensions/email_address_extension.dart';
import 'package:tmail_ui_user/features/base/model/filter_filter.dart';
import 'package:tmail_ui_user/features/composer/presentation/composer_controller.dart';
import 'package:tmail_ui_user/features/composer/presentation/model/draggable_email_address.dart';

extension RemoveDraggableEmailAddressBetweenRecipientFieldsExtension on ComposerController {
  void removeDraggableEmailAddress(DraggableEmailAddress draggableEmailAddress) {
    if (composerId == null || composerId == draggableEmailAddress.composerId) {
      removeDraggableEmailAddressByComposerController(
        controller: this,
        draggableEmailAddress: draggableEmailAddress,
      );
    } else if (draggableEmailAddress.composerId != null) {
      final composerManager = mailboxDashBoardController.composerManager;
      if (!composerManager.composers.containsKey(composerId)) return;

      final draggableComposerController = composerManager
        .getComposerView(draggableEmailAddress.composerId!)
        .controller;

      removeDraggableEmailAddressByComposerController(
        controller: draggableComposerController,
        draggableEmailAddress: draggableEmailAddress,
      );
    }
  }

  void removeDraggableEmailAddressByComposerController({
    required ComposerController controller,
    required DraggableEmailAddress draggableEmailAddress,
  }) {
    switch(draggableEmailAddress.filterField) {
      case FilterField.to:
        controller.removeRecipient(
          PrefixEmailAddress.to, draggableEmailAddress.emailAddress.emailAddress);
        break;
      case FilterField.cc:
        controller.removeRecipient(
          PrefixEmailAddress.cc, draggableEmailAddress.emailAddress.emailAddress);
        break;
      case FilterField.bcc:
        controller.removeRecipient(
          PrefixEmailAddress.bcc, draggableEmailAddress.emailAddress.emailAddress);
        break;
      case FilterField.replyTo:
        controller.removeRecipient(
          PrefixEmailAddress.replyTo, draggableEmailAddress.emailAddress.emailAddress);
        break;
      default:
        break;
    }
    controller.isInitialRecipient.value = true;
    controller.isInitialRecipient.refresh();
    controller.updateStatusEmailSendButton();
  }
}
