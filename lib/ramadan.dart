import 'dart:math';

import 'plan.dart';

// Ramadan: the fast runs from the end of sehri to iftar, and the day's four meals become Sehri,
// Iftar, a snack after Maghrib and dinner after Tarawih.

/// Where Ramadan times are worked out for: Bangladesh's 64 districts, then cities abroad where
/// many Bangladeshis live. (name, latitude, longitude)
const ramadanPlaces = <(String, double, double)>[
  ('Dhaka', 23.8103, 90.4125), ('Bagerhat', 22.6516, 89.7859), ('Bandarban', 22.1953, 92.2184),
  ('Barguna', 22.1591, 90.1262), ('Barishal', 22.7010, 90.3535), ('Bhola', 22.6859, 90.6482),
  ('Bogura', 24.8465, 89.3773), ('Brahmanbaria', 23.9571, 91.1119), ('Chandpur', 23.2333, 90.6713),
  ('Chapainawabganj', 24.5965, 88.2776), ('Chattogram', 22.3569, 91.7832), ('Chuadanga', 23.6402, 88.8418),
  ("Cox's Bazar", 21.4272, 92.0058), ('Cumilla', 23.4607, 91.1809), ('Dinajpur', 25.6217, 88.6355),
  ('Faridpur', 23.6071, 89.8429), ('Feni', 23.0159, 91.3976), ('Gaibandha', 25.3288, 89.5281),
  ('Gazipur', 23.9999, 90.4203), ('Gopalganj', 23.0050, 89.8266), ('Habiganj', 24.3745, 91.4155),
  ('Jamalpur', 24.9375, 89.9378), ('Jashore', 23.1664, 89.2081), ('Jhalokathi', 22.6406, 90.1987),
  ('Jhenaidah', 23.5450, 89.1726), ('Joypurhat', 25.0968, 89.0227), ('Khagrachhari', 23.1193, 91.9847),
  ('Khulna', 22.8456, 89.5403), ('Kishoreganj', 24.4449, 90.7766), ('Kurigram', 25.8054, 89.6362),
  ('Kushtia', 23.9013, 89.1205), ('Lakshmipur', 22.9447, 90.8282), ('Lalmonirhat', 25.9923, 89.2847),
  ('Madaripur', 23.1641, 90.1897), ('Magura', 23.4873, 89.4199), ('Manikganj', 23.8617, 90.0003),
  ('Meherpur', 23.7622, 88.6318), ('Moulvibazar', 24.4829, 91.7774), ('Munshiganj', 23.5422, 90.5305),
  ('Mymensingh', 24.7471, 90.4203), ('Naogaon', 24.7936, 88.9318), ('Narail', 23.1725, 89.5127),
  ('Narayanganj', 23.6238, 90.5000), ('Narsingdi', 23.9322, 90.7151), ('Natore', 24.4206, 89.0003),
  ('Netrokona', 24.8709, 90.7279), ('Nilphamari', 25.9310, 88.8560), ('Noakhali', 22.8696, 91.0995),
  ('Pabna', 24.0064, 89.2372), ('Panchagarh', 26.3411, 88.5542), ('Patuakhali', 22.3596, 90.3299),
  ('Pirojpur', 22.5841, 89.9720), ('Rajbari', 23.7574, 89.6445), ('Rajshahi', 24.3745, 88.6042),
  ('Rangamati', 22.6533, 92.1789), ('Rangpur', 25.7439, 89.2752), ('Satkhira', 22.7185, 89.0705),
  ('Shariatpur', 23.2423, 90.4348), ('Sherpur', 25.0205, 90.0153), ('Sirajganj', 24.4534, 89.7007),
  ('Sunamganj', 25.0715, 91.3992), ('Sylhet', 24.8949, 91.8687), ('Tangail', 24.2513, 89.9167),
  ('Thakurgaon', 26.0336, 88.4616),
  // abroad
  ('Abu Dhabi', 24.4539, 54.3773), ('Doha', 25.2854, 51.5310), ('Dubai', 25.2048, 55.2708),
  ('Jeddah', 21.4858, 39.1925), ('Kolkata', 22.5726, 88.3639), ('Kuala Lumpur', 3.1390, 101.6869),
  ('Kuwait City', 29.3759, 47.9774), ('London', 51.5074, -0.1278), ('Makkah', 21.3891, 39.8579),
  ('Melbourne', -37.8136, 144.9631), ('Muscat', 23.5880, 58.3829), ('New York', 40.7128, -74.0060),
  ('Riyadh', 24.7136, 46.6753), ('Rome', 41.9028, 12.4964), ('Singapore', 1.3521, 103.8198),
  ('Sydney', -33.8688, 151.2093), ('Tokyo', 35.6762, 139.6503), ('Toronto', 43.6532, -79.3832),
];

/// The 64 districts come first in [ramadanPlaces]; the rest are abroad.
const ramadanDistricts = 64;

/// A first guess from the phone's time zone (IANA name), else Dhaka.
String placeForZone(String zone) =>
    const {
      'Asia/Dubai': 'Dubai',
      'Asia/Qatar': 'Doha',
      'Asia/Riyadh': 'Riyadh',
      'Asia/Kuwait': 'Kuwait City',
      'Asia/Muscat': 'Muscat',
      'Asia/Kolkata': 'Kolkata',
      'Asia/Calcutta': 'Kolkata',
      'Asia/Kuala_Lumpur': 'Kuala Lumpur',
      'Asia/Singapore': 'Singapore',
      'Asia/Tokyo': 'Tokyo',
      'Europe/London': 'London',
      'Europe/Rome': 'Rome',
      'America/New_York': 'New York',
      'America/Toronto': 'Toronto',
      'Australia/Sydney': 'Sydney',
      'Australia/Melbourne': 'Melbourne',
    }[zone] ??
    'Dhaka';

(String, double, double) _place = ramadanPlaces.first;

/// Where Ramadan times are for (Store keeps it, like the diet chart).
void useRamadanPlace(String name) =>
    _place = ramadanPlaces.firstWhere((p) => p.$1 == name, orElse: () => ramadanPlaces.first);

/// When sehri ends and iftar starts on [day] at the chosen place, from the sun, in this phone's
/// time: sehri ends at Fajr (sun 18° below the horizon, as the Islamic Foundation counts it),
/// iftar is sunset. A minute is taken off sehri and two added to iftar for safety, which matches
/// the Foundation's Dhaka table (19 Feb 2026: 05:12 and 17:58). Where the sun never gets 18° down
/// (London in summer), Fajr is a seventh of the night before sunrise. Some countries count Fajr
/// at 15°, later than here: the earlier time is the safe one.
({DateTime sehri, DateTime iftar}) ramadanTimes(DateTime day) {
  final (_, lat, lng) = _place;
  final midnightUtc = DateTime.utc(day.year, day.month, day.day);
  final n = midnightUtc.difference(DateTime.utc(day.year)).inDays;
  final g = 2 * pi / 365 * n; // NOAA's approximation: good to about a minute
  final eqt =
      229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g));
  final dec =
      0.006918 -
      0.399912 * cos(g) +
      0.070257 * sin(g) -
      0.006758 * cos(2 * g) +
      0.000907 * sin(2 * g) -
      0.002697 * cos(3 * g) +
      0.00148 * sin(3 * g);
  final phi = lat * pi / 180;
  // minutes after midnight UTC when the sun is [below]° under the horizon (NaN if it never is)
  double at(double below, bool morning) {
    final ha = acos((sin(-below * pi / 180) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec))) * 180 / pi;
    return 720 - 4 * lng - eqt + (morning ? -4 * ha : 4 * ha);
  }

  final sunset = at(.833, false), sunrise = at(.833, true);
  var fajr = at(18, true);
  if (fajr.isNaN) fajr = sunrise - (sunrise + 1440 - sunset) / 7;
  // shown in this phone's clock: the place's own time when the phone is there
  DateTime local(int minutes) => midnightUtc.add(Duration(minutes: minutes)).toLocal();
  return (sehri: local(fajr.floor() - 1), iftar: local((sunset + 2).ceil()));
}

String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Sehri and Iftar for the first two meals; the snack and dinner stay the plan's (or the trainer's).
List<Meal> ramadanMenu(List<Meal> plan) => [
  const Meal('m1', 'Sehri', '', [
    MealOption(
      'Rice + chicken + doi',
      ['1 cup cooked rice', '150 g chicken', '½ cup dal', '1 cup plain doi', '2–3 glasses of water'],
      580,
      48,
    ),
    MealOption(
      'Roti + eggs + doi',
      ['2 small atta roti', '3 eggs: 2 whole + 1 white', 'Vegetables', '1 cup plain doi', '2–3 glasses of water'],
      560,
      34,
    ),
    MealOption(
      'Oats + milk + eggs',
      ['1 bowl oats with milk', '2 boiled eggs', '1 banana', '2–3 glasses of water'],
      500,
      28,
    ),
  ], 'Slow food that lasts: rice or roti with protein. Little salt, no fried food'),
  const Meal('m2', 'Iftar', '', [
    MealOption(
      'Dates + chola + fruit',
      ['3 dates', '½ cup chola, little oil', '1 cup fruit: papaya, guava, watermelon', '1 boiled egg', 'Water'],
      430,
      19,
    ),
    MealOption(
      'Dates + chicken + muri',
      ['3 dates', '100 g grilled chicken', '½ cup muri', 'Cucumber salad', 'Water'],
      420,
      31,
    ),
    MealOption('Dates + doi + fruit', ['3 dates', '1 cup plain doi', '1 cup fruit', '10 almonds', 'Water'], 380, 14),
  ], 'Dates and water first. Skip piyaju, beguni, jilapi and sugary sherbet'),
  plan[2],
  plan[3],
];

/// The menu with [day]'s times: sehri in the 45 minutes before it ends, iftar at sunset, a snack
/// after Maghrib and dinner after Tarawih.
List<Meal> withRamadanTimes(List<Meal> menu, DateTime day) {
  final (:sehri, :iftar) = ramadanTimes(day);
  String w(DateTime a, DateTime b) => '${hhmm(a)}–${hhmm(b)}';
  final at = DateTime(day.year, day.month, day.day);
  final windows = {
    'm1': w(sehri.subtract(const Duration(minutes: 45)), sehri),
    'm2': w(iftar, iftar.add(const Duration(minutes: 30))),
    'm3': w(iftar.add(const Duration(minutes: 75)), iftar.add(const Duration(minutes: 105))),
    'm4': w(at.add(const Duration(hours: 21, minutes: 30)), at.add(const Duration(hours: 22, minutes: 30))),
  };
  return [for (final m in menu) Meal(m.id, m.name, windows[m.id] ?? m.window, m.options, m.note)];
}
