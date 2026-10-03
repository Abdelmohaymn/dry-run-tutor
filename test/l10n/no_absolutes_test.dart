// FR-030 / Principle IV: nothing the app authors ever tells a learner they
// were "correct" or "wrong". A verdict is always hedged, and a rate limit,
// a spent taster, or a reached turn cap are none of them a judgement on
// the learner. Cheaper to hold the whole ARB file to this bar than to
// scope the check to verdict copy alone (contracts/error-copy.md).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app_en.arb contains neither "correct" nor "wrong"', () {
    final File arb = File('lib/l10n/app_en.arb');
    expect(arb.existsSync(), isTrue, reason: 'lib/l10n/app_en.arb must exist');

    final Map<String, Object?> entries =
        jsonDecode(arb.readAsStringSync()) as Map<String, Object?>;

    for (final MapEntry<String, Object?> entry in entries.entries) {
      if (entry.key.startsWith('@')) {
        continue; // ARB metadata blocks, not learner-facing strings.
      }
      final Object? value = entry.value;
      if (value is! String) {
        continue;
      }
      final String lower = value.toLowerCase();
      expect(
        lower.contains('correct'),
        isFalse,
        reason: '${entry.key} contains "correct": "$value"',
      );
      expect(
        lower.contains('wrong'),
        isFalse,
        reason: '${entry.key} contains "wrong": "$value"',
      );
    }
  });
}
