import 'package:flutter/material.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';

/// AGPL-3.0 attribution required by docs/16-branding.md.
class AboutNumberInbox extends StatelessWidget {
  const AboutNumberInbox({super.key});

  @override
  Widget build(BuildContext context) {
    const attribution =
        'NumberInbox Mail is based on Twake Mail (Linagora), licensed AGPL-3.0. '
        'Source: https://github.com/numberinbox/mobile-app';
    return Scaffold(
      appBar: AppBar(title: const Text('About NumberInbox')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image(
              image: AssetImage('assets/images/numberinbox_mark.png'),
              width: 72,
              height: 72,
            ),
            SizedBox(height: 12),
            Text('NumberInbox',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                    color: NumberInboxPalette.navy)),
            SizedBox(height: 8),
            Text('Email, reimagined with your number.'),
            SizedBox(height: 16),
            Text(attribution, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
