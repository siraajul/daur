import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'l10n.dart';
import 'store.dart';
import 'targets.dart' show groundChip;
import 'theme.dart';
import 'visuals.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key, required this.store});
  final Store store;

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late final TextEditingController _allergies = TextEditingController(text: widget.store.allergyNotes);
  bool _savingReports = false;
  Store get s => widget.store;
  String label(String text) => navLabel(s.appLanguage, text);

  @override
  void dispose() {
    _allergies.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _reports(bool enabled) async {
    setState(() => _savingReports = true);
    try {
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
        if (!enabled) {
          await FirebaseCrashlytics.instance.deleteUnsentReports();
        }
      }
      s.setPreferences(reports: enabled);
      if (mounted) {
        _say(enabled ? 'Crash reporting enabled on supported mobile devices.' : 'Crash reporting turned off.');
      }
    } catch (_) {
      if (mounted) {
        _say('Could not change crash reporting. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _savingReports = false);
      }
    }
  }

  Future<void> _training(String setup) async {
    if (setup == s.trainingSetup) {
      return;
    }
    final confirmed = await confirmPop(
      context,
      'Change training setup?',
      'This replaces your current workout exercises with a ${{'gym': 'gym', 'home': 'bodyweight home', 'dumbbells': 'dumbbell'}[setup]} routine. Your recorded workout history stays saved. Export your data first if you want a copy of the current routine.',
      'Replace routine',
    );
    if (confirmed && mounted) {
      s.applyTrainingSetup(setup);
    }
  }

  Future<void> _restart() async {
    if (!await confirmPop(
      context,
      'Start a new programme?',
      'Start a new 12-week programme today using your latest weight. The previous programme is archived and your logged history stays saved.',
      'Start new programme',
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (s.programmePausedOn != null) {
      s.pauseProgramme(false);
    }
    s.chooseFinish('again');
  }

  Widget _choices(Map<String, String> values, String selected, ValueChanged<String> change) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: values.entries
        .map((e) => groundChip(context, label(e.value), selected == e.key, () => change(e.key)))
        .toList(),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) {
      final t = Daur.of(context);
      Widget heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Text(label(text), style: t.title()),
      );
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              PageHeader(label('Preferences')),
              heading('Food preferences'),
              _choices(
                const {'any': 'Any food', 'vegetarian': 'Vegetarian', 'pescatarian': 'Pescatarian'},
                s.dietPreference,
                (v) => s.setPreferences(diet: v),
              ),
              const SizedBox(height: 12),
              Text(
                'Food suggestions use this preference. Check ingredients, preparation and labels yourself, especially for mixed dishes.',
                style: t.sec(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _allergies,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Allergies or foods to avoid',
                  hintText: 'Optional notes for your reference',
                  border: OutlineInputBorder(),
                ),
              ),
              Text('These notes do not check allergens or guarantee a meal is safe.', style: t.sec()),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    s.setPreferences(allergies: _allergies.text.trim());
                    FocusScope.of(context).unfocus();
                    _say('Food notes saved.');
                  },
                  child: Text(label('Save food notes')),
                ),
              ),
              heading('Training setup'),
              _choices(
                const {'gym': 'Gym', 'home': 'Home · bodyweight', 'dumbbells': 'Dumbbells'},
                s.trainingSetup,
                _training,
              ),
              const SizedBox(height: 8),
              Text('Changing setup replaces your current routine after confirmation.', style: t.sec()),
              heading('Optional features'),
              for (final module in const {
                'fasting': 'Fasting and Ramadan',
                'spending': 'Food spending',
                'social': 'Friends and sharing',
              }.entries)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label(module.value)),
                  value: s.enabledModules.contains(module.key),
                  onChanged: (v) => s.setModule(module.key, v),
                ),
              Text(
                'Hiding a feature keeps its saved data. Hiding sharing does not revoke anyone’s existing access; manage access in the sharing screen.',
                style: t.sec(),
              ),
              heading('Programme'),
              Text(
                s.programmePausedOn == null
                    ? 'Your programme is active.'
                    : 'Paused since ${s.programmePausedOn}. Resume when you are ready.',
                style: t.body(),
              ),
              TextButton(
                onPressed: () => s.pauseProgramme(s.programmePausedOn == null),
                child: Text(label(s.programmePausedOn == null ? 'Pause programme' : 'Resume programme')),
              ),
              OutlinedButton(onPressed: _restart, child: Text(label('Start a new programme'))),
              if (s.programmes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(label('Previous programmes'), style: t.body()),
                for (final p in s.programmes.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${p['startDay']} → ${p['endDay']}'),
                    subtitle: Text('${p['startKg']} kg → ${p['endKg']} kg'),
                  ),
              ],
              heading('Navigation language'),
              _choices(const {'en': 'English', 'bn': 'বাংলা'}, s.appLanguage, (v) => s.setPreferences(language: v)),
              const SizedBox(height: 8),
              Text(
                'Changes navigation labels. Some screens, food names and guidance remain in English.',
                style: t.sec(),
              ),
              heading('Diagnostics'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label('Share crash reports')),
                subtitle: const Text(
                  'Optional technical error reports through Firebase Crashlytics on Android and iOS. Reports can include device details and stack traces. Previously stored reports may upload when enabled.',
                ),
                value: s.crashReports,
                onChanged: _savingReports ? null : _reports,
              ),
              Text(
                'Keep health records and personal details out of diagnostic reports. You can turn reporting off here at any time.',
                style: t.sec(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
