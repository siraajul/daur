import 'dart:convert';
import 'dart:math';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'cloud.dart';
import 'foods.dart';
import 'store.dart';

/// "2 parathas, an egg and milk tea" → items with kcal and protein, via Gemini (Firebase AI Logic).
/// The prompt carries the closest foods from Daur's Dhaka food list, so estimates use the same
/// numbers as the rest of the app. The person checks the plate before logging.
class MealAi {
  // App Check guards the Gemini API. Daur is installed outside Google Play, so it uses a debug
  // token passed at build time (--dart-define=APPCHECK_DEBUG_TOKEN=…) and registered in the
  // Firebase console; Play Integrity / App Attest take over once there's a store build.
  static const _debugToken = String.fromEnvironment('APPCHECK_DEBUG_TOKEN');

  static Future<void> activateAppCheck() async {
    if (kIsWeb) return;
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: _debugToken.isEmpty
            ? const AndroidPlayIntegrityProvider()
            : const AndroidDebugProvider(debugToken: _debugToken),
        providerApple: _debugToken.isEmpty
            ? const AppleAppAttestWithDeviceCheckFallbackProvider()
            : const AppleDebugProvider(debugToken: _debugToken),
      );
    } catch (e) {
      debugPrint('App Check: $e');
    }
  }

  /// Flash first, then Lite. Free-tier requests per day for this project, from Google Cloud quotas
  /// (generativelanguage.googleapis.com, Oct 2026). Shared by everyone using Daur; reset at
  /// midnight US Pacific.
  static const models = [('gemini-3.8-flash', 'flash', 20), ('gemini-3.5-flash-lite', 'lite', 500)];

  /// Google's quota day: the date in Los Angeles.
  static String quotaDay() {
    tzdata.initializeTimeZones();
    return dayKey(tz.TZDateTime.now(tz.getLocation('America/Los_Angeles')));
  }

  /// When the free quota comes back, in local time ("13:00").
  static String resetsAt() {
    tzdata.initializeTimeZones();
    final la = tz.getLocation('America/Los_Angeles');
    final n = tz.TZDateTime.now(la);
    final local = tz.TZDateTime(la, n.year, n.month, n.day + 1).toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// Today's count per model: the shared cloud count when signed in, never less than this phone's.
  static Future<Map<String, int>> used(Store s) async {
    final day = quotaDay();
    final local = s.aiUsedOn(day), shared = await Cloud.instance.aiUsage(day) ?? const {};
    return {for (final (_, k, _) in models) k: max(local[k] ?? 0, shared[k] ?? 0)};
  }

  /// Estimates left today across both models.
  static Future<int> left(Store s) async {
    final u = await used(s);
    return models.fold<int>(0, (a, m) => a + max(0, m.$3 - (u[m.$2] ?? 0)));
  }

  static GenerativeModel _model(String name) => FirebaseAI.googleAI().generativeModel(
    model: name,
    systemInstruction: Content.system(
      'You estimate calories and protein for food eaten in Dhaka, Bangladesh. Split the description '
      'into separate items. Use the reference list\'s numbers when an item matches one; otherwise give '
      'a realistic Dhaka home or restaurant serving. qty is how many of the stated portion. '
      'junk is true for fried snacks, fast food, sweets and sugary drinks. category is where the food '
      'belongs on a Dhaka menu (a hotel rice plate is office-lunch, cha or a soft drink is drink). '
      'Never invent items.',
    ),
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'items': Schema.array(
            items: Schema.object(
              properties: {
                'name': Schema.string(description: 'Short English name, e.g. Paratha'),
                'portion': Schema.string(description: 'One portion, e.g. 1 piece (~80 g)'),
                'qty': Schema.number(description: 'How many portions'),
                'kcal': Schema.integer(description: 'kcal for ONE portion'),
                'protein': Schema.integer(description: 'grams of protein for ONE portion'),
                'junk': Schema.boolean(),
                // sorted into Daur's own categories, so saved AI foods sit under the right chip
                'category': Schema.enumString(enumValues: [for (final (k, _) in foodCategories) k]),
              },
            ),
          ),
        },
      ),
    ),
  );

  /// Up to 30 foods from the list that share a word with the description: the model's anchor.
  static List<Food> references(String text) {
    final words = {
      for (final w in text.toLowerCase().split(RegExp(r'[^a-z\u0980-\u09ff]+')))
        if (w.length >= 3) ...[w, if (w.endsWith('s')) w.substring(0, w.length - 1)], // parathas → paratha
    };
    return foods.where((f) => words.any(f.matches)).take(30).toList();
  }

  /// Items for the plate, or throws with a short message. A description estimated before comes
  /// back from the saved estimates without spending a request.
  static Future<List<Eaten>> estimate(String text, Store s) async {
    final saved = s.savedEstimate(text);
    if (saved != null) return saved;
    final refs = references(text)
        .map((f) => '${f.name} | ${f.portion} | ${f.kcal} kcal | ${f.protein} g protein${f.rare ? ' | junk' : ''}')
        .join('\n');
    final prompt = [
      Content.text('Reference foods (per portion):\n${refs.isEmpty ? '(none matched)' : refs}\n\nWhat I ate: $text'),
    ];
    final day = quotaDay(), u = await used(s);
    final open = models.where((m) => (u[m.$2] ?? 0) < m.$3).toList();
    if (open.isEmpty) throw const AiQuotaGone();
    GenerateContentResponse? r;
    for (final (i, (name, key, limit)) in open.indexed) {
      try {
        r = await _model(name).generateContent(prompt);
        s.noteAi(day, key);
        Cloud.instance.countAi(day, key);
        break;
      } on FirebaseAIException catch (e) {
        final quota = RegExp(r'\[429\]|RESOURCE_EXHAUSTED|quota').hasMatch(e.message);
        final busy = RegExp(r'\[(500|503)\]|high demand|overloaded').hasMatch(e.message);
        if (quota) s.noteAi(day, key, to: limit); // Google says it's gone: count it as gone today
        if (!(quota || busy)) rethrow;
        if (i == open.length - 1) {
          if (quota) throw const AiQuotaGone();
          rethrow;
        }
        debugPrint('MealAi: $name ${quota ? 'out of quota' : 'busy'}, trying ${open[i + 1].$1}');
      }
    }
    final items = (jsonDecode(r?.text ?? '{}') as Map<String, dynamic>)['items'] as List? ?? const [];
    final out = [
      for (final x in items.cast<Map<String, dynamic>>())
        if ((x['kcal'] as num? ?? 0) > 0)
          Eaten(
            x['name'] as String? ?? 'Food',
            (x['kcal'] as num).round(),
            (x['protein'] as num? ?? 0).round(),
            rare: x['junk'] as bool? ?? false,
            qty: ((x['qty'] as num? ?? 1).toDouble() * 2).round() / 2, // the sheet's ½ steps
            portion: x['portion'] as String? ?? '',
            cat: foodCategories.any((c) => c.$1 == x['category']) ? x['category'] as String : '',
          ),
    ];
    s.saveEstimate(text, out);
    return out;
  }
}

/// The project's free AI estimates for today are used up.
class AiQuotaGone implements Exception {
  const AiQuotaGone();
}
