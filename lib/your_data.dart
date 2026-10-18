import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'cloud.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show Cta;
import 'visuals.dart';

/// Backup, recovery and explicit account lifecycle controls.
class DataScreen extends StatelessWidget {
  const DataScreen({super.key, required this.store});
  final Store store;

  Future<bool> _confirm(BuildContext context, String title, String body, String action) =>
      confirmPop(context, title, body, action, destructive: true);

  void _say(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)));

  Future<void> _share(String raw, String name) => SharePlus.instance.share(
    ShareParams(
      subject: 'Daur data',
      files: [XFile.fromData(utf8.encode(raw), mimeType: 'application/json')],
      fileNameOverrides: [name],
    ),
  );

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) _say(context, '$e');
    }
  }

  Future<void> _import(BuildContext context) async {
    await _run(context, () async {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Daur JSON backup',
            extensions: ['json'],
            mimeTypes: ['application/json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() > 5000000) throw const FormatException('Choose a backup smaller than 5 MB.');
      final raw = await file.readAsString();
      final data = Store.decodeBackup(raw);
      if (!context.mounted) return;
      if (!await _confirm(
        context,
        'Restore this backup?',
        'Plan started ${data['startDay']}. This replaces this phone’s tracking data. A copy is kept so you can undo. Your current account’s sharing connections stay unchanged. If signed in, the restored data will be offered for cloud backup.',
        'Restore',
      )) {
        return;
      }
      await store.importBackup(raw);
      if (context.mounted) _say(context, 'Backup restored. You can undo below.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context), c = Cloud.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([c, store]),
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const PageHeader('Your data'),
              const SizedBox(height: 12),
              const Tip(Icons.phone_android_rounded, 'Tracking data is saved on this phone'),
              Tip(c.error != null ? Icons.cloud_off_outlined : Icons.cloud_outlined, c.backupStatus),
              if (store.recoveryNotice != null) Tip(Icons.restore, store.recoveryNotice!),
              if (c.signedIn && c.conflictData == null)
                TextButton.icon(
                  onPressed: c.syncing ? null : () => _run(context, c.retrySync),
                  icon: const Icon(Icons.sync),
                  label: const Text('Check and retry backup'),
                ),
              if (c.conflictData != null) ...[
                Text('Choose your saved copy', style: t.title()),
                Text(
                  'Automatic backup is paused. Export this phone first if you want to compare. The other copy is retained on this phone for recovery.',
                  style: t.sec(),
                ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => _resolve(context, false), child: const Text('Keep this phone’s copy')),
                OutlinedButton(onPressed: () => _resolve(context, true), child: const Text('Use the cloud copy')),
              ],
              const SizedBox(height: 20),
              Cta(
                label: 'Export my data',
                trailing: 'JSON',
                onTap: () => _run(context, () => _share(store.snapshot(), 'daur-${store.today}.json')),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _import(context),
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Restore a JSON backup'),
              ),
              if (store.canUndoImport)
                TextButton(onPressed: () => _run(context, store.undoImport), child: const Text('Undo last import')),
              if (c.signedIn)
                TextButton(
                  onPressed: () => _run(context, () async {
                    final raw = await c.recoveredSyncCopy();
                    if (raw == null) {
                      if (context.mounted) _say(context, 'No conflict recovery copy yet.');
                      return;
                    }
                    await _share(raw, 'daur-conflict-recovery.json');
                  }),
                  child: const Text('Export previous sync conflict copy'),
                ),
              const SizedBox(height: 28),
              if (c.signedIn)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_off_rounded),
                  title: Text('Delete cloud data and account', style: t.body()),
                  subtitle: Text('Verify your identity first · this phone keeps its data', style: t.meta()),
                  enabled: !c.busy,
                  onTap: () async {
                    if (!await _confirm(
                      context,
                      'Delete cloud data?',
                      'Your backup, sharing invitations, coaching data and account will be deleted. This phone keeps its tracking data. Google will ask you to verify your identity.',
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
                leading: const Icon(Icons.delete_forever_outlined),
                title: Text('Erase this phone', style: t.body()),
                subtitle: Text(
                  c.signedIn ? 'Your cloud backup stays' : 'All local tracking and recovery copies',
                  style: t.meta(),
                ),
                onTap: () async {
                  if (!await _confirm(
                    context,
                    'Erase this phone?',
                    c.signedIn
                        ? 'You will be signed out first. The existing cloud backup stays; unsynced changes will be lost. All local tracking and recovery copies are erased.'
                        : 'All local tracking and recovery copies will be erased. Export a backup first if you need them.',
                    'Erase',
                  )) {
                    return;
                  }
                  if (!context.mounted) return;
                  await _run(context, () async {
                    if (c.signedIn) await c.signOut(requireBackup: false);
                    store.eraseAll();
                    await store.saved;
                    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resolve(BuildContext context, bool useCloud) async {
    if (!await _confirm(
      context,
      'Use ${useCloud ? 'cloud' : 'phone'} copy?',
      'The selected copy becomes your active backup. The other copy can be exported using the recovery button.',
      'Use this copy',
    )) {
      return;
    }
    if (context.mounted) await _run(context, () => Cloud.instance.resolveConflict(useCloud: useCloud));
  }
}
