// Constraint copy is the one place in the app where a number is the whole
// message. `1000000000` is read digit by digit and says nothing; `10⁹`
// says the only thing the constraint is there to say. The rewrite has to
// be exact, and — just as importantly — has to leave alone every number
// that is not an order of magnitude: a LeetCode reference, a date, a
// problem id, an array literal in a worked example.
import 'package:dry_run/core/text/math_notation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('comparisons', () {
    test('ASCII comparisons become their typeset forms', () {
      expect(MathNotation.format('2 <= n <= 100'), '2 ≤ n ≤ 100');
      expect(MathNotation.format('n >= 1'), 'n ≥ 1');
      expect(MathNotation.format('a != b'), 'a ≠ b');
    });
  });

  group('carets', () {
    test('an authored caret becomes a superscript', () {
      expect(MathNotation.format('10^9'), '10⁹');
      expect(MathNotation.format('2^31 - 1'), '2³¹ - 1');
    });

    test('a parenthesised exponent keeps its closing paren', () {
      expect(MathNotation.format('O(n^2) time'), 'O(n²) time');
    });

    test('negative exponents keep their sign', () {
      expect(MathNotation.format('10^-3'), '10⁻³');
    });
  });

  group('long digit runs', () {
    test('an exact power of ten collapses', () {
      expect(MathNotation.format('1000000000 elements'), '10⁹ elements');
      expect(MathNotation.format('up to 100000'), 'up to 10⁵');
    });

    test('a leading digit with trailing zeros keeps its mantissa', () {
      expect(MathNotation.format('20000'), '2 × 10⁴');
    });

    test('a number that is not an order of magnitude is left alone', () {
      // A LeetCode reference, a date, a problem id, and a plain count.
      expect(
        MathNotation.format('LeetCode 2108 on 2026-09-04, id vp-0001'),
        'LeetCode 2108 on 2026-09-04, id vp-0001',
      );
      expect(MathNotation.format('2500 words'), '2500 words');
      expect(MathNotation.format('up to 100 words'), 'up to 100 words');
    });

    test('an example’s array literal survives untouched', () {
      expect(
        MathNotation.format('nums = [2, 7, 11, 15], target = 9'),
        'nums = [2, 7, 11, 15], target = 9',
      );
    });
  });

  group('spelled and scientific magnitudes', () {
    test('a spelled magnitude is normalised, not just superscripted', () {
      // 10 million is 10⁷, not 10 × 10⁶.
      expect(MathNotation.format('up to 10 million numbers'), 'up to 10⁷ numbers');
    });

    test('a word numeral carries its mantissa through', () {
      expect(
        MathNotation.format('as large as about two billion (32-bit)'),
        'as large as about 2 × 10⁹ (32-bit)',
      );
    });

    test('e-notation collapses the same way', () {
      expect(MathNotation.format('1 <= n <= 1e5'), '1 ≤ n ≤ 10⁵');
      expect(MathNotation.format('3e4'), '3 × 10⁴');
    });

    test('below 10^3 nothing is rewritten — plain digits read fine', () {
      expect(MathNotation.format('100'), '100');
    });
  });
}
