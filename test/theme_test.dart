import 'dart:math' as math;

import 'package:daur/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  for (final brightness in Brightness.values) {
    test('$brightness: readable text, actions and essential boundaries', () {
      final t = brightness == Brightness.light ? Daur.light : Daur.dark;
      for (final surface in [t.ground, t.infield, t.sheet]) {
        expect(contrast(t.ink, surface), greaterThanOrEqualTo(4.5));
        expect(contrast(t.ink2, surface), greaterThanOrEqualTo(4.5));
        expect(contrast(t.accent, surface), greaterThanOrEqualTo(4.5));
        expect(contrast(t.lane, surface), greaterThanOrEqualTo(3));
        expect(contrast(t.error, surface), greaterThanOrEqualTo(4.5));
      }
      expect(contrast(t.onAccent, t.accent), greaterThanOrEqualTo(4.5));
      final scheme = buildTheme(brightness).colorScheme;
      expect(scheme.primary, t.accent);
      expect(scheme.onPrimary, t.onAccent);
      expect(scheme.surface, t.ground);
      expect(scheme.error, t.error);
    });
  }
}
