import 'package:flutter/widgets.dart';

/// Colour and type tokens transcribed verbatim from
/// `specs/002-voice-tutor-app/contracts/design-tokens.md`, itself lifted
/// from `docs/ui-prototype.html`. A hex that differs from the prototype is a
/// bug — do not "improve" a value here without updating both sources.
abstract final class AppTokens {
  // --- Colour --------------------------------------------------------

  /// Page ground, behind everything.
  static const Color bg = Color(0xFF0A0C10);

  /// Cards, the problem card, the composer.
  static const Color surface = Color(0xFF0D1117);

  /// Raised: message bubbles, chips.
  static const Color surface2 = Color(0xFF161B22);

  /// Highest: the learner's own turn.
  static const Color surface3 = Color(0xFF1C2230);

  /// Default hairline.
  static const Color border = Color(0xFF21262D);

  /// Emphasised hairline, focus.
  static const Color border2 = Color(0xFF30363D);

  /// Primary text.
  static const Color text = Color(0xFFE6EDF3);

  /// Secondary text, labels.
  static const Color muted = Color(0xFF8B949E);

  /// Tertiary text, "or type instead".
  static const Color faint = Color(0xFF6E7681);

  /// The one accent. Mic, primary action, insight hit.
  static const Color accent = Color(0xFF3FB950);

  /// Accent fill, 14% alpha.
  static const Color accentDim = Color(0x243FB950);

  /// Accent outline, 35% alpha.
  static const Color accentBorder = Color(0x593FB950);

  /// Wrap-up nudge, the 15-second warning, hedged-borderline.
  static const Color amber = Color(0xFFD29922);

  /// Amber fill, 12% alpha.
  static const Color amberDim = Color(0x1FD29922);

  /// Amber outline, 30% alpha.
  static const Color amberBorder = Color(0x4DD29922);

  /// Reserved. Failed send and destructive confirmation ONLY. See
  /// design-tokens.md — most of what could reach for red is not an error.
  static const Color red = Color(0xFFF85149);

  /// Red fill, 12% alpha.
  static const Color redDim = Color(0x1FF85149);

  /// Links, the language-pack route, informational.
  static const Color blue = Color(0xFF58A6FF);

  /// Blue fill, 12% alpha.
  static const Color blueDim = Color(0x1F58A6FF);

  // --- Type ------------------------------------------------------------

  /// Anything numeric or systemic: turn gauge, timer, hint counter,
  /// complexity, streak count, problem id, constraints.
  static const List<String> monoFontFamilyFallback = <String>[
    'JetBrains Mono',
    'SF Mono',
    'Menlo',
    'Consolas',
    'monospace',
  ];

  /// Prose: statement, conversation, feedback, editorial, every
  /// explanatory line. Resolves to Roboto on Android.
  static const List<String> sansFontFamilyFallback = <String>[
    'Roboto',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'sans-serif',
  ];
}
