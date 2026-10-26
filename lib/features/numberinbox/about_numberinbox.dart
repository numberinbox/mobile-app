import 'package:flutter/material.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';
import 'package:tmail_ui_user/main/utils/app_utils.dart';

class AboutNumberInbox extends StatelessWidget {
  const AboutNumberInbox({super.key});

  @override
  Widget build(BuildContext context) {
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
            TextButton.icon(
              onPressed: () => AppUtils.launchLink(AppConfig.websiteUrl),
              icon: const Icon(Icons.open_in_new),
              label: const Text('numberinbox.com'),
              style: TextButton.styleFrom(
                foregroundColor: NumberInboxPalette.actionBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
