import 'package:flutter/widgets.dart';

import 'l10n_core.dart';
import 'l10n_tracking.dart';
import 'l10n_social.dart';
import 'l10n_services.dart';

/// Display-only localisation. Stored food/exercise identifiers and user-authored text stay unchanged.
String tr(
  BuildContext context,
  String message, [
  Map<String, Object> args = const {},
]) => trLanguage(Localizations.localeOf(context).languageCode, message, args);

String trLanguage(
  String language,
  String message, [
  Map<String, Object> args = const {},
]) {
  var result = language == 'bn' ? _bangla[message] ?? message : message;
  for (final arg in args.entries) {
    result = result.replaceAll('{${arg.key}}', '${arg.value}');
  }
  return result;
}

final _bangla = {
  ..._banglaNavigation,
  ...banglaCore,
  ...banglaTracking,
  ...banglaSocial,
  ...banglaServices,
};

String navLabel(String language, String text) => trLanguage(language, text);

const _banglaNavigation = <String, String>{
  'Today': 'আজ',
  'Gym': 'জিম',
  'Train': 'প্রশিক্ষণ',
  'Progress': 'অগ্রগতি',
  'Students': 'শিক্ষার্থীরা',
  'Family': 'পরিবার',
  'People': 'মানুষজন',
  'Food guide': 'খাবারের নির্দেশিকা',
  'Food database': 'খাবারের তালিকা',
  'Your targets': 'আপনার লক্ষ্য',
  'Burn': 'ক্যালরি খরচ',
  'Fasting': 'উপবাস',
  'Spending': 'খরচ',
  'Couple': 'সঙ্গী',
  'Friends': 'বন্ধুরা',
  'Coaches': 'প্রশিক্ষকেরা',
  'Your data': 'আপনার তথ্য',
  'Reminders': 'মনে করিয়ে দেওয়া',
  'Preferences & programme': 'পছন্দ ও কর্মসূচি',
  'Privacy & support': 'গোপনীয়তা ও সহায়তা',
  'More': 'আরও',
  'Add home-screen widget': 'হোম স্ক্রিনে উইজেট যোগ করুন',
  'Plan start date': 'পরিকল্পনা শুরুর তারিখ',
  'Preferences': 'পছন্দ',
  'Food preferences': 'খাবারের পছন্দ',
  'Training setup': 'ব্যায়ামের ব্যবস্থা',
  'Optional features': 'ঐচ্ছিক সুবিধা',
  'Programme': 'কর্মসূচি',
  'Navigation language': 'নেভিগেশনের ভাষা',
  'Crash reporting': 'ক্র্যাশ রিপোর্ট',
  'Diagnostics': 'ত্রুটি নির্ণয়',
  'Share crash reports': 'ক্র্যাশ রিপোর্ট পাঠান',
  'Fasting and Ramadan': 'উপবাস ও রমজান',
  'Food spending': 'খাবারের খরচ',
  'Friends and sharing': 'বন্ধু ও তথ্য ভাগাভাগি',
  'Any food': 'সব ধরনের খাবার',
  'Vegetarian': 'নিরামিষ',
  'Pescatarian': 'মাছসহ নিরামিষ',
  'Home · bodyweight': 'বাড়ি · শরীরের ওজন দিয়ে',
  'Dumbbells': 'ডাম্বেল',
  'Pause programme': 'কর্মসূচি বিরতি দিন',
  'Resume programme': 'কর্মসূচি চালু করুন',
  'Start a new programme': 'নতুন কর্মসূচি শুরু করুন',
  'Previous programmes': 'আগের কর্মসূচি',
  'Save food notes': 'খাবারের নোট সংরক্ষণ করুন',
};
