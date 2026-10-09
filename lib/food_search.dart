// Food search that understands how people in Dhaka actually type: English or Banglish for the
// same food (milk tea = dudh cha, rice = bhat), any Banglish spelling (bhat = vat = bhaat,
// porota = paratha) and small typos (chiken, paratah). Runs on the phone; no AI.

import 'food_words.dart';

/// Hand-picked words that mean the same food (checked first). The first is the canonical form.
const synonyms = <List<String>>[
  ['dudh cha', 'milk tea', 'tea with milk', 'milk cha', 'chai'],
  ['rong cha', 'red tea', 'tea with sugar'],
  ['cha', 'tea'],
  ['bhat', 'rice', 'vat'],
  ['dim', 'egg', 'eggs', 'anda', 'dimer'],
  ['mach', 'fish'],
  ['murgi', 'chicken', 'murg', 'morog'],
  ['gorur mangsho', 'beef', 'gorur', 'goru'],
  ['khasi', 'mutton', 'goat'],
  ['dal', 'lentil', 'lentils', 'dhal'],
  ['ruti', 'roti', 'chapati'],
  ['sabji', 'vegetable', 'vegetables', 'veg', 'torkari'],
  ['bhorta', 'mashed', 'mash'],
  ['bhaji', 'fry', 'fried', 'bhaja'],
  ['shak', 'spinach', 'greens', 'saag'],
  ['doi', 'yogurt', 'yoghurt', 'curd', 'dahi'],
  ['mishti', 'sweet', 'sweets', 'dessert'],
  ['muri', 'puffed rice'],
  ['chira', 'flattened rice', 'poha'],
  ['alu', 'potato', 'potatoes'],
  ['begun', 'eggplant', 'brinjal', 'aubergine'],
  ['lau', 'bottle gourd'],
  ['potol', 'pointed gourd'],
  ['kumra', 'pumpkin'],
  ['phulkopi', 'cauliflower'],
  ['badhakopi', 'cabbage'],
  ['chola', 'chickpea', 'chickpeas', 'chana', 'boot'],
  ['chingri', 'shrimp', 'prawn', 'prawns'],
  ['ilish', 'hilsa'],
  ['kola', 'banana', 'bananas'],
  ['aam', 'mango', 'mangoes'],
  ['kathal', 'jackfruit'],
  ['peyara', 'guava'],
  ['komola', 'orange', 'oranges'],
  ['narkel', 'coconut'],
  ['dudh', 'milk'],
  ['pani', 'water'],
  ['tormuj', 'watermelon'],
  ['anaros', 'pineapple'],
  ['angur', 'grapes', 'grape'],
  ['khejur', 'dates'],
  ['badam', 'peanut', 'peanuts', 'nuts'],
  ['khichuri', 'khichdi'],
  ['polao', 'pulao', 'pilaf'],
  ['jilapi', 'jalebi'],
  ['roshogolla', 'rasgulla'],
  ['halua', 'halwa'],
  ['shemai', 'vermicelli'],
  ['kabab', 'kebab'],
  ['fuchka', 'puchka', 'panipuri', 'golgappa'],
  ['pauruti', 'bread'],
];

/// One-way kinds: searching the kind finds its members, never the reverse ("fish" finds rui;
/// "rui" doesn't find ilish). Keys are canonical words of groups above.
const kinds = <String, List<String>>{
  'mach': [
    'rui',
    'katla',
    'mrigel',
    'ilish',
    'pangas',
    'tilapia',
    'telapia',
    'koi',
    'pabda',
    'shing',
    'magur',
    'boal',
    'chitol',
    'tengra',
    'puti',
    'mola',
    'kachki',
    'loitta',
    'rupchanda',
    'chingri',
    'shutki',
    'bhetki',
  ],
  'mangsho': ['murgi', 'chicken', 'gorur', 'beef', 'khasi', 'mutton', 'hash', 'duck', 'kabab', 'chap', 'kima'],
  'mishti': [
    'roshogolla',
    'chomchom',
    'kalojam',
    'rosmalai',
    'sandesh',
    'mishti doi',
    'jilapi',
    'laddu',
    'payesh',
    'firni',
    'shemai',
    'halua',
    'pitha',
  ],
  'fol': [
    'kola',
    'banana',
    'aam',
    'mango',
    'peyara',
    'guava',
    'apple',
    'pepe',
    'papaya',
    'anaros',
    'komola',
    'malta',
    'tormuj',
    'kathal',
    'khejur',
    'litchi',
    'angur',
  ],
};

const _stop = {'and', 'with', 'a', 'an', 'the', 'of', 'some', 'ate', 'had', 'plus', 'or', 'in'};

/// One spelling for every Banglish spelling: bhat = vat = bhaat, porota = paratha,
/// biriyani = biryani, phulkopi = fulkopi. Plurals drop their s.
String soundKey(String word) {
  var w = word.toLowerCase();
  w = w.replaceAll('ph', 'f').replaceAll('v', 'b').replaceAll('z', 'j').replaceAll('q', 'k').replaceAll('w', 'o');
  w = w.replaceAllMapped(RegExp(r'([bcdgjkpst])h'), (m) => m[1]!); // bh→b, ch→c, sh→s, th→t…
  w = w.replaceAll('ee', 'i').replaceAll('oo', 'u').replaceAll('y', 'i').replaceAll('o', 'a');
  w = w.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!); // bhaat → bat
  if (w.length > 3 && w.endsWith('s')) w = w.substring(0, w.length - 1);
  return w;
}

List<String> _words(String text) =>
    text.toLowerCase().split(RegExp(r'[^a-z0-9ঀ-৿]+')).where((w) => w.isNotEmpty && !_stop.contains(w)).toList();

/// Every word group: the hand-picked ones above, then the researched vocabulary (food_words.dart).
final List<List<String>> _groups = [...synonyms, ...foodWordGroups];

/// phrase → the groups it belongs to (a phrase can mean more than one thing: kola, jam, dim).
final Map<String, List<int>> _index = () {
  final m = <String, List<int>>{};
  for (final (i, g) in _groups.indexed) {
    for (final p in g) {
      (m[_words(p).join(' ')] ??= []).add(i);
    }
  }
  return m;
}();

/// The query in units: the longest known phrase at each point ("milk tea", not "milk" + "tea"),
/// each with every way of saying it, and its head (last) word's ways too, because in both
/// Bangla and English the food comes last: "golda chingri" is a chingri, "lal shak" is shak.
List<(List<String>, List<String>)> _units(String text) {
  final w = _words(text).where((x) => !RegExp(r'^\d+$').hasMatch(x)).toList();
  final out = <(List<String>, List<String>)>[];
  List<String> waysOf(String word) => {word, for (final g in _index[word] ?? const <int>[]) ..._groups[g]}.toList();
  for (var i = 0; i < w.length;) {
    var took = 1;
    List<int>? groups;
    for (var n = 4; n >= 1; n--) {
      if (i + n > w.length) continue;
      final g = _index[w.sublist(i, i + n).join(' ')];
      if (g != null) {
        groups = g;
        took = n;
        break;
      }
    }
    final phrase = w.sublist(i, i + took).join(' ');
    final ways = {phrase, for (final g in groups ?? const <int>[]) ..._groups[g]};
    out.add((
      {...ways, for (final k in ways) ...?kinds[k]}.toList(),
      took > 1 ? waysOf(w[i + took - 1]) : const <String>[],
    ));
    i += took;
  }
  return out;
}

/// The key saved AI estimates are filed under: every phrase in its canonical form, spellings
/// evened out; amounts and order still count. "2 milk tea" and "2 dudh cha" → "2 dud ca".
String canonicalKey(String text) {
  final out = <String>[];
  final w = _words(text);
  for (var i = 0; i < w.length;) {
    var took = 1;
    String? canon;
    for (var n = 4; n >= 1; n--) {
      if (i + n > w.length) continue;
      final g = _index[w.sublist(i, i + n).join(' ')];
      if (g != null) {
        canon = _groups[g.first].first;
        took = n;
        break;
      }
    }
    out.addAll((canon ?? w.sublist(i, i + took).join(' ')).split(' ').map(soundKey));
    i += took;
  }
  return out.join(' ');
}

/// Edit distance with swapped neighbours counted as one (paratah → paratha).
int _distance(String a, String b) {
  final d = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var v = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost].reduce((x, y) => x < y ? x : y);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] && d[i - 2][j - 2] + 1 < v) {
        v = d[i - 2][j - 2] + 1;
      }
      d[i][j] = v;
    }
  }
  return d[a.length][b.length];
}

/// A query word fits a name word: the start of it (chick → chicken), or within a typo or two.
bool _fits(String q, String n) {
  if (q.length <= 2) return q == n; // "ca" (cha) must not find "cafi" (coffee)
  if (n.startsWith(q)) return true;
  if (q.length < 4) return false; // short words must be exact; "dal" mustn't match "dam"
  final allowed = q.length >= 7 ? 2 : 1;
  final cut = n.length > q.length + allowed ? n.substring(0, q.length + allowed) : n; // prefix typos too
  return _distance(q, n) <= allowed || _distance(q, cut) <= allowed;
}

/// Does [query] find the food called [name] (Bangla name [bn])? Every part of the query must fit
/// the name in one of its meanings: each word of that meaning fits some word of the name, after
/// spellings are evened out on both sides and a typo or two is forgiven.
bool foodMatches(String name, String bn, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (bn.isNotEmpty && bn.contains(q)) return true; // Bangla script, as typed
  if (name.toLowerCase().contains(q)) return true;
  final units = _units(q);
  if (units.isEmpty) return false;
  final nameWords = _words(name).map(soundKey).toSet();
  bool fitsName(String phrase) {
    final ws = _words(phrase).map(soundKey).toList();
    return ws.isNotEmpty && ws.every((w) => nameWords.any((n) => _fits(w, n)));
  }

  return units.every((u) => u.$1.any(fitsName) || u.$2.any(fitsName));
}
