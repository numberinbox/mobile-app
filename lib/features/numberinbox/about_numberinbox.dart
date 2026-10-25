import 'package:flutter/material.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';
import 'package:tmail_ui_user/main/utils/app_utils.dart';

/// AGPL-3.0 attribution required by docs/16-branding.md.
class AboutNumberInbox extends StatelessWidget {
  const AboutNumberInbox({super.key});

  @override
  Widget build(BuildContext context) {
    const attribution =
        'NumberInbox Mail is based on Twake Mail by LINAGORA and is a modified '
        'version licensed under GNU AGPL v3.';
    return Scaffold(
      appBar: AppBar(title: const Text('About NumberInbox')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Image(
              image: AssetImage('assets/images/numberinbox_mark.png'),
              width: 72,
              height: 72,
            ),
            const SizedBox(height: 12),
            const Text(
              'NumberInbox',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: NumberInboxPalette.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Email, reimagined with your number.'),
            const SizedBox(height: 16),
            const Text(attribution),
            const SizedBox(height: 8),
            const Text(
              'The GNU AGPL v3 permits recipients to use, modify, and '
              'redistribute this software under its terms. This software is '
              'provided without warranty except where expressly provided or '
              'required by law.',
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => AppUtils.launchLink(AppConfig.openSourceUrl),
              icon: const Icon(Icons.open_in_new),
              label: const Text('License notices and source code'),
              style: TextButton.styleFrom(
                foregroundColor: NumberInboxPalette.actionBlue,
              ),
            ),
            const SizedBox(height: 4),
            const SelectableText(
              AppConfig.openSourceUrl,
              style: TextStyle(color: NumberInboxPalette.actionBlue),
            ),
          ],
        ),
      ),
    );
  }
}
