import 'food_search.dart';

/// Foods Dhaka working people commonly eat, for logging "something else".
/// kcal / protein per typical Dhaka serving. Sources: Food Composition Table for Bangladesh 2013
/// (INFS, University of Dhaka / FAO) first, then USDA FoodData Central / IFCT 2017 and pack labels.
/// Restaurant and street food is oil-heavy and varies by shop: treat biryani, haleem, nehari and
/// street plates as ±20%. Each line's comment says how its number was reached.
/// Generated from the research file (201 items); rare = on the plan's keep-rare list.
class Food {
  final String name, portion;
  final int kcal, protein;
  final bool rare;
  final String cat, bn; // category key (see foodCategories), Bangla name for search
  const Food(this.name, this.portion, this.kcal, this.protein, {this.rare = false, this.cat = '', this.bn = ''});

  bool matches(String q) => foodMatches(name, bn, q);
}

/// Category chips in the "something else" list, in the order a Dhaka day runs.
const foodCategories = [
  ('office-lunch', 'Office lunch'),
  ('street', 'Street & tea stall'),
  ('staple', 'Rice & roti'),
  ('protein', 'Fish, meat, egg'),
  ('curry/veg', 'Dal, veg & bhorta'),
  ('breakfast', 'Breakfast'),
  ('fast-food', 'Fast food'),
  ('sweet', 'Sweets'),
  ('drink', 'Drinks'),
  ('fruit', 'Fruit'),
];

const foods = [
  // ---- office-lunch ----
  // Sum: rice 300 g (333) + hotel fish curry (~170) + hotel dal (95); oilier hotel gravy
  Food(
    'Bhaat-mach (hotel plate)',
    '1 plate rice + 1 rui/katla piece + dal',
    600,
    26,
    cat: 'office-lunch',
    bn: 'ভাত-মাছ',
  ),
  // Sum: rice 300 g (333) + hotel chicken curry (260) + hotel dal (95)
  Food(
    'Bhaat-murgi (hotel plate)',
    '1 plate rice + 1 chicken piece + dal',
    690,
    30,
    cat: 'office-lunch',
    bn: 'ভাত-মুরগি',
  ),
  // Sum: rice 300 g (333) + hotel beef (350) + dal (95)
  Food(
    'Bhaat-gorur mangsho (hotel plate)',
    '1 plate rice + beef curry + dal',
    780,
    32,
    rare: true,
    cat: 'office-lunch',
    bn: 'ভাত-গরুর মাংস',
  ),
  // Sum: rice 300 g (333) + egg curry (170) + dal (95)
  Food('Bhaat-dim (hotel plate)', '1 plate rice + egg curry + dal', 600, 18, cat: 'office-lunch', bn: 'ভাত-ডিম'),
  // Sum: rice 300 g + alu bhorta + begun bhorta + hotel dal
  Food(
    'Bhaat-bhorta-dal (hotel plate)',
    '1 plate rice + 2 bhorta + dal',
    595,
    13,
    cat: 'office-lunch',
    bn: 'ভাত-ভর্তা-ডাল',
  ),
  // Sum: rice 300 g (333) + mixed sabji (150) + dal (95)
  Food('Bhaat-sabji-dal (hotel plate)', '1 plate rice + sabji + dal', 580, 13, cat: 'office-lunch', bn: 'ভাত-সবজি-ডাল'),
  // Sum of components; typical canteen/restaurant set lunch
  Food(
    'Set menu (rice + chicken + sabji + dal)',
    '1 set',
    840,
    33,
    cat: 'office-lunch',
    bn: 'সেট মেনু (ভাত-মুরগি-সবজি-ডাল)',
  ),
  // Sum: hotel polao ~300 g (~510) + chicken roast (380) + salad
  Food(
    'Set menu (polao + roast + salad)',
    '1 set (~1.5 cup polao + 1 roast)',
    900,
    37,
    rare: true,
    cat: 'office-lunch',
    bn: 'সেট মেনু (পোলাও-রোস্ট)',
  ),
  // Recipe estimate: ghee rice ~300 g at ~180/100 g + ~100 g edible mutton + ghee-fried potato; UNCERTAIN +/-20%
  Food(
    'Kacchi biryani (mutton)',
    '1 plate (~450 g, 2 meat pieces + alu)',
    950,
    33,
    rare: true,
    cat: 'office-lunch',
    bn: 'কাচ্চি বিরিয়ানি',
  ),
  // Recipe estimate: oily/dalda rice ~300 g at ~175/100 g + ~60 g beef cubes; uncertain
  Food('Beef tehari', '1 plate (~350 g)', 700, 22, rare: true, cat: 'office-lunch', bn: 'গরুর তেহারি'),
  // Recipe estimate: rice ~300 g at ~170/100 g + ~90 g edible chicken + potato
  Food('Chicken biryani', '1 plate (~400 g, 1 piece)', 750, 30, rare: true, cat: 'office-lunch', bn: 'চিকেন বিরিয়ানি'),
  // Recipe: FCT BD pulao adjusted to ~175/100 g (hotel ghee) x 300 g + ~90 g edible chicken
  Food('Morog polao', '1 plate (~400 g)', 720, 30, rare: true, cat: 'office-lunch', bn: 'মোরগ পোলাও'),
  // Sum: bhuna khichuri 300 g (570) + ~100 g beef bhuna (280)
  Food(
    'Khichuri with beef',
    '1 plate (bhuna khichuri + beef)',
    850,
    32,
    rare: true,
    cat: 'office-lunch',
    bn: 'খিচুড়ি-গরুর মাংস',
  ),
  // Sum: FCT BD khichuri 163/100 g x 300 g + 1 fried/bhuna egg
  Food('Khichuri with egg', '1 plate (khichuri + 1 egg bhuna/fry)', 620, 22, cat: 'office-lunch', bn: 'খিচুড়ি-ডিম'),

  // ---- street ----
  // FCT BD bread bun 270 kcal, 8.8 g P/100 g x 60 g; sweet tea-stall buns a bit more
  Food('Bun / banroti', '1 piece (~60 g)', 165, 5, cat: 'street', bn: 'বনরুটি'),
  // Estimate: flattened beef, batter, shallow-fried; very oily; uncertain
  Food('Beef chap (Old Dhaka)', '1 piece (~120 g)', 380, 22, rare: true, cat: 'street', bn: 'বিফ চাপ'),
  // USDA/IFCT samosa ~280-300 kcal/100 g x 50 g; deep-fried, potato filling
  Food('Singara', '1 piece (~50 g)', 140, 2, rare: true, cat: 'street', bn: 'সিঙ্গারা'),
  // Estimate: thin fried pastry ~380 kcal/100 g x 35 g
  Food('Samosa (Dhaka, keema/onion)', '1 piece (~35 g)', 135, 4, rare: true, cat: 'street', bn: 'সমুচা'),
  // Estimate: deep-fried lentil-filled bread ~350 kcal/100 g x 40 g
  Food('Dal puri', '1 piece (~40 g)', 140, 4, rare: true, cat: 'street', bn: 'ডালপুরি'),
  // Estimate: lentil-onion fritter ~330 kcal/100 g x 20 g; ~10 g lentil
  Food('Piyaju', '1 piece (~20 g)', 65, 2, rare: true, cat: 'street', bn: 'পিঁয়াজু'),
  // Estimate: besan-battered brinjal, deep-fried ~250 kcal/100 g x 40 g
  Food('Beguni', '1 piece (~40 g)', 100, 2, rare: true, cat: 'street', bn: 'বেগুনি'),
  // Estimate: battered potato, deep-fried ~230 kcal/100 g x 50 g
  Food('Alur chop', '1 piece (~50 g)', 115, 2, rare: true, cat: 'street', bn: 'আলুর চপ'),
  // IFCT/USDA pakora ~300 kcal/100 g x 25 g
  Food('Pakora (onion/veg)', '1 piece (~25 g)', 75, 2, rare: true, cat: 'street', bn: 'পাকোড়া'),
  // FCT BD Bengal gram boiled 182 kcal, 10.6 g P/100 g x 100 g + ~6 g oil
  Food('Chola / boot (iftar/street)', '1 small bowl (~100 g)', 240, 10, cat: 'street', bn: 'ছোলা (বুট)'),
  // Estimate: 8 fried puris (~30 kcal each) + dabli/potato filling + egg grating + tamarind water; uncertain
  Food('Fuchka', '1 plate (8 pieces with filling + egg)', 350, 9, rare: true, cat: 'street', bn: 'ফুচকা'),
  // FCT BD dried pea boiled 170 kcal, 11.5 g P/100 g x ~120 g + potato, egg, crushed fuchka, tetul water
  Food('Chotpoti', '1 plate (~250 g)', 300, 13, cat: 'street', bn: 'চটপটি'),
  // Estimate: fried puris + chola/dabli filling; uncertain
  Food('Velpuri', '1 plate (5-6 pieces)', 300, 8, rare: true, cat: 'street', bn: 'ভেলপুরি'),
  // FCT BD muri 361/100 g x 40 g + chanachur 10 g + 3 g mustard oil + chola
  Food('Jhalmuri', '1 thonga (~40 g muri + chanachur)', 250, 6, cat: 'street', bn: 'ঝালমুড়ি'),
  // Sum: muri 40 g + chola 60 g + 1 piyaju + 1 beguni + oil; varies a lot
  Food(
    'Muri makha (iftar bowl)',
    '1 big bowl (muri + chola + piyaju/beguni)',
    450,
    12,
    rare: true,
    cat: 'street',
    bn: 'মুড়ি মাখা',
  ),
  // USDA Bombay mix ~520 kcal, 15 g P/100 g x 30 g
  Food('Chanachur', '1 handful (~30 g)', 160, 4, rare: true, cat: 'street', bn: 'চানাচুর'),
  // USDA potato chips ~540 kcal/100 g x 25 g
  Food('Chips (packet)', '1 small pack (~25 g)', 135, 2, rare: true, cat: 'street', bn: 'চিপস'),
  // USDA dry-roasted peanuts 585 kcal, 24 g P/100 g x 30 g
  Food('Peanuts (badam, roasted)', '1 thonga (~30 g shelled)', 170, 8, cat: 'street', bn: 'চিনাবাদাম'),
  // FCT BD sweet corn 147 kcal, 3.5 g P/100 g x 90 g
  Food('Bhutta (roasted corn)', '1 cob (~90 g kernels)', 130, 4, cat: 'street', bn: 'ভুট্টা পোড়া'),
  // Sum: paratha ~70 g (230) + 1 fried egg (115) + sauce
  Food('Egg roll', '1 roll', 360, 11, rare: true, cat: 'street', bn: 'এগ রোল'),
  // Sum: paratha ~70 g (230) + ~60 g chicken (120) + 10 g mayo (70)
  Food('Chicken roll', '1 roll', 420, 18, rare: true, cat: 'street', bn: 'চিকেন রোল'),
  // Estimate: pita/khubz ~80 g + ~80 g chicken + garlic mayo; Dhaka versions mayo-heavy
  Food('Shawarma (chicken)', '1 piece', 450, 22, rare: true, cat: 'street', bn: 'শর্মা'),
  // Estimate: ~40 kcal, 2.2 g P per steamed dumpling; fried momo ~+100 kcal
  Food('Momo (chicken, steamed)', '1 plate (8 pieces)', 320, 18, cat: 'street', bn: 'মোমো'),
  // Estimate: boiled noodles ~150 g + ~15 g oil + veg + egg
  Food('Chowmein (street)', '1 plate (~250 g)', 450, 12, rare: true, cat: 'street', bn: 'চাউমিন'),
  // Pack labels ~460-470 kcal/100 g dry x 62 g
  Food(
    'Instant noodles (Mr Noodles/Maggi)',
    '1 pack (~62 g dry)',
    290,
    6,
    rare: true,
    cat: 'street',
    bn: 'ইনস্ট্যান্ট নুডলস',
  ),
  // Estimate: wheat/lentil + beef stew with oil tarka; uncertain
  Food('Haleem', '1 bowl (~300 g)', 450, 24, rare: true, cat: 'street', bn: 'হালিম'),
  // Estimate: beef shank stew, fatty gravy; excludes naan
  Food('Nehari', '1 bowl (~300 ml with meat)', 450, 25, rare: true, cat: 'street', bn: 'নেহারি'),
  // Estimate: trotter soup, collagen + fat; uncertain
  Food('Paya', '1 bowl (~300 ml)', 350, 18, rare: true, cat: 'street', bn: 'পায়া'),
  // Estimate from USDA fried chicken ~260 kcal/100 g; street batter/oil
  Food('Chicken fry (street)', '1 piece (~120 g with bone)', 300, 20, rare: true, cat: 'street', bn: 'চিকেন ফ্রাই'),
  // USDA pound cake ~390 kcal/100 g x 50 g
  Food('Cake slice (bakery)', '1 slice (~50 g)', 200, 3, rare: true, cat: 'street', bn: 'কেক'),
  // USDA cream cake ~370 kcal/100 g x 70 g
  Food('Pastry (cream)', '1 piece (~70 g)', 260, 3, rare: true, cat: 'street', bn: 'পেস্ট্রি'),
  // Pack labels ~480 kcal/100 g; FCT BD sweet biscuit 344/100 g seems low for these
  Food('Energy Plus-type biscuit', '4 biscuits (~30 g)', 145, 2, rare: true, cat: 'street', bn: 'এনার্জি বিস্কুট'),
  // Pack labels ~440 kcal, 7 g P/100 g x 24 g
  Food('Marie biscuit', '4 biscuits (~24 g)', 105, 2, rare: true, cat: 'street', bn: 'মেরি বিস্কুট'),
  // USDA/IFCT rusk ~410 kcal, 10 g P/100 g x 30 g
  Food('Toast biscuit (rusk)', '2 pieces (~30 g)', 125, 3, rare: true, cat: 'street', bn: 'টোস্ট বিস্কুট'),

  // ---- staple ----
  // FCT BD white rice boiled 111 kcal, 2.1 g P/100 g x 160 g
  Food('Rice (bhaat), 1 cup cooked', '1 cup cooked (~160 g)', 178, 3, cat: 'staple', bn: 'ভাত'),
  // FCT BD white rice boiled 111 kcal/100 g x 80 g
  Food('Rice (bhaat), half cup', '1/2 cup cooked (~80 g)', 89, 2, cat: 'staple', bn: 'ভাত (আধা কাপ)'),
  // FCT BD rice boiled 111 kcal/100 g x 300 g; hotel plates vary 250-400 g
  Food('Rice (bhaat), 1 hotel plate', '1 plate (~300 g, ~2 cups)', 333, 6, cat: 'staple', bn: 'ভাত (এক প্লেট)'),
  // FCT BD brown parboiled rice boiled 112 kcal, 2.5 g P/100 g x 160 g
  Food('Red/brown rice (lal chaler bhaat)', '1 cup cooked (~160 g)', 179, 4, cat: 'staple', bn: 'লাল চালের ভাত'),
  // FCT BD ruti 246 kcal, 7.5 g P/100 g x 40 g; no oil
  Food('Atta ruti (home)', '1 piece (~40 g)', 98, 3, cat: 'staple', bn: 'আটার রুটি'),
  // FCT BD ruti 246 kcal/100 g x 55 g; hotel ruti bigger, often maida
  Food('Ruti (hotel/dokan, large)', '1 piece (~55 g)', 135, 4, cat: 'staple', bn: 'হোটেলের রুটি'),
  // USDA naan ~291 kcal, 9 g P/100 g x 90 g; butter naan +40 kcal
  Food('Naan / tandoor ruti', '1 piece (~90 g)', 262, 8, cat: 'staple', bn: 'নান রুটি'),
  // IFCT/USDA paratha ~320 kcal/100 g x 80 g; hotel dalda/oil, could be 300+
  Food('Paratha (plain, hotel)', '1 piece (~80 g)', 260, 5, rare: true, cat: 'staple', bn: 'পরোটা'),
  // USDA/IFCT layered paratha ~355 kcal/100 g x 90 g; extra ghee/dalda between layers
  Food('Lachha paratha', '1 piece (~90 g)', 320, 6, rare: true, cat: 'staple', bn: 'লাচ্ছা পরোটা'),
  // USDA/IFCT poori ~360 kcal/100 g x 25 g; deep-fried maida
  Food('Luchi / puri (plain)', '1 piece (~25 g)', 90, 2, rare: true, cat: 'staple', bn: 'লুচি'),
  // Estimate: flaky ghee/dalda pastry ~450 kcal/100 g x 30 g; uncertain
  Food('Bakarkhani', '1 piece (~30 g)', 135, 2, rare: true, cat: 'staple', bn: 'বাখরখানি'),
  // FCT BD plain khichuri recipe 163 kcal, 5.1 g P/100 g x 200 g
  Food('Plain khichuri (home)', '1 cup (~200 g)', 326, 10, cat: 'staple', bn: 'খিচুড়ি'),
  // FCT BD khichuri 163/100 g adjusted to ~190/100 g for extra oil/ghee x 300 g
  Food('Bhuna khichuri', '1 plate (~300 g)', 570, 14, cat: 'staple', bn: 'ভুনা খিচুড়ি'),
  // FCT BD plain pulao 128 kcal/100 g x 160 g = 205, +25 for ghee in hotel/biye polao
  Food('Plain polao', '1 cup (~160 g)', 230, 4, rare: true, cat: 'staple', bn: 'পোলাও'),
  // FCT BD muri 361 kcal, 6.7 g P/100 g x 15 g
  Food('Muri (puffed rice)', '1 cup (~15 g)', 54, 1, cat: 'staple', bn: 'মুড়ি'),
  // FCT BD rice flakes 356 kcal, 6.5 g P/100 g x 50 g
  Food('Chira (dry)', '1 cup dry (~50 g)', 178, 3, cat: 'staple', bn: 'চিড়া'),
  // USDA oats 379 kcal/100 g x 40 g + FCT BD whole milk 63 kcal/100 g x 200 ml; +20 per tsp sugar
  Food('Oats with milk', '1 bowl (40 g oats + 200 ml milk, no sugar)', 278, 12, cat: 'staple', bn: 'দুধ দিয়ে ওটস'),
  // FCT BD white bread 272 kcal, 8.0 g P/100 g x 25 g
  Food('Bread slice (pauruti)', '1 slice (~25 g)', 68, 2, cat: 'staple', bn: 'পাউরুটি'),
  // USDA whole-milk plain yogurt 61 kcal, 3.5 g P/100 g
  Food('Plain yogurt (tok doi)', '1 cup (~100 g)', 65, 3, cat: 'staple', bn: 'টক দই'),
  // FCT BD potato boiled 67 kcal, 1.2 g P/100 g
  Food('Boiled potato (alu siddho)', '1 medium (~100 g)', 67, 1, cat: 'staple', bn: 'আলু সিদ্ধ'),

  // ---- protein ----
  // FCT BD Bengal gram boiled 182 kcal, 10.6 g P/100 g x 150 g + 6 g oil
  Food('Chhola bhuna (home)', '1 cup (~150 g)', 320, 15, cat: 'protein', bn: 'ছোলা ভুনা'),
  // Recipe: broiler meat 60 g cooked (~115 kcal, 16 g P; FCT BD chicken leg) + 8 g oil + onion
  Food('Chicken curry (home)', '1 piece + gravy (~60 g meat)', 200, 16, cat: 'protein', bn: 'মুরগির তরকারি'),
  // As chicken curry with ~4 g oil
  Food('Chicken jhol (light, home)', '1 piece + gravy (~60 g meat)', 160, 16, cat: 'protein', bn: 'মুরগির ঝোল'),
  // Recipe: ~80 g cooked meat + ~12 g oil in gravy; hotel oil-heavy
  Food('Chicken curry (hotel)', '1 piece + gravy (~80 g meat)', 260, 20, cat: 'protein', bn: 'হোটেলের মুরগির তরকারি'),
  // As hotel chicken curry, thicker oily masala
  Food('Chicken bhuna (hotel)', '1 piece (~80 g meat, thick masala)', 280, 21, cat: 'protein', bn: 'মুরগি ভুনা'),
  // Recipe: ~130 g edible chicken with skin (~250 kcal) + ghee/oil, sugar, fried onion; party dish
  Food(
    'Chicken roast (biye-style)',
    '1 quarter piece (~180 g with bone)',
    380,
    30,
    rare: true,
    cat: 'protein',
    bn: 'মুরগির রোস্ট',
  ),
  // Recipe: ~90 g meat + yogurt, ghee, nut paste; estimate
  Food('Chicken rezala', '1 piece + gravy', 320, 22, rare: true, cat: 'protein', bn: 'মুরগির রেজালা'),
  // Leaner than broiler; FCT BD chicken + 8 g oil; estimate
  Food('Deshi murgi curry', '1 piece + gravy (~60 g meat)', 180, 15, cat: 'protein', bn: 'দেশি মুরগির তরকারি'),
  // USDA chicken breast roasted, skinless 165 kcal, 31 g P/100 g
  Food('Chicken breast (boiled/grilled)', '100 g cooked', 165, 31, cat: 'protein', bn: 'মুরগির বুকের মাংস'),
  // USDA tandoori chicken ~150-200 kcal/100 g; marinade oil varies
  Food('Chicken tikka / boti kebab', '1 serving (~100 g, 5-6 pieces)', 200, 25, cat: 'protein', bn: 'চিকেন টিক্কা'),
  // USDA roasted chicken with skin ~215 kcal/100 g x 130 g edible + basting oil; skip mayo
  Food('Chicken grill (quarter)', '1 quarter (~200 g with bone)', 320, 33, cat: 'protein', bn: 'চিকেন গ্রিল'),
  // Recipe: FCT BD beef 15-20% fat 207 kcal/100 g x 110 g raw + 10 g oil
  Food(
    'Beef curry (home)',
    '1 bowl (~4-5 pieces, ~100 g meat)',
    330,
    22,
    rare: true,
    cat: 'protein',
    bn: 'গরুর মাংসের তরকারি',
  ),
  // Recipe: FCT BD lean beef 103 kcal, 20.7 g P/100 g x 115 g raw + 5 g oil
  Food(
    'Beef jhol / stew (lean, less oil)',
    '1 bowl (~100 g meat)',
    220,
    24,
    cat: 'protein',
    bn: 'গরুর মাংসের ঝোল (কম তেল)',
  ),
  // Recipe: fatty beef dry-cooked in mustard oil; estimate, oil content uncertain
  Food('Beef kala bhuna', '1 serving (~100 g)', 380, 22, rare: true, cat: 'protein', bn: 'কালা ভুনা'),
  // As home beef curry with extra oil; hotel
  Food(
    'Beef kosha / bhuna (hotel)',
    '1 serving (~100 g meat)',
    350,
    22,
    rare: true,
    cat: 'protein',
    bn: 'গরুর মাংস কষা',
  ),
  // FCT BD beef handi kabab 233 kcal, 12.7 g P/100 g; shik is leaner mince, ~250/100 g x 80 g
  Food('Beef shik kabab', '1 skewer (~80 g)', 200, 16, rare: true, cat: 'protein', bn: 'শিক কাবাব'),
  // Recipe: FCT BD goat meat 118 kcal/100 g, ~100 g edible + 12 g oil; hotel versions fattier
  Food(
    'Mutton / khasi curry',
    '1 serving (~100 g meat on bone + gravy)',
    280,
    20,
    rare: true,
    cat: 'protein',
    bn: 'খাসির মাংস',
  ),
  // FCT BD rohu 104 kcal, 19.7 g P/100 g x 80 g (edible) + 7 g oil
  Food('Rui curry / jhol', '1 piece + gravy (~80 g fish)', 150, 16, cat: 'protein', bn: 'রুই মাছের তরকারি'),
  // FCT BD rohu x 80 g + ~6 g oil absorbed
  Food('Rui fry (mach bhaja)', '1 piece (~80 g fish)', 140, 16, cat: 'protein', bn: 'রুই মাছ ভাজা'),
  // FCT BD catla 103 kcal, 19.9 g P/100 g x 90 g + 7 g oil
  Food('Katla curry', '1 piece + gravy (~100 g fish)', 170, 19, cat: 'protein', bn: 'কাতলা মাছের তরকারি'),
  // FCT BD pangas 162 kcal, 15.9 g P/100 g x 100 g + 7 g oil; fatty fish
  Food('Pangas curry', '1 piece + gravy (~100 g fish)', 235, 16, cat: 'protein', bn: 'পাঙ্গাস মাছের তরকারি'),
  // FCT BD tilapia 110 kcal, 20.8 g P/100 g x 100 g + 7 g oil
  Food('Tilapia curry / fry', '1 fish (~100 g edible)', 180, 21, cat: 'protein', bn: 'তেলাপিয়া মাছ'),
  // FCT BD hilsa 223 kcal, 18 g P/100 g x 80 g + 6 g mustard oil
  Food('Ilish curry / jhol', '1 piece (~80 g fish)', 240, 14, cat: 'protein', bn: 'ইলিশ মাছের ঝোল'),
  // FCT BD hilsa x 80 g + ~8 g oil absorbed
  Food('Ilish bhaja (fried)', '1 piece (~80 g fish)', 250, 15, cat: 'protein', bn: 'ইলিশ মাছ ভাজা'),
  // FCT BD hilsa x 80 g + mustard paste 10 g (FCT mustard seed 501/100 g) + 8 g oil
  Food('Shorshe ilish / ilish bhapa', '1 piece (~80 g fish)', 300, 16, cat: 'protein', bn: 'সর্ষে ইলিশ / ভাপা ইলিশ'),
  // FCT BD Thai koi 139 kcal, 17.5 g P/100 g x 70 g + 8 g oil (often fried first)
  Food('Koi curry / bhuna', '1 fish (~70 g edible)', 175, 12, cat: 'protein', bn: 'কই মাছ'),
  // FCT BD pabda 95 kcal, 17.3 g P/100 g x 60 g + 5 g oil
  Food('Pabda jhol', '1 fish (~60 g edible)', 105, 10, cat: 'protein', bn: 'পাবদা মাছের ঝোল'),
  // FCT BD stinging catfish 101 kcal, 17.2 g P/100 g x 70 g + 5 g oil
  Food('Shing mach jhol', '1 serving (~70 g fish)', 125, 12, cat: 'protein', bn: 'শিং মাছের ঝোল'),
  // FCT BD walking catfish 103 kcal, 15.6 g P/100 g x 70 g + 5 g oil
  Food('Magur mach curry', '1 serving (~70 g fish)', 125, 11, cat: 'protein', bn: 'মাগুর মাছ'),
  // FCT BD golda prawn 102 kcal, 20.9 g P/100 g + FCT coconut milk 213/100 g x 50 g + 8 g oil/ghee; rich
  Food('Chingri malai curry', '1 serving (~2 golda, ~100 g prawn)', 290, 22, cat: 'protein', bn: 'চিংড়ি মালাইকারি'),
  // FCT BD river prawn ~85 kcal, 18 g P/100 g x 60 g + 8 g oil
  Food('Chingri bhuna (small prawn)', '1 serving (~60 g prawns)', 130, 11, cat: 'protein', bn: 'চিংড়ি ভুনা'),
  // FCT BD dried fish ~330 kcal, 60-70 g P/100 g x 30 g + 10 g oil + onion
  Food('Shutki bhuna / curry', '1 serving (~30 g dried fish)', 200, 20, cat: 'protein', bn: 'শুঁটকি ভুনা'),
  // FCT BD farm egg boiled 158 kcal, 16.5 g P/100 g x 50 g
  Food('Boiled egg (farm)', '1 egg (~50 g edible)', 79, 8, cat: 'protein', bn: 'সিদ্ধ ডিম'),
  // FCT BD native egg boiled 179 kcal, 15.1 g P/100 g x 38 g
  Food('Boiled egg (deshi)', '1 egg (~38 g edible)', 68, 6, cat: 'protein', bn: 'দেশি মুরগির ডিম সিদ্ধ'),
  // FCT BD duck egg boiled 214 kcal, 15.3 g P/100 g x 65 g
  Food('Duck egg, boiled', '1 egg (~65 g edible)', 139, 10, cat: 'protein', bn: 'হাঁসের ডিম সিদ্ধ'),
  // FCT BD farm egg raw 139 kcal, 14.5 g P/100 g x 50 g + ~5 g oil
  Food('Dimer pouch / fried egg', '1 egg', 115, 7, cat: 'protein', bn: 'ডিম পোচ / ডিম ভাজা'),
  // FCT BD egg x 50 g + ~6 g oil + onion
  Food('Omelette (1 egg, onion-chilli)', '1 egg', 130, 8, cat: 'protein', bn: 'ডিমের অমলেট'),
  // FCT BD egg + ~8 g oil + onion masala
  Food('Dim bhuna', '1 egg + masala', 160, 8, cat: 'protein', bn: 'ডিম ভুনা'),
  // FCT BD egg + 50 g potato + ~7 g oil
  Food(
    'Egg curry with alu (dimer torkari)',
    '1 egg + 1 potato piece + gravy',
    170,
    8,
    cat: 'protein',
    bn: 'ডিমের তরকারি',
  ),

  // ---- curry/veg ----
  // Recipe: FCT BD lentil raw 25 g (79 kcal, 6.9 g P) + 5 g oil
  Food('Masoor dal, thin (patla)', '1 bowl (~200 ml)', 125, 6, cat: 'curry/veg', bn: 'পাতলা মসুর ডাল'),
  // Recipe: FCT BD lentil raw 45 g (143 kcal, 12.5 g P) + 8 g oil
  Food('Masoor dal, thick (ghono)', '1 bowl (~200 ml)', 215, 12, cat: 'curry/veg', bn: 'ঘন মসুর ডাল'),
  // Recipe: FCT BD mung split 35 g (123 kcal, 8.3 g P) + 7 g oil/ghee
  Food('Mug dal', '1 bowl (~200 ml)', 185, 8, cat: 'curry/veg', bn: 'মুগ ডাল'),
  // Recipe: ~15 g lentil + 5 g oil; hotel dal is watery; uncertain
  Food('Dal (hotel/canteen)', '1 bati (~150 ml)', 95, 4, cat: 'curry/veg', bn: 'হোটেলের ডাল'),
  // FCT BD boiled veg ~40 kcal/100 g x 150 g + 10 g oil
  Food('Mixed sabji / bhaji', '1 cup (~150 g)', 150, 3, cat: 'curry/veg', bn: 'মিক্সড সবজি'),
  // FCT BD potato 67 kcal/100 g x 100 g + ~10 g oil absorbed
  Food('Alu bhaji (potato fry)', '1 cup (~120 g)', 165, 2, cat: 'curry/veg', bn: 'আলু ভাজি'),
  // FCT BD potato/cauliflower boiled ~50 kcal/100 g x 150 g + 8 g oil
  Food('Alu-phulkopi torkari', '1 cup (~150 g)', 145, 4, cat: 'curry/veg', bn: 'আলু-ফুলকপির তরকারি'),
  // USDA bottle gourd ~15-20 kcal/100 g x 150 g + 6 g oil
  Food('Lau torkari (bottle gourd)', '1 cup (~150 g)', 85, 1, cat: 'curry/veg', bn: 'লাউ তরকারি'),
  // FCT BD pumpkin boiled 29 kcal, 2.2 g P/100 g x 150 g + 7 g oil
  Food('Misti kumra bhaji', '1 cup (~150 g)', 107, 3, cat: 'curry/veg', bn: 'মিষ্টি কুমড়া ভাজি'),
  // FCT BD pointed gourd/brinjal boiled ~27 kcal/100 g x 150 g + 7 g oil
  Food('Potol / jhinga / begun torkari', '1 cup (~150 g)', 105, 3, cat: 'curry/veg', bn: 'পটল/ঝিঙা/বেগুন তরকারি'),
  // FCT BD amaranth/spinach boiled 30-47 kcal, 2-5 g P/100 g + 7 g oil
  Food('Shak bhaji (lal/palong/pui)', '1 cup cooked (~100 g)', 100, 4, cat: 'curry/veg', bn: 'শাক ভাজি'),
  // FCT BD lady's finger-tomato bhuna recipe 127 kcal, 3.4 g P/100 g
  Food('Dheros bhuna (okra)', '1 cup (~100 g)', 127, 3, cat: 'curry/veg', bn: 'ঢেঁড়স ভুনা'),
  // FCT BD bitter gourd fry recipe 130 kcal, 3.1 g P/100 g x 60 g
  Food('Korola bhaji (bitter gourd)', '1 small serving (~60 g)', 78, 2, cat: 'curry/veg', bn: 'করলা ভাজি'),
  // FCT BD brinjal 24 kcal/100 g x 50 g + ~8 g oil absorbed; soaks oil
  Food('Begun bhaja (home)', '1 slice (~50 g)', 90, 1, cat: 'curry/veg', bn: 'বেগুন ভাজা'),
  // FCT BD potato mash 84 kcal/100 g x 75 g + 5 g mustard oil
  Food('Alu bhorta', '1 scoop (~80 g)', 100, 1, cat: 'curry/veg', bn: 'আলু ভর্তা'),
  // FCT BD brinjal 24 kcal/100 g x 80 g + 5 g mustard oil
  Food('Begun bhorta', '1 scoop (~80 g)', 65, 2, cat: 'curry/veg', bn: 'বেগুন ভর্তা'),
  // FCT BD dried fish ~330 kcal, 60-70 g P/100 g x 15 g + 5 g oil + onion/chilli
  Food('Shutki bhorta', '1 scoop (~30 g)', 100, 9, cat: 'curry/veg', bn: 'শুঁটকি ভর্তা'),
  // FCT BD lentil raw 15 g + 5 g mustard oil
  Food('Dal bhorta', '1 scoop (~50 g)', 95, 4, cat: 'curry/veg', bn: 'ডাল ভর্তা'),
  // FCT BD small fish (kachki) fry recipe 107 kcal, 7.4 g P/100 g
  Food('Choto mach chorchori (small fish)', '1 serving (~100 g)', 107, 7, cat: 'curry/veg', bn: 'ছোট মাছের চচ্চড়ি'),
  // USDA cucumber/tomato/onion ~15-25 kcal/100 g
  Food('Salad (shosha-tomato-peyaj)', '1 plate (~100 g)', 20, 1, cat: 'curry/veg', bn: 'সালাদ'),

  // ---- breakfast ----
  // Sum: hotel paratha (260) + omelette/fried egg (~130)
  Food('Paratha + dim bhaji', '1 paratha + 1 egg', 390, 12, rare: true, cat: 'breakfast', bn: 'পরোটা-ডিম ভাজি'),
  // Sum: hotel paratha (260) + ~120 g oily bhaji (~120)
  Food('Paratha + sabji bhaji', '1 paratha + 1 bati bhaji', 380, 7, rare: true, cat: 'breakfast', bn: 'পরোটা-ভাজি'),
  // Sum: hotel paratha (260) + hotel dal (95)
  Food('Paratha + dal', '1 paratha + 1 bati dal', 355, 9, rare: true, cat: 'breakfast', bn: 'পরোটা-ডাল'),
  // Sum: 2 home ruti (196) + mixed sabji (150)
  Food('Ruti + sabji', '2 ruti + 1 cup sabji', 345, 9, cat: 'breakfast', bn: 'রুটি-সবজি'),
  // Sum: 2 home ruti (196) + thin masoor dal (125)
  Food('Ruti + dal', '2 ruti + 1 bowl dal', 320, 12, cat: 'breakfast', bn: 'রুটি-ডাল'),
  // FCT BD bread 2 x 25 g (136) + USDA jam 250 kcal/100 g x 20 g
  Food('Bread + jam', '2 slices + 1 tbsp jam', 186, 4, cat: 'breakfast', bn: 'পাউরুটি-জ্যাম'),
  // FCT BD bread 2 x 25 g + 1 egg fried in ~5 g oil
  Food('Bread + egg', '2 slices + 1 fried egg/omelette', 260, 12, cat: 'breakfast', bn: 'পাউরুটি-ডিম'),
  // FCT BD chira 356/100 g x 50 g + sweet curd 94/100 g x 100 g + date jaggery 352/100 g x 15 g
  Food('Chira-doi-gur', '1 bowl (50 g chira + 100 g doi + 15 g gur)', 330, 7, cat: 'breakfast', bn: 'চিড়া-দই-গুড়'),
  // Pack label ~375 kcal/100 g x 30 g + FCT BD whole milk 63/100 ml x 200 + 5 g sugar
  Food(
    'Cornflakes with milk',
    '1 bowl (30 g + 200 ml milk + 1 tsp sugar)',
    258,
    8,
    cat: 'breakfast',
    bn: 'দুধ দিয়ে কর্নফ্লেক্স',
  ),

  // ---- fast-food ----
  // Chain data: KFC Zinger ~450-480 kcal, ~24 g P
  Food('Chicken burger (fried patty)', '1 burger', 480, 24, rare: true, cat: 'fast-food', bn: 'চিকেন বার্গার'),
  // USDA/chain data single cheeseburger 500-650 kcal; Dhaka burgers often larger
  Food('Beef burger (cheese, restaurant)', '1 burger', 600, 30, rare: true, cat: 'fast-food', bn: 'বিফ বার্গার'),
  // USDA chicken/cheese pizza ~270 kcal, 12 g P/100 g
  Food('Pizza slice', '1 slice of 12-inch (~100 g)', 280, 12, rare: true, cat: 'fast-food', bn: 'পিজ্জা'),
  // KFC published data: original/crispy thigh ~280-290 kcal, ~19-21 g P
  Food(
    'Fried chicken piece (KFC-style)',
    '1 piece (thigh/drum avg)',
    280,
    20,
    rare: true,
    cat: 'fast-food',
    bn: 'ফ্রাইড চিকেন',
  ),
  // KFC/USDA fried wings ~80 kcal, ~4.5 g P each
  Food('Chicken wings (hot wings)', '6 pieces', 470, 28, rare: true, cat: 'fast-food', bn: 'চিকেন উইংস'),
  // McDonald's 6-pc nuggets ~250-270 kcal, ~14 g P
  Food('Chicken nuggets', '6 pieces', 270, 14, rare: true, cat: 'fast-food', bn: 'চিকেন নাগেটস'),
  // USDA/McDonald's medium fries ~320 kcal; Dhaka 'regular' ~110 g
  Food('French fries', '1 regular (~110 g)', 300, 4, rare: true, cat: 'fast-food', bn: 'ফ্রেঞ্চ ফ্রাই'),
  // Estimate: 2 slices bread (136) + chicken + mayo
  Food(
    'Chicken sandwich (café/bakery)',
    '1 sandwich (2 triangles)',
    300,
    14,
    rare: true,
    cat: 'fast-food',
    bn: 'চিকেন স্যান্ডউইচ',
  ),
  // Estimate: cream/cheese sauce pasta ~215 kcal/100 g; uncertain
  Food('Pasta (white-sauce chicken)', '1 plate (~300 g)', 650, 25, rare: true, cat: 'fast-food', bn: 'পাস্তা'),
  // Estimate: cornflour-thickened soup with chicken/prawn/egg
  Food('Thai soup', '1 bowl (~250 ml, per person)', 170, 10, cat: 'fast-food', bn: 'থাই স্যুপ'),
  // USDA chicken fried rice ~180 kcal, 5 g P/100 g x 300 g
  Food('Fried rice (Chinese restaurant)', '1 plate (~300 g)', 550, 14, rare: true, cat: 'fast-food', bn: 'ফ্রাইড রাইস'),
  // USDA chicken chow mein/lo mein ~175-185 kcal/100 g x 300 g
  Food('Chicken chowmein (restaurant)', '1 plate (~300 g)', 550, 20, rare: true, cat: 'fast-food', bn: 'চিকেন চাউমিন'),
  // Estimate: battered fried chicken in sauce; uncertain
  Food(
    'Chicken chilli / masala (Chinese)',
    '1 serving (~150 g)',
    350,
    22,
    rare: true,
    cat: 'fast-food',
    bn: 'চিকেন চিলি',
  ),

  // ---- sweet ----
  // IFCT/published rasgulla ~185-265 kcal/100 g incl. syrup; ~45 g piece
  Food('Roshogolla', '1 medium piece (~45 g)', 120, 2, rare: true, cat: 'sweet', bn: 'রসগোল্লা'),
  // Estimate: chhana + syrup ~290 kcal/100 g x 60 g
  Food('Chomchom', '1 piece (~60 g)', 175, 4, rare: true, cat: 'sweet', bn: 'চমচম'),
  // USDA/IFCT gulab jamun ~380 kcal/100 g x 50 g; fried + syrup
  Food('Kalojam / gulab jamun', '1 piece (~50 g)', 190, 3, rare: true, cat: 'sweet', bn: 'কালোজাম'),
  // Estimate: chhana + thickened sweet milk ~330 kcal/100 g x 60 g
  Food('Rosmalai', '1 piece with milk (~60 g)', 200, 5, rare: true, cat: 'sweet', bn: 'রসমালাই'),
  // IFCT/estimate sandesh ~370 kcal, 13 g P/100 g x 30 g
  Food('Sandesh', '1 piece (~30 g)', 110, 4, rare: true, cat: 'sweet', bn: 'সন্দেশ'),
  // FCT BD sweetened curd 94 kcal/100 g; adjusted up for sweeter commercial (Bogura-style) doi
  Food('Mishti doi', '1 small cup (~100 g)', 130, 4, rare: true, cat: 'sweet', bn: 'মিষ্টি দই'),
  // USDA/IFCT jalebi ~400 kcal/100 g x 30 g; iftar shahi jilapi much bigger
  Food('Jilapi', '1 medium piece (~30 g)', 120, 1, rare: true, cat: 'sweet', bn: 'জিলাপি'),
  // Estimate: rice-milk-sugar pudding ~165 kcal/100 g
  Food('Firni', '1 bowl (~120 g)', 200, 5, rare: true, cat: 'sweet', bn: 'ফিরনি'),
  // FCT BD payesh recipe 205 kcal, 4.3 g P/100 g x 120 g
  Food('Payesh', '1 small bowl (~120 g)', 246, 5, rare: true, cat: 'sweet', bn: 'পায়েস'),
  // FCT BD vermicelli + whole milk + sugar + ghee; estimate ~210/100 g
  Food('Shemai (sweet vermicelli)', '1 bowl (~120 g)', 250, 6, rare: true, cat: 'sweet', bn: 'সেমাই'),
  // Estimate: FCT BD semolina + ghee + sugar ~330 kcal/100 g
  Food('Suji halua', '1 serving (~60 g)', 200, 2, rare: true, cat: 'sweet', bn: 'সুজির হালুয়া'),
  // Estimate: rice flour + gur + coconut ~230 kcal/100 g
  Food('Bhapa pitha', '1 piece (~70 g)', 160, 2, rare: true, cat: 'sweet', bn: 'ভাপা পিঠা'),
  // Estimate: steamed rice-flour cake ~190 kcal/100 g; add gur/curry separately
  Food('Chitoi pitha (plain)', '1 piece (~50 g)', 95, 2, cat: 'sweet', bn: 'চিতই পিঠা'),
  // Estimate: crepe with kheer/coconut-gur filling ~260 kcal/100 g
  Food('Patishapta', '1 piece (~60 g)', 155, 3, rare: true, cat: 'sweet', bn: 'পাটিসাপটা'),
  // IFCT/USDA boondi laddu ~450 kcal/100 g x 40 g
  Food('Laddu (boondi)', '1 piece (~40 g)', 180, 3, rare: true, cat: 'sweet', bn: 'লাড্ডু'),
  // USDA vanilla ice cream ~200 kcal/100 g x 60 g
  Food('Ice cream', '1 cup (~100 ml, ~60 g)', 120, 2, rare: true, cat: 'sweet', bn: 'আইসক্রিম'),
  // Label: milk chocolate ~535 kcal/100 g x 25 g
  Food('Chocolate bar (small)', '1 small bar (~25 g)', 135, 2, rare: true, cat: 'sweet', bn: 'চকলেট'),

  // ---- drink ----
  // Estimate: ~12 g condensed milk (FCT BD 334/100 g) + 1 tsp sugar; FCT BD dudh cha 41/100 ml is home-style
  Food('Dudh cha (tong, condensed milk)', '1 cup (~100 ml)', 70, 2, cat: 'drink', bn: 'দুধ চা (টং)'),
  // FCT BD tea with sugar & milk powder 41 kcal, 0.7 g P/100 ml x 150 ml
  Food('Dudh cha (home)', '1 cup (~150 ml)', 62, 1, cat: 'drink', bn: 'দুধ চা'),
  // FCT BD liquor tea with sugar 29 kcal/100 ml x 120 ml
  Food('Rong cha with sugar', '1 cup (~120 ml)', 35, 0, cat: 'drink', bn: 'রং চা (চিনি সহ)'),
  // USDA brewed tea ~1 kcal/100 ml
  Food('Black tea, no sugar', '1 cup', 2, 0, cat: 'drink', bn: 'রং চা (চিনি ছাড়া)'),
  // FCT BD coffee with sugar & milk powder 38 kcal, 0.9 g P/100 ml x 150 ml
  Food('Coffee (instant, milk & sugar)', '1 cup (~150 ml)', 57, 1, cat: 'drink', bn: 'কফি'),
  // Chain data: whole-milk 12 oz latte ~180 kcal; add ~20 per sugar sachet
  Food('Cappuccino / latte (café)', '1 regular cup (~300 ml)', 180, 8, cat: 'drink', bn: 'ক্যাপুচিনো / লাতে'),
  // Estimate: milk + sugar syrup + ice cream scoop
  Food('Cold coffee (café, with ice cream)', '1 glass (~350 ml)', 350, 8, rare: true, cat: 'drink', bn: 'কোল্ড কফি'),
  // Recipe: FCT BD curd ~200 g + ~30 g sugar
  Food('Lassi (sweet)', '1 glass (~300 ml)', 260, 7, rare: true, cat: 'drink', bn: 'লাচ্ছি'),
  // Recipe: ~150 g yogurt + ~15 g sugar + spices; sweetness varies
  Food('Borhani', '1 glass (~250 ml)', 130, 5, cat: 'drink', bn: 'বোরহানি'),
  // FCT BD buttermilk low fat 33 kcal, 3.4 g P/100 ml x 250 ml; bottled may add sugar
  Food('Matha / ghol (buttermilk)', '1 glass (~250 ml)', 83, 8, cat: 'drink', bn: 'মাঠা'),
  // FCT BD cow milk whole 63 kcal, 3.1 g P/100 ml x 250 ml
  Food('Milk (full cream)', '1 glass (~250 ml)', 158, 8, cat: 'drink', bn: 'দুধ'),
  // FCT BD skimmed milk 30 kcal/100 ml; USDA 1% milk ~42; midpoint
  Food('Milk (low fat/skimmed)', '1 glass (~250 ml)', 85, 8, cat: 'drink', bn: 'লো-ফ্যাট দুধ'),
  // FCT BD lists 33 kcal/100 g (likely diluted); fresh juice ~70/100 ml; street with ice ~60/100 ml; UNCERTAIN
  Food('Akher ros (sugarcane juice)', '1 glass (~250 ml)', 150, 0, rare: true, cat: 'drink', bn: 'আখের রস'),
  // USDA orange juice 45 kcal/100 ml x 300 + ~10 g sugar added by juice bars
  Food('Fresh juice (malta/orange, with sugar)', '1 glass (~300 ml)', 180, 2, rare: true, cat: 'drink', bn: 'ফলের রস'),
  // ~20 g sugar (FCT BD 398 kcal/100 g); without sugar ~5 kcal
  Food(
    'Lebur shorbot (lemon water with sugar)',
    '1 glass (~250 ml)',
    80,
    0,
    rare: true,
    cat: 'drink',
    bn: 'লেবুর শরবত',
  ),
  // Labels (Pran/Frutika-type) ~55-60 kcal/100 ml
  Food('Packaged mango/fruit drink', '1 pack (250 ml)', 145, 0, rare: true, cat: 'drink', bn: 'প্যাকেট জুস'),
  // Labels ~42 kcal/100 ml (10.6 g sugar)
  Food(
    'Soft drink (Coke/Pepsi/Sprite/Mojo)',
    '1 can/bottle (250 ml)',
    105,
    0,
    rare: true,
    cat: 'drink',
    bn: 'কোমল পানীয়',
  ),
  // Labels ~42 kcal/100 ml x 500 ml
  Food('Soft drink, large', '1 bottle (500 ml)', 210, 0, rare: true, cat: 'drink', bn: 'কোমল পানীয় (বড়)'),
  // Labels ~45-48 kcal/100 ml (sugar ~11-12 g/100 ml); verify local label
  Food('Energy drink (Speed/Tiger)', '1 can/bottle (250 ml)', 115, 0, rare: true, cat: 'drink', bn: 'এনার্জি ড্রিংক'),
  // USDA/chain data milkshake ~120-130 kcal/100 ml
  Food('Milkshake', '1 glass (~350 ml)', 450, 10, rare: true, cat: 'drink', bn: 'মিল্কশেক'),
  // FCT BD coconut water 20 kcal, 0.6 g P/100 ml x 300 ml
  Food('Daber pani (coconut water)', '1 dab (~300 ml)', 60, 2, cat: 'drink', bn: 'ডাবের পানি'),

  // ---- fruit ----
  // FCT BD banana Sagar ripe 95 kcal, 1.3 g P/100 g
  Food('Sagor kola (banana)', '1 medium (~100 g edible)', 95, 1, cat: 'fruit', bn: 'সাগর কলা'),
  // FCT BD banana ~95 kcal/100 g x 70 g (no separate Chompa entry)
  Food('Chompa / deshi kola (small banana)', '1 small (~70 g edible)', 65, 1, cat: 'fruit', bn: 'চাঁপা কলা'),
  // FCT BD guava 63 kcal, 1.0 g P/100 g x 150 g
  Food('Peyara (guava)', '1 medium (~150 g)', 95, 2, cat: 'fruit', bn: 'পেয়ারা'),
  // FCT BD apple with skin 62 kcal/100 g x 150 g
  Food('Apple', '1 medium (~150 g)', 93, 0, cat: 'fruit', bn: 'আপেল'),
  // FCT BD Langra 82 kcal/100 g x 200 g; Fazli 70/100 g but bigger fruit
  Food('Mango (aam)', '1 medium (~200 g edible)', 164, 2, cat: 'fruit', bn: 'আম'),
  // FCT BD ripe papaya 33 kcal, 0.6 g P/100 g x 150 g
  Food('Papaya (pepe)', '1 plate/cup (~150 g)', 50, 1, cat: 'fruit', bn: 'পেঁপে'),
  // FCT BD pineapple 47 kcal, 1.0 g P/100 g x 150 g
  Food('Pineapple (anaros)', '1 cup pieces (~150 g)', 70, 2, cat: 'fruit', bn: 'আনারস'),
  // FCT BD orange 44 kcal, 0.7 g P/100 g x 130 g
  Food('Orange (komola)', '1 medium (~130 g edible)', 57, 1, cat: 'fruit', bn: 'কমলা'),
  // FCT BD sweet orange (malta) 49 kcal/100 g x 150 g
  Food('Malta', '1 medium (~150 g edible)', 74, 0, cat: 'fruit', bn: 'মাল্টা'),
  // FCT BD watermelon 22 kcal, 0.5 g P/100 g x 300 g
  Food('Watermelon (tormuj)', '1 plate (~300 g)', 66, 2, cat: 'fruit', bn: 'তরমুজ'),
  // FCT BD ripe jackfruit 74 kcal, 1.2 g P/100 g x 150 g
  Food('Jackfruit (kathal)', '10 koa / bulbs (~150 g)', 111, 2, cat: 'fruit', bn: 'কাঁঠাল'),
  // FCT BD dates dried 301 kcal/100 g x 8 g; Medjool ~20 g = 60 kcal
  Food('Dates (khejur, dried)', '1 piece (~8 g)', 24, 0, cat: 'fruit', bn: 'খেজুর'),
  // USDA litchi raw 66 kcal, 0.8 g P/100 g
  Food('Litchi', '10 pieces (~100 g edible)', 66, 1, cat: 'fruit', bn: 'লিচু'),
  // USDA grapes 69 kcal, 0.7 g P/100 g
  Food('Grapes (angur)', '1 cup (~100 g)', 69, 1, cat: 'fruit', bn: 'আঙুর'),
];
