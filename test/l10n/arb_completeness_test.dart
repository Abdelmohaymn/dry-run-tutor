// T160 (Polish), FR-052: every learner-facing string resolves through an
// ARB key. `tools/lints/no_string_literals_in_widgets.dart` (T052) is the
// AST-precise version of this check, but `custom_lint` findings surface
// at INFO severity under plain `flutter analyze` — they do not fail CI
// the way the constitution's "zero warnings" bar implies. This is the
// coarser, `dart:io`-based backstop that actually runs as part of
// `flutter test` (`no_absolutes_test.dart`'s pattern), so a bare string
// literal handed to `Text(...)` under `lib/features/` fails a build
// regardless of custom_lint's severity configuration.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A `Text(` call whose first argument opens with a quote — a string
/// literal, not an `l10n.someKey` reference or a variable. Deliberately
/// simple (no full AST parse, matching this file's `dart:io` sibling)
/// rather than precise about every possible Dart expression shape; it
/// still catches exactly what T052's lint targets — a raw string handed
/// straight to `Text`. A string that opens with `${` only joins values that
/// were already resolved (e.g. an error copy and its code), so it is let
/// through; any literal words before the first `${` still fail.
final RegExp _textLiteralCall = RegExp('''Text\\(\\s*['"](?!\\\$\\{)''');

/// Widgets with no learner-facing copy of their own are exempt by
/// directory or by name, mirroring T052's own lint scope and
/// `placeholder_screen.dart`'s explicit carve-out (nothing rendered
/// there ever ships).
const List<String> _exemptBasenames = <String>['placeholder_screen.dart'];

void main() {
  test('no widget under lib/features/ hands Text() a bare string literal', () {
    final Directory featuresDir = Directory('lib/features');
    expect(featuresDir.existsSync(), isTrue, reason: 'lib/features/ must exist');

    final List<String> violations = <String>[];
    for (final FileSystemEntity entity in featuresDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String basename = entity.path.split(Platform.pathSeparator).last;
      if (_exemptBasenames.contains(basename)) {
        continue;
      }
      final String contents = entity.readAsStringSync();
      for (final RegExpMatch match in _textLiteralCall.allMatches(contents)) {
        final int line = '\n'.allMatches(contents.substring(0, match.start)).length + 1;
        violations.add('${entity.path}:$line');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Text() called with a bare string literal (should route through an ARB key):\n${violations.join('\n')}',
    );
  });
}
