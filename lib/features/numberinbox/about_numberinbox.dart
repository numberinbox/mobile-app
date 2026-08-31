import 'package:flutter/material.dart';

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
            Text('NumberInbox',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Your number is your inbox'),
            SizedBox(height: 16),
            Text(attribution, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
