import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'cloud.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show Cta;
import 'visuals.dart';

/// Drawer → Your data: where it lives, a full export, and real deletion.
class DataScreen extends StatelessWidget {
  const DataScreen({super.key, required this.store});
  final Store store;

  Future<bool> _confirm(BuildContext context, String title, String body, String action) =>
      confirmPop(context, title, body, action);

  void _say(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final c = Cloud.instance;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const PageHeader('Your data'),
              const SizedBox(height: 12),
              const Tip(Icons.phone_android_rounded, 'Everything is saved on this phone'),
              Tip(
                c.signedIn ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                c.signedIn ? 'Backed up to your Google account' : 'Not backed up · sign in from the menu',
              ),
              const Tip(Icons.notifications_none_rounded, 'Reminders are scheduled on the phone, no server'),
              const SizedBox(height: 20),
              Cta(
                label: 'Export my data',
                trailing: 'JSON',
                onTap: () async {
                  final name = 'daur-${store.today}.json';
                  await SharePlus.instance.share(
                    ShareParams(
                      subject: 'Daur data',
                      files: [XFile.fromData(utf8.encode(store.snapshot()), mimeType: 'application/json')],
                      fileNameOverrides: [name],
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              if (c.signedIn)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cloud_off_rounded, color: t.ink),
                  title: Text('Delete my cloud data and account', style: t.body()),
                  subtitle: Text('This phone keeps its data', style: t.meta()),
                  onTap: () async {
                    if (!await _confirm(
                      context,
                      'Delete cloud data?',
                      'Your backup, your account and your family board place are deleted. This phone keeps everything.',
                      'Delete',
                    )) {
                      return;
                    }
                    final err = await c.deleteAccount();
                    if (context.mounted) _say(context, err ?? 'Cloud data and account deleted');
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_forever_outlined, color: t.ink),
                title: Text('Erase this phone', style: t.body()),
                subtitle: Text(c.signedIn ? 'Your cloud backup stays' : 'Everything, for good', style: t.meta()),
                onTap: () async {
                  if (!await _confirm(
                    context,
                    'Erase this phone?',
                    c.signedIn
                        ? 'You\'ll be signed out first, so your cloud backup stays. Sign in again to bring it back.'
                        : 'Meals, weights, gym, spending: all of it. It can\'t be undone.',
                    'Erase',
                  )) {
                    return;
                  }
                  if (c.signedIn) await c.signOut();
                  store.eraseAll();
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
