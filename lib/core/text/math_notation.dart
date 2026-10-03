/// Renders authored numeric copy the way a problem set does: `10⁹`, not
/// `1000000000`, and `≤` rather than `<=`.
///
/// Constraint and example text is authored as prose (the statement is
/// spoken aloud, so it stays prose deliberately) — but a bare
/// `10000000` in a constraint is read digit by digit and tells a learner
/// nothing about the order of magnitude, which is the only thing that
/// constraint is there to say. This is a *display* transform: nothing
/// here rewrites what is stored, sent, or judged.
///
/// It is deliberately conservative. A number is only rewritten when the
/// rewrite is exact — a leading run of digits followed by at least three
/// zeros, an `e`-notation literal, or a spelled magnitude. `2108`,
/// `2026-09-04` and `vp-0001` are left exactly as authored.
abstract final class MathNotation {
  /// Unicode superscripts, so the result is a plain [String] that renders
  /// in any `Text` — no `RichText`, no per-call-site baseline maths.
  static const Map<String, String> _superscripts = <String, String>{
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
    '-': '⁻',
    '+': '⁺',
    'n': 'ⁿ',
    'i': 'ⁱ',
  };

  static const Map<String, int> _wordNumbers = <String, int>{
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'fifteen': 15,
    'twenty': 20,
    'fifty': 50,
    'hundred': 100,
  };

  static const Map<String, int> _magnitudes = <String, int>{
    'thousand': 3,
    'million': 6,
    'billion': 9,
    'trillion': 12,
  };

  static final RegExp _spelledMagnitude = RegExp(
    r'\b(\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|fifteen|twenty|fifty|hundred)'
    r'\s+(thousand|million|billion|trillion)\b',
    caseSensitive: false,
  );

  static final RegExp _scientific = RegExp(r'\b(\d+(?:\.\d+)?)[eE]\+?(\d+)\b');

  static final RegExp _longRun = RegExp(r'\b\d{4,}\b');

  /// `10^9`, `n^2`, `O(n^2)` — an authored caret, whatever it sits on.
  /// The parenthesised form is a separate alternative rather than an
  /// optional `\)?`, which would otherwise eat the closing paren of
  /// `O(n^2)` and leave it unbalanced.
  static final RegExp _caret = RegExp(r'\^\((-?\d+|[nkmij])\)|\^(-?\d+|[nkmij])');

  /// The whole transform, in the order the rewrites must not undo each
  /// other: comparisons first (they carry no digits), then the three
  /// number forms, then any caret the author wrote by hand.
  static String format(String source) {
    String out = source
        .replaceAll('<=', '≤')
        .replaceAll('>=', '≥')
        .replaceAll('!=', '≠');

    out = out.replaceAllMapped(_spelledMagnitude, (Match m) {
      final String head = m[1]!;
      final int exponent = _magnitudes[m[2]!.toLowerCase()]!;
      final double? mantissa = double.tryParse(head) ??
          _wordNumbers[head.toLowerCase()]?.toDouble();
      if (mantissa == null) {
        return m[0]!;
      }
      return _render(mantissa, exponent) ?? m[0]!;
    });

    out = out.replaceAllMapped(_scientific, (Match m) {
      final double? mantissa = double.tryParse(m[1]!);
      final int? exponent = int.tryParse(m[2]!);
      if (mantissa == null || exponent == null) {
        return m[0]!;
      }
      return _render(mantissa, exponent) ?? m[0]!;
    });

    out = out.replaceAllMapped(_longRun, (Match m) {
      final String digits = m[0]!;
      // A leading run followed by three or more zeros, and nothing else —
      // anything looser would rewrite a year or an ordinal.
      final Match? split = RegExp(r'^([1-9]\d*?)(0{3,})$').firstMatch(digits);
      if (split == null) {
        return digits;
      }
      final double? mantissa = double.tryParse(split[1]!);
      if (mantissa == null) {
        return digits;
      }
      return _render(mantissa, split[2]!.length) ?? digits;
    });

    return out.replaceAllMapped(_caret, (Match m) => superscript(m[1] ?? m[2]!));
  }

  /// `10⁹` when the mantissa is 1 after normalising, `2 × 10⁹` otherwise.
  /// Returns null below `10³`, where plain digits already read fine —
  /// nobody writes `10²` for a hundred.
  static String? _render(double mantissa, int exponent) {
    double m = mantissa;
    int e = exponent;
    // 10 million is 10⁷, not 10 × 10⁶.
    while (m >= 10 && m % 10 == 0) {
      m /= 10;
      e += 1;
    }
    if (e < 3) {
      return null;
    }
    final String power = '10${superscript('$e')}';
    if (m == 1) {
      return power;
    }
    final String head = m == m.roundToDouble() ? '${m.round()}' : '$m';
    return '$head × $power';
  }

  /// The digits of [value] as Unicode superscripts, unchanged where there
  /// is no superscript form for a character.
  static String superscript(String value) {
    final StringBuffer buffer = StringBuffer();
    for (final String char in value.split('')) {
      buffer.write(_superscripts[char] ?? char);
    }
    return buffer.toString();
  }
}
