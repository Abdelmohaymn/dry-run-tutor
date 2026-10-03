import 'package:flutter/material.dart';

import 'tokens.dart';

/// The mono/sans split as named, reusable text styles.
///
/// The prototype's rule holds without exception: monospace means "this is a
/// number the system is telling you" (turn gauge, timer, hint counter,
/// complexity, streak count, problem id, constraints), sans means "this is
/// something someone wrote" (statement, conversation, feedback, editorial).
/// Exposing the split as named styles on a [ThemeExtension] — rather than as
/// bare `TextStyle(fontFamily: ...)` calls scattered through widgets — is
/// what makes the boundary enforceable at call sites: reach for
/// `context.appTypography.monoLabel`, never for a raw font family.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.monoDisplay,
    required this.monoBody,
    required this.monoLabel,
    required this.monoCaption,
    required this.sansHeadline,
    required this.sansBody,
    required this.sansCaption,
  });

  /// Large systemic numbers: the turn gauge, the recording timer.
  final TextStyle monoDisplay;

  /// Body-sized systemic text: complexity annotations, problem ids.
  final TextStyle monoBody;

  /// Small systemic labels: section kickers, chip text, the "who" label.
  final TextStyle monoLabel;

  /// The smallest systemic text: captions, hints under a mono value.
  final TextStyle monoCaption;

  /// Prose headings.
  final TextStyle sansHeadline;

  /// Prose body: conversation, statement, feedback, editorial.
  final TextStyle sansBody;

  /// Prose captions: secondary explanatory lines.
  final TextStyle sansCaption;

  @override
  AppTypography copyWith({
    TextStyle? monoDisplay,
    TextStyle? monoBody,
    TextStyle? monoLabel,
    TextStyle? monoCaption,
    TextStyle? sansHeadline,
    TextStyle? sansBody,
    TextStyle? sansCaption,
  }) {
    return AppTypography(
      monoDisplay: monoDisplay ?? this.monoDisplay,
      monoBody: monoBody ?? this.monoBody,
      monoLabel: monoLabel ?? this.monoLabel,
      monoCaption: monoCaption ?? this.monoCaption,
      sansHeadline: sansHeadline ?? this.sansHeadline,
      sansBody: sansBody ?? this.sansBody,
      sansCaption: sansCaption ?? this.sansCaption,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) {
      return this;
    }
    return AppTypography(
      monoDisplay: TextStyle.lerp(monoDisplay, other.monoDisplay, t)!,
      monoBody: TextStyle.lerp(monoBody, other.monoBody, t)!,
      monoLabel: TextStyle.lerp(monoLabel, other.monoLabel, t)!,
      monoCaption: TextStyle.lerp(monoCaption, other.monoCaption, t)!,
      sansHeadline: TextStyle.lerp(sansHeadline, other.sansHeadline, t)!,
      sansBody: TextStyle.lerp(sansBody, other.sansBody, t)!,
      sansCaption: TextStyle.lerp(sansCaption, other.sansCaption, t)!,
    );
  }
}

/// Convenience accessor: `context.appTypography.monoLabel`.
extension AppTypographyContext on BuildContext {
  AppTypography get appTypography =>
      Theme.of(this).extension<AppTypography>()!;
}

const String _monoFamily = 'JetBrains Mono';
const String _sansFamily = 'Roboto';

final AppTypography _appTypography = AppTypography(
  monoDisplay: const TextStyle(
    fontFamily: _monoFamily,
    fontFamilyFallback: AppTokens.monoFontFamilyFallback,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppTokens.text,
  ),
  monoBody: const TextStyle(
    fontFamily: _monoFamily,
    fontFamilyFallback: AppTokens.monoFontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppTokens.text,
  ),
  monoLabel: const TextStyle(
    fontFamily: _monoFamily,
    fontFamilyFallback: AppTokens.monoFontFamilyFallback,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: AppTokens.muted,
  ),
  monoCaption: const TextStyle(
    fontFamily: _monoFamily,
    fontFamilyFallback: AppTokens.monoFontFamilyFallback,
    fontSize: 10,
    color: AppTokens.faint,
  ),
  sansHeadline: const TextStyle(
    fontFamily: _sansFamily,
    fontFamilyFallback: AppTokens.sansFontFamilyFallback,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppTokens.text,
  ),
  sansBody: const TextStyle(
    fontFamily: _sansFamily,
    fontFamilyFallback: AppTokens.sansFontFamilyFallback,
    fontSize: 14,
    color: AppTokens.text,
  ),
  sansCaption: const TextStyle(
    fontFamily: _sansFamily,
    fontFamilyFallback: AppTokens.sansFontFamilyFallback,
    fontSize: 12.5,
    color: AppTokens.muted,
  ),
);

/// The Material 3 dark theme, built entirely from [AppTokens]. No colour or
/// font literal belongs in a widget — reach for `Theme.of(context)` and
/// [AppTypographyContext.appTypography] instead.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppTokens.bg,
  colorScheme: const ColorScheme.dark(
    surface: AppTokens.surface,
    onSurface: AppTokens.text,
    primary: AppTokens.accent,
    onPrimary: Color(0xFF04180A),
    secondary: AppTokens.blue,
    onSecondary: AppTokens.bg,
    error: AppTokens.red,
    onError: AppTokens.text,
    outline: AppTokens.border,
    outlineVariant: AppTokens.border2,
  ),
  fontFamily: _sansFamily,
  fontFamilyFallback: AppTokens.sansFontFamilyFallback,
  extensions: <ThemeExtension<dynamic>>[_appTypography],
  appBarTheme: const AppBarTheme(
    backgroundColor: AppTokens.bg,
    foregroundColor: AppTokens.text,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: AppTokens.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(11),
      side: const BorderSide(color: AppTokens.border),
    ),
  ),
  dividerTheme: const DividerThemeData(color: AppTokens.border, space: 1),
  textTheme: TextTheme(
    headlineSmall: _appTypography.sansHeadline,
    bodyLarge: _appTypography.sansBody,
    bodyMedium: _appTypography.sansBody,
    bodySmall: _appTypography.sansCaption,
    labelSmall: _appTypography.monoLabel,
  ),
);
