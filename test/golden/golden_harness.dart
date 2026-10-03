import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Wraps [child] in a saturation-zero [ColorFilter] inside a full
/// [MaterialApp], so every golden rendered through this harness is a
/// greyscale legibility check (SC-015).
///
/// Colour is never allowed to be the sole carrier of meaning: the verdict
/// chip must still read by its word, the heatmap by luminance, insight hits
/// and misses by glyph. Rendering through this filter before diffing turns
/// that requirement into a build failure rather than a design-review note.
///
/// Carries the same `localizationsDelegates`/`supportedLocales` as
/// `app.dart`'s real `MaterialApp.router` — every screen resolves its
/// copy through `AppLocalizations.of(context)!`, which throws with no
/// delegate in the tree, so a golden of any real screen was unreachable
/// until this harness carried them too.
Widget goldenHarness(Widget child) {
  return MaterialApp(
    theme: appTheme,
    debugShowCheckedModeBanner: false,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: ColorFiltered(
      colorFilter: const ColorFilter.matrix(_greyscaleMatrix),
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    ),
  );
}

/// A standard luminance-preserving saturation-zero matrix (Rec. 601 weights).
const List<double> _greyscaleMatrix = <double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];
