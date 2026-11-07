import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:flutter/material.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';
import 'package:tmail_ui_user/main/utils/app_utils.dart';

class AboutNumberInbox extends StatelessWidget {
  const AboutNumberInbox({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About NumberInbox')),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Image(
              image: AssetImage('assets/images/numberinbox_mark.png'),
              width: 78,
              height: 78,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 14),
            const Text(
              'Your number.\nYour inbox.',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.2,
                color: NumberInboxPalette.navy,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your phone number is your email identity. Sign in with an SMS code, then read, write and organize your mail.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            _feature(
              Icons.mail_outline,
              'Made for everyday email',
              'Messages, attachments, search and folders — in one place.',
            ),
            const SizedBox(height: 20),
            _feature(
              Icons.favorite_border,
              'Free. No ads.',
              'We don’t sell your personal data or use your mail for targeted ads.',
            ),
            const SizedBox(height: 20),
            _feature(
              Icons.tune,
              'Built around your choices',
              'Choose your notifications and delete your account from Settings whenever you need to.',
            ),
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: NumberInboxPalette.primaryActionGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => AppUtils.launchLink(AppConfig.websiteUrl),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: NumberInboxPalette.primaryActionForeground,
                    minimumSize: const Size(0, 54),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Explore numberinbox.com',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 9),
                      ExcludeSemantics(
                        child: Icon(
                          Icons.open_in_new,
                          size: 18,
                          color: NumberInboxPalette.primaryActionForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Email that starts with you.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF526277)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String title, String description) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: ExcludeSemantics(
          child: Icon(
            icon,
            size: 22,
            color: NumberInboxPalette.interactiveAccent,
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: NumberInboxPalette.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: Color(0xFF526277)),
            ),
          ],
        ),
      ),
    ],
  );
}
