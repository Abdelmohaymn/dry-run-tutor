// Constitution VII / FR-011: there is no audio pipeline at all.
// `speech_to_text` hands the feature text and a sound-level stream, so
// nothing under `lib/features/voice/` should ever need a file or a
// socket. `tools/lints/lib/src/no_io_in_voice_feature.dart` enforces this
// as a `custom_lint` rule; this test asserts the same import boundary
// directly against source, so the guarantee survives even if lint
// tooling is ever skipped in a run.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nothing under lib/features/voice/ imports dart:io, path_provider, dio, or http', () {
    final Directory voiceDir =
        Directory('${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}features${Platform.pathSeparator}voice');
    expect(voiceDir.existsSync(), isTrue, reason: 'lib/features/voice/ must exist');

    const List<String> bannedExact = <String>['dart:io'];
    const List<String> bannedPackagePrefixes = <String>[
      'package:path_provider/',
      'package:dio/',
      'package:http/',
    ];

    final List<File> dartFiles = voiceDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    expect(dartFiles, isNotEmpty);

    final RegExp importPattern = RegExp("^import\\s+['\"]([^'\"]+)['\"]", multiLine: true);
    final List<String> violations = <String>[];

    for (final File file in dartFiles) {
      final String contents = file.readAsStringSync();
      for (final RegExpMatch match in importPattern.allMatches(contents)) {
        final String uri = match.group(1)!;
        final bool banned = bannedExact.contains(uri) ||
            bannedPackagePrefixes.any((String prefix) => uri.startsWith(prefix));
        if (banned) {
          violations.add('${file.path}: import "$uri"');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
