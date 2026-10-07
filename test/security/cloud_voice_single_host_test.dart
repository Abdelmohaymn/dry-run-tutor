// Cloud voice single-host backstop: recorded audio leaves the device only
// through `RelayClient`, and therefore only through the host allowlist.
// Nothing under `lib/features/cloud_voice/` may open its own HTTP channel,
// so it must not import `package:dio/` or `package:http/`. This test checks
// the import boundary directly against source, independent of lint tooling.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nothing under lib/features/cloud_voice/ imports or exports dio or http', () {
    final Directory cloudVoiceDir = Directory(
      <String>[Directory.current.path, 'lib', 'features', 'cloud_voice'].join(Platform.pathSeparator),
    );
    expect(cloudVoiceDir.existsSync(), isTrue, reason: 'lib/features/cloud_voice/ must exist');

    const List<String> bannedPackagePrefixes = <String>['package:dio/', 'package:http/'];

    final List<File> dartFiles = cloudVoiceDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    expect(dartFiles, isNotEmpty);

    final RegExp directivePattern = RegExp("^(?:import|export)\\s+['\"]([^'\"]+)['\"]", multiLine: true);
    final List<String> violations = <String>[];

    for (final File file in dartFiles) {
      final String contents = file.readAsStringSync();
      for (final RegExpMatch match in directivePattern.allMatches(contents)) {
        final String uri = match.group(1)!;
        if (bannedPackagePrefixes.any((String prefix) => uri.startsWith(prefix))) {
          violations.add('${file.path}: "$uri"');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
