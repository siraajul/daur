import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'visuals.dart';

/// Plain-language product information; not a substitute for a published legal policy.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    Widget section(String title, String body) => Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.title()),
          const SizedBox(height: 8),
          Text(body, style: t.body()),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            const PageHeader('Privacy and support'),
            section(
              'Saved on this phone',
              'Daur saves your profile, programme and tracking history locally. You can export a backup from Your data. Protect exported files: they can contain health and personal information.',
            ),
            section(
              'Optional cloud backup',
              'Signing in enables Firebase cloud backup. Tracking records, including imported health totals, can be included. Check the backup status in Your data; signing in alone does not prove a backup succeeded.',
            ),
            section(
              'Health connections',
              'Health access is optional and depends on the permissions you grant. Review or revoke permissions in your phone’s settings. Previously imported values remain in Daur until you remove the relevant data.',
            ),
            section(
              'AI meal estimates',
              'Using an AI meal estimate sends the meal information you provide to Google’s Firebase AI service. Avoid including names or other personal details in meal descriptions. Estimates can be wrong; review portions and nutrition before saving.',
            ),
            section(
              'Sharing with people',
              'Family, trainer and partner features share information according to the role you invite. A partner sees a limited day summary. Review active connections and revoke access when it is no longer needed. Hiding a feature does not stop sharing.',
            ),
            section(
              'Crash reporting',
              'Crash reporting is optional and off by default. If enabled, Firebase Crashlytics receives technical error reports on supported mobile devices. Control it in Preferences. This is separate from your cloud backup.',
            ),
            section(
              'Deleting data',
              'Your data provides separate controls for cloud account deletion and resetting this phone. Read each confirmation before continuing. A minimal account-ID deletion marker is retained to block old sign-in sessions. Deleting a cloud account does not erase backup files you previously exported or copies someone else has already saved.',
            ),
            section(
              'Fitness guidance',
              'Targets and meal estimates are starting points for personal tracking. They do not diagnose conditions or account for every individual need. Review your plan when your circumstances change.',
            ),
            section(
              'Contact support',
              'For help with Daur, contact the developer below. Do not email passwords, sign-in codes or a full health backup.',
            ),
            const SizedBox(height: 12),
            const SelectableText('siraajulislaaam@gmail.com'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy support email'),
                onPressed: () async {
                  await Clipboard.setData(const ClipboardData(text: 'siraajulislaaam@gmail.com'));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support email copied.')));
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'This screen describes how the app works. Store publication also requires a maintained, public privacy policy and the applicable platform disclosures.',
              style: t.sec(),
            ),
          ],
        ),
      ),
    );
  }
}
